-- Hardening after the Supabase security advisor run.

-- 1. Pin search_path on every function that didn't set it.
alter function public.ad_source()                                  set search_path = '';
alter function public.protect_first_touch()                        set search_path = '';
alter function public.url_decode(text)                             set search_path = '';
alter function public.referrer_param(text, text)                   set search_path = '';
alter function public.parse_source(text, text)                     set search_path = '';
alter function public.can_see(public.audience)                     set search_path = '';
alter function public.check_post_audience()                        set search_path = '';
alter function public.explore(text, int, int)                      set search_path = '';
alter function public.channel_posts(uuid, timestamptz, int)        set search_path = '';
alter function public.feed(timestamptz, int)                       set search_path = '';

-- 2. Trigger functions are never called directly.
revoke execute on function public.handle_new_user()      from public, anon, authenticated;
revoke execute on function public.handle_user_upgraded() from public, anon, authenticated;
revoke execute on function public.on_plan_activated()    from public, anon, authenticated;
revoke execute on function public.sync_members_count()   from public, anon, authenticated;
revoke execute on function public.protect_first_touch()  from public, anon, authenticated;
revoke execute on function public.check_post_audience()  from public, anon, authenticated;

-- 3. Owner actions need a signed-in session (they also check is_owner()).
revoke execute on function public.grant_premium(uuid, text)                      from public, anon;
revoke execute on function public.set_ads_access(uuid, public.ads_access_status) from public, anon;
revoke execute on function public.attribution_report(timestamptz, timestamptz)   from public, anon;
grant  execute on function public.grant_premium(uuid, text)                      to authenticated;
grant  execute on function public.set_ads_access(uuid, public.ads_access_status) to authenticated;
grant  execute on function public.attribution_report(timestamptz, timestamptz)   to authenticated;

-- Remaining SECURITY DEFINER functions stay executable on purpose: the RLS
-- policies call them (is_admin, can_see, post_visible, …) and they only answer
-- questions about the caller; record_install / log_event are the app's entry points.
