"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// Exact Supabase Auth identity verified against the production database.
const ADMIN_EMAIL = "perfumwala@gmail.com";
const ADMIN_USER_ID = "efc36630-092b-444b-8ac6-319f838eae76";

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) redirect("/login?error=invalid");

  const authenticatedEmail = (data.user.email ?? "").trim().toLowerCase();
  const isAllowedAdmin =
    data.user.id === ADMIN_USER_ID || authenticatedEmail === ADMIN_EMAIL;

  if (!isAllowedAdmin) {
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
