import type { SupabaseClient } from "@supabase/supabase-js";

export type AdminRole = "owner" | "content_admin";

export type AdminContext = {
  role: AdminRole;
  source: "admins" | "legacy_profiles";
};

// The current production database still uses profiles.role while the NexVault
// migration set uses admins. Checking both is intentional during the schema
// transition; neither branch trusts form input or client-side state.
export async function getAdminContext(supabase: SupabaseClient, userId: string): Promise<AdminContext | null> {
  const { data: admin } = await supabase
    .from("admins")
    .select("role")
    .eq("user_id", userId)
    .maybeSingle();

  if (admin?.role === "owner" || admin?.role === "content_admin") {
    return { role: admin.role, source: "admins" };
  }

  const { data: profile } = await supabase.from("profiles").select("role").eq("id", userId).maybeSingle();
  if (profile?.role === "admin") {
    return { role: "owner", source: "legacy_profiles" };
  }

  return null;
}
