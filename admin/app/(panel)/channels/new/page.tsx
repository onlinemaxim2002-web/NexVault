import { ChannelForm } from "@/components/channel-form";
import { Card, Flash, PageHeader } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { createChannel } from "../actions";

export default async function NewChannelPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  await requireAdmin();
  return (
    <>
      <PageHeader title="New channel" />
      <Flash error={error} />
      <Card>
        <ChannelForm action={createChannel} submitLabel="Create channel" />
      </Card>
    </>
  );
}
