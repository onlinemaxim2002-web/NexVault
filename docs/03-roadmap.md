# Roadmap

Durations assume a solo developer working with Claude; adjust once the team is known.

## Phase 0: Foundations
- [x] Product spec from Jollify screenshots (docs 01, 06)
- [x] Backend decision: Supabase + Cloudflare R2
- [ ] Brand: logo, colors, app icon
- [ ] Repo structure: `mobile/` (Flutter), `supabase/` (migrations, Edge Functions), `admin/` (Next.js), `worker/` (FFmpeg), `web/` (download page)
- [x] Supabase project (`cloud-storage`, Mumbai) with schema applied
- [ ] Cloudflare R2 bucket
- [x] Database schema v1 + RLS policies + tests (`supabase/`)
- [x] CI: lint/test, build organic + ads APKs

## Phase 1: Admin panel + content (core)
- [x] Admin login, roles (owner / content admin), add admins
- [x] Channels + folders CRUD with audience
- [x] Posts: audience, publish/schedule/draft, premium toggle per item
- [x] Media upload (Supabase Storage for now; Cloudflare R2 at the end)
- [x] Channel requests from app users (approve + choose audience)
- [x] Thumbnails (made in the browser / app)
- [ ] Media worker: HLS, preview clips (later, with R2)
- [x] Users list, grant premium manually, approvals queue, plans editor

## Phase 2: App: browse & watch
- [x] Guest auto-login (anonymous), consent dialog
- [x] Install attribution (ads vs organic APK) + `record_install`
- [x] Explore (tabs), Channels (Discover/Joined, filters), channel page (Telegram-style), Feed
- [x] Email login (upgrade guest), Join channel
- [ ] Google login
- [x] Plans page + gates (login, paywall), plan requests
- [x] Online player for premium
- [ ] Preview clips for ads users (needs the media worker)
- [x] Profile, edit name, settings, logout, delete account
- [x] Users create channels and post to approved channels

## Phase 3: Cloud storage (premium)
- [x] Files & folders, upload, viewer, rename/delete, storage meter
- [ ] Share links, resumable uploads for big files

## Phase 4: Distribution & reports
- [ ] Download page (organic / `?src=meta`), "Open in Chrome" helper
- [ ] APKs published to fixed R2 URLs by CI
- [ ] Attribution report (source / campaign)
- [ ] Tester APK release

## Later
- [ ] Payment integration (deferred)
- [ ] AdMob ads
- [ ] iOS, Hindi + regional languages
