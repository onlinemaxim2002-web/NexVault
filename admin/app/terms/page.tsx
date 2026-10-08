import type { Metadata } from "next";
import { PublicPage } from "@/components/public-page";
import { POLICIES } from "@/lib/policies";

export const metadata: Metadata = { title: "NexVault — Terms & Conditions", robots: { index: true } };

export default function TermsPage() {
  const order = ["terms", "community", "refund"];
  return (
    <PublicPage title="Terms & Conditions">
      {order.map((k) => POLICIES.find((p) => p.key === k)!).map((p) => (
        <section key={p.key} id={p.key} className="mb-10 scroll-mt-6">
          <h2 className="mb-3 text-xl font-semibold">{p.title}</h2>
          <p className="whitespace-pre-line leading-relaxed text-gray-700">{p.body}</p>
        </section>
      ))}
    </PublicPage>
  );
}
