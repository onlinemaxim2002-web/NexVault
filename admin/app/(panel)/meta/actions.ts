"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOwner } from "@/lib/auth";
import { withMessage } from "@/lib/format";

export async function saveMeta(formData: FormData) {
  const { supabase } = await requireOwner();
  const pixel = String(formData.get("pixel_id") ?? "").trim();
  const token = String(formData.get("access_token") ?? "").trim();
  const testCode = String(formData.get("test_event_code") ?? "").trim();
  const source = String(formData.get("action_source") ?? "website");
  const origin = String(formData.get("origin") ?? "").trim();
  const apkUrl = String(formData.get("apk_url") ?? "").trim();
  const title = String(formData.get("page_title") ?? "").trim().slice(0, 60);
  const subtitle = String(formData.get("page_subtitle") ?? "").trim().slice(0, 160);
  // Website events point to the download page.
  const website = /^https?:\/\//.test(origin) ? `${origin}/d` : "";
  const enabled = formData.get("enabled") === "on";

  if (pixel && !/^[0-9]{5,20}$/.test(pixel)) {
    redirect(withMessage("/meta", "error", "The Pixel ID is a number (find it in Events Manager)."));
  }
  if (enabled && (!pixel || (!token && formData.get("has_token") !== "1"))) {
    redirect(withMessage("/meta", "error", "Enter the Pixel ID and access token before turning tracking on."));
  }
  if (apkUrl && !/^https?:\/\//.test(apkUrl)) {
    redirect(withMessage("/meta", "error", "The APK link must start with https://"));
  }

  const update: Record<string, unknown> = {
    pixel_id: pixel || null,
    test_event_code: testCode || null,
    action_source: source === "app" ? "app" : "website",
    apk_url: apkUrl || null,
    page_title: title || "Flixvault",
    page_subtitle: subtitle || "Premium videos, trailers and 2 TB cloud storage — all in one app.",
    enabled,
    updated_at: new Date().toISOString(),
  };
  if (website) update.website_url = website;
  // An empty token field keeps the saved token.
  if (token) update.access_token = token;

  const { error, count } = await supabase.from("meta_settings").update(update, { count: "exact" }).eq("id", 1);
  if (error) redirect(withMessage("/meta", "error", error.message));
  if (count === 0) redirect(withMessage("/meta", "error", "You don't have permission to change this."));
  revalidatePath("/meta");
  redirect(withMessage("/meta", "ok", enabled ? "Saved. Tracking is on." : "Saved. Tracking is off."));
}

export async function sendTestEvent() {
  const { supabase } = await requireOwner();
  const { error } = await supabase.rpc("admin_meta_test_event");
  if (error) redirect(withMessage("/meta", "error", error.message));
  redirect(
    withMessage(
      "/meta",
      "ok",
      "Test event sent. Refresh this page in a minute to see Meta's answer, and check Events Manager → Test events.",
    ),
  );
}
