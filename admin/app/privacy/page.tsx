import type { Metadata } from "next";
import { PublicPage } from "@/components/public-page";
import { POLICIES } from "@/lib/policies";

export const metadata: Metadata = { title: "NexVault — Privacy Policy", robots: { index: true } };

// Public policies page (Play Console privacy policy link; linked from the app and download page).
export default function PrivacyPage() {
  return (
    <PublicPage title="NexVault policies">
      {POLICIES.map((p) => (
        <section key={p.key} id={p.key} className="mb-10 scroll-mt-6">
          <h2 className="mb-3 text-xl font-semibold">{p.title}</h2>
          <p className="whitespace-pre-line leading-relaxed text-gray-700">{p.body}</p>
        </section>
      ))}
    </PublicPage>
  );
}
