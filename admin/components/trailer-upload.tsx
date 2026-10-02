"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { MAX_UPLOAD_BYTES, extension } from "@/lib/media";
import { createClient } from "@/lib/supabase/browser";

// Add or replace the trailer of a video item (played by ads users before they buy).
export function TrailerUpload({ postId, itemId, hasTrailer }: { postId: string; itemId: string; hasTrailer: boolean }) {
  const router = useRouter();
  const [status, setStatus] = useState<string | null>(null);

  async function onFile(file: File | undefined) {
    if (!file) return;
    if (file.size > MAX_UPLOAD_BYTES) {
      setStatus("Max 50 MB");
      return;
    }
    setStatus("Uploading…");
    const supabase = createClient();
    const key = `posts/${postId}/${crypto.randomUUID()}-trailer.${extension(file)}`;
    const up = await supabase.storage.from("media").upload(key, file, { contentType: file.type });
    if (up.error) {
      setStatus(up.error.message);
      return;
    }
    const { error } = await supabase.from("post_items").update({ trailer_key: key }).eq("id", itemId);
    if (error) {
      setStatus(error.message);
      return;
    }
    setStatus(null);
    router.refresh();
  }

  return (
    <label className="cursor-pointer text-xs font-medium text-red-700 hover:underline">
      {status ?? (hasTrailer ? "Replace trailer" : "Add trailer")}
      <input type="file" accept="video/*" className="sr-only" onChange={(e) => onFile(e.target.files?.[0])} />
    </label>
  );
}
