// Deletes the calling user's account (Settings → Delete account in the app).
// Uses the Auth admin API with the service role, which only exists on the server.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // Who is calling? Resolve the user from their own access token.
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) return json({ error: "not signed in" }, 401);
  const userId = userData.user.id;

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // Admin accounts are managed from the admin panel, not the app.
  const { data: isAdmin } = await admin.from("admins").select("user_id").eq("user_id", userId).maybeSingle();
  if (isAdmin) return json({ error: "admin accounts can't be deleted from the app" }, 403);

  // Remove the user's personal cloud files first (database rows cascade with the user).
  const { data: files } = await admin.from("cloud_files").select("storage_key").eq("user_id", userId);
  const keys = (files ?? []).map((f) => f.storage_key).filter((k): k is string => !!k);
  for (let i = 0; i < keys.length; i += 100) {
    await admin.storage.from("cloud").remove(keys.slice(i, i + 100));
  }

  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) return json({ error: error.message }, 500);
  return json({ deleted: true });
});
