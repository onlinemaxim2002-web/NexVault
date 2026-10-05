"use client";

import { useState } from "react";

declare global {
  interface Window {
    fbq?: (...args: unknown[]) => void;
  }
}

function cookie(name: string) {
  return document.cookie
    .split("; ")
    .find((c) => c.startsWith(`${name}=`))
    ?.split("=")[1];
}

// Download: browser Pixel "Lead" + server record (same event id, so Meta
// counts it once), then the APK download starts.
export function DownloadButton({ apkUrl }: { apkUrl: string | null }) {
  const [busy, setBusy] = useState(false);

  async function onClick() {
    if (!apkUrl || busy) return;
    setBusy(true);
    const params = new URLSearchParams(window.location.search);
    const eventId = `lead-${crypto.randomUUID()}`;
    const fbclid = params.get("fbclid");
    const fbc = cookie("_fbc") ?? (fbclid ? `fb.1.${Date.now()}.${fbclid}` : undefined);
    window.fbq?.("track", "Lead", { content_name: "APK download" }, { eventID: eventId });
    try {
      await fetch("/api/click", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        keepalive: true,
        body: JSON.stringify({
          event_id: eventId,
          fbc,
          fbp: cookie("_fbp"),
          utm_source: params.get("utm_source"),
          utm_medium: params.get("utm_medium"),
          utm_campaign: params.get("utm_campaign"),
          utm_content: params.get("utm_content"),
          page_url: window.location.href.split("#")[0],
        }),
      });
    } catch {
      // The download must start even if tracking fails.
    }
    window.location.href = apkUrl;
    setTimeout(() => setBusy(false), 3000);
  }

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!apkUrl}
      className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#FF7A1A] px-6 py-4 text-lg font-bold text-white shadow-[0_10px_30px_-10px_rgba(255,122,26,0.8)] transition active:scale-[0.98] disabled:opacity-50"
    >
      <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth={2.2} aria-hidden>
        <path d="M12 3v12m0 0-5-5m5 5 5-5M4 19h16" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      {apkUrl ? (busy ? "Starting download…" : "Download the app") : "Download coming soon"}
    </button>
  );
}
