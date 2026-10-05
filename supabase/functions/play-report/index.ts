// Reports approved UPI payments made in the Google Play build to Google Play
// ("alternative billing only"), and refunds when a payment is revoked.
// Woken every 5 minutes by pg_cron (public.play_report_tick) while there is
// work. Needs the secret GOOGLE_SERVICE_ACCOUNT_JSON (a service account with
// access to the app in Play Console). Safe to call any time: it only sends
// what is queued, and Google rejects duplicates.
import { createClient } from "npm:@supabase/supabase-js@2";

const API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

function b64url(data: ArrayBuffer | string) {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function googleToken(sa: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`Google sign-in failed: ${JSON.stringify(json).slice(0, 300)}`);
  return json.access_token as string;
}

Deno.serve(async () => {
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const done = async (error: string | null, body: Record<string, unknown>) => {
    await db.from("play_settings").update({ last_run_at: new Date().toISOString(), last_error: error }).eq("id", 1);
    return Response.json(body, { status: error ? 500 : 200 });
  };

  const { data: settings } = await db.from("play_settings").select("package_name, enabled").eq("id", 1).single();
  if (!settings?.enabled) return Response.json({ skipped: "disabled" });
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!raw) return done("GOOGLE_SERVICE_ACCOUNT_JSON secret is not set", { error: "no credentials" });

  let token: string;
  try {
    token = await googleToken(JSON.parse(raw));
  } catch (e) {
    return done(String(e), { error: "auth" });
  }

  const { data: orders, error } = await db
    .from("payment_orders")
    .select("id, reference, amount_paise, verified_at, created_at, play_token, play_report_status, play_attempts")
    .in("play_report_status", ["pending", "refund_pending"])
    .not("play_token", "is", null)
    .order("verified_at")
    .limit(50);
  if (error) return done(error.message, { error: "query" });

  const base = `${API}/${settings.package_name}/externalTransactions`;
  const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
  let ok = 0;
  let failed = 0;
  for (const o of orders ?? []) {
    const refund = o.play_report_status === "refund_pending";
    const micros = String(BigInt(o.amount_paise) * 10000n); // paise → micros (1 ₹ = 1,000,000)
    const res = refund
      ? await fetch(`${base}/${o.reference}:refundExternalTransaction`, {
          method: "POST",
          headers,
          body: JSON.stringify({ refundTime: new Date().toISOString(), fullRefund: {} }),
        })
      : await fetch(`${base}?externalTransactionId=${encodeURIComponent(o.reference)}`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            // Prices are reported as entered in the plans (tax 0). If you
            // charge GST, report the pre-tax part and the GST separately.
            originalPreTaxAmount: { priceMicros: micros, currency: "INR" },
            originalTaxAmount: { priceMicros: "0", currency: "INR" },
            transactionTime: new Date(o.verified_at ?? o.created_at).toISOString(),
            oneTimeTransaction: { externalTransactionToken: o.play_token },
            userTaxAddress: { regionCode: "IN" },
          }),
        });
    const text = await res.text();
    const duplicate = res.status === 409 || /ALREADY_EXISTS/i.test(text);
    if (res.ok || duplicate) {
      ok++;
      await db.from("payment_orders").update({
        play_report_status: refund ? "refunded" : "reported",
        play_reported_at: new Date().toISOString(),
        play_report_error: null,
      }).eq("id", o.id);
    } else {
      failed++;
      const attempts = (o.play_attempts ?? 0) + 1;
      await db.from("payment_orders").update({
        play_attempts: attempts,
        play_report_error: `${res.status}: ${text.slice(0, 500)}`,
        play_report_status: attempts >= 12 ? "failed" : o.play_report_status,
      }).eq("id", o.id);
    }
  }
  return done(failed ? `${failed} report(s) failed — see Payments` : null, { reported: ok, failed });
});
