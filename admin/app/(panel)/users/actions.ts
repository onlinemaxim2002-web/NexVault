"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOwner } from "@/lib/auth";
import { withMessage } from "@/lib/format";

const messages: Record<string, string> = {
  approved: "Approved. They can now see Ads-only content.",
  rejected: "Rejected. They keep seeing Everyone + Organic content.",
  none: "Approval removed.",
};

export async function setAdsAccess(userId: string, status: string, back: string) {
  const { supabase } = await requireOwner();
  const { error } = await supabase.rpc("set_ads_access", { p_user_id: userId, p_status: status });
  if (error) redirect(withMessage(back, "error", error.message));
  revalidatePath("/", "layout");
  redirect(withMessage(back, "ok", messages[status] ?? "Saved."));
}

export async function grantPremium(userId: string, back: string, formData: FormData) {
  const { supabase } = await requireOwner();
  const plan = String(formData.get("plan") ?? "");
  const { error } = await supabase.rpc("grant_premium", { p_user_id: userId, p_plan_code: plan });
  if (error) redirect(withMessage(back, "error", error.message));
  revalidatePath("/", "layout");
  redirect(withMessage(back, "ok", "Premium granted."));
}

export async function dismissPlanRequest(requestId: string, back: string) {
  const { supabase } = await requireOwner();
  const { error } = await supabase.from("plan_requests").update({ status: "dismissed" }).eq("id", requestId);
  if (error) redirect(withMessage(back, "error", error.message));
  revalidatePath("/", "layout");
  redirect(withMessage(back, "ok", "Request dismissed."));
}
