"use client";

import { useActionState } from "react";
import type { FormState } from "@/app/public-actions/support";

const input = "mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-base focus:border-gray-900 focus:outline-none";

type Field = { name: string; label: string; type?: string; required?: boolean; textarea?: boolean; placeholder?: string };

// Small public form with a server action and an inline result message.
export function SupportForm({
  action,
  fields,
  confirm,
  submit,
}: {
  action: (s: FormState, f: FormData) => Promise<FormState>;
  fields: Field[];
  confirm: string;
  submit: string;
}) {
  const [state, formAction, pending] = useActionState(action, {});
  if (state.ok) {
    return <p role="status" className="rounded-xl bg-green-50 p-4 font-medium text-green-800">{state.ok}</p>;
  }
  return (
    <form key={JSON.stringify(state.values ?? {})} action={formAction} className="grid gap-4">
      {fields.map((f) => (
        <label key={f.name} className="text-sm font-medium text-gray-800">
          {f.label}
          {f.textarea ? (
            <textarea name={f.name} required={f.required} rows={5} placeholder={f.placeholder} className={input} defaultValue={state.values?.[f.name]} />
          ) : (
            <input name={f.name} type={f.type ?? "text"} required={f.required} placeholder={f.placeholder} className={input} defaultValue={state.values?.[f.name]} />
          )}
        </label>
      ))}
      <label className="flex items-start gap-2 text-sm text-gray-700">
        <input type="checkbox" name="confirm" className="mt-1 h-4 w-4" defaultChecked={state.values?.confirm === "on"} /> {confirm}
      </label>
      {state.error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{state.error}</p>}
      <button type="submit" disabled={pending} className="rounded-xl bg-gray-900 px-5 py-3 font-semibold text-white disabled:opacity-50">
        {pending ? "Sending…" : submit}
      </button>
    </form>
  );
}
