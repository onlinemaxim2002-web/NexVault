# Roadmap

Durations assume a solo developer working with Claude; adjust once the team is known.

## Phase 0: Foundations
- [x] Product spec from Jollify screenshots (docs 01, 06)
- [x] Backend decision: Supabase + Cloudflare R2
- [ ] Brand: logo, colors, app icon
- [ ] Repo structure: `mobile/` (Flutter), `supabase/` (migrations, Edge Functions), `admin/` (Next.js), `worker/` (FFmpeg), `web/` (download page)
- [ ] Supabase project + R2 bucket
- [ ] Database schema v1 + RLS policies + tests
- [ ] CI: lint/test, build organic + ads APKs

## Phase 1: Admin panel + content (core)
- [ ] Admin login, roles (owner / content admin), invite admins
- [ ] Channels + folders CRUD with audience
- [ ] Upload content (direct-to-R2), premium toggle, audience, publish/schedule
- [ ] Media worker: thumbnails, HLS, preview clips
- [ ] Users list, grant premium manually

## Phase 2: App: browse & watch
- [ ] Guest auto-login (anonymous), consent dialog
- [ ] Install attribution (ads vs organic APK) + `record_install`
- [ ] Explore (tabs), Channels (Discover/Joined, filters), channel page (Telegram-style), Feed
- [ ] Email / Google login (upgrade guest), Join channel
- [ ] Plans page + gates (login sheet, paywall)
- [ ] Online player for premium; preview clips for ads users
- [ ] Profile, edit name, settings, logout, delete account

## Phase 3: Cloud storage (premium)
- [ ] Files & folders, resumable uploads, viewer, share links, storage meter

## Phase 4: Distribution & reports
- [ ] Download page (organic / `?src=meta`), "Open in Chrome" helper
- [ ] APKs published to fixed R2 URLs by CI
- [ ] Attribution report (source / campaign)
- [ ] Tester APK release

## Later
- [ ] Payment integration (deferred)
- [ ] AdMob ads
- [ ] iOS, Hindi + regional languages
