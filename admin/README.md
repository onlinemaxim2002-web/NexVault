# Admin panel

Next.js web panel where the owner and invited admins manage the app.

| Page | Who | What |
|---|---|---|
| Dashboard | All admins | Installs (ads vs organic), users, premium, content counts; attribution table for the owner |
| Channels | All admins | Create/edit channels, audience (Everyone / Organic only / Ads only), status, folders |
| Posts | All admins | Create/edit posts, audience, publish now / schedule / draft, mark media 👑 premium |
| Approvals | Owner | Organic buyers waiting for approval → Approve / Reject / Revoke |
| Users | Owner | Search users, source + campaign, plan, approve/revoke, grant premium |
| Plans | Owner | Prices, durations, perks, show/hide |
| Admins | Owner | Add content admins (optionally limited to channels), remove admins |

All permissions are enforced by the database (RLS); the panel only shows what
the signed-in admin is allowed to do. Media upload is enabled once Cloudflare R2
is connected.

## Run locally

```bash
cp .env.example .env.local   # fill in the values
npm install
npm run dev                  # http://localhost:3000
```

Environment variables:

| Name | Where to find it |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase → Project Settings → API Keys (publishable) |
| `SUPABASE_SECRET_KEY` | Supabase → Project Settings → API Keys (secret). Server only; needed to add admins |

For a fully local setup, `npx supabase start` in the repo root gives a local
Supabase with all migrations applied.

## Deploy

Deploy the `admin/` folder to Vercel (or any Node host) with the three
environment variables above.
