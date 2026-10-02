-- Owner-only read models for the admin panel (emails live in auth.users,
-- which clients can't query directly).

create or replace function public.admin_users(
  p_filter text default 'all',          -- all | pending | approved | rejected | premium | ads | organic
  p_search text default null,
  p_limit  int  default 50,
  p_offset int  default 0)
returns table (
  id                 uuid,
  email              text,
  display_name       text,
  is_guest           boolean,
  source             text,
  campaign           text,
  plan_name          text,
  plan_ends_at       timestamptz,
  ads_access_status  public.ads_access_status,
  created_at         timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'only the owner can list users';
  end if;
  return query
  select p.id, u.email::text, p.display_name, p.is_guest,
         public.source_of(p.id), ua.first_touch_campaign,
         cur.name, cur.ends_at, p.ads_access_status, p.created_at
    from public.profiles p
    join auth.users u on u.id = p.id
    left join public.user_attribution ua on ua.user_id = p.id
    left join lateral (
      select pl.name, s.ends_at from public.subscriptions s
        join public.plans pl on pl.id = s.plan_id
       where s.user_id = p.id and now() between s.starts_at and s.ends_at
       order by s.ends_at desc limit 1) cur on true
   where not exists (select 1 from public.admins a where a.user_id = p.id)
     and (p_search is null or p_search = ''
          or u.email ilike '%' || p_search || '%'
          or p.display_name ilike '%' || p_search || '%'
          or p.id::text = p_search)
     and case p_filter
           when 'pending'  then p.ads_access_status = 'pending'
           when 'approved' then p.ads_access_status = 'approved'
           when 'rejected' then p.ads_access_status = 'rejected'
           when 'premium'  then cur.ends_at is not null
           when 'ads'      then public.source_of(p.id) = 'ads'
           when 'organic'  then public.source_of(p.id) = 'organic'
           else true
         end
   order by (p.ads_access_status = 'pending') desc, p.created_at desc
   limit least(p_limit, 200) offset p_offset;
end $$;

create or replace function public.admin_list_admins()
returns table (user_id uuid, email text, role public.admin_role, created_at timestamptz,
               channel_ids uuid[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'only the owner can list admins';
  end if;
  return query
  select a.user_id, u.email::text, a.role, a.created_at,
         coalesce(array_agg(c.channel_id) filter (where c.channel_id is not null), '{}')
    from public.admins a
    join auth.users u on u.id = a.user_id
    left join public.admin_channel_access c on c.admin_id = a.user_id
   group by a.user_id, u.email, a.role, a.created_at
   order by a.role, a.created_at;
end $$;

create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  return jsonb_build_object(
    'pending_approvals', (select count(*) from public.profiles where ads_access_status = 'pending'),
    'users',             (select count(*) from public.profiles p
                           where not exists (select 1 from public.admins a where a.user_id = p.id)),
    'registered',        (select count(*) from public.profiles p where not p.is_guest
                             and not exists (select 1 from public.admins a where a.user_id = p.id)),
    'premium',           (select count(distinct user_id) from public.subscriptions
                           where now() between starts_at and ends_at),
    'installs_ads',      (select count(*) from public.installs where source = public.ad_source()),
    'installs_organic',  (select count(*) from public.installs where source <> public.ad_source()),
    'channels',          (select count(*) from public.channels),
    'posts_published',   (select count(*) from public.posts where status = 'published'));
end $$;

revoke execute on function public.admin_users(text, text, int, int) from public, anon;
revoke execute on function public.admin_list_admins()               from public, anon;
revoke execute on function public.admin_dashboard()                 from public, anon;
grant  execute on function public.admin_users(text, text, int, int) to authenticated;
grant  execute on function public.admin_list_admins()               to authenticated;
grant  execute on function public.admin_dashboard()                 to authenticated;
