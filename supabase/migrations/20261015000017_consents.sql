-- Versioned policy acceptance for anonymous and registered NexVault users.
-- A user may accept each version once; a later version prompts again in the app.
create table if not exists public.consents (
  user_id uuid not null references auth.users (id) on delete cascade,
  version text not null check (length(trim(version)) > 0),
  accepted_at timestamptz not null default now(),
  primary key (user_id, version)
);

alter table public.consents enable row level security;

grant select, insert on public.consents to authenticated;

drop policy if exists consents_select_own on public.consents;
create policy consents_select_own on public.consents
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists consents_insert_own on public.consents;
create policy consents_insert_own on public.consents
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
