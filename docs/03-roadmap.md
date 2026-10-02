# Roadmap

Durations assume a solo developer working with Claude; adjust once the team is known.

## Phase 0: Foundations (week 1)
- [ ] Finalize the product spec from Jollify screenshots
- [ ] Brand: name, logo, colors, app icon
- [ ] Set up the monorepo: `mobile/` (Flutter), `backend/` (NestJS), `admin/` (Next.js)
- [ ] Docker Compose for local dev (Postgres, Redis, MinIO as local S3)
- [ ] CI: lint + test on every PR

## Phase 1: MVP drive (weeks 2–6)
- [ ] Auth: phone OTP, Google sign-in, JWT refresh, sessions
- [ ] Files & folders CRUD, Trash
- [ ] Resumable multipart uploads + dedup
- [ ] Download, image viewer, thumbnails
- [ ] Video playback (HLS)
- [ ] Auto photo/video backup (background)
- [ ] Share links + public web share page
- [ ] Storage summary screen
- [ ] Settings, delete account (in-app + web)
- [ ] Privacy, Terms, Refund, Community, Delete-account pages live on the website
- [ ] Signed tester APK build

## Phase 2: Premium & gating (weeks 7–9)
- [ ] Plans page (admin-editable plans, prices, perks)
- [ ] Entitlement checks: guest / free / premium (Join, Play, Download, Upload, Add Channel)
- [ ] Login gate sheet + paywall redirect
- [ ] Admin: grant/revoke premium manually (until payments are added)
- [ ] Payment integration: **deferred**, to be planned later
- [ ] Feature gates (speed, file size, video quality, ads, batch download)
- [ ] AdMob integration (banner, rewarded)
- [ ] Paywall screens + A/B-testable pricing
- [ ] Tester APK release

## Phase 3: Channels (weeks 10–14)
- [ ] Channel create/edit, public/private, invite links
- [ ] Posts from the drive, feed, follow, discovery/search
- [ ] Report/block, moderation queue, NSFW + hash checks
- [ ] Admin panel: users, reports, takedowns, plans, stats

## Phase 4: Growth
- [ ] iOS release
- [ ] Web app (drive in the browser)
- [ ] Referral program (bonus perks)
- [ ] Hindi + regional languages
- [ ] Desktop sync client
- [ ] Private encrypted vault
