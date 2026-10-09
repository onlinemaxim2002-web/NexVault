import { redirect } from "next/navigation";
import { getAdminContext } from "@/lib/admin-access";
import { createClient } from "@/lib/supabase/server";

export type { AdminRole } from "@/lib/admin-access";

// Every panel page and action starts here: signed in AND listed in admins.
export async function requireAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const admin = await getAdminContext(supabase, user.id);
  if (!admin) redirect("/login?error=not_admin");

  return { supabase, user, role: admin.role };
}

export async function requireOwner() {
  const ctx = await requireAdmin();
  if (ctx.role !== "owner") redirect("/?error=owner_only");
  return ctx;
}
