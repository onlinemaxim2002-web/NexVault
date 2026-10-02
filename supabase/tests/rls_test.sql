-- Behaviour tests for the schema: audience rules, approvals, attribution,
-- membership, admin permissions. Run with supabase/tests/run_tests.sh.
\set ON_ERROR_STOP on
\set QUIET on
set client_min_messages = notice;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create schema t;
grant usage on schema t to anon, authenticated;

create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then
    raise exception 'FAIL: %', msg;
  end if;
  raise notice 'ok - %', msg;
end $$;

create function t.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    raise notice 'ok - % (%)', msg, sqlerrm;
    return;
  end;
  raise exception 'FAIL: expected error: %', msg;
end $$;
grant execute on all functions in schema t to anon, authenticated;

-- Fixed ids make the tests readable.
create table t.ids (name text primary key, id uuid not null);
insert into t.ids values
  ('owner',          '00000000-0000-0000-0000-000000000001'),
  ('content_admin',  '00000000-0000-0000-0000-000000000002'),
  ('ads_guest',      '00000000-0000-0000-0000-000000000003'),
  ('organic_guest',  '00000000-0000-0000-0000-000000000004'),
  ('ads_user',       '00000000-0000-0000-0000-000000000005'),
  ('organic_user',   '00000000-0000-0000-0000-000000000006'),
  ('organic_buyer',  '00000000-0000-0000-0000-000000000007');
grant select on t.ids to anon, authenticated;
create function t.id(p text) returns uuid language sql stable as $$ select id from t.ids where name = p $$;
grant execute on function t.id(text) to anon, authenticated;

-- Switch the session to a user (role authenticated) or back to superuser.
create function t.act_as(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(t.id(p)::text, ''), false);
end $$;

-- ---------------------------------------------------------------------------
-- Fixtures (as superuser)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, is_anonymous) values
  (t.id('owner'),         'owner@example.com', false),
  (t.id('content_admin'), 'staff@example.com', false),
  (t.id('ads_guest'),     null,                true),
  (t.id('organic_guest'), null,                true),
  (t.id('ads_user'),      null,                true),
  (t.id('organic_user'),  null,                true),
  (t.id('organic_buyer'), null,                true);

insert into public.admins (user_id, role) values
  (t.id('owner'), 'owner'), (t.id('content_admin'), 'content_admin');

select t.ok((select count(*) from public.profiles) = 7, 'profile created for every auth user');
select t.ok((select display_name from public.profiles where id = t.id('ads_guest')) like 'User-%',
            'guest gets a generated User-xxxx name');

-- Channels and posts
insert into public.channels (id, name, audience, status) values
  ('10000000-0000-0000-0000-000000000001', 'Everyone channel', 'all',     'published'),
  ('10000000-0000-0000-0000-000000000002', 'Ads channel',      'ads',     'published'),
  ('10000000-0000-0000-0000-000000000003', 'Organic channel',  'organic', 'published'),
  ('10000000-0000-0000-0000-000000000004', 'Draft channel',    'all',     'draft');

insert into public.posts (id, channel_id, title, audience, status, published_at) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'all/all',      'all',     'published', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'all/ads',      'ads',     'published', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'all/organic',  'organic', 'published', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'ads/ads',      'ads',     'published', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000003', 'org/org',      'organic', 'published', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'hidden',       'all',     'hidden',    now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001', 'draft',        'all',     'draft',     null),
  ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001', 'scheduled',    'all',     'published', now() + interval '1 day'),
  ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000001', 'processing',   'all',     'published', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000004', 'in draft ch',  'all',     'published', now() - interval '1 hour');

insert into public.post_items (post_id, kind, is_premium, media_key, hls_key, processing_status)
select id, 'video', true, 'orig/' || id, 'hls/' || id,
       case when title = 'processing' then 'pending'::public.processing_status else 'ready' end
  from public.posts;

select t.fails($$insert into public.posts (channel_id, title, audience)
                 values ('10000000-0000-0000-0000-000000000002', 'x', 'organic')$$,
               'organic post cannot be placed in an ads-only channel');

-- ---------------------------------------------------------------------------
-- Attribution
-- ---------------------------------------------------------------------------
select t.ok(public.parse_source('ok', 'utm_source=facebook&utm_medium=paid_social') = 'meta', 'facebook → meta');
select t.ok(public.parse_source('ok', 'utm_source%3Dig%26utm_campaign%3Dx') = 'meta', 'url-encoded ig → meta');
select t.ok(public.parse_source('apk', 'utm_source=meta&utm_medium=paid_social&utm_campaign=apk_download') = 'meta', 'ads APK → meta');
select t.ok(public.parse_source('ok', 'utm_source=google-play&utm_medium=organic') = 'organic', 'play organic → organic');
select t.ok(public.parse_source('not_available', null) = 'direct', 'plain APK → direct');
select t.ok(public.parse_source('ok', 'utm_source=newsletter') = 'other', 'other source → other');

set role authenticated;

select t.act_as('ads_guest');
select t.ok(public.record_install('30000000-0000-0000-0000-000000000003', 'apk',
            'utm_source=meta&utm_medium=paid_social&utm_campaign=apk_download') = 'meta',
            'ads guest install recorded as meta');
select t.ok(public.user_source() = 'ads', 'ads guest is an ads user');

select t.act_as('organic_guest');
select t.ok(public.record_install('30000000-0000-0000-0000-000000000004', 'not_available') = 'direct',
            'organic guest install recorded as direct');
select t.ok(public.user_source() = 'organic', 'organic guest is organic');

select t.act_as('ads_user');
select public.record_install('30000000-0000-0000-0000-000000000005', 'apk',
       'utm_source=instagram&utm_campaign=diwali');
select t.act_as('organic_user');
select public.record_install('30000000-0000-0000-0000-000000000006', 'not_available');
select t.act_as('organic_buyer');
select public.record_install('30000000-0000-0000-0000-000000000007', 'not_available');

select t.ok(not exists (select 1 from public.installs), 'app users cannot read installs');

reset role;
-- Guests that link Email/Google become registered.
update auth.users set is_anonymous = false
 where id in (t.id('ads_user'), t.id('organic_user'), t.id('organic_buyer'));
select t.ok((select count(*) from public.profiles where not is_guest) = 5, 'linked users are no longer guests');

-- Test 6: first touch never changes after reinstall via the other link.
set role authenticated;
select t.act_as('ads_user');
select public.record_install('30000000-0000-0000-0000-000000000099', 'not_available');
select t.ok(public.user_source() = 'ads', 'reinstall via organic APK keeps first touch = ads');
select t.ok((select last_touch_install_id from public.user_attribution where user_id = t.id('ads_user'))
            = '30000000-0000-0000-0000-000000000099', 'last touch is updated');
select t.act_as('organic_user');
select public.record_install('30000000-0000-0000-0000-000000000098', 'apk', 'utm_source=meta');
select t.ok(public.user_source() = 'organic', 'reinstall via ads APK keeps first touch = organic');
reset role;
select t.fails($$update public.user_attribution set first_touch_source = 'meta'
                  where user_id = t.id('organic_user')$$,
               'first touch cannot be overwritten even by a direct update');

-- First successful referrer read wins.
select public.record_install('30000000-0000-0000-0000-000000000050', 'error');
select public.record_install('30000000-0000-0000-0000-000000000050', 'ok', 'utm_source=fb');
select public.record_install('30000000-0000-0000-0000-000000000050', 'ok', 'utm_source=google-play&utm_medium=organic');
select t.ok((select source from public.installs where install_id = '30000000-0000-0000-0000-000000000050') = 'meta',
            'failed read is replaced by the first successful one, which is then kept');

-- ---------------------------------------------------------------------------
-- Visibility (tests 1, 4, 5)
-- ---------------------------------------------------------------------------
create function t.visible_titles() returns text language sql as $$
  select coalesce(string_agg(title, ',' order by title), '') from public.posts
$$;
grant execute on function t.visible_titles() to authenticated;

set role authenticated;

select t.act_as('ads_guest');
select t.ok(t.visible_titles() = 'ads/ads,all/ads,all/all', 'ads guest: everyone + ads posts only');
select t.ok((select count(*) from public.channels) = 2, 'ads guest: Everyone + Ads channels');

select t.act_as('organic_guest');
select t.ok(t.visible_titles() = 'all/all,all/organic,org/org', 'organic guest: everyone + organic posts only');
select t.ok((select count(*) from public.channels) = 2, 'organic guest: Everyone + Organic channels');

select t.act_as('ads_user');
select t.ok(t.visible_titles() = 'ads/ads,all/ads,all/all', 'logged-in ads user: everyone + ads');

select t.act_as('organic_user');
select t.ok(t.visible_titles() = 'all/all,all/organic,org/org', 'logged-in organic user: everyone + organic');
select t.ok((select count(*) from public.post_items) = 3, 'items follow post visibility');
select t.ok(not exists (select 1 from public.posts where title in
            ('hidden', 'draft', 'scheduled', 'processing', 'in draft ch')),
            'hidden, draft, scheduled, still-processing, and draft-channel posts never appear');
select t.ok((select count(*) from public.explore('latest')) = 3, 'explore() respects the same rules');
select t.fails($$select media_key from public.post_items$$, 'app users cannot read media keys');

-- ---------------------------------------------------------------------------
-- Approvals for organic buyers
-- ---------------------------------------------------------------------------
select t.act_as('organic_buyer');
select t.fails($$select public.grant_premium(t.id('organic_buyer'), 'gold')$$,
               'users cannot grant themselves premium');
select t.fails($$update public.profiles set ads_access_status = 'approved' where id = t.id('organic_buyer')$$,
               'users cannot approve themselves');

select t.act_as('owner');
select public.grant_premium(t.id('organic_buyer'), 'gold');
select public.grant_premium(t.id('ads_user'), 'trial');
select t.ok((select ads_access_status from public.profiles where id = t.id('organic_buyer')) = 'pending',
            'organic buyer is highlighted as pending');
select t.ok((select ads_access_status from public.profiles where id = t.id('ads_user')) = 'none',
            'ads buyer is not sent for approval');

select t.act_as('organic_buyer');
select t.ok(public.is_premium_user(), 'buyer is premium');
select t.ok(t.visible_titles() = 'all/all,all/organic,org/org', 'pending organic buyer still cannot see ads content');

select t.act_as('content_admin');
select t.fails($$select public.set_ads_access(t.id('organic_buyer'), 'approved')$$,
               'content admins cannot approve');

select t.act_as('owner');
select public.set_ads_access(t.id('organic_buyer'), 'approved');

select t.act_as('organic_buyer');
select t.ok(t.visible_titles() = 'ads/ads,all/ads,all/all,all/organic,org/org',
            'approved organic buyer sees everything');

select t.act_as('owner');
select public.set_ads_access(t.id('organic_buyer'), 'rejected');
select t.act_as('organic_buyer');
select t.ok(t.visible_titles() = 'all/all,all/organic,org/org', 'revoked approval removes ads content again');

-- ---------------------------------------------------------------------------
-- Channel membership
-- ---------------------------------------------------------------------------
select t.act_as('ads_guest');
select t.fails($$insert into public.channel_members (channel_id, user_id)
                 values ('10000000-0000-0000-0000-000000000001', t.id('ads_guest'))$$,
               'guests must log in to join');

select t.act_as('organic_user');
insert into public.channel_members (channel_id, user_id)
values ('10000000-0000-0000-0000-000000000001', t.id('organic_user'));
select t.ok(true, 'logged-in user joins a channel');
select t.fails($$insert into public.channel_members (channel_id, user_id)
                 values ('10000000-0000-0000-0000-000000000002', t.id('organic_user'))$$,
               'organic user cannot join an ads-only channel');
select t.ok((select string_agg(title, ',' order by title) from public.feed()) = 'all/all,all/organic',
            'feed shows visible posts from joined channels');

reset role;
select t.ok((select members_count from public.channels
              where id = '10000000-0000-0000-0000-000000000001') = 1, 'members_count updated');

-- ---------------------------------------------------------------------------
-- Admin permissions
-- ---------------------------------------------------------------------------
set role authenticated;
select t.act_as('content_admin');
select t.ok((select count(*) from public.posts) = 10, 'admins see all posts, including drafts');
update public.posts set title = 'all/all' where id = '20000000-0000-0000-0000-000000000001';
select t.ok(true, 'content admin can edit posts');

reset role;
insert into public.admin_channel_access values (t.id('content_admin'), '10000000-0000-0000-0000-000000000002');
set role authenticated;
select t.act_as('content_admin');
update public.posts set caption = 'nope' where id = '20000000-0000-0000-0000-000000000001';
reset role;
select t.ok((select caption from public.posts where id = '20000000-0000-0000-0000-000000000001') is null,
            'content admin limited to one channel cannot edit other channels');

set role authenticated;
select t.act_as('organic_user');
update public.posts set title = 'hacked' where id = '20000000-0000-0000-0000-000000000001';
reset role;
select t.ok((select title from public.posts where id = '20000000-0000-0000-0000-000000000001') = 'all/all',
            'app users cannot edit posts');

-- ---------------------------------------------------------------------------
-- Analytics & report (test 7)
-- ---------------------------------------------------------------------------
set role authenticated;
select t.act_as('ads_user');
select public.log_event('30000000-0000-0000-0000-000000000005', 'content_view',
       '20000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000001');
select public.log_event('30000000-0000-0000-0000-000000000005', 'content_view',
       '20000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000001');
select t.fails($$select public.log_event(null, 'purchase')$$, 'clients cannot log purchases');

select t.act_as('organic_user');
select t.fails($$select * from public.attribution_report()$$, 'only the owner sees the report');

select t.act_as('owner');
select t.ok((select count(*) from public.analytics_events where event = 'special_content_view') = 1,
            'special_content_view logged once per view');
select t.ok((select installs from public.attribution_report() where source = 'meta' and campaign = 'apk_download') = 1,
            'report counts installs per source and campaign');
select t.ok((select registrations from public.attribution_report() where source = 'meta' and campaign = 'diwali') = 1,
            'report counts registrations');
select t.ok((select buyers from public.attribution_report() where source = 'direct') = 1,
            'report counts buyers');

reset role;

-- ---------------------------------------------------------------------------
-- Admin panel read models
-- ---------------------------------------------------------------------------
set role authenticated;
select t.act_as('organic_user');
select t.fails($$select * from public.admin_users()$$, 'app users cannot list users');
select t.fails($$select public.admin_dashboard()$$, 'app users cannot read the dashboard');
select t.act_as('content_admin');
select t.fails($$select * from public.admin_list_admins()$$, 'content admins cannot list admins');
select t.ok((public.admin_dashboard()->>'posts_published')::int = 8, 'content admins can read the dashboard');

select t.act_as('owner');
select t.ok((select count(*) from public.admin_users()) = 5, 'owner lists app users (admins excluded)');
select t.ok((select source from public.admin_users() where id = t.id('ads_user')) = 'ads', 'user list shows source');
select t.ok((select plan_name from public.admin_users() where id = t.id('organic_buyer')) = 'Gold Plan',
            'user list shows the active plan');
select t.ok((select count(*) from public.admin_users('rejected')) = 1, 'filter by approval status');
select t.ok((select count(*) from public.admin_users('all', 'staff@')) = 0, 'search does not return admins');
select t.ok((select email from public.admin_list_admins() where role = 'content_admin') = 'staff@example.com',
            'owner lists admins with emails');
select t.ok((select array_length(channel_ids, 1) from public.admin_list_admins() where role = 'content_admin') = 1,
            'admin list shows channel limits');
select t.ok((public.admin_dashboard()->>'installs_ads')::int >= 2, 'dashboard counts ads installs');
reset role;
\echo
\echo 'All tests passed.'
