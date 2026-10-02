# Cloud Storage

A mobile-first cloud storage app with generous free storage, fast upload/download,
secure link sharing, and public/private **Channels** for sharing content.

> Status: database live on Supabase; admin panel built (`admin/`). App and media upload next.

## Documentation

| Doc | What it covers |
|---|---|
| [docs/01-product-spec.md](docs/01-product-spec.md) | Features, user flows, free vs premium, competitor reference |
| [docs/02-architecture.md](docs/02-architecture.md) | Tech stack, system design, data model, API outline |
| [docs/03-roadmap.md](docs/03-roadmap.md) | Phased milestones and deliverables |
| [docs/04-compliance-and-policies.md](docs/04-compliance-and-policies.md) | Reference only (out of scope for the tester APK) |
| [docs/05-open-questions.md](docs/05-open-questions.md) | Decisions still pending |
| [docs/06-app-flow-analysis.md](docs/06-app-flow-analysis.md) | Screen-by-screen analysis of the reference app |
| [docs/07-attribution-and-personalisation.md](docs/07-attribution-and-personalisation.md) | Ads vs organic installs, content audience, APK builds, download page |
| [docs/08-admin-panel.md](docs/08-admin-panel.md) | Online admin panel: roles, upload, premium, audience, reports |

## Repository layout

```
mobile/    Flutter app (Android first, iOS later)
supabase/  Database migrations, RLS policies, Edge Functions
admin/     Next.js admin panel (upload content, audience, premium, reports)
worker/    Media worker (FFmpeg: thumbnails, HLS, preview clips)
web/       APK download page
docs/      Product and technical planning
```
