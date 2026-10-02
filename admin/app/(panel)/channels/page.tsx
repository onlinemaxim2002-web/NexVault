import Link from "next/link";
import {
  AudienceBadge,
  Empty,
  Flash,
  LinkButton,
  PageHeader,
  StatusBadge,
  Table,
  Td,
  Th,
} from "@/components/ui";
import { requireAdmin } from "@/lib/auth";

type Row = {
  id: string;
  name: string;
  category: string | null;
  audience: string;
  status: string;
  members_count: number;
  channel_folders: { count: number }[];
  posts: { count: number }[];
};

export default async function ChannelsPage({
  searchParams,
}: {
  searchParams: Promise<{ ok?: string; error?: string; audience?: string }>;
}) {
  const { ok, error, audience } = await searchParams;
  const { supabase } = await requireAdmin();

  let query = supabase
    .from("channels")
    .select("id, name, category, audience, status, members_count, channel_folders(count), posts(count)")
    .order("created_at", { ascending: false });
  if (audience) query = query.eq("audience", audience);
  const { data } = await query;
  const rows = (data ?? []) as Row[];

  const filters = [
    { value: "", label: "All" },
    { value: "all", label: "Everyone" },
    { value: "organic", label: "Organic only" },
    { value: "ads", label: "Ads only" },
  ];

  return (
    <>
      <PageHeader
        title="Channels"
        subtitle="Channels hold folders and posts. Their posts also appear in Explore."
        action={<LinkButton href="/channels/new">New channel</LinkButton>}
      />
      <Flash ok={ok} error={error} />

      <div className="mb-4 flex flex-wrap gap-2">
        {filters.map((f) => (
          <Link
            key={f.value}
            href={f.value ? `/channels?audience=${f.value}` : "/channels"}
            className={`rounded-full px-3 py-1 text-sm ${
              (audience ?? "") === f.value ? "bg-red-700 text-white" : "bg-white text-gray-700 ring-1 ring-gray-300"
            }`}
          >
            {f.label}
          </Link>
        ))}
      </div>

      {rows.length === 0 ? (
        <Empty>No channels yet. Create your first channel to start posting.</Empty>
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>Channel</Th>
              <Th>Audience</Th>
              <Th>Status</Th>
              <Th className="text-right">Members</Th>
              <Th className="text-right">Folders</Th>
              <Th className="text-right">Posts</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {rows.map((c) => (
              <tr key={c.id} className="hover:bg-gray-50">
                <Td>
                  <Link href={`/channels/${c.id}`} className="font-medium text-gray-900 hover:text-red-700">
                    {c.name}
                  </Link>
                  {c.category && <p className="text-xs text-gray-500">{c.category}</p>}
                </Td>
                <Td><AudienceBadge audience={c.audience} /></Td>
                <Td><StatusBadge status={c.status} /></Td>
                <Td className="text-right tabular-nums">{c.members_count}</Td>
                <Td className="text-right tabular-nums">{c.channel_folders[0]?.count ?? 0}</Td>
                <Td className="text-right tabular-nums">{c.posts[0]?.count ?? 0}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </>
  );
}
