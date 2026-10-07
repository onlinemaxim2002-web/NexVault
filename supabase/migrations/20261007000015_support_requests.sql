-- Public requests from the website: account deletion (required by Google
-- Play) and copyright / content reports (DMCA). Anyone can submit; only the
-- owner can read and close them in the admin panel.

create table if not exists public.support_requests (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('delete_account', 'content_report')),
  email        text not null,
  name         text,
  content_url  text,
  details      text,
  user_id      uuid references auth.users (id) on delete set null,   -- matched account (delete requests)
  status       text not null default 'open' check (status in ('open', 'done', 'rejected')),
  note         text,
  created_at   timestamptz not null default now(),
  closed_at    timestamptz
);
create index if not exists support_requests_status_idx on public.support_requests (status, created_at desc);
alter table public.support_requests enable row level security;
create policy support_requests_owner on public.support_requests for select using (public.is_owner());
revoke insert, update, delete on public.support_requests from anon, authenticated;

create or replace function public.submit_support_request(
  p_kind text, p_email text, p_name text default null, p_content_url text default null, p_details text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_id uuid;
begin
  if p_kind not in ('delete_account', 'content_report') then raise exception 'invalid request type'; end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 200 then
    raise exception 'Please enter a valid email address.';
  end if;
  if p_kind = 'content_report' and coalesce(trim(p_details), '') = '' then
    raise exception 'Please describe the content and why it should be removed.';
  end if;
  -- Light spam guard: at most 5 open requests per email.
  if (select count(*) from public.support_requests where email = v_email and status = 'open') >= 5 then
    raise exception 'We already have your request. We will reply by email.';
  end if;
  insert into public.support_requests (kind, email, name, content_url, details, user_id)
  values (p_kind, v_email, left(trim(p_name), 120), left(trim(p_content_url), 500), left(trim(p_details), 4000),
          (select id from auth.users where lower(email) = v_email limit 1))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.admin_close_support_request(p_id uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can do this'; end if;
  if p_status not in ('open', 'done', 'rejected') then raise exception 'invalid status'; end if;
  update public.support_requests
     set status = p_status, note = left(p_note, 1000),
         closed_at = case when p_status = 'open' then null else now() end
   where id = p_id;
end $$;

-- Badge on the admin menu.
create or replace function public.admin_open_support_requests()
returns int language sql stable security definer set search_path = '' as $$
  select case when public.is_owner()
    then (select count(*)::int from public.support_requests where status = 'open') else 0 end
$$;

revoke execute on function public.submit_support_request(text, text, text, text, text) from public;
revoke execute on function public.admin_close_support_request(uuid, text, text) from public, anon;
revoke execute on function public.admin_open_support_requests() from public, anon;
grant execute on function public.submit_support_request(text, text, text, text, text) to anon, authenticated;
grant execute on function public.admin_close_support_request(uuid, text, text) to authenticated;
grant execute on function public.admin_open_support_requests() to authenticated;
