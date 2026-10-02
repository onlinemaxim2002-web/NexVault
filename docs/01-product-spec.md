# Product Spec

## 1. Vision

Give every user a large amount of free cloud storage with fast transfers and easy
sharing, and let them publish content to followers through Channels. Earn money
through ads, short paid plans, and premium features. Storage space itself is not
what we sell.

## 2. Competitor reference: Jollify ("Cloud & Channel")

Public information gathered so far (their site and Play listing could not be read
directly; screenshots pending):

- Package `com.jollify.cloudspace`, live since Nov 2025, v6.0, ~52 MB APK.
- Headline: **1 TB free cloud storage**.
- Features: photo/video/document backup, fast upload/download, secure share links,
  public/private Channels (user-generated content).
- Paid plans (INR): Trial 2 days ₹69 · Silver 7 days ₹129 · Gold 1 month ₹259 ·
  Platinum 6 months ₹599 · Diamond 1 year ₹999 (in-app, Oct 2026; earlier listed as ₹899).
  In-app perks shown: ad-free, 2 TB storage (free = 1 TB), fast upload/download.
  Premium (👑) channel content can only be watched by paying users.
- Policy pages: privacy, refund, terms, community guidelines, delete account.

Takeaway: it looks like the TeraBox model. Storage is free, and revenue comes from
speed, convenience, ads, and impulse-priced short plans.

> TODO: Map each Jollify screen once screenshots arrive (section 6).

## 3. Target users

- Indian Android users with low-storage phones who want to back up photos and videos.
- People sharing large files (videos, course material, documents) by link.
- Creators who want to share content collections with followers (Channels).

## 4. Features

### 4.1 Account
- **Guest-first:** an anonymous guest account is created automatically on first launch
  (random display name). Users can browse, join channels and use Cloud as a guest.
- Upgrade to a full account with **Email or Google** when buying a plan or creating a
  channel; guest data is kept (same account, credentials attached).
- Profile: name, avatar, username (used for Channels).
- Devices & sessions list, log out everywhere.
- Delete account (in-app and via a web URL, required by Play Store).

### 4.2 Drive
- Upload files/folders from the device, camera, and share sheet ("Share to Cloud Storage").
- Resumable chunked uploads that keep going when the network drops; background uploads.
- Download, with offline availability for selected files.
- Folders: create, rename, move, copy, delete; Trash with 30-day restore.
- Views: grid/list, sort, filter by type (Photos, Videos, Docs, Audio, Apps, Others).
- Search by name; later by date, type, and on-device image labels.
- Previews: images, video streaming (HLS), audio, PDF, common docs.
- Storage meter (used / quota) with a breakdown by file type.

### 4.3 Auto backup
- Photo and video backup from selected albums.
- Options: Wi-Fi only, charging only, include videos, backup original vs compressed.
- Free up device space by removing local copies that are already backed up.

### 4.4 Sharing
- Share link for a file or folder; optional password, expiry, download limit.
- Public link landing page (web) with preview and "Save to my Cloud Storage".
- Share to WhatsApp/Telegram/etc. through the system share sheet.
- Manage and revoke my links.

### 4.5 Channels (Phase 3)
- Create a public or private channel (name, icon, description, invite link for private).
- Post files/albums/text from the drive into a channel.
- Follow/join, a feed of followed channels, channel search/discovery.
- Owner tools: delete posts, remove members, view stats.
- Safety: report post/channel, block user, age-gating flags.

### 4.6 Premium
Ideas for paid perks (final list decided in [open questions](05-open-questions.md)):

| Perk | Free | Premium |
|---|---|---|
| Storage | 1 TB (configurable cap) | 2 TB |
| Premium (👑) channel content | Thumbnail only, Watch → paywall | Full access |
| Download speed | Throttled | Full speed |
| Max single file size | e.g. 4 GB | e.g. 20 GB |
| Ads | Yes | No |
| Video playback | 480p | Up to 1080p/original |
| Batch download / zip | No | Yes |
| Parallel uploads | 1–2 | 5+ |
| Share link options (password/expiry) | Basic | Full |
| Trash retention | 10 days | 30 days |
| Channel limits | 1 channel | Many + analytics |

Plan durations to mirror the market: 2 days, 7 days, 1 month, 6 months, 1 year.

### 4.7 Settings & support
- Theme (light/dark), language (English, Hindi; more later).
- Backup settings, notifications, cache size.
- Help/FAQ, contact support, report a problem.
- Links to legal pages.

## 5. Core user flows

1. **Onboarding:** splash → guest account auto-created → consent dialog → Agree →
   Explore. Permissions are requested only when a feature needs them.
2. **Upload:** home → "+" → pick source → choose folder → upload progress sheet →
   done notification.
3. **Share:** long-press file → Share → link options → copy/share → recipient opens
   web page → preview/download/save.
4. **Upgrade:** tap 👑 / Profile tab, or Watch on premium content → plans → Next →
   login with Email/Google (if guest) → payment → premium active → back to the content.
5. **Channel post:** Channels tab → my channel → "+" → choose files from the drive →
   caption → publish.
6. **Delete account:** Settings → Account → Delete → confirm (OTP) → 30-day grace
   window → permanent purge.

## 6. Screen inventory

Detailed analysis: [06-app-flow-analysis.md](06-app-flow-analysis.md).

| # | Screen | Jollify equivalent | Status |
|---|---|---|---|
| 1 | Consent dialog (first launch) | Terms & Privacy card, single "Agree" | Analysed |
| 2 | Explore (default landing) | 3-col grid, tabs All/Latest/Popular/Most watched | Analysed |
| 3 | Channels | Search, Discover/Joined, Trending/Latest/Top Rated, Join | Analysed |
| 4 | Feed | Posts from joined channels; empty state | Analysed |
| 5 | Cloud Storage | Personal drive, "+" button; empty state | Analysed |
| 6 | Profile tab → Premium plans | Benefits card + 5 plan radio cards + Next | Analysed |
| 6b | User profile (👤) | Avatar, guest name, edit, settings, My Channels, Add Channel | Analysed |
| 7 | Login (Email / Google) | Shown at plan purchase / Add Channel | Need screenshot |
| 8 | Content detail (from Explore) | "Posted by" channel, items with 👑 + Watch | Analysed (viewer still needed) |
| 9 | Channel detail / folders / upload | TBD | Need screenshot |
| 10 | Cloud upload sheet, folder, file viewer, share | TBD | Need screenshot |
| 11 | Paywall / plans (crown) | Same as Profile tab screen | Analysed |
| 12 | Settings / delete account | TBD | Need screenshot |
