"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdmin } from "@/lib/auth";
import { withMessage } from "@/lib/format";

function friendly(message: string) {
  return message.includes("row-level security") ? "You don't have permission to change this." : message;
}

function channelFields(formData: FormData) {
  const handle = String(formData.get("handle") ?? "").trim().toLowerCase();
  return {
    name: String(formData.get("name") ?? "").trim(),
    handle: handle || null,
    description: String(formData.get("description") ?? "").trim() || null,
    category: String(formData.get("category") ?? "").trim() || null,
    icon_url: String(formData.get("icon_url") ?? "").trim() || null,
    audience: String(formData.get("audience") ?? "all"),
    status: String(formData.get("status") ?? "draft"),
  };
}

export async function createChannel(formData: FormData) {
  const { supabase, user } = await requireAdmin();
  const fields = channelFields(formData);
  const { data, error } = await supabase
    .from("channels")
    .insert({ ...fields, created_by: user.id })
    .select("id")
    .single();
  if (error) redirect(withMessage("/channels/new", "error", friendly(error.message)));
  revalidatePath("/channels");
  redirect(withMessage(`/channels/${data.id}`, "ok", "Channel created."));
}

export async function updateChannel(id: string, formData: FormData) {
  const { supabase } = await requireAdmin();
  const { error, count } = await supabase
    .from("channels")
    .update({ ...channelFields(formData), updated_at: new Date().toISOString() }, { count: "exact" })
    .eq("id", id);
  const back = `/channels/${id}`;
  if (!error && count === 0) redirect(withMessage(back, "error", "You don't have permission to change this."));
  if (error) {
    const message = error.message.includes("must match its channel audience")
      ? "Some posts in this channel have a different audience. Change those posts first."
      : error.message;
    redirect(withMessage(back, "error", message));
  }
  revalidatePath("/channels");
  redirect(withMessage(back, "ok", "Channel saved."));
}

export async function deleteChannel(id: string) {
  const { supabase } = await requireAdmin();
  const { error, count } = await supabase.from("channels").delete({ count: "exact" }).eq("id", id);
  if (error || count === 0) {
    redirect(withMessage(`/channels/${id}`, "error", "Only the owner can delete channels."));
  }
  revalidatePath("/channels");
  redirect(withMessage("/channels", "ok", "Channel deleted."));
}

export async function addFolder(channelId: string, formData: FormData) {
  const { supabase } = await requireAdmin();
  const name = String(formData.get("name") ?? "").trim();
  const back = `/channels/${channelId}`;
  if (!name) redirect(withMessage(back, "error", "Folder name is required."));
  const { count } = await supabase
    .from("channel_folders")
    .select("id", { count: "exact", head: true })
    .eq("channel_id", channelId);
  const { error } = await supabase
    .from("channel_folders")
    .insert({ channel_id: channelId, name, position: count ?? 0 });
  if (error) redirect(withMessage(back, "error", friendly(error.message)));
  revalidatePath(back);
  redirect(withMessage(back, "ok", "Folder added."));
}

export async function updateFolder(channelId: string, folderId: string, formData: FormData) {
  const { supabase } = await requireAdmin();
  const back = `/channels/${channelId}`;
  const { error, count } = await supabase
    .from("channel_folders")
    .update(
      {
        name: String(formData.get("name") ?? "").trim(),
        position: Number(formData.get("position") ?? 0),
      },
      { count: "exact" },
    )
    .eq("id", folderId);
  if (error) redirect(withMessage(back, "error", error.message));
  if (count === 0) redirect(withMessage(back, "error", "You don't have permission to change this."));
  revalidatePath(back);
  redirect(withMessage(back, "ok", "Folder saved."));
}

export async function deleteFolder(channelId: string, folderId: string) {
  const { supabase } = await requireAdmin();
  const back = `/channels/${channelId}`;
  const { error, count } = await supabase
    .from("channel_folders")
    .delete({ count: "exact" })
    .eq("id", folderId);
  if (error) redirect(withMessage(back, "error", error.message));
  if (count === 0) redirect(withMessage(back, "error", "You don't have permission to change this."));
  revalidatePath(back);
  redirect(withMessage(back, "ok", "Folder deleted. Its posts stay in the channel."));
}
