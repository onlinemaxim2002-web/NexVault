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
import { dismissPlanRequest, grantPremium, setAdsAccess } from "./actions";

type PlanRequest = {
  id: string;
  user_id: string;
  email: string;
  display_name: string;
  source: "ads" | "organic";
  plan_code: string;
  plan_name: string;
  created_at: string;
};

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

  const [{ data }, { data: plans }, { data: requestRows }] = await Promise.all([
    supabase.rpc("admin_users", { p_filter: filter, p_search: q || null, p_limit: 200 }),
    supabase.from("plans").select("code, name").eq("active", true).order("position"),
    supabase.rpc("admin_plan_requests"),
  ]);
  const users = (data ?? []) as AppUser[];
  const requests = (requestRows ?? []) as PlanRequest[];

  return (
    <>
      <PageHeader title="Users" subtitle="App users, where they came from, and their plans." />
      <Flash ok={sp.ok} error={sp.error} />

      {requests.length > 0 && (
        <section className="mb-8">
          <h2 className="mb-2 font-semibold">Plan requests ({requests.length})</h2>
          <p className="mb-3 text-sm text-gray-500">
            Users who picked a plan in the app. Payments aren&apos;t connected yet, so grant the plan here.
          </p>
          <Table>
            <thead>
              <tr>
                <Th>User</Th>
                <Th>Source</Th>
                <Th>Requested</Th>
                <Th>When</Th>
                <Th className="text-right">Action</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {requests.map((r) => (
                <tr key={r.id} className="bg-amber-50/60">
                  <Td>
                    <p className="font-medium">{r.display_name}</p>
                    <p className="text-xs text-gray-500">{r.email}</p>
                  </Td>
                  <Td><SourceBadge source={r.source} /></Td>
                  <Td><Badge tone="amber">👑 {r.plan_name}</Badge></Td>
                  <Td className="whitespace-nowrap">{formatDate(r.created_at)}</Td>
                  <Td className="text-right">
                    <div className="flex justify-end gap-2">
                      <form action={grantPremium.bind(null, r.user_id, back)}>
                        <input type="hidden" name="plan" value={r.plan_code} />
                        <Button variant="success" type="submit">Grant {r.plan_name}</Button>
                      </form>
                      <form action={dismissPlanRequest.bind(null, r.id, back)}>
                        <Button variant="secondary" type="submit">Dismiss</Button>
                      </form>
                    </div>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </section>
      )}

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
