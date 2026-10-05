import { NextResponse, type NextRequest } from "next/server";
import { createPublicClient } from "@/lib/supabase/server";

// Download tapped on /d: save the Meta click id (fbc), browser id (fbp), IP and
// browser so the app install, and later the purchase, can be credited to the ad.
export async function POST(request: NextRequest) {
  let body: Record<string, unknown> = {};
  try {
    body = await request.json();
  } catch {
    return new NextResponse(null, { status: 400 });
  }
  const str = (v: unknown, max: number) => (typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null);
  const ip =
    request.headers.get("x-real-ip") ??
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    null;

  const { error } = await createPublicClient().rpc("record_ad_click", {
    p_event_id: str(body.event_id, 80),
    p_fbc: str(body.fbc, 300),
    p_fbp: str(body.fbp, 120),
    p_ip: ip,
    p_user_agent: str(request.headers.get("user-agent"), 400),
    p_utm_source: str(body.utm_source, 100),
    p_utm_medium: str(body.utm_medium, 100),
    p_utm_campaign: str(body.utm_campaign, 200),
    p_utm_content: str(body.utm_content, 200),
    p_page_url: str(body.page_url, 500),
  });
  return new NextResponse(null, { status: error ? 500 : 204 });
}
