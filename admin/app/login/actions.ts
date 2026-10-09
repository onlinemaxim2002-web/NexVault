"use server";

import { redirect } from "next/navigation";
import { createClient, createServiceClient } from "@/lib/supabase/server";

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) redirect("/login?error=invalid");

  // Check the admin role with a server-only client so profiles RLS cannot
  // incorrectly hide the signed-in user's admin row.
  let profile: { role: string } | null = null;
  try {
    const adminCheck = createServiceClient();
    const result = await adminCheck
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .eq("role", "admin")
      .maybeSingle();
    if (!result.error) profile = result.data;
  } catch {
    // Missing server-only key or database error: fail closed.
  }

  if (!profile) {
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
