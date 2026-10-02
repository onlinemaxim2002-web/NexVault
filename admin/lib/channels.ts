import type { SupabaseClient } from "@supabase/supabase-js";
import type { ChannelOption } from "@/components/post-form";

// Channels with their folders, for the post form.
export async function loadChannelOptions(supabase: SupabaseClient): Promise<ChannelOption[]> {
  const { data } = await supabase
    .from("channels")
    .select("id, name, audience, channel_folders(id, name, position)")
    .order("name");
  return (data ?? []).map((c) => ({
    id: c.id,
    name: c.name,
    audience: c.audience,
    folders: [...(c.channel_folders ?? [])]
      .sort((a, b) => a.position - b.position)
      .map((f) => ({ id: f.id, name: f.name })),
  }));
}
