# Supabase

Database schema, Row Level Security rules, and (later) Edge Functions.

```
migrations/   SQL migrations, applied in filename order
tests/        Behaviour tests run on a throwaway local Postgres
functions/    Edge Functions (stream-url, preview-url, admin-upload-url) — coming next
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
- **Premium:** granted by the owner with `grant_premium` until payments are added.

## Run the tests

```bash
supabase/tests/run_tests.sh
```

Needs PostgreSQL 15+ server binaries (`initdb`, `pg_ctl`, `psql`). The script
starts a temporary database, loads a small stub of Supabase's `auth` schema and
roles, applies all migrations, and runs `tests/rls_test.sql`.

## Apply to the Supabase project

With the Supabase CLI: `supabase link --project-ref <ref>` then `supabase db push`.
