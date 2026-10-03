import Link from "next/link";
import { Badge, Button, Card, Empty, Flash, Input, PageHeader, SourceBadge, Table, Td, Th } from "@/components/ui";
import { requireOwner } from "@/lib/auth";
import { formatDate } from "@/lib/format";
import { markPaid, revokePayment, saveSettings } from "./actions";

type Order = {
  id: string;
  reference: string;
  user_id: string;
  email: string | null;
  display_name: string | null;
  source: string;
  plan_name: string;
  amount_paise: number;
  status: string;
  status_reason: string | null;
  upi_response: string | null;
  client_status: string | null;
  txn_id: string | null;
  verification_source: string | null;
  reviewed_by_email: string | null;
  report_count: number;
  created_at: string;
  updated_at: string;
  verified_at: string | null;
};

const filters = [
  { value: "all", label: "All" },
  { value: "pending", label: "Pending" },
  { value: "success", label: "Success" },
  { value: "failed", label: "Failed" },
  { value: "cancelled", label: "Cancelled" },
  { value: "revoked", label: "Revoked" },
];

const rupees = (paise: number) => (paise / 100).toFixed(2);

function OrderStatus({ status }: { status: string }) {
  switch (status) {
    case "approved":
      return <Badge tone="green">Success</Badge>;
    case "failed":
      return <Badge tone="red">Failed</Badge>;
    case "cancelled":
      return <Badge>Cancelled</Badge>;
    case "revoked":
      return <Badge tone="purple">Revoked</Badge>;
    case "initiated":
      return <Badge tone="amber">Pending (app not answered)</Badge>;
    default:
      return <Badge tone="amber">Pending</Badge>;
  }
}

export default async function PaymentsPage({
  searchParams,
}: {
  searchParams: Promise<{ ok?: string; error?: string; status?: string }>;
}) {
  const sp = await searchParams;
  const status = filters.some((f) => f.value === sp.status) ? sp.status! : "all";
  const back = `/payments?status=${status}`;
  const { supabase } = await requireOwner();
  const [{ data, error }, { data: settings }] = await Promise.all([
    supabase.rpc("admin_payment_orders", { p_status: status, p_limit: 300 }),
    supabase.from("payment_settings").select("upi_id, payee_name, enabled").eq("id", 1).maybeSingle(),
  ]);
  const orders = (data ?? []) as Order[];

  return (
    <>
      <PageHeader title="Payments" subtitle="UPI orders from the app. Check every success against your bank statement." />
      <Flash ok={sp.ok} error={sp.error ?? error?.message} />

      <Card className="mb-6 border-amber-200 bg-amber-50 text-sm text-amber-900">
        <p className="font-semibold">How to read this page</p>
        <ul className="mt-1 list-disc space-y-1 pl-5">
          <li>
            <b>Success (source upi_app)</b>: the customer&apos;s UPI app said SUCCESS and the order passed the checks
            (matching reference, unused transaction id, under 2 hours). This answer comes from the customer&apos;s phone and{" "}
            <b>can be forged</b>. Confirm the UTR and amount in your bank statement; use <b>Revoke</b> if it isn&apos;t there.
          </li>
          <li>
            <b>Pending</b>: no reliable answer yet. If the money is in your bank, use <b>Mark as paid</b> with the bank UTR.
          </li>
          <li>Open orders are cancelled automatically after 24 hours.</li>
        </ul>
      </Card>

      <div className="mb-4 flex flex-wrap gap-2">
        {filters.map((f) => (
          <Link
            key={f.value}
            href={`/payments?status=${f.value}`}
            className={`rounded-full px-3 py-1 text-sm font-medium ring-1 ${
              f.value === status ? "bg-red-700 text-white ring-red-700" : "bg-white text-gray-700 ring-gray-300"
            }`}
          >
            {f.label}
          </Link>
        ))}
      </div>

      {orders.length === 0 ? (
        <Empty>No orders.</Empty>
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>Order</Th>
              <Th>User</Th>
              <Th>Plan</Th>
              <Th>Amount</Th>
              <Th>Status</Th>
              <Th>UTR / source</Th>
              <Th>Raw UPI answer</Th>
              <Th>Times</Th>
              <Th>Action</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {orders.map((o) => {
              const open = o.status === "initiated" || o.status === "pending";
              return (
                <tr key={o.id} className={open && o.upi_response ? "bg-amber-50/60" : ""}>
                  <Td>
                    <p className="font-mono text-xs font-semibold">{o.reference}</p>
                    <p className="font-mono text-[10px] text-gray-400">{o.id}</p>
                  </Td>
                  <Td>
                    <p className="font-medium">{o.display_name ?? "—"}</p>
                    <p className="text-xs text-gray-500">{o.email ?? "Guest"}</p>
                    <SourceBadge source={o.source} />
                  </Td>
                  <Td>{o.plan_name}</Td>
                  <Td className="whitespace-nowrap font-semibold">₹{rupees(o.amount_paise)}</Td>
                  <Td>
                    <OrderStatus status={o.status} />
                    {o.status_reason && <p className="mt-1 max-w-48 text-xs text-gray-500">{o.status_reason}</p>}
                  </Td>
                  <Td>
                    <p className="font-mono text-xs">{o.txn_id ?? "—"}</p>
                    {o.verification_source && <p className="text-xs text-gray-500">{o.verification_source}</p>}
                    {o.reviewed_by_email && <p className="text-xs text-gray-400">by {o.reviewed_by_email}</p>}
                  </Td>
                  <Td>
                    {o.upi_response ? (
                      <code className="block max-w-64 break-all text-[11px] text-gray-700">{o.upi_response}</code>
                    ) : (
                      <span className="text-xs text-gray-400">none yet</span>
                    )}
                    {o.report_count > 1 && <p className="text-[10px] text-gray-400">{o.report_count} answers</p>}
                  </Td>
                  <Td className="whitespace-nowrap text-xs text-gray-600">
                    <p>Created {formatDate(o.created_at)}</p>
                    <p>Updated {formatDate(o.updated_at)}</p>
                    <p>Verified {formatDate(o.verified_at)}</p>
                  </Td>
                  <Td>
                    {o.status === "approved" ? (
                      <form action={revokePayment.bind(null, o.id, back)} className="flex min-w-48 flex-col gap-1">
                        <Input name="reason" placeholder="Reason (optional)" aria-label="Revoke reason" />
                        <Button variant="danger" type="submit">Revoke</Button>
                      </form>
                    ) : o.status !== "revoked" ? (
                      <form action={markPaid.bind(null, o.id, back)} className="flex min-w-48 flex-col gap-1">
                        <Input name="utr" required minLength={6} maxLength={40} placeholder="Bank UTR" aria-label="Bank UTR" />
                        <Input
                          name="amount"
                          required
                          inputMode="decimal"
                          placeholder={`Amount received (₹${rupees(o.amount_paise)})`}
                          aria-label="Amount received"
                        />
                        <Button variant="success" type="submit">Mark as paid</Button>
                      </form>
                    ) : null}
                  </Td>
                </tr>
              );
            })}
          </tbody>
        </Table>
      )}

      <Card className="mt-8 max-w-xl">
        <h2 className="mb-3 font-semibold">UPI settings</h2>
        <form action={saveSettings.bind(null, back)} className="grid gap-3">
          <label className="text-sm">
            UPI ID
            <Input name="upi_id" defaultValue={settings?.upi_id ?? ""} required />
          </label>
          <label className="text-sm">
            Payee name (shown in the UPI app)
            <Input name="payee_name" defaultValue={settings?.payee_name ?? ""} required />
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="enabled" defaultChecked={settings?.enabled ?? true} /> Accept payments in the app
          </label>
          <div>
            <Button type="submit">Save</Button>
          </div>
        </form>
      </Card>
    </>
  );
}
