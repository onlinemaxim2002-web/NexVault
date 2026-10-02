# Architecture

## 1. Tech stack

| Layer | Choice | Reason |
|---|---|---|
| Mobile | Flutter (Dart), Riverpod, Dio, go_router | One codebase for Android + iOS, good media performance |
| Backend API | NestJS (TypeScript) | Structured modules, easy hiring, good ecosystem |
| Database | PostgreSQL (Prisma ORM) | Relational metadata, transactions for quotas |
| Cache / queues | Redis + BullMQ | Rate limits, sessions, background jobs |
| Object storage | Cloudflare R2 (S3-compatible) | No egress fees, which matters for a download-heavy app. Wasabi/B2 as alternatives |
| CDN | Cloudflare | Thumbnails, HLS segments, public share pages |
| Media processing | Worker service + FFmpeg + libvips/sharp | Thumbnails, HLS transcoding, metadata |
| Auth | Own JWT (access + refresh) + Firebase Phone Auth / MSG91 for OTP, Google Sign-In | |
| Payments | Google Play Billing (in-app), Razorpay (web) | Play requires its billing for digital goods |
| Ads | Google AdMob (banner, interstitial, rewarded) | |
| Push / crash | Firebase Cloud Messaging, Crashlytics | |
| Admin panel | Next.js + same API (admin role) | |
| Share pages (web) | Next.js (SSR) | Link previews, SEO-safe landing pages |
| Infra | Docker; start on a single VPS / Render / Fly.io, move to k8s later | Keep the launch cost low |
| Observability | Sentry, Prometheus/Grafana or a hosted alternative | |

## 2. High-level design

```
 Flutter app ──HTTPS──► API (NestJS) ──► PostgreSQL
     │                     │   └──────► Redis (cache, rate limit, BullMQ)
     │                     │
     │  presigned URLs     ▼
     └──────────────► Object storage (R2) ◄── Workers (thumbnails, HLS, virus scan, moderation)
                            │
                            ▼
                        Cloudflare CDN ──► share pages / streaming
```

Key rule: **file bytes never pass through the API servers.** The API only issues
presigned upload/download URLs and records metadata.

## 3. Upload flow (resumable, multipart)

1. App computes the file's SHA-256 (in chunks) → `POST /uploads/init {name, size, mime, sha256, parentId}`.
2. API checks the quota and dedup:
   - If a blob with the same hash exists → create a file record pointing to it (instant upload).
   - Else → create an S3 multipart upload and return presigned part URLs (e.g. 8–16 MB parts).
3. App uploads parts in parallel (limit by plan) and retries failed parts.
4. `POST /uploads/{id}/complete {parts}` → API completes the multipart upload, creates the file record, and enqueues jobs.
5. Workers: generate a thumbnail, extract metadata, transcode video to HLS, run hash/NSFW checks if the file is shared publicly.

## 4. Download & streaming

- `GET /files/{id}/download` → short-lived presigned URL (or a signed CDN URL).
- Free-tier speed throttling: serve through a CDN worker that rate-limits per token, or
  route free downloads via a throttled origin path. Premium gets the direct URL.
- Video: HLS renditions (480p free, 720p/1080p premium) with signed playlist URLs.

## 5. Data model (initial)

```
users           id, phone, email, google_id, name, username, avatar_url,
                plan_id, plan_expires_at, quota_bytes, used_bytes,
                status(active|suspended|pending_deletion), created_at, deleted_at
sessions        id, user_id, device_name, platform, refresh_token_hash, last_seen_at
blobs           id, sha256, size, storage_key, mime, ref_count, created_at
files           id, user_id, parent_id(null=root), name, is_folder, blob_id,
                mime, size, thumb_key, hls_key, status(uploading|ready|trashed),
                trashed_at, created_at, updated_at
uploads         id, user_id, file_name, size, sha256, s3_upload_id, parts_done, status, expires_at
share_links     id, file_id, owner_id, token, password_hash, expires_at,
                max_downloads, download_count, revoked_at
plans           id, code(trial|silver|gold|platinum|diamond), duration_days,
                price_inr, quota_bytes, features(jsonb), play_product_id
subscriptions   id, user_id, plan_id, provider(play|razorpay), provider_ref,
                status, starts_at, ends_at
channels        id, owner_id, name, handle, description, icon_url, visibility(public|private),
                invite_token, followers_count, status
channel_members channel_id, user_id, role(owner|admin|member), joined_at
posts           id, channel_id, author_id, caption, status, created_at
post_items      post_id, file_id, position
reports         id, reporter_id, target_type(post|channel|user|share_link), target_id,
                reason, details, status, handled_by, created_at
audit_logs      id, actor_id, action, target, meta(jsonb), created_at
```

Notes:
- `blobs` lets identical files share storage (dedup); delete a blob only when `ref_count = 0`.
- `used_bytes` is updated transactionally on upload complete / purge.
- Files the user has deleted from Trash are purged by a scheduled job.

## 6. API outline (v1)

```
Auth        POST /auth/otp/send, /auth/otp/verify, /auth/google, /auth/refresh, /auth/logout
Me          GET/PATCH /me, GET /me/sessions, DELETE /me/sessions/:id, POST /me/delete
Files       GET /files?parentId=&type=&sort=, POST /folders, PATCH /files/:id (rename/move),
            POST /files/:id/copy, DELETE /files/:id (trash), POST /files/:id/restore,
            DELETE /trash/:id (purge), GET /files/search?q=
Uploads     POST /uploads/init, GET /uploads/:id/parts, POST /uploads/:id/complete, DELETE /uploads/:id
Download    GET /files/:id/download, GET /files/:id/stream
Share       POST /share-links, GET /share-links, DELETE /share-links/:id,
            GET /s/:token (public), POST /s/:token/save
Storage     GET /storage/summary
Billing     GET /plans, POST /billing/play/verify, POST /billing/razorpay/order,
            POST /webhooks/play, POST /webhooks/razorpay
Channels    CRUD /channels, POST /channels/:id/follow, GET /feed, CRUD /channels/:id/posts
Safety      POST /reports, POST /users/:id/block
Admin       /admin/users, /admin/reports, /admin/takedowns, /admin/plans, /admin/stats
```

## 7. Security

- TLS everywhere; presigned URLs with short TTLs (5–15 min).
- Encryption at rest (provider-managed); optional client-side encrypted "vault" later.
- Rate limiting on OTP, login, share link access, and uploads.
- Malware scan (ClamAV) for publicly shared files.
- CSAM hash matching and an NSFW classifier on publicly shared/Channel content.
- Least-privilege storage credentials; separate buckets for originals, thumbnails, and HLS.

## 8. Cost control

- Deduplicate by SHA-256.
- Lifecycle rules: delete abandoned multipart uploads after 24h.
- Free-account inactivity policy (e.g. warn at 6 months, purge at 12 months, stated in the Terms).
- Configurable free quota (start at 1 TB marketing quota, enforce a fair-use cap).
- Watch cost per active user from day one.
