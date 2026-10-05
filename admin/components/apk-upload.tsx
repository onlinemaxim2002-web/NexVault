"use client";

import { useState } from "react";
import { Input } from "@/components/ui";
import { createClient } from "@/lib/supabase/browser";

// Upload the APK to the public "downloads" bucket; the download page links to it.
export function ApkUpload({ defaultValue }: { defaultValue?: string | null }) {
  const [url, setUrl] = useState(defaultValue ?? "");
  const [status, setStatus] = useState<string | null>(null);

  async function onFile(file: File | undefined) {
    if (!file) return;
    if (!file.name.toLowerCase().endsWith(".apk")) {
      setStatus("Choose the .apk file (for ads use Flixvault-ads.apk).");
      return;
    }
    if (file.size > 50 * 1024 * 1024) {
      setStatus("The APK must be under 50 MB.");
      return;
    }
    setStatus("Uploading… this can take a minute.");
    const key = `Flixvault-${new Date().toISOString().slice(0, 10)}-${crypto.randomUUID().slice(0, 8)}.apk`;
    const supabase = createClient();
    const { error } = await supabase.storage
      .from("downloads")
      .upload(key, file, { contentType: "application/vnd.android.package-archive", upsert: false });
    if (error) {
      setStatus(error.message);
      return;
    }
    setUrl(supabase.storage.from("downloads").getPublicUrl(key).data.publicUrl);
    setStatus("Uploaded. Press Save to use it on the download page.");
  }

  return (
    <div className="grid gap-2">
      <Input type="file" accept=".apk,application/vnd.android.package-archive" onChange={(e) => onFile(e.target.files?.[0])} aria-label="APK file" />
      <Input name="apk_url" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="…or paste a download link (https://…)" />
      {status && <p className="text-xs text-gray-600">{status}</p>}
    </div>
  );
}
