"use server";

import { redirect } from "next/navigation";
import { getAdminContext } from "@/lib/admin-access";
import { createClient } from "@/lib/supabase/server";

function supabaseHostname() {
  try {
    return new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? "").hostname || null;
  } catch {
    return null;
  }
}

function authErrorDetails(error: { code?: string; message?: string } | null) {
  if (!error) return null;
  return {
    code: error.code ?? null,
    message: (error.message ?? "").replace(/\s+/g, " ").slice(0, 160),
  };
}

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  console.info("admin_login_auth_result", {
    authenticationError: !!error,
    authenticationErrorDetails: authErrorDetails(error),
    userExists: !!data.user,
    userId: data.user?.id ?? null,
    normalizedEmail: (data.user?.email ?? "").trim().toLowerCase() || null,
    supabaseHostname: supabaseHostname(),
  });

  if (error || !data.user) {
    console.info("admin_login_redirect", { destination: "invalid", supabaseHostname: supabaseHostname() });
    redirect("/login?error=invalid");
  }

  const admin = await getAdminContext(supabase, data.user.id);
  const isAllowedAdmin = !!admin;
  console.info("admin_login_authorization", {
    userId: data.user.id,
    normalizedEmail: (data.user.email ?? "").trim().toLowerCase() || null,
    isAllowedAdmin,
    authorizationSource: admin?.source ?? null,
    supabaseHostname: supabaseHostname(),
  });

  if (!isAllowedAdmin) {
    await supabase.auth.signOut();
    console.info("admin_login_redirect", { destination: "not_admin", supabaseHostname: supabaseHostname() });
    redirect("/login?error=not_admin");
  }

  console.info("admin_login_redirect", { destination: "dashboard", supabaseHostname: supabaseHostname() });
  redirect("/");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
