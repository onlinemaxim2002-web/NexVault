-- =============================================================================
-- Meta (Facebook) Pixel / Conversions API
--
-- The owner enters the Pixel (dataset) ID + access token in the admin panel.
-- Events are created by the database itself when things happen in the app and
-- sent to Meta's Conversions API every minute (pg_cron + pg_net). No app
-- update is needed and the token never reaches the app.
--
--   AppInstall            first launch of an install (custom event)
--   CompleteRegistration  a guest creates an account / logs in for the first time
--   ViewContent           a video/image is opened (full or trailer)
--   InitiateCheckout      a UPI payment order is created (value = plan price)
--   Purchase + Subscribe  a payment is approved (value = amount paid, INR)
--
-- Purchase is sent only after the server approved the payment, with the order
-- id as event_id so Meta never counts it twice.
-- =============================================================================

create table public.meta_settings (
  id               int primary key default 1 check (id = 1),
  pixel_id         text check (pixel_id ~ '^[0-9]{5,20}$'),
  access_token     text,
  test_event_code  text,
  action_source    text not null default 'app' check (action_source in ('app', 'website')),
  website_url      text,
  app_package      text not null default 'com.cloudstorage.app',
  enabled          boolean not null default false,
  updated_at       timestamptz not null default now()
);
insert into public.meta_settings (id) values (1);

alter table public.meta_settings enable row level security;
create policy meta_settings_owner on public.meta_settings for all
  using (public.is_owner()) with check (public.is_owner());

create table public.meta_events (
  id           bigint generated always as identity primary key,
  event_name   text not null,
  event_id     text not null unique,
  event_time   timestamptz not null default now(),
  user_id      uuid references auth.users (id) on delete set null,
  install_id   uuid,
  custom_data  jsonb not null default '{}'::jsonb,
  status       text not null default 'queued' check (status in ('queued', 'sent', 'ok', 'failed')),
  attempts     int not null default 0,
  request_id   bigint,
  response     text,
  created_at   timestamptz not null default now(),
  sent_at      timestamptz
);
create index meta_events_status_idx on public.meta_events (status, id);

alter table public.meta_events enable row level security;
create policy meta_events_owner on public.meta_events for select using (public.is_owner());
revoke insert, update, delete on public.meta_events from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Queue an event (only while the integration is enabled)
-- ---------------------------------------------------------------------------
create or replace function public.meta_enqueue(
  p_event_name text, p_event_id text, p_user_id uuid, p_install_id uuid, p_custom jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.meta_settings
                  where id = 1 and enabled and pixel_id is not null and access_token is not null) then
    return;
  end if;
  insert into public.meta_events (event_name, event_id, user_id, install_id, custom_data)
  values (p_event_name, p_event_id, p_user_id, p_install_id, coalesce(p_custom, '{}'::jsonb))
  on conflict (event_id) do nothing;
exception when others then
  null;  -- tracking must never break the app
end $$;

create or replace function public.meta_sha256(p text)
returns text language sql immutable set search_path = '' as $$
  select case when p is null or trim(p) = '' then null
              else encode(sha256(convert_to(lower(trim(p)), 'UTF8')), 'hex') end
$$;

-- ---------------------------------------------------------------------------
-- Triggers on existing app actions
-- ---------------------------------------------------------------------------
create or replace function public.meta_on_install()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.meta_enqueue('AppInstall', 'install-' || new.install_id, new.first_user_id, new.install_id,
                              jsonb_build_object('source', new.source, 'campaign', new.utm_campaign));
  return new;
end $$;
create trigger meta_installs after insert on public.installs
  for each row execute function public.meta_on_install();

create or replace function public.meta_on_registration()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.is_guest and not new.is_guest then
    perform public.meta_enqueue('CompleteRegistration', 'register-' || new.id, new.id, null,
                                jsonb_build_object('status', 'registered'));
  end if;
  return new;
end $$;
create trigger meta_profiles after update of is_guest on public.profiles
  for each row execute function public.meta_on_registration();

create or replace function public.meta_on_view()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.event in ('content_view', 'preview_view') and new.content_id is not null then
    perform public.meta_enqueue('ViewContent', 'view-' || new.id, new.user_id, new.install_id,
      jsonb_build_object('content_ids', jsonb_build_array(new.content_id::text),
                         'content_type', case new.event when 'preview_view' then 'trailer' else 'video' end));
  end if;
  return new;
end $$;
create trigger meta_analytics after insert on public.analytics_events
  for each row execute function public.meta_on_view();

create or replace function public.meta_on_payment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_plan public.plans;
  v_data jsonb;
begin
  select * into v_plan from public.plans where id = new.plan_id;
  v_data := jsonb_build_object(
    'value', round(new.amount_paise / 100.0, 2),
    'currency', 'INR',
    'content_ids', jsonb_build_array(coalesce(v_plan.code, new.plan_id::text)),
    'content_name', v_plan.name,
    'content_type', 'product',
    'order_id', new.reference);
  if tg_op = 'INSERT' then
    perform public.meta_enqueue('InitiateCheckout', 'checkout-' || new.id, new.user_id, null, v_data);
  elsif new.status = 'approved' and old.status is distinct from 'approved' then
    perform public.meta_enqueue('Purchase', 'purchase-' || new.id, new.user_id, null, v_data);
    perform public.meta_enqueue('Subscribe', 'subscribe-' || new.id, new.user_id, null,
                                v_data || jsonb_build_object('predicted_ltv', round(new.amount_paise / 100.0, 2)));
  end if;
  return new;
end $$;
create trigger meta_payment_insert after insert on public.payment_orders
  for each row execute function public.meta_on_payment();
create trigger meta_payment_update after update of status on public.payment_orders
  for each row execute function public.meta_on_payment();

-- ---------------------------------------------------------------------------
-- Sender (runs every minute via pg_cron; needs pg_net)
-- ---------------------------------------------------------------------------
create or replace function public.meta_event_payload(e public.meta_events, s public.meta_settings)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_email text;
  v_user  jsonb := '{}'::jsonb;
  v_ev    jsonb;
begin
  if e.user_id is not null then
    select email into v_email from auth.users where id = e.user_id;
    v_user := jsonb_build_object('external_id', jsonb_build_array(public.meta_sha256(e.user_id::text)));
    if v_email is not null then
      v_user := v_user || jsonb_build_object('em', jsonb_build_array(public.meta_sha256(v_email)));
    end if;
  elsif e.install_id is not null then
    v_user := jsonb_build_object('external_id', jsonb_build_array(public.meta_sha256(e.install_id::text)));
  end if;

  v_ev := jsonb_build_object(
    'event_name', e.event_name,
    'event_time', extract(epoch from e.event_time)::bigint,
    'event_id', e.event_id,
    'action_source', s.action_source,
    'user_data', v_user,
    'custom_data', e.custom_data);

  if s.action_source = 'app' then
    v_ev := v_ev || jsonb_build_object('app_data', jsonb_build_object(
      'advertiser_tracking_enabled', 1,
      'application_tracking_enabled', 1,
      'extinfo', jsonb_build_array('a2', s.app_package, '1.0', '1.0', '13', 'Android', 'en_IN', 'IST',
                                   '', '1080', '2400', '2.75', '8', '64', '32', 'Asia/Kolkata')));
  else
    v_ev := v_ev || jsonb_build_object('event_source_url', coalesce(s.website_url, 'https://example.com'));
  end if;
  return v_ev;
end $$;

create or replace function public.meta_dispatch()
returns int language plpgsql security definer set search_path = '' as $$
declare
  s     public.meta_settings;
  v_ids bigint[];
  v_req bigint;
  v_n   int := 0;
begin
  if to_regclass('net.http_request_queue') is null then
    return 0;  -- pg_net not installed (local tests)
  end if;

  -- 1. Read Meta's answers for batches sent earlier.
  execute $q$
    update public.meta_events e
       set status = case when r.status_code between 200 and 299 then 'ok'
                         when e.attempts >= 5 then 'failed' else 'queued' end,
           response = left(coalesce(r.content::text, r.error_msg, ''), 1000)
      from net._http_response r
     where e.status = 'sent' and r.id = e.request_id
  $q$;
  -- Batches with no answer after 10 minutes are retried.
  update public.meta_events
     set status = case when attempts >= 5 then 'failed' else 'queued' end,
         response = coalesce(response, 'no response from Meta')
   where status = 'sent' and sent_at < now() - interval '10 minutes';

  select * into s from public.meta_settings where id = 1;
  if not found or not s.enabled or s.pixel_id is null or s.access_token is null then
    return 0;
  end if;

  -- 2. Send up to 500 queued events in one request.
  select array_agg(id order by id) into v_ids
    from (select id from public.meta_events where status = 'queued' order by id limit 500) q;
  if v_ids is null then return 0; end if;

  execute $q$
    select net.http_post(
      url     := 'https://graph.facebook.com/v21.0/' || $1 || '/events',
      body    := $2,
      params  := jsonb_build_object('access_token', $3),
      headers := '{"Content-Type": "application/json"}'::jsonb,
      timeout_milliseconds := 20000)
  $q$
  into v_req
  using s.pixel_id,
        jsonb_strip_nulls(jsonb_build_object(
          'data', (select jsonb_agg(public.meta_event_payload(e, s) order by e.id)
                     from public.meta_events e where e.id = any (v_ids)),
          'test_event_code', nullif(trim(coalesce(s.test_event_code, '')), ''))),
        s.access_token;

  update public.meta_events
     set status = 'sent', request_id = v_req, attempts = attempts + 1, sent_at = now()
   where id = any (v_ids);
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- ---------------------------------------------------------------------------
-- Owner tools for the admin panel
-- ---------------------------------------------------------------------------
create or replace function public.admin_meta_test_event()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can send test events'; end if;
  if not exists (select 1 from public.meta_settings
                  where id = 1 and enabled and pixel_id is not null and access_token is not null) then
    raise exception 'enter the Pixel ID and access token and turn tracking on first';
  end if;
  perform public.meta_enqueue('ViewContent', 'test-' || gen_random_uuid(), auth.uid(), null,
                              jsonb_build_object('content_type', 'test', 'content_ids', jsonb_build_array('test')));
  perform public.meta_dispatch();
end $$;

create or replace function public.admin_meta_events(p_limit int default 100)
returns table (id bigint, event_name text, event_id text, email text, value numeric, status text,
               attempts int, response text, created_at timestamptz, sent_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can see tracking events'; end if;
  perform public.meta_dispatch();  -- also picks up Meta's latest answers
  return query
  select e.id, e.event_name, e.event_id, u.email::text, (e.custom_data->>'value')::numeric, e.status,
         e.attempts, e.response, e.created_at, e.sent_at
    from public.meta_events e
    left join auth.users u on u.id = e.user_id
   order by e.id desc
   limit least(p_limit, 500);
end $$;

revoke execute on function public.meta_enqueue(text, text, uuid, uuid, jsonb)            from public, anon, authenticated;
revoke execute on function public.meta_dispatch()                                        from public, anon, authenticated;
revoke execute on function public.meta_event_payload(public.meta_events, public.meta_settings) from public, anon, authenticated;
revoke execute on function public.meta_on_install()                                      from public, anon, authenticated;
revoke execute on function public.meta_on_registration()                                 from public, anon, authenticated;
revoke execute on function public.meta_on_view()                                         from public, anon, authenticated;
revoke execute on function public.meta_on_payment()                                      from public, anon, authenticated;
revoke execute on function public.admin_meta_test_event()                                from public, anon;
revoke execute on function public.admin_meta_events(int)                                 from public, anon;
grant  execute on function public.admin_meta_test_event()                                to authenticated;
grant  execute on function public.admin_meta_events(int)                                 to authenticated;

-- Sender every minute (Supabase: pg_net + pg_cron). Skipped where unavailable.
do $$
begin
  create extension if not exists pg_net;
  perform cron.schedule('meta-dispatch', '* * * * *', 'select public.meta_dispatch()');
exception when others then
  raise notice 'meta dispatch not scheduled: %', sqlerrm;
end $$;
