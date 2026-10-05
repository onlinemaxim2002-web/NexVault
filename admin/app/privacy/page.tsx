import type { Metadata } from "next";
import { POLICIES } from "@/lib/policies";

export const metadata: Metadata = { title: "Flixvault — Policies", robots: { index: true } };

// Public policies page (linked from the download page and the ads).
export default function PrivacyPage() {
  return (
    <main className="mx-auto max-w-2xl px-5 py-10">
      <h1 className="mb-8 text-3xl font-bold">Flixvault policies</h1>
      {POLICIES.map((p) => (
        <section key={p.key} id={p.key} className="mb-10 scroll-mt-6">
          <h2 className="mb-3 text-xl font-semibold">{p.title}</h2>
          <p className="whitespace-pre-line leading-relaxed text-gray-700">{p.body}</p>
        </section>
      ))}
    </main>
  );
}
