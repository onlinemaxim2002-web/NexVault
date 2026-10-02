import { createBrowserClient } from "@supabase/ssr";

// Browser client sharing the admin's session cookie. Used for direct uploads
// to Supabase Storage (file bytes don't pass through the Next.js server).
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}

export function publicUrl(path: string | null | undefined) {
  if (!path) return null;
  return `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/public/${path}`;
}
