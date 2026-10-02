-- =============================================================================
-- Cloud Storage: initial schema
--
-- Content model : channels → folders → posts → post_items
-- Visibility    : audience (all | organic | ads) on channels and posts,
--                 enforced by RLS through public.can_see()
-- Attribution   : installs + user_attribution (first touch immutable)
-- Approvals     : organic buyers need owner approval to see 'ads' content
-- Premium       : per item (is_premium); playback URLs come from Edge Functions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------
create type public.audience          as enum ('all', 'organic', 'ads');
create type public.content_status    as enum ('draft', 'published', 'hidden');
create type public.processing_status as enum ('pending', 'ready', 'failed');
create type public.media_kind        as enum ('video', 'image');
create type public.admin_role        as enum ('owner', 'content_admin');
create type public.ads_access_status as enum ('none', 'pending', 'approved', 'rejected');

-- The ad network whose installs count as "ads users".
create or replace function public.ad_source()
returns text language sql immutable as $$ select 'meta' $$;

-- ---------------------------------------------------------------------------
-- Profiles (one per auth user, guests included)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                     uuid primary key references auth.users (id) on delete cascade,
  display_name           text not null,
  avatar_url             text,
  is_guest               boolean not null default true,
  quota_bytes            bigint not null default 0,
  used_bytes             bigint not null default 0,
  status                 text not null default 'active'
                           check (status in ('active', 'suspended', 'pending_deletion')),
  ads_access_status      public.ads_access_status not null default 'none',
  ads_access_decided_by  uuid references auth.users (id) on delete set null,
  ads_access_decided_at  timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, is_guest)
  values (
    new.id,
    'User-' || substr(replace(new.id::text, '-', ''), 1, 8),
    coalesce(new.is_anonymous, true)
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- A guest that links Email/Google keeps the same id; just flip is_guest.
create or replace function public.handle_user_upgraded()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles
     set is_guest = coalesce(new.is_anonymous, false), updated_at = now()
   where id = new.id;
  return new;
end $$;

create trigger on_auth_user_upgraded
  after update of is_anonymous on auth.users
  for each row when (old.is_anonymous is distinct from new.is_anonymous)
  execute function public.handle_user_upgraded();

-- ---------------------------------------------------------------------------
-- Admins
-- ---------------------------------------------------------------------------
create table public.admins (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  role        public.admin_role not null,
  invited_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins where user_id = auth.uid() and role = 'owner')
$$;

create or replace function public.is_registered()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and not is_guest)
$$;

-- ---------------------------------------------------------------------------
-- Attribution
-- ---------------------------------------------------------------------------
create table public.installs (
  install_id       uuid primary key,
  referrer_status  text not null,            -- ok | not_available | error | apk
  raw_referrer     text,
  source           text not null,            -- meta | organic | direct | other | unknown
  utm_source       text,
  utm_medium       text,
  utm_campaign     text,
  utm_content      text,
  utm_term         text,
  click_ts         timestamptz,
  install_ts       timestamptz,
  first_user_id    uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table public.user_attribution (
  user_id                   uuid primary key references auth.users (id) on delete cascade,
  first_touch_source        text not null,
  first_touch_medium        text,
  first_touch_campaign      text,
  first_touch_content       text,
  first_touch_at            timestamptz not null default now(),
  first_touch_install_id    uuid references public.installs (install_id) on delete set null,
  last_touch_source         text not null,
  last_touch_medium         text,
  last_touch_campaign       text,
  last_touch_content        text,
  last_touch_at             timestamptz not null default now(),
  last_touch_install_id     uuid references public.installs (install_id) on delete set null
);

-- First touch can never change once written.
create or replace function public.protect_first_touch()
returns trigger language plpgsql as $$
begin
  if (new.first_touch_source, new.first_touch_medium, new.first_touch_campaign,
      new.first_touch_content, new.first_touch_at)
     is distinct from
     (old.first_touch_source, old.first_touch_medium, old.first_touch_campaign,
      old.first_touch_content, old.first_touch_at) then
    raise exception 'first touch attribution is immutable';
  end if;
  return new;
end $$;

create trigger user_attribution_protect_first_touch
  before update on public.user_attribution
  for each row execute function public.protect_first_touch();

-- Minimal URL decoding for referrer strings (%XX and '+').
create or replace function public.url_decode(p text)
returns text language plpgsql immutable as $$
declare
  result bytea := '';
  i int := 1;
  ch text;
begin
  if p is null then return null; end if;
  while i <= length(p) loop
    ch := substr(p, i, 1);
    if ch = '%' and substr(p, i + 1, 2) ~ '^[0-9A-Fa-f]{2}$' then
      result := result || decode(substr(p, i + 1, 2), 'hex');
      i := i + 3;
    else
      result := result || convert_to(case when ch = '+' then ' ' else ch end, 'UTF8');
      i := i + 1;
    end if;
  end loop;
  return convert_from(result, 'UTF8');
end $$;

create or replace function public.referrer_param(p_referrer text, p_key text)
returns text language sql immutable as $$
  select public.url_decode(split_part(kv, '=', 2))
    from unnest(string_to_array(public.url_decode(coalesce(p_referrer, '')), '&')) as kv
   where lower(split_part(kv, '=', 1)) = lower(p_key)
   limit 1
$$;

-- Map a referrer to a source: meta | organic | direct | other | unknown.
create or replace function public.parse_source(p_status text, p_referrer text)
returns text language plpgsql immutable as $$
declare
  src text := lower(coalesce(public.referrer_param(p_referrer, 'utm_source'), ''));
  med text := lower(coalesce(public.referrer_param(p_referrer, 'utm_medium'), ''));
  ref text := lower(coalesce(p_referrer, ''));
begin
  if src in ('meta', 'facebook', 'fb', 'instagram', 'ig', 'messenger', 'threads',
             'audience_network')
     or ref like '%facebook.com%' or ref like '%instagram.com%' then
    return public.ad_source();
  elsif src = 'google-play' and med = 'organic' then
    return 'organic';
  elsif coalesce(p_referrer, '') = '' then
    return case when p_status in ('not_available', 'apk') then 'direct' else 'unknown' end;
  elsif src <> '' then
    return 'other';
  end if;
  return 'unknown';
end $$;

-- Link the given install to the signed-in user. First touch is written once.
create or replace function public.attribute_user(p_install_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_inst public.installs;
begin
  if v_uid is null then return null; end if;
  select * into v_inst from public.installs where install_id = p_install_id;
  if not found then return null; end if;

  update public.installs
     set first_user_id = v_uid, updated_at = now()
   where install_id = p_install_id and first_user_id is null;

  insert into public.user_attribution as ua (
    user_id,
    first_touch_source, first_touch_medium, first_touch_campaign, first_touch_content,
    first_touch_install_id,
    last_touch_source, last_touch_medium, last_touch_campaign, last_touch_content,
    last_touch_install_id)
  values (
    v_uid,
    v_inst.source, v_inst.utm_medium, v_inst.utm_campaign, v_inst.utm_content,
    v_inst.install_id,
    v_inst.source, v_inst.utm_medium, v_inst.utm_campaign, v_inst.utm_content,
    v_inst.install_id)
  on conflict (user_id) do update
     set last_touch_source     = excluded.last_touch_source,
         last_touch_medium     = excluded.last_touch_medium,
         last_touch_campaign   = excluded.last_touch_campaign,
         last_touch_content    = excluded.last_touch_content,
         last_touch_install_id = excluded.last_touch_install_id,
         last_touch_at         = now();

  return (select first_touch_source from public.user_attribution where user_id = v_uid);
end $$;

-- Called once per install by the app (retried until it succeeds).
-- The first successful referrer read wins and is never overwritten.
create or replace function public.record_install(
  p_install_id      uuid,
  p_referrer_status text,
  p_referrer        text default null,
  p_click_ts        timestamptz default null,
  p_install_ts      timestamptz default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_source text := public.parse_source(p_referrer_status, p_referrer);
begin
  insert into public.installs as i (
    install_id, referrer_status, raw_referrer, source,
    utm_source, utm_medium, utm_campaign, utm_content, utm_term,
    click_ts, install_ts)
  values (
    p_install_id, p_referrer_status, p_referrer, v_source,
    public.referrer_param(p_referrer, 'utm_source'),
    public.referrer_param(p_referrer, 'utm_medium'),
    public.referrer_param(p_referrer, 'utm_campaign'),
    public.referrer_param(p_referrer, 'utm_content'),
    public.referrer_param(p_referrer, 'utm_term'),
    p_click_ts, p_install_ts)
  on conflict (install_id) do update
     set referrer_status = excluded.referrer_status,
         raw_referrer    = excluded.raw_referrer,
         source          = excluded.source,
         utm_source      = excluded.utm_source,
         utm_medium      = excluded.utm_medium,
         utm_campaign    = excluded.utm_campaign,
         utm_content     = excluded.utm_content,
         utm_term        = excluded.utm_term,
         click_ts        = excluded.click_ts,
         install_ts      = excluded.install_ts,
         updated_at      = now()
   where i.referrer_status not in ('ok', 'apk')
     and excluded.referrer_status in ('ok', 'apk');

  perform public.attribute_user(p_install_id);
  return (select source from public.installs where install_id = p_install_id);
end $$;

-- 'ads' or 'organic' for a user, from their immutable first touch.
create or replace function public.source_of(p_user_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case when exists (
    select 1 from public.user_attribution
     where user_id = p_user_id and first_touch_source = public.ad_source())
  then 'ads' else 'organic' end
$$;

create or replace function public.user_source()
returns text language sql stable security definer set search_path = '' as $$
  select public.source_of(auth.uid())
$$;

-- Ads users, plus organic users the owner approved.
create or replace function public.has_ads_access()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.source_of(auth.uid()) = 'ads'
      or exists (select 1 from public.profiles
                  where id = auth.uid() and ads_access_status = 'approved')
$$;

create or replace function public.can_see(p_audience public.audience)
returns boolean language sql stable as $$
  select public.is_admin() or case p_audience
    when 'all'     then true
    when 'organic' then public.user_source() = 'organic'
    when 'ads'     then public.has_ads_access()
  end
$$;

-- ---------------------------------------------------------------------------
-- Content
-- ---------------------------------------------------------------------------
create table public.channels (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  handle         text unique,
  description    text,
  icon_url       text,
  category       text,
  audience       public.audience not null default 'all',
  status         public.content_status not null default 'draft',
  members_count  int not null default 0,
  rating         numeric(3, 2) not null default 0,
  created_by     uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table public.channel_folders (
  id          uuid primary key default gen_random_uuid(),
  channel_id  uuid not null references public.channels (id) on delete cascade,
  name        text not null,
  cover_url   text,
  position    int not null default 0,
  created_at  timestamptz not null default now()
);

create table public.channel_members (
  channel_id  uuid not null references public.channels (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  joined_at   timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create table public.posts (
  id            uuid primary key default gen_random_uuid(),
  channel_id    uuid not null references public.channels (id) on delete cascade,
  folder_id     uuid references public.channel_folders (id) on delete set null,
  title         text not null,
  caption       text,
  audience      public.audience not null default 'all',
  status        public.content_status not null default 'draft',
  published_at  timestamptz,                -- in the future = scheduled
  view_count    bigint not null default 0,
  like_count    bigint not null default 0,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index posts_channel_published_idx on public.posts (channel_id, published_at desc);
create index posts_published_idx on public.posts (published_at desc);

create table public.post_items (
  id                 uuid primary key default gen_random_uuid(),
  post_id            uuid not null references public.posts (id) on delete cascade,
  position           int not null default 0,
  kind               public.media_kind not null,
  is_premium         boolean not null default false,
  media_key          text not null,          -- original upload in R2 (never exposed)
  hls_key            text,                   -- HLS master playlist (never exposed)
  preview_key        text,                   -- short preview clip (never exposed)
  thumb_key          text,
  duration_s         int,
  width              int,
  height             int,
  processing_status  public.processing_status not null default 'pending',
  created_at         timestamptz not null default now()
);

create index post_items_post_idx on public.post_items (post_id, position);

-- A post can't be visible to more people than its channel.
create or replace function public.check_post_audience()
returns trigger language plpgsql as $$
declare
  ch public.audience;
begin
  select audience into ch from public.channels where id = new.channel_id;
  if ch <> 'all' and new.audience <> ch then
    raise exception 'post audience (%) must match its channel audience (%)', new.audience, ch;
  end if;
  return new;
end $$;

create trigger posts_check_audience
  before insert or update of audience, channel_id on public.posts
  for each row execute function public.check_post_audience();

-- Admins: owner can manage every channel; content admins all channels unless
-- limited through admin_channel_access.
create table public.admin_channel_access (
  admin_id    uuid not null references public.admins (user_id) on delete cascade,
  channel_id  uuid not null references public.channels (id) on delete cascade,
  primary key (admin_id, channel_id)
);

create or replace function public.can_manage_channel(p_channel_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_owner()
      or (public.is_admin() and (
            not exists (select 1 from public.admin_channel_access where admin_id = auth.uid())
            or exists (select 1 from public.admin_channel_access
                        where admin_id = auth.uid() and channel_id = p_channel_id)))
$$;

create or replace function public.channel_visible(p_channel_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.channels c
     where c.id = p_channel_id
       and (public.is_admin() or (c.status = 'published' and public.can_see(c.audience))))
$$;

create or replace function public.post_visible(p_post_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.posts p
     where p.id = p_post_id
       and (public.is_admin() or (
             p.status = 'published'
             and p.published_at <= now()
             and public.can_see(p.audience)
             and public.channel_visible(p.channel_id)
             and not exists (select 1 from public.post_items i
                              where i.post_id = p.id and i.processing_status <> 'ready'))))
$$;

-- Keep members_count in sync.
create or replace function public.sync_members_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.channels
     set members_count = (select count(*) from public.channel_members
                           where channel_id = coalesce(new.channel_id, old.channel_id))
   where id = coalesce(new.channel_id, old.channel_id);
  return null;
end $$;

create trigger channel_members_count
  after insert or delete on public.channel_members
  for each row execute function public.sync_members_count();

-- ---------------------------------------------------------------------------
-- Plans & subscriptions (payments deferred: owner grants premium)
-- ---------------------------------------------------------------------------
create table public.plans (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  name           text not null,
  duration_days  int not null check (duration_days > 0),
  price_inr      int not null check (price_inr >= 0),
  perks          jsonb not null default '[]',
  active         boolean not null default true,
  position       int not null default 0
);

create table public.subscriptions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  plan_id     uuid not null references public.plans (id),
  source      text not null default 'admin_grant' check (source in ('admin_grant', 'payment')),
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz not null,
  granted_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

create index subscriptions_user_idx on public.subscriptions (user_id, ends_at desc);

create or replace function public.is_premium_user()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.subscriptions
                  where user_id = auth.uid() and now() between starts_at and ends_at)
$$;

-- Organic buyer → highlighted for owner approval.
create or replace function public.on_plan_activated()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if public.source_of(new.user_id) = 'organic' then
    update public.profiles
       set ads_access_status = 'pending', updated_at = now()
     where id = new.user_id and ads_access_status = 'none';
  end if;
  return new;
end $$;

create trigger subscriptions_on_plan_activated
  after insert on public.subscriptions
  for each row execute function public.on_plan_activated();

-- ---------------------------------------------------------------------------
-- Analytics, consents, reports, audit
-- ---------------------------------------------------------------------------
create table public.analytics_events (
  id          bigint generated always as identity primary key,
  install_id  uuid,
  user_id     uuid references auth.users (id) on delete set null,
  event       text not null check (event in ('app_open', 'login', 'content_view',
                'preview_view', 'special_content_view', 'purchase')),
  content_id  uuid,
  view_id     uuid,
  created_at  timestamptz not null default now(),
  unique (view_id, event)
);

create index analytics_events_event_idx on public.analytics_events (event, created_at);

create table public.consents (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  policy_version  text not null,
  accepted_at     timestamptz not null default now()
);

create table public.reports (
  id           bigint generated always as identity primary key,
  reporter_id  uuid references auth.users (id) on delete set null,
  target_type  text not null check (target_type in ('post', 'channel', 'user')),
  target_id    uuid not null,
  reason       text not null,
  details      text,
  status       text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  created_at   timestamptz not null default now()
);

create table public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid references auth.users (id) on delete set null,
  action      text not null,
  target      text,
  meta        jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RPCs used by the app and the admin panel
-- ---------------------------------------------------------------------------
create or replace function public.log_event(
  p_install_id uuid, p_event text, p_content_id uuid default null, p_view_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_audience public.audience;
begin
  if p_event not in ('app_open', 'login', 'content_view', 'preview_view') then
    raise exception 'event % cannot be logged by clients', p_event;
  end if;

  insert into public.analytics_events (install_id, user_id, event, content_id, view_id)
  values (p_install_id, auth.uid(), p_event, p_content_id, p_view_id)
  on conflict (view_id, event) do nothing;

  if p_event = 'content_view' and p_content_id is not null then
    update public.posts set view_count = view_count + 1 where id = p_content_id
    returning audience into v_audience;
    if v_audience = 'ads' then
      insert into public.analytics_events (install_id, user_id, event, content_id, view_id)
      values (p_install_id, auth.uid(), 'special_content_view', p_content_id, p_view_id)
      on conflict (view_id, event) do nothing;
    end if;
  end if;
end $$;

-- Explore grid. Runs as the caller, so RLS decides what is visible.
create or replace function public.explore(
  p_tab text default 'all', p_limit int default 30, p_offset int default 0)
returns setof public.posts language sql stable as $$
  select p.* from public.posts p
   order by
     case when p_tab = 'popular'      then p.like_count end desc nulls last,
     case when p_tab = 'most_watched' then p.view_count end desc nulls last,
     p.published_at desc
   limit least(p_limit, 100) offset p_offset
$$;

-- Channel page stream (newest first, keyset pagination).
create or replace function public.channel_posts(
  p_channel_id uuid, p_before timestamptz default null, p_limit int default 30)
returns setof public.posts language sql stable as $$
  select p.* from public.posts p
   where p.channel_id = p_channel_id
     and (p_before is null or p.published_at < p_before)
   order by p.published_at desc
   limit least(p_limit, 100)
$$;

-- Feed: posts from channels the user joined.
create or replace function public.feed(p_before timestamptz default null, p_limit int default 30)
returns setof public.posts language sql stable as $$
  select p.* from public.posts p
   join public.channel_members m on m.channel_id = p.channel_id and m.user_id = auth.uid()
   where (p_before is null or p.published_at < p_before)
   order by p.published_at desc
   limit least(p_limit, 100)
$$;

-- Owner: approve / reject / revoke an organic user's access to 'ads' content.
create or replace function public.set_ads_access(p_user_id uuid, p_status public.ads_access_status)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'only the owner can change ads-content access';
  end if;
  update public.profiles
     set ads_access_status = p_status,
         ads_access_decided_by = auth.uid(),
         ads_access_decided_at = now(),
         updated_at = now()
   where id = p_user_id;
  insert into public.audit_logs (actor_id, action, target, meta)
  values (auth.uid(), 'set_ads_access', p_user_id::text, jsonb_build_object('status', p_status));
end $$;

-- Owner: grant premium manually (until payments are integrated).
create or replace function public.grant_premium(p_user_id uuid, p_plan_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_plan public.plans;
  v_start timestamptz;
  v_id uuid;
begin
  if not public.is_owner() then
    raise exception 'only the owner can grant premium';
  end if;
  select * into v_plan from public.plans where code = p_plan_code;
  if not found then raise exception 'unknown plan %', p_plan_code; end if;

  -- Extend from the end of the current plan, if any.
  select greatest(now(), coalesce(max(ends_at), now())) into v_start
    from public.subscriptions where user_id = p_user_id;

  insert into public.subscriptions (user_id, plan_id, source, starts_at, ends_at, granted_by)
  values (p_user_id, v_plan.id, 'admin_grant', v_start,
          v_start + make_interval(days => v_plan.duration_days), auth.uid())
  returning id into v_id;

  insert into public.audit_logs (actor_id, action, target, meta)
  values (auth.uid(), 'grant_premium', p_user_id::text, jsonb_build_object('plan', p_plan_code));
  return v_id;
end $$;

-- Owner: installs / registrations / buyers per source and campaign.
create or replace function public.attribution_report(
  p_from timestamptz default '-infinity', p_to timestamptz default 'infinity')
returns table (source text, campaign text, installs bigint, registrations bigint,
               buyers bigint, subscriptions bigint, revenue_inr bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'only the owner can view the attribution report';
  end if;
  return query
  with inst as (
    select i.source, coalesce(i.utm_campaign, '') as campaign, count(*) as n
      from public.installs i
     where i.created_at between p_from and p_to
     group by 1, 2),
  users as (
    select ua.first_touch_source as source, coalesce(ua.first_touch_campaign, '') as campaign,
           count(distinct ua.user_id) filter (where not pr.is_guest) as registrations,
           count(distinct s.user_id) as buyers,
           count(s.id) as subs,
           coalesce(sum(case when s.source = 'payment' then pl.price_inr end), 0) as revenue
      from public.user_attribution ua
      join public.profiles pr on pr.id = ua.user_id
      left join public.subscriptions s on s.user_id = ua.user_id
      left join public.plans pl on pl.id = s.plan_id
     where ua.first_touch_at between p_from and p_to
     group by 1, 2)
  select coalesce(inst.source, users.source), coalesce(inst.campaign, users.campaign),
         coalesce(inst.n, 0), coalesce(users.registrations, 0), coalesce(users.buyers, 0),
         coalesce(users.subs, 0), coalesce(users.revenue, 0)::bigint
    from inst full join users on users.source = inst.source and users.campaign = inst.campaign
   order by 3 desc;
end $$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles             enable row level security;
alter table public.admins               enable row level security;
alter table public.installs             enable row level security;
alter table public.user_attribution     enable row level security;
alter table public.channels             enable row level security;
alter table public.channel_folders      enable row level security;
alter table public.channel_members      enable row level security;
alter table public.posts                enable row level security;
alter table public.post_items           enable row level security;
alter table public.admin_channel_access enable row level security;
alter table public.plans                enable row level security;
alter table public.subscriptions        enable row level security;
alter table public.analytics_events     enable row level security;
alter table public.consents             enable row level security;
alter table public.reports              enable row level security;
alter table public.audit_logs           enable row level security;

-- profiles: own row (or owner). Users may only edit name/avatar (column grants below).
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_owner());
create policy profiles_update_self on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- admins
create policy admins_select on public.admins for select
  using (user_id = auth.uid() or public.is_owner());
create policy admins_owner_all on public.admins for all
  using (public.is_owner()) with check (public.is_owner());

-- attribution: functions only; users can read their own row, owner reads all.
create policy installs_owner_select on public.installs for select using (public.is_owner());
create policy user_attribution_select on public.user_attribution for select
  using (user_id = auth.uid() or public.is_owner());

-- channels
create policy channels_select on public.channels for select
  using (public.is_admin() or (status = 'published' and public.can_see(audience)));
create policy channels_admin_insert on public.channels for insert
  with check (public.is_admin());
create policy channels_admin_update on public.channels for update
  using (public.can_manage_channel(id)) with check (public.can_manage_channel(id));
create policy channels_admin_delete on public.channels for delete
  using (public.is_owner());

-- folders
create policy folders_select on public.channel_folders for select
  using (public.channel_visible(channel_id));
create policy folders_admin_all on public.channel_folders for all
  using (public.can_manage_channel(channel_id)) with check (public.can_manage_channel(channel_id));

-- members: logged-in (non-guest) users join visible channels
create policy members_select on public.channel_members for select
  using (user_id = auth.uid() or public.is_admin());
create policy members_join on public.channel_members for insert
  with check (user_id = auth.uid() and public.is_registered()
              and public.channel_visible(channel_id));
create policy members_leave on public.channel_members for delete
  using (user_id = auth.uid());

-- posts
create policy posts_select on public.posts for select
  using (public.post_visible(id));
create policy posts_admin_all on public.posts for all
  using (public.can_manage_channel(channel_id)) with check (public.can_manage_channel(channel_id));

-- post items (media keys hidden by column grants)
create policy items_select on public.post_items for select
  using (public.post_visible(post_id));
create policy items_admin_all on public.post_items for all
  using (exists (select 1 from public.posts p
                  where p.id = post_id and public.can_manage_channel(p.channel_id)))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and public.can_manage_channel(p.channel_id)));

create policy admin_channel_access_owner on public.admin_channel_access for all
  using (public.is_owner()) with check (public.is_owner());
create policy admin_channel_access_self on public.admin_channel_access for select
  using (admin_id = auth.uid());

-- plans
create policy plans_select on public.plans for select using (active or public.is_owner());
create policy plans_owner_all on public.plans for all
  using (public.is_owner()) with check (public.is_owner());

-- subscriptions: read own; owner manages (grant_premium)
create policy subscriptions_select on public.subscriptions for select
  using (user_id = auth.uid() or public.is_owner());
create policy subscriptions_owner_all on public.subscriptions for all
  using (public.is_owner()) with check (public.is_owner());

-- analytics: written via log_event only; owner reads
create policy analytics_owner_select on public.analytics_events for select using (public.is_owner());

-- consents
create policy consents_own on public.consents for select using (user_id = auth.uid());
create policy consents_insert on public.consents for insert with check (user_id = auth.uid());

-- reports
create policy reports_insert on public.reports for insert with check (reporter_id = auth.uid());
create policy reports_admin_select on public.reports for select using (public.is_admin());
create policy reports_admin_update on public.reports for update
  using (public.is_admin()) with check (public.is_admin());

-- audit
create policy audit_owner_select on public.audit_logs for select using (public.is_owner());

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Profiles: users can change only their name and avatar.
revoke update on public.profiles from anon, authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

-- Media keys never leave the database for app users; Edge Functions use the
-- service role to sign URLs. Admin panel reads keys through the service role too.
revoke select on public.post_items from anon, authenticated;
grant select (id, post_id, position, kind, is_premium, thumb_key, duration_s, width, height,
              processing_status, created_at)
  on public.post_items to anon, authenticated;
grant insert, update, delete on public.post_items to authenticated;

-- Server-only helpers.
revoke execute on function public.attribute_user(uuid) from public, anon;
grant execute on function public.attribute_user(uuid) to authenticated;
revoke execute on function public.source_of(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Seed: plans (prices editable in the admin panel)
-- ---------------------------------------------------------------------------
insert into public.plans (code, name, duration_days, price_inr, position, perks) values
  ('trial',    'Trial',          2,  69, 1, '["Ad-free experience", "2 TB cloud storage", "Fast upload & download"]'),
  ('silver',   'Silver Plan',    7, 129, 2, '["Ad-free experience", "2 TB cloud storage", "Fast upload & download"]'),
  ('gold',     'Gold Plan',     30, 259, 3, '["Ad-free experience", "2 TB cloud storage", "Fast upload & download"]'),
  ('platinum', 'Platinum Plan', 180, 599, 4, '["Ad-free experience", "2 TB cloud storage", "Fast upload & download"]'),
  ('diamond',  'Diamond Plan',  365, 999, 5, '["Ad-free experience", "2 TB cloud storage", "Fast upload & download"]');
