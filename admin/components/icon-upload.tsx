"use client";

import { useState } from "react";
import { Input } from "@/components/ui";
import { extension } from "@/lib/media";
import { createClient, publicUrl } from "@/lib/supabase/browser";

// Channel icon: upload an image to the public bucket and keep its URL in the form.
export function IconUpload({ defaultValue }: { defaultValue?: string | null }) {
  const [url, setUrl] = useState(defaultValue ?? "");
  const [status, setStatus] = useState<string | null>(null);

  async function onFile(file: File | undefined) {
    if (!file) return;
    setStatus("Uploading…");
    const key = `channels/${crypto.randomUUID()}.${extension(file)}`;
    const { error } = await createClient()
      .storage.from("public")
      .upload(key, file, { contentType: file.type, upsert: false });
    if (error) {
      setStatus(error.message);
      return;
    }
    setUrl(publicUrl(key) ?? "");
    setStatus(null);
  }

  return (
    <div className="flex items-center gap-3">
      {url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt="" className="h-12 w-12 shrink-0 rounded-full object-cover ring-1 ring-gray-200" />
      ) : (
        <div className="h-12 w-12 shrink-0 rounded-full bg-gray-100 ring-1 ring-gray-200" />
      )}
      <div className="min-w-0 flex-1">
        <Input type="file" accept="image/*" onChange={(e) => onFile(e.target.files?.[0])} aria-label="Channel icon" />
        {status && <p className="mt-1 text-xs text-gray-500">{status}</p>}
      </div>
      <input type="hidden" name="icon_url" value={url} />
    </div>
  );
}
