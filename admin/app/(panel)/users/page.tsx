import {
  Badge,
  Button,
  Empty,
  Flash,
  Input,
  PageHeader,
  Select,
  SourceBadge,
  Table,
  Td,
  Th,
} from "@/components/ui";
import { requireOwner } from "@/lib/auth";
import { formatDate } from "@/lib/format";
import type { AppUser } from "@/lib/users";
import { grantPremium, setAdsAccess } from "./actions";

const filters = [
  { value: "all", label: "All users" },
  { value: "ads", label: "From ads" },
  { value: "organic", label: "Organic" },
  { value: "premium", label: "Premium" },
  { value: "pending", label: "Waiting for approval" },
  { value: "approved", label: "Approved" },
];

function AccessBadge({ status }: { status: AppUser["ads_access_status"] }) {
  if (status === "pending") return <Badge tone="amber">Waiting</Badge>;
  if (status === "approved") return <Badge tone="green">Approved</Badge>;
  if (status === "rejected") return <Badge tone="red">Rejected</Badge>;
  return null;
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ ok?: string; error?: string; filter?: string; q?: string }>;
}) {
  const sp = await searchParams;
  const filter = sp.filter ?? "all";
  const q = sp.q ?? "";
  const back = `/users?filter=${filter}&q=${encodeURIComponent(q)}`;
  const { supabase } = await requireOwner();

  const [{ data }, { data: plans }] = await Promise.all([
    supabase.rpc("admin_users", { p_filter: filter, p_search: q || null, p_limit: 200 }),
    supabase.from("plans").select("code, name").eq("active", true).order("position"),
  ]);
  const users = (data ?? []) as AppUser[];

  return (
    <>
      <PageHeader title="Users" subtitle="App users, where they came from, and their plans." />
      <Flash ok={sp.ok} error={sp.error} />

      <form className="mb-4 grid gap-3 sm:grid-cols-[1fr_220px_auto]">
        <Input name="q" defaultValue={q} placeholder="Search name, email or user ID" aria-label="Search" />
        <Select name="filter" defaultValue={filter} aria-label="Filter">
          {filters.map((f) => (
            <option key={f.value} value={f.value}>{f.label}</option>
          ))}
        </Select>
        <Button variant="secondary" type="submit">Search</Button>
      </form>

      {users.length === 0 ? (
        <Empty>No users found.</Empty>
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>User</Th>
              <Th>Source</Th>
              <Th>Plan</Th>
              <Th>Ads content</Th>
              <Th>Joined</Th>
              <Th>Grant premium</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {users.map((u) => (
              <tr key={u.id} className={u.ads_access_status === "pending" ? "bg-amber-50/60" : ""}>
                <Td>
                  <p className="font-medium">{u.display_name}</p>
                  <p className="text-xs text-gray-500">{u.is_guest ? "Guest" : u.email}</p>
                </Td>
                <Td>
                  <SourceBadge source={u.source} />
                  {u.campaign && <p className="mt-1 text-xs text-gray-500">{u.campaign}</p>}
                </Td>
                <Td>
                  {u.plan_name ? (
                    <>
                      <Badge tone="amber">👑 {u.plan_name}</Badge>
                      <p className="mt-1 text-xs text-gray-500">until {formatDate(u.plan_ends_at)}</p>
                    </>
                  ) : (
                    <span className="text-gray-400">Free</span>
                  )}
                </Td>
                <Td>
                  {u.source === "ads" ? (
                    <span className="text-xs text-gray-500">Yes (ads user)</span>
                  ) : (
                    <div className="flex flex-col items-start gap-1">
                      <AccessBadge status={u.ads_access_status} />
                      {u.ads_access_status === "approved" ? (
                        <form action={setAdsAccess.bind(null, u.id, "rejected", back)}>
                          <button className="text-xs text-red-700 hover:underline">Revoke</button>
                        </form>
                      ) : (
                        <form action={setAdsAccess.bind(null, u.id, "approved", back)}>
                          <button className="text-xs text-green-700 hover:underline">Approve</button>
                        </form>
                      )}
                    </div>
                  )}
                </Td>
                <Td className="whitespace-nowrap">{formatDate(u.created_at)}</Td>
                <Td>
                  {u.is_guest ? (
                    <span className="text-xs text-gray-400">Must log in first</span>
                  ) : (
                    <form action={grantPremium.bind(null, u.id, back)} className="flex gap-2">
                      <Select name="plan" aria-label="Plan" defaultValue="gold">
                        {(plans ?? []).map((p) => (
                          <option key={p.code} value={p.code}>{p.name}</option>
                        ))}
                      </Select>
                      <Button variant="secondary" type="submit">Grant</Button>
                    </form>
                  )}
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </>
  );
}
