"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// Explicit allowlist for the verified NexVault owner/admin account.
const ADMIN_EMAIL = "perfumwala@gmail.com";

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) redirect("/login?error=invalid");

  // Allow only the exact verified admin email, using the email returned by
  // Supabase Auth (not the untrusted form input).
  if ((data.user.email ?? "").trim().toLowerCase() !== ADMIN_EMAIL) {
    await supabase.auth.signOut();
    redirect("/login?error=not_admin");
  }

  redirect("/");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
