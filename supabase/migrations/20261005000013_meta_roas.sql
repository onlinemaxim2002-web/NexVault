-- Meta ads ROAS: connect the ad click to the purchase.
--
-- The app is installed from an APK, so Meta cannot attribute app installs the
-- Play Store way. Instead ads point to a download page (admin panel /d) that
-- runs the Pixel. When someone taps Download we save their Meta click id (fbc),
-- browser id (fbp), IP and browser. When the app is first opened from the same
-- network within 48 hours, the install is linked to that click, and every
-- later event for that user (registration, views, checkout, purchase) carries
-- fbc/fbp/IP/user agent, so Meta can credit the purchase to the ad.

-- ---------------------------------------------------------------------------
-- Settings: APK download link for the download page
-- ---------------------------------------------------------------------------
alter table public.meta_settings
  add column if not exists apk_url text,
  add column if not exists page_title text not null default 'NexVault',
  add column if not exists page_subtitle text not null
    default 'Premium videos, trailers and 2 TB cloud storage — all in one app.';

-- ---------------------------------------------------------------------------
-- Ad clicks (download page)
-- ---------------------------------------------------------------------------
create table if not exists public.ad_clicks (
  id            uuid primary key default gen_random_uuid(),
  event_id      text unique,               -- shared with the browser Pixel "Lead" (dedupe)
  fbc           text,
  fbp           text,
  client_ip     text,
  user_agent    text,
  utm_source    text,
  utm_medium    text,
  utm_campaign  text,
  utm_content   text,
  page_url      text,
  install_id    uuid,                      -- set when the app install is matched
  created_at    timestamptz not null default now()
);
create index if not exists ad_clicks_ip_idx on public.ad_clicks (client_ip, created_at desc);
alter table public.ad_clicks enable row level security;
create policy ad_clicks_owner on public.ad_clicks for select using (public.is_owner());
revoke insert, update, delete on public.ad_clicks from anon, authenticated;

alter table public.installs
  add column if not exists client_ip  text,
  add column if not exists user_agent text,
  add column if not exists fbc        text,
  add column if not exists fbp        text,
  add column if not exists ad_click_id uuid references public.ad_clicks (id) on delete set null;

alter table public.meta_events
  add column if not exists ad_click_id uuid references public.ad_clicks (id) on delete set null,
  add column if not exists client_ip  text,
  add column if not exists user_agent text;

-- Caller's IP / user agent from the API request (Supabase passes the headers).
create or replace function public.request_ip()
returns text language sql stable set search_path = '' as $$
  select nullif(trim(split_part(coalesce(
           h->>'cf-connecting-ip', h->>'x-real-ip', h->>'x-forwarded-for', ''), ',', 1)), '')
    from (select nullif(current_setting('request.headers', true), '')::json as h) x
$$;
create or replace function public.request_user_agent()
returns text language sql stable set search_path = '' as $$
  select nullif(left(h->>'user-agent', 400), '')
    from (select nullif(current_setting('request.headers', true), '')::json as h) x
$$;

-- Public config for the download page (no secrets).
create or replace function public.download_page_config()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'pixel_id', case when s.enabled then s.pixel_id end,
    'apk_url', s.apk_url,
    'title', s.page_title,
    'subtitle', s.page_subtitle)
    from public.meta_settings s where s.id = 1
$$;

-- Download tapped on the download page. Called by the admin panel's server
-- route with the visitor's IP and browser.
create or replace function public.record_ad_click(
  p_event_id text, p_fbc text, p_fbp text, p_ip text, p_user_agent text,
  p_utm_source text default null, p_utm_medium text default null,
  p_utm_campaign text default null, p_utm_content text default null, p_page_url text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  insert into public.ad_clicks (event_id, fbc, fbp, client_ip, user_agent, utm_source, utm_medium,
                                utm_campaign, utm_content, page_url)
  values (left(p_event_id, 80), left(p_fbc, 300), left(p_fbp, 120), left(p_ip, 64), left(p_user_agent, 400),
          left(p_utm_source, 100), left(p_utm_medium, 100), left(p_utm_campaign, 200),
          left(p_utm_content, 200), left(p_page_url, 500))
  on conflict (event_id) do nothing
  returning id into v_id;
  if v_id is not null then
    insert into public.meta_events (event_name, event_id, custom_data, ad_click_id)
    select 'Lead', coalesce(left(p_event_id, 80), 'lead-' || v_id), jsonb_build_object('content_name', 'APK download'), v_id
     where exists (select 1 from public.meta_settings
                    where id = 1 and enabled and pixel_id is not null and access_token is not null)
    on conflict (event_id) do nothing;
  end if;
  return v_id;
end $$;

-- New install: remember the phone's IP / user agent and link the latest
-- unmatched ad click from the same IP (48 hours).
create or replace function public.install_match_click()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  c public.ad_clicks;
begin
  new.client_ip  := coalesce(new.client_ip, public.request_ip());
  new.user_agent := coalesce(new.user_agent, public.request_user_agent());
  if new.client_ip is not null and new.ad_click_id is null then
    select * into c from public.ad_clicks
     where client_ip = new.client_ip and install_id is null
       and created_at > now() - interval '48 hours'
     order by created_at desc limit 1;
    if found then
      new.ad_click_id := c.id;
      new.fbc := c.fbc;
      new.fbp := c.fbp;
      update public.ad_clicks set install_id = new.install_id where id = c.id;
    end if;
  end if;
  return new;
exception when others then
  return new;  -- attribution must never block an install
end $$;
drop trigger if exists installs_match_click on public.installs;
create trigger installs_match_click before insert on public.installs
  for each row execute function public.install_match_click();

-- Queue: also remember the acting user's IP / user agent.
create or replace function public.meta_enqueue(
  p_event_name text, p_event_id text, p_user_id uuid, p_install_id uuid, p_custom jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_mine boolean := p_user_id is not null and p_user_id = auth.uid();
begin
  if not exists (select 1 from public.meta_settings
                  where id = 1 and enabled and pixel_id is not null and access_token is not null) then
    return;
  end if;
  insert into public.meta_events (event_name, event_id, user_id, install_id, custom_data, client_ip, user_agent)
  values (p_event_name, p_event_id, p_user_id, p_install_id, coalesce(p_custom, '{}'::jsonb),
          case when v_mine or p_user_id is null then public.request_ip() end,
          case when v_mine or p_user_id is null then public.request_user_agent() end)
  on conflict (event_id) do nothing;
exception when others then
  null;  -- tracking must never break the app
end $$;

-- Payload: match keys from the event, the user's install and the ad click.
create or replace function public.meta_event_payload(e public.meta_events, s public.meta_settings)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_email text;
  v_user  jsonb := '{}'::jsonb;
  v_ev    jsonb;
  v_inst  public.installs;
  v_click public.ad_clicks;
  v_ip    text;
  v_ua    text;
begin
  if e.ad_click_id is not null then
    select * into v_click from public.ad_clicks where id = e.ad_click_id;
  end if;
  select * into v_inst from public.installs i
   where i.install_id = coalesce(
           e.install_id,
           (select coalesce(ua.last_touch_install_id, ua.first_touch_install_id)
              from public.user_attribution ua where ua.user_id = e.user_id),
           (select i2.install_id from public.installs i2 where i2.first_user_id = e.user_id
             order by i2.created_at desc limit 1));
  if v_click.id is null and v_inst.ad_click_id is not null then
    select * into v_click from public.ad_clicks where id = v_inst.ad_click_id;
  end if;

  if e.user_id is not null then
    select email into v_email from auth.users where id = e.user_id;
    v_user := jsonb_build_object('external_id', jsonb_build_array(public.meta_sha256(e.user_id::text)));
    if v_email is not null then
      v_user := v_user || jsonb_build_object('em', jsonb_build_array(public.meta_sha256(v_email)));
    end if;
  elsif e.install_id is not null then
    v_user := jsonb_build_object('external_id', jsonb_build_array(public.meta_sha256(e.install_id::text)));
  elsif v_click.id is not null then
    v_user := jsonb_build_object('external_id', jsonb_build_array(public.meta_sha256(v_click.id::text)));
  end if;
  v_user := v_user || jsonb_build_object('country', jsonb_build_array(public.meta_sha256('in')));

  v_ip := coalesce(e.client_ip, v_click.client_ip, v_inst.client_ip);
  v_ua := coalesce(v_click.user_agent, e.user_agent, v_inst.user_agent);
  if coalesce(v_click.fbc, v_inst.fbc) is not null then
    v_user := v_user || jsonb_build_object('fbc', coalesce(v_click.fbc, v_inst.fbc));
  end if;
  if coalesce(v_click.fbp, v_inst.fbp) is not null then
    v_user := v_user || jsonb_build_object('fbp', coalesce(v_click.fbp, v_inst.fbp));
  end if;
  if v_ip is not null then v_user := v_user || jsonb_build_object('client_ip_address', v_ip); end if;
  if v_ua is not null then v_user := v_user || jsonb_build_object('client_user_agent', v_ua); end if;

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
    v_ev := v_ev || jsonb_build_object('event_source_url',
      coalesce(v_click.page_url, s.website_url, 'https://example.com'));
  end if;
  return v_ev;
end $$;

-- Owner: attribution health for the admin page.
create or replace function public.admin_meta_health()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can see this'; end if;
  return jsonb_build_object(
    'clicks_7d', (select count(*) from public.ad_clicks where created_at > now() - interval '7 days'),
    'matched_7d', (select count(*) from public.ad_clicks where created_at > now() - interval '7 days'
                     and install_id is not null),
    'purchases_7d', (select count(*) from public.meta_events where event_name = 'Purchase'
                       and created_at > now() - interval '7 days'),
    'purchases_ok_7d', (select count(*) from public.meta_events where event_name = 'Purchase'
                          and status = 'ok' and created_at > now() - interval '7 days'),
    'purchases_with_click_7d', (
      select count(*) from public.meta_events e
        left join public.user_attribution ua on ua.user_id = e.user_id
        left join public.installs i on i.install_id = coalesce(ua.last_touch_install_id, ua.first_touch_install_id)
       where e.event_name = 'Purchase' and e.created_at > now() - interval '7 days'
         and i.ad_click_id is not null),
    'revenue_7d', (select coalesce(sum((custom_data->>'value')::numeric), 0) from public.meta_events
                    where event_name = 'Purchase' and created_at > now() - interval '7 days'));
end $$;

-- ---------------------------------------------------------------------------
-- APK downloads bucket (public, admins upload)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('downloads', 'downloads', true, 52428800,
   array['application/vnd.android.package-archive', 'application/octet-stream'])
on conflict (id) do nothing;
create policy downloads_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'downloads' and public.is_admin());
create policy downloads_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'downloads' and public.is_admin());
create policy downloads_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'downloads' and public.is_admin());

revoke execute on function public.request_ip()                    from public, anon, authenticated;
revoke execute on function public.request_user_agent()            from public, anon, authenticated;
revoke execute on function public.install_match_click()           from public, anon, authenticated;
revoke execute on function public.meta_event_payload(public.meta_events, public.meta_settings) from public, anon, authenticated;
revoke execute on function public.record_ad_click(text, text, text, text, text, text, text, text, text, text) from public;
revoke execute on function public.admin_meta_health()             from public, anon;
grant  execute on function public.download_page_config()          to anon, authenticated;
grant  execute on function public.record_ad_click(text, text, text, text, text, text, text, text, text, text) to anon, authenticated;
grant  execute on function public.admin_meta_health()             to authenticated;
