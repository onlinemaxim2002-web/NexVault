import { PostForm } from "@/components/post-form";
import { Card, Flash, PageHeader } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { loadChannelOptions } from "@/lib/channels";
import { createPost } from "../actions";

export default async function NewPostPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; channel?: string }>;
}) {
  const { error, channel } = await searchParams;
  const { supabase } = await requireAdmin();
  const channels = await loadChannelOptions(supabase);

  return (
    <>
      <PageHeader title="New post" subtitle="Create the post, then add its videos and images." />
      <Flash error={error} />
      <Card>
        <PostForm
          action={createPost}
          channels={channels}
          values={channel ? { channel_id: channel } : undefined}
          submitLabel="Create post"
        />
      </Card>
    </>
  );
}
