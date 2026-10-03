// Bank / payment-provider hook for UPI payments (source 'provider_api').
//
// NOT DEPLOYED. It is ready for when your bank or payment aggregator gives you
// a payment callback (webhook) or a transaction-status API. Every bank sends a
// different format and signs it differently, so adapt `parse()` and
// `verify()` to their documentation before deploying:
//
//   supabase secrets set UPI_WEBHOOK_SECRET=<long random string>
//   supabase functions deploy upi-webhook --no-verify-jwt
//
// It only ever calls provider_confirm_payment(), which runs the same checks as
// every other path (amount must match, each UTR once, idempotent). Without
// UPI_WEBHOOK_SECRET it refuses every request.
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

// Constant-time comparison of the shared secret.
function safeEqual(a: string, b: string) {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

// Replace with your bank's signature check (often an HMAC of the raw body).
function verify(req: Request, secret: string) {
  return safeEqual(req.headers.get("x-webhook-secret") ?? "", secret);
}

type Confirmation = { reference: string; amountPaise: number; utr: string; success: boolean };

// Replace with your bank's payload format. Expected here:
// { "reference": "CS2610…", "amount": "129.00", "utr": "627312345678", "status": "SUCCESS" }
function parse(body: Record<string, unknown>): Confirmation | null {
  const reference = String(body.reference ?? body.tr ?? "").trim().toUpperCase();
  const utr = String(body.utr ?? body.rrn ?? "").trim().toUpperCase();
  const amount = Number(body.amount);
  if (!reference || !utr || !Number.isFinite(amount)) return null;
  return {
    reference,
    utr,
    amountPaise: Math.round(amount * 100),
    success: String(body.status ?? "").toUpperCase() === "SUCCESS",
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const secret = Deno.env.get("UPI_WEBHOOK_SECRET");
  if (!secret) return json({ error: "webhook not configured" }, 503);
  if (!verify(req, secret)) return json({ error: "unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }
  const c = parse(body);
  if (!c) return json({ error: "missing reference, amount or utr" }, 400);
  if (!c.success) return json({ ok: true, ignored: "not a success" });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data, error } = await admin.rpc("provider_confirm_payment", {
    p_reference: c.reference,
    p_amount_paise: c.amountPaise,
    p_utr: c.utr,
  });
  if (error) return json({ ok: false, error: error.message }, 422);
  return json({ ok: true, result: data });
});
