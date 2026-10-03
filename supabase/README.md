# Supabase

Database schema, Row Level Security rules, and (later) Edge Functions.

```
migrations/   SQL migrations, applied in filename order
tests/        Behaviour tests run on a throwaway local Postgres
functions/    Edge Functions (delete-account; upi-webhook, not deployed)
```

## What the schema enforces

- **Audience:** channels and posts are `all`, `organic`, or `ads`. App users only see
  rows their source allows (`can_see()`), in every query, not just in the app.
- **Approvals:** an organic user who gets a plan becomes `pending`; only the owner can
  approve (`set_ads_access`). Approved users also see `ads` content.
- **Attribution:** `record_install` stores the install source (first successful read
  wins) and links it to the user; first touch can never be changed.
- **Membership:** only logged-in (non-guest) users can join, and only visible channels.
- **Admins:** owner manages everything; content admins manage content, optionally
  limited to selected channels.
- **Media keys** (`media_key`, `hls_key`, `preview_key`) are never readable by app
  users; Edge Functions sign playback URLs with the service role.
- **Premium:** granted by UPI payments (`activate_payment`, server only) or by the owner
  with `grant_premium`. See [docs/09-upi-payments.md](../docs/09-upi-payments.md).
- **Payments:** users read only their own orders; only database functions change them;
  each UTR / transaction id can approve one order.

## Run the tests

```bash
supabase/tests/run_tests.sh
```

Needs PostgreSQL 15+ server binaries (`initdb`, `pg_ctl`, `psql`). The script
starts a temporary database, loads a small stub of Supabase's `auth` schema and
roles, applies all migrations, and runs `tests/rls_test.sql`.

## Supabase project

- Project: **cloud-storage** · ref `lcfiohprmviolzwglkhm` · region ap-south-1 (Mumbai)
- Applied migrations: `20261002000001_init`, `20261002000002_harden_functions`, `20261002000003_admin_rpcs`,
  `20261002000004_storage_and_cloud` (applied live in four parts: storage_buckets_policies, cloud_files,
  plan_requests, app_status_rpcs), `20261002000005_user_channels` (applied in three parts),
  `20261003000006_trailers`, `20261003000007_upi_payments` (applied in four parts: tables, core,
  report_admin, cron), `20261003000008_app_channel_requests`
- Edge Functions: `delete-account`

## Apply to the Supabase project

With the Supabase CLI: `supabase link --project-ref <ref>` then `supabase db push`.
