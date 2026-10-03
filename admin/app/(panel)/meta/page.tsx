import { Badge, Button, Card, Empty, Flash, Input, PageHeader, Select, Table, Td, Th } from "@/components/ui";
import { requireOwner } from "@/lib/auth";
import { formatDate } from "@/lib/format";
import { saveMeta, sendTestEvent } from "./actions";

type Settings = {
  pixel_id: string | null;
  access_token: string | null;
  test_event_code: string | null;
  action_source: "app" | "website";
  website_url: string | null;
  enabled: boolean;
};

type MetaEvent = {
  id: number;
  event_name: string;
  event_id: string;
  email: string | null;
  value: number | null;
  status: "queued" | "sent" | "ok" | "failed";
  attempts: number;
  response: string | null;
  created_at: string;
  sent_at: string | null;
};

const EVENTS = [
  ["AppInstall", "First time the app is opened on a phone"],
  ["CompleteRegistration", "A guest creates an account or logs in for the first time"],
  ["ViewContent", "A video, image or trailer is opened"],
  ["InitiateCheckout", "Continue to payment is tapped (UPI order created), with the plan price"],
  ["Purchase", "A payment is approved, with the amount paid in INR"],
  ["Subscribe", "Sent together with Purchase, for subscription optimisation"],
];

function StatusBadge({ status }: { status: MetaEvent["status"] }) {
  if (status === "ok") return <Badge tone="green">Received by Meta</Badge>;
  if (status === "failed") return <Badge tone="red">Failed</Badge>;
  if (status === "sent") return <Badge tone="blue">Sent</Badge>;
  return <Badge tone="amber">Waiting</Badge>;
}

function mask(token: string | null) {
  if (!token) return "Not set";
  return `••••••••${token.slice(-4)}`;
}

export default async function MetaPage({
  searchParams,
}: {
  searchParams: Promise<{ ok?: string; error?: string }>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireOwner();
  const [{ data: s }, { data: events }] = await Promise.all([
    supabase.from("meta_settings").select("*").eq("id", 1).maybeSingle(),
    supabase.rpc("admin_meta_events", { p_limit: 100 }),
  ]);
  const settings = (s ?? { action_source: "app", enabled: false }) as Settings;
  const list = (events ?? []) as MetaEvent[];
  const ok = list.filter((e) => e.status === "ok").length;
  const failed = list.filter((e) => e.status === "failed").length;

  return (
    <>
      <PageHeader
        title="Meta Pixel"
        subtitle="Send app events to Meta for your ads. Enter the Pixel ID and access token once; everything else is automatic."
      />
      <Flash ok={sp.ok} error={sp.error} />

      <div className="grid gap-6 lg:grid-cols-[1fr_1fr]">
        <Card>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-semibold">Settings</h2>
            {settings.enabled ? <Badge tone="green">Tracking on</Badge> : <Badge>Tracking off</Badge>}
          </div>
          <form action={saveMeta} className="grid gap-4">
            <label className="text-sm font-medium">
              Pixel ID (dataset ID)
              <Input name="pixel_id" defaultValue={settings.pixel_id ?? ""} placeholder="e.g. 123456789012345" inputMode="numeric" />
            </label>
            <label className="text-sm font-medium">
              Conversions API access token
              <Input name="access_token" type="password" placeholder={settings.access_token ? `Saved (${mask(settings.access_token)}) — leave empty to keep` : "Paste the token"} autoComplete="off" />
              <input type="hidden" name="has_token" value={settings.access_token ? "1" : "0"} />
            </label>
            <label className="text-sm font-medium">
              Test event code <span className="font-normal text-gray-500">(optional, only while testing)</span>
              <Input name="test_event_code" defaultValue={settings.test_event_code ?? ""} placeholder="e.g. TEST12345" />
            </label>
            <label className="text-sm font-medium">
              Event source
              <Select name="action_source" defaultValue={settings.action_source}>
                <option value="app">App (recommended)</option>
                <option value="website">Website</option>
              </Select>
              <span className="mt-1 block text-xs font-normal text-gray-500">
                Use Website only if Meta rejects app events (shown in the log below) and your ads point to a download website.
              </span>
            </label>
            <label className="text-sm font-medium">
              Website address <span className="font-normal text-gray-500">(only for Website)</span>
              <Input name="website_url" defaultValue={settings.website_url ?? ""} placeholder="https://your-download-page.com" />
            </label>
            <label className="flex items-center gap-2 text-sm font-medium">
              <input type="checkbox" name="enabled" defaultChecked={settings.enabled} className="h-4 w-4" /> Tracking on
            </label>
            <div className="flex flex-wrap gap-2">
              <Button type="submit">Save</Button>
            </div>
          </form>
          <form action={sendTestEvent} className="mt-3">
            <Button variant="secondary" type="submit">Send test event</Button>
          </form>
        </Card>

        <Card>
          <h2 className="mb-3 font-semibold">Events sent automatically</h2>
          <ul className="space-y-2 text-sm">
            {EVENTS.map(([name, text]) => (
              <li key={name} className="flex gap-3">
                <code className="shrink-0 rounded bg-gray-100 px-1.5 py-0.5 text-xs font-semibold">{name}</code>
                <span className="text-gray-600">{text}</span>
              </li>
            ))}
          </ul>
          <h3 className="mb-2 mt-6 text-sm font-semibold">How to get the Pixel ID and token</h3>
          <ol className="list-decimal space-y-1 pl-5 text-sm text-gray-600">
            <li>Open Meta <b>Events Manager</b> → <b>Data sources</b> → your Pixel/dataset (create one if needed). Copy its ID.</li>
            <li>In that dataset open <b>Settings</b> → <b>Conversions API</b> → <b>Generate access token</b>. Copy it.</li>
            <li>Paste both here, tick <b>Tracking on</b> and Save.</li>
            <li>To check: in Events Manager open <b>Test events</b>, copy the test code, paste it above, Save, then press <b>Send test event</b>. Remove the test code when done.</li>
          </ol>
          <p className="mt-4 text-xs text-gray-500">
            Emails and user ids are sent only as SHA-256 hashes. The token stays on the server and is never sent to the app.
            Purchase is sent once per order, only after the payment is approved.
          </p>
        </Card>
      </div>

      <div className="mb-3 mt-8 flex items-center justify-between">
        <h2 className="font-semibold">Recent events</h2>
        <p className="text-sm text-gray-500">
          {ok} received · {failed} failed (last {list.length})
        </p>
      </div>
      {list.length === 0 ? (
        <Empty>No events yet. They appear here once tracking is on and people use the app.</Empty>
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>Event</Th>
              <Th>User</Th>
              <Th>Value</Th>
              <Th>Status</Th>
              <Th>Meta&apos;s answer</Th>
              <Th>Time</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {list.map((e) => (
              <tr key={e.id}>
                <Td className="font-medium">{e.event_name}</Td>
                <Td className="text-xs text-gray-600">{e.email ?? "—"}</Td>
                <Td>{e.value != null ? `₹${Number(e.value).toFixed(2)}` : "—"}</Td>
                <Td>
                  <StatusBadge status={e.status} />
                  {e.attempts > 1 && <p className="mt-1 text-xs text-gray-400">{e.attempts} tries</p>}
                </Td>
                <Td>
                  <code className="block max-w-72 break-all text-[11px] text-gray-600">{e.response ?? "—"}</code>
                </Td>
                <Td className="whitespace-nowrap text-xs text-gray-600">{formatDate(e.created_at)}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </>
  );
}
