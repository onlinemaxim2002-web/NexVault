# Open Questions

| # | Question | Options | Decision |
|---|---|---|---|
| 1 | Platforms at launch | Android only / Android + iOS | |
| 2 | Channels / Explore / Feed in MVP? | MVP / Phase 3 | Proposed: **MVP**. Jollify opens on Explore and 3 of 5 tabs are social (see 06-app-flow-analysis §7) |
| 3 | Free quota | 1 TB marketing quota + fair use / smaller (e.g. 100 GB) | |
| 4 | Launch infra budget (monthly) | | |
| 5 | Team | Solo + Claude / more developers | |
| 6 | Brand name, domain, logo | | Project name: Cloud Storage |
| 7 | Final premium perks & prices | See product spec §4.6 | |
| 8 | Legal entity (for policies, Play account, GST) | | |
| 9 | Storage provider | Cloudflare R2 / Wasabi / Backblaze B2 / AWS S3 | Proposed: R2 |
| 10 | OTP provider | Firebase Phone Auth / MSG91 / Twilio | |
| 11 | Guest browsing without login? | Yes (like Jollify) / login first | **Decided: Yes.** Auto guest account; Email/Google at purchase or Add Channel |
| 12 | Can regular users create channels, or admins only? | | Logged-in users can (Add Channel needs login) |
| 13 | Launch content: who seeds the category channels, and with what licensed content? | | |
| 14 | Who can mark content as premium (👑)? | Admins only / verified channels / any channel owner | **Decided: app owner only** (admin panel) |
| 15 | Do channel creators earn a revenue share from premium views? | | |
| 16 | Plans: one-time passes or auto-renew subscriptions? | | Proposed: one-time passes (like Jollify) |
| 17 | Profile tab: open paywall (like Jollify) or open profile with a Premium card? | | |
| 18 | Can guests upload to Cloud, or only logged-in users? | | Jollify: **premium only** (+ opens the plans page) |
| 19 | Free users and Cloud: copy Jollify (no uploads without a plan) or give a small free quota? | Premium-only / e.g. 5–10 GB free | **Decided: premium-only** (same as Jollify) |
| 20 | Can premium users download channel content to their phone, or only stream? | Stream only / stream + download | **Decided: stream only, no downloads** |
| 21 | Channel posting: owner/admins only (Telegram broadcast) or any member? | | **Updated: channel creators post** in their approved channels; admins can post anywhere; members join and watch |
| 22 | Payment provider and integration | | **Deferred** by product owner |
| 23 | Distribution | Play Store / tester APK | **Decided: tester APK only** (sideloaded). Play Store and legal compliance are out of scope for now |
| 24 | Backend: NestJS + Postgres, or Supabase (Postgres + RLS + Edge Functions + anonymous auth)? | | **Decided: Supabase** |
| 25 | Ads guest logs into an existing organic account: keep organic (first touch wins)? | | Proposed: yes |
| 26 | Where to host APKs (repo is private) | Public releases repo / public R2 bucket / make repo public | Proposed: public R2 bucket |
| 27 | "Admins" who post: app owner/staff only, or channel owners + their admins? | | **Decided: owner + admins the owner invites** (via the online admin panel) |
| 28 | Content audience options | | **Decided: Everyone / Organic only / Ads only**, on channels and posts |
| 29 | Can regular app users still create channels ("Add Channel" in profile)? | Yes / remove the button | **Decided: yes.** Owner approves each channel and chooses its audience; creators post to approved channels |
| 30 | Approved organic user's plan expires: keep the approval or remove it? | Keep / remove | Proposed: keep (approval is per user) |
| 31 | Tell a waiting organic buyer that approval is pending? | Silent / show a message | Proposed: silent |
| 32 | Approved organic user: see Organic-only content too, or switch fully to the ads view? | See everything / ads view only | Proposed: see everything |
| 33 | Creator uploads premium by default? | Premium / free | **Default: premium** (owner can switch per item) — confirm |
| 34 | Storage provider for now | | **Supabase Storage (free plan, 50 MB per file)**; Cloudflare R2 at the end |
