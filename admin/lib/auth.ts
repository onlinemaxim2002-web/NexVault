import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type AdminRole = "owner" | "content_admin";

// Every panel page and action starts here: signed in AND listed in admins.
export async function requireAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: admin } = await supabase
    .from("admins")
    .select("role")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!admin) redirect("/login?error=not_admin");

  return { supabase, user, role: admin.role as AdminRole };
}

export async function requireOwner() {
  const ctx = await requireAdmin();
  if (ctx.role !== "owner") redirect("/?error=owner_only");
  return ctx;
}
