import Link from "next/link";
import { Card, Flash, PageHeader, Table, Td, Th } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";

type Stats = Record<string, number>;
type ReportRow = {
  source: string;
  campaign: string;
  installs: number;
  registrations: number;
  buyers: number;
};

export default async function Dashboard({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const { supabase, role } = await requireAdmin();
  const { data } = await supabase.rpc("admin_dashboard");
  const s = (data ?? {}) as Stats;

  let report: ReportRow[] = [];
  if (role === "owner") {
    const { data: rows } = await supabase.rpc("attribution_report");
    report = (rows ?? []) as ReportRow[];
  }

  const tiles = [
    { label: "Installs from ads", value: s.installs_ads },
    { label: "Organic installs", value: s.installs_organic },
    { label: "App users", value: s.users },
    { label: "Logged in", value: s.registered },
    { label: "Premium users", value: s.premium },
    { label: "Channels", value: s.channels },
    { label: "Published posts", value: s.posts_published },
  ];

  return (
    <>
      <PageHeader title="Dashboard" subtitle="Overview of installs, users and content" />
      <Flash error={error === "owner_only" ? "That page is only available to the owner." : undefined} />

      {role === "owner" && s.pending_approvals > 0 && (
        <Link
          href="/approvals"
          className="mb-6 flex items-center justify-between rounded-xl bg-red-700 px-5 py-4 text-white shadow-sm hover:bg-red-800"
        >
          <span className="font-medium">
            {s.pending_approvals} organic buyer{s.pending_approvals === 1 ? "" : "s"} waiting for approval
          </span>
          <span className="text-sm">Review →</span>
        </Link>
      )}

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {tiles.map((t) => (
          <Card key={t.label}>
            <p className="text-sm text-gray-500">{t.label}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">{t.value ?? 0}</p>
          </Card>
        ))}
      </div>

      {role === "owner" && (
        <section className="mt-8">
          <h2 className="mb-3 text-lg font-semibold">Installs by source and campaign</h2>
          {report.length === 0 ? (
            <p className="text-sm text-gray-500">No installs yet.</p>
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>Source</Th>
                  <Th>Campaign</Th>
                  <Th className="text-right">Installs</Th>
                  <Th className="text-right">Logged in</Th>
                  <Th className="text-right">Buyers</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {report.map((r) => (
                  <tr key={`${r.source}-${r.campaign}`}>
                    <Td>{r.source}</Td>
                    <Td>{r.campaign || "—"}</Td>
                    <Td className="text-right tabular-nums">{r.installs}</Td>
                    <Td className="text-right tabular-nums">{r.registrations}</Td>
                    <Td className="text-right tabular-nums">{r.buyers}</Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </section>
      )}
    </>
  );
}
