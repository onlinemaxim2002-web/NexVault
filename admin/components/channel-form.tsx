import { Button, Field, Input, Select, Textarea } from "@/components/ui";
import { AUDIENCES, STATUSES } from "@/lib/format";

export type ChannelValues = {
  name: string;
  handle: string | null;
  description: string | null;
  category: string | null;
  icon_url: string | null;
  audience: string;
  status: string;
};

export function ChannelForm({
  action,
  values,
  submitLabel,
}: {
  action: (formData: FormData) => Promise<void>;
  values?: ChannelValues;
  submitLabel: string;
}) {
  return (
    <form action={action} className="grid gap-4 md:grid-cols-2">
      <Field label="Name">
        <Input name="name" required defaultValue={values?.name} placeholder="Friends Status" />
      </Field>
      <Field label="Handle" hint="Optional short id, e.g. friends-status">
        <Input name="handle" defaultValue={values?.handle ?? ""} pattern="[a-z0-9_\-]*" />
      </Field>
      <Field label="Category">
        <Input name="category" defaultValue={values?.category ?? ""} placeholder="Entertainment" />
      </Field>
      <Field label="Icon URL" hint="Image upload comes with the storage setup">
        <Input name="icon_url" type="url" defaultValue={values?.icon_url ?? ""} />
      </Field>
      <div className="md:col-span-2">
        <Field label="Description">
          <Textarea name="description" defaultValue={values?.description ?? ""} />
        </Field>
      </div>
      <Field label="Who can see this channel" hint="Posts inside can't be shown to more people than the channel">
        <Select name="audience" defaultValue={values?.audience ?? "all"}>
          {AUDIENCES.map((a) => (
            <option key={a.value} value={a.value}>
              {a.label}
            </option>
          ))}
        </Select>
      </Field>
      <Field label="Status" hint="Only published channels appear in the app">
        <Select name="status" defaultValue={values?.status ?? "draft"}>
          {STATUSES.map((s) => (
            <option key={s.value} value={s.value}>
              {s.label}
            </option>
          ))}
        </Select>
      </Field>
      <div className="md:col-span-2">
        <Button type="submit">{submitLabel}</Button>
      </div>
    </form>
  );
}
