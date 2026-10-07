"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOwner } from "@/lib/auth";
import { withMessage } from "@/lib/format";
import { createServiceClient } from "@/lib/supabase/server";

export async function closeRequest(id: string, status: "done" | "rejected" | "open", back: string, form: FormData) {
  const { supabase } = await requireOwner();
  const { error } = await supabase.rpc("admin_close_support_request", {
    p_id: id,
    p_status: status,
    p_note: String(form.get("note") ?? "").trim() || null,
  });
  if (error) redirect(withMessage(back, "error", error.message));
  revalidatePath("/requests");
  redirect(withMessage(back, "ok", status === "open" ? "Reopened." : "Request closed."));
}

// Website deletion request: delete the matching account (same steps as the
// app's delete-account function), then close the request.
export async function deleteRequestedAccount(id: string, back: string) {
  const { supabase } = await requireOwner();
  const { data: req } = await supabase.from("support_requests").select("user_id, kind").eq("id", id).maybeSingle();
  if (!req || req.kind !== "delete_account" || !req.user_id) {
    redirect(withMessage(back, "error", "No account matches this request."));
  }
  const admin = createServiceClient();
  const { data: isAdmin } = await admin.from("admins").select("user_id").eq("user_id", req.user_id).maybeSingle();
  if (isAdmin) redirect(withMessage(back, "error", "This is an admin account. Remove it under Admins instead."));

  const { data: files } = await admin.from("cloud_files").select("storage_key").eq("user_id", req.user_id);
  const keys = (files ?? []).map((f) => f.storage_key as string | null).filter((k): k is string => !!k);
  for (let i = 0; i < keys.length; i += 100) await admin.storage.from("cloud").remove(keys.slice(i, i + 100));
  const { error } = await admin.auth.admin.deleteUser(req.user_id);
  if (error) redirect(withMessage(back, "error", error.message));

  await supabase.rpc("admin_close_support_request", { p_id: id, p_status: "done", p_note: "Account deleted" });
  revalidatePath("/requests");
  redirect(withMessage(back, "ok", "Account and its data deleted. Reply to the user by email to confirm."));
}
