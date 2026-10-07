"use server";

import { createPublicClient } from "@/lib/supabase/server";

export type FormState = { ok?: string; error?: string; values?: Record<string, string> };

const field = (f: FormData, k: string) => String(f.get(k) ?? "").trim();

// Keep what the visitor typed when we show an error (the form is reset after submit).
const fail = (error: string, f: FormData): FormState => ({
  error,
  values: Object.fromEntries([...f.entries()].map(([k, v]) => [k, String(v)])),
});

// Public forms (no login): account deletion requests and content reports.
export async function requestDeletion(_: FormState, form: FormData): Promise<FormState> {
  if (form.get("confirm") !== "on") return fail("Please tick the box to confirm.", form);
  const { error } = await createPublicClient().rpc("submit_support_request", {
    p_kind: "delete_account",
    p_email: field(form, "email"),
    p_details: field(form, "reason") || null,
  });
  if (error) return fail(error.message, form);
  return { ok: "Request received. We will delete your account and reply by email within 7 days." };
}

export async function reportContent(_: FormState, form: FormData): Promise<FormState> {
  if (form.get("confirm") !== "on") return fail("Please tick the box to confirm the statement.", form);
  const { error } = await createPublicClient().rpc("submit_support_request", {
    p_kind: "content_report",
    p_email: field(form, "email"),
    p_name: field(form, "name") || null,
    p_content_url: field(form, "content_url") || null,
    p_details: field(form, "details"),
  });
  if (error) return fail(error.message, form);
  return { ok: "Report received. We review reports quickly and remove content that breaks our rules." };
}
