# Architecture

> **Decision (Oct 2026): backend = Supabase.** Postgres with Row Level Security (RLS)
> enforces the content rules (premium, audience, hidden/draft) in the database, plus
> Edge Functions for signed media URLs and anonymous auth for guest accounts.

## 1. Tech stack

| Layer | Choice | Reason |
|---|---|---|
| Mobile | Flutter (Dart), Riverpod, go_router, `supabase_flutter`, `video_player` (HLS) | Android first (tester APK), iOS later from the same code |
| Backend | **Supabase**: Postgres + RLS, Auth, Edge Functions (Deno/TypeScript), Realtime | Rules live in the DB; little server code to maintain |
| Auth | Supabase **anonymous sign-in** for guests → link **Email** (OTP) or **Google** to upgrade the same user | Guest-first flow, same `user_id` before and after login |
| Object storage | **Cloudflare R2** (S3-compatible) for videos, images, HLS, Cloud files | No egress fees; signed URLs issued by Edge Functions |
| Media processing | Worker (FFmpeg) on a small VPS / Fly.io, triggered by a DB job queue | Thumbnails, HLS renditions, **preview clips** |
| Admin panel | **Next.js** web app + Supabase Auth (admin roles) | Log in, upload content, set premium + audience, reports. See [08-admin-panel.md](08-admin-panel.md) |
| Download page | Static `download.html` on Cloudflare Pages | Serves organic / ads APK |
| CI | GitHub Actions | Build both APKs, upload to R2, deploy admin + DB migrations |
| Payments | **Deferred** | Premium granted from the admin panel until then |
| Ads (AdMob) | Later | |
| Push / crash | Firebase Cloud Messaging, Crashlytics | |

## 2. High-level design

```
 Flutter app ──► Supabase (Auth · Postgres+RLS · RPC · Edge Functions)
     │                │                     │
     │                │ job queue           │ signed URLs (premium / preview / upload)
     │                ▼                     ▼
     │          Media worker (FFmpeg) ──► Cloudflare R2  ◄── Admin panel uploads (presigned)
     │                                     │
     └──────────── HLS stream / images ◄───┘ (via Cloudflare CDN)

 Admin panel (Next.js) ──► Supabase (admin role) + R2 presigned uploads
```

Rules:
- **File bytes never pass through Supabase.** Uploads and playback use short-lived
  presigned R2 URLs that Edge Functions issue after checking permissions.
- **The database decides visibility.** The app's local flags are only for UI.

## 3. Content model

```
Channel ─┬─ audience: all | organic | ads
         └─ Folder ── Post ─┬─ audience: all | organic | ads
                            └─ Item (video / image)
                                 ├─ is_premium        (set by owner/admins)
                                 ├─ preview clip      (auto, for ads users)
                                 └─ HLS renditions + thumbnail
```

- **Audience** (who can see it), set by admins on channels and posts:
  - `all`: everyone
  - `organic`: only users who did **not** come from an ad
  - `ads`: only users who installed **from your ads** (Meta)
- **Effective audience of a post** = the stricter of the channel's and the post's
  setting. The admin panel won't let a post be wider than its channel.
- **Premium** is per item: free to play, or 👑 needs login + plan.
- Every published post the user is allowed to see also appears in **Explore**, and
  in **Feed** if the user joined its channel.
- Only **admins** post. Members join and watch. **No downloads**: streaming only.

## 4. Data model (initial)

```
profiles          id (= auth.users.id), display_name, avatar_url, is_guest,
                  quota_bytes, used_bytes, status, created_at
admins            user_id PK, role (owner | content_admin), invited_by, created_at
admin_channel_access  admin_id, channel_id      -- optional: limit a content_admin to channels

channels          id, name, handle, description, icon_url, category,
                  audience (all|organic|ads), status (draft|published|hidden),
                  members_count, rating, created_by, created_at
channel_folders   id, channel_id, name, cover_url, position
channel_members   channel_id, user_id, joined_at
posts             id, channel_id, folder_id, title, caption, audience (all|organic|ads),
                  status (draft|scheduled|published|hidden), publish_at,
                  view_count, like_count, created_by, created_at
post_items        id, post_id, position, kind (video|image), is_premium,
                  media_key, hls_key, preview_key, thumb_key, duration_s, width, height,
                  processing_status (pending|ready|failed)

files / blobs / uploads / share_links   -- personal Cloud storage (premium only)
plans             id, code, name, duration_days, price_inr, perks jsonb, active, position
subscriptions     id, user_id, plan_id, source (admin_grant | payment), starts_at, ends_at
consents          id, user_id, policy_version, accepted_at

installs, user_attribution, analytics_events   -- see 07-attribution-and-personalisation.md
reports, audit_logs
```

## 5. Key database functions / policies

| Name | Kind | Purpose |
|---|---|---|
| `user_source()` | security definer | `'ads'` if the current user's first-touch source is the ad source, else `'organic'` |
| `can_see(audience)` | SQL | `audience = 'all' or audience = user_source()`; admins see everything |
| RLS on `channels`, `posts`, `post_items` | policy | `status = 'published'` + `can_see(...)` on both channel and post |
| `explore(tab, cursor)` | RPC | Visible posts sorted by latest / popular / most watched |
| `channel_posts(channel_id, cursor)` | RPC | Telegram-style stream, newest first |
| `is_premium_user()` | security definer | Active plan check |
| `stream-url` | Edge Function | Premium + visibility check → signed HLS playlist URL |
| `preview-url` | Edge Function | Ads user + visibility check → signed preview-clip URL |
| `admin-upload-url` | Edge Function | Admin check → presigned R2 multipart upload |
| `record_install`, `attribute_user`, `log_event` | RPC | Attribution (doc 07) |

## 6. Upload & processing (admin content)

1. Admin picks files in the panel → `admin-upload-url` returns presigned multipart URLs.
2. Browser uploads directly to R2 (resumable, parallel parts).
3. Panel creates the `post` + `post_items` rows (`processing_status = pending`).
4. Media worker: thumbnail, HLS (480p/720p), **preview clip** (first ~20 s),
   duration/size → marks `ready`.
5. The post shows in the app when `status = published` (or at `publish_at`) **and**
   all items are `ready`.

Personal Cloud uploads from the app (premium users) use the same presigned flow.

## 7. Access control

| Level | Who | Allowed |
|---|---|---|
| `guest` | Anonymous Supabase user | Browse content visible to their source, edit name; ads guests can watch previews |
| `free` | Email/Google linked, no plan | + join channels |
| `premium` | Active plan | + play full content (stream), upload to Cloud, no ads |
| `content_admin` | Staff invited by the owner | Admin panel: upload/edit content (optionally only some channels) |
| `owner` | You | Everything: admins, plans, premium grants, reports |

`402` responses carry the plans list so the app opens the paywall; `401
login_required` opens the login sheet.

## 8. Security

- RLS on every table. The anon key is safe in the app because policies decide access.
- Service-role key only in Edge Functions, the worker, and CI secrets.
- Signed URLs with short TTLs (5–15 min).
- Admin actions written to `audit_logs`.

## 9. Cost control

- Dedup personal Cloud files by SHA-256.
- R2 lifecycle: delete abandoned multipart uploads after 24 h.
- Transcode once to a small set of renditions; previews are short.
