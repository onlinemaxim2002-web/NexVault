import Link from "next/link";
import type { ReactNode } from "react";
import { SUPPORT_EMAIL } from "@/lib/policies";

// Simple frame for the public pages (policies, account deletion, reports).
export function PublicPage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="min-h-screen bg-white">
      <header className="border-b border-gray-200">
        <div className="mx-auto flex max-w-2xl items-center gap-2 px-5 py-4">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[#FF7A1A] text-sm font-black text-white">F</div>
          <Link href="/d" className="font-semibold">NexVault</Link>
        </div>
      </header>
      <main className="mx-auto max-w-2xl px-5 py-8">
        <h1 className="mb-6 text-3xl font-bold">{title}</h1>
        {children}
      </main>
      <footer className="mx-auto max-w-2xl border-t border-gray-200 px-5 py-6 text-sm text-gray-500">
        <p className="flex flex-wrap gap-x-4 gap-y-1">
          <Link href="/privacy" className="underline">Privacy Policy</Link>
          <Link href="/terms" className="underline">Terms</Link>
          <Link href="/delete-account" className="underline">Delete account</Link>
          <Link href="/report-content" className="underline">Report content</Link>
        </p>
        <p className="mt-2">Contact: <a href={`mailto:${SUPPORT_EMAIL}`} className="underline">{SUPPORT_EMAIL}</a></p>
      </footer>
    </div>
  );
}

