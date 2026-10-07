-- Google Play "alternative billing only" reporting (Play Store build).
-- The payment is the normal UPI flow. The Play build gets a one-time
-- externalTransactionToken from Google before the UPI app opens and stores it
-- on the order; once the payment is approved, the play-report Edge Function
-- reports it to Google (and reports refunds when a payment is revoked).
-- Orders from the direct APKs have no token and are never reported.

alter table public.payment_orders
  add column if not exists play_token          text,
  add column if not exists play_report_status  text
    check (play_report_status in ('pending', 'reported', 'refund_pending', 'refunded', 'failed')),
  add column if not exists play_reported_at    timestamptz,
  add column if not exists play_report_error   text,
  add column if not exists play_attempts       int not null default 0;
create index if not exists payment_orders_play_report_idx on public.payment_orders (play_report_status)
  where play_report_status in ('pending', 'refund_pending');

create table if not exists public.play_settings (
  id            int primary key default 1 check (id = 1),
  package_name  text not null default 'com.flixvault.app',
  enabled       boolean not null default false,
  function_url  text,
  last_run_at   timestamptz,
  last_error    text
);
insert into public.play_settings (id) values (1) on conflict do nothing;
alter table public.play_settings enable row level security;
create policy play_settings_owner on public.play_settings for all
  using (public.is_owner()) with check (public.is_owner());

-- App (Play build): attach Google's token to my own open order.
create or replace function public.attach_play_token(p_order_id uuid, p_token text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_token is null or length(trim(p_token)) < 10 or length(p_token) > 2000 then
    raise exception 'invalid token';
  end if;
  update public.payment_orders
     set play_token = trim(p_token), updated_at = now()
   where id = p_order_id and user_id = auth.uid()
     and status in ('initiated', 'pending') and play_token is null;
  if not found then raise exception 'order not found'; end if;
end $$;

-- Approved → queue the Google report; revoked after reporting → queue refund.
create or replace function public.play_queue_report()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.play_token is null then return new; end if;
  if new.status = 'approved' and old.status is distinct from 'approved'
     and new.play_report_status is null then
    new.play_report_status := 'pending';
  elsif new.status = 'revoked' and old.status = 'approved' then
    new.play_report_status := case
      when old.play_report_status = 'reported' then 'refund_pending'
      when old.play_report_status = 'pending' then null   -- never reported: nothing to refund
      else old.play_report_status end;
  end if;
  return new;
end $$;
drop trigger if exists payment_orders_play_report on public.payment_orders;
create trigger payment_orders_play_report before update of status on public.payment_orders
  for each row execute function public.play_queue_report();

-- Owner: report status for the admin panel.
create or replace function public.admin_play_report_summary()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can see this'; end if;
  return jsonb_build_object(
    'pending', (select count(*) from public.payment_orders where play_report_status in ('pending', 'refund_pending')),
    'reported', (select count(*) from public.payment_orders where play_report_status = 'reported'),
    'refunded', (select count(*) from public.payment_orders where play_report_status = 'refunded'),
    'failed', (select count(*) from public.payment_orders where play_report_status = 'failed'),
    'overdue', (select count(*) from public.payment_orders where play_report_status = 'pending'
                  and verified_at < now() - interval '20 hours'));
end $$;

-- Every 5 minutes: wake the play-report Edge Function (when enabled).
create or replace function public.play_report_tick()
returns void language plpgsql security definer set search_path = '' as $$
declare
  s public.play_settings;
begin
  select * into s from public.play_settings where id = 1;
  if not found or not s.enabled or s.function_url is null then return; end if;
  if not exists (select 1 from public.payment_orders where play_report_status in ('pending', 'refund_pending')) then
    return;
  end if;
  if to_regclass('net.http_request_queue') is null then return; end if;
  execute 'select net.http_post(url := $1, body := ''{}''::jsonb, headers := ''{"Content-Type": "application/json"}''::jsonb)'
    using s.function_url;
end $$;

revoke execute on function public.attach_play_token(uuid, text) from public, anon;
revoke execute on function public.play_queue_report() from public, anon, authenticated;
revoke execute on function public.admin_play_report_summary() from public, anon;
revoke execute on function public.play_report_tick() from public, anon, authenticated;
grant execute on function public.attach_play_token(uuid, text) to authenticated;
grant execute on function public.admin_play_report_summary() to authenticated;
revoke update (play_token, play_report_status, play_reported_at, play_report_error, play_attempts)
  on public.payment_orders from anon, authenticated;

-- Owner: Google report status for the orders shown in the admin panel.
create or replace function public.admin_play_report_rows(p_ids uuid[])
returns table (id uuid, play_report_status text, play_report_error text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can see this'; end if;
  return query select o.id, o.play_report_status, o.play_report_error
    from public.payment_orders o where o.id = any(p_ids) and o.play_token is not null;
end $$;
revoke execute on function public.admin_play_report_rows(uuid[]) from public, anon;
grant execute on function public.admin_play_report_rows(uuid[]) to authenticated;

do $$
begin
  perform cron.schedule('play-report', '*/5 * * * *', 'select public.play_report_tick()');
exception when others then
  raise notice 'play report not scheduled: %', sqlerrm;
end $$;
