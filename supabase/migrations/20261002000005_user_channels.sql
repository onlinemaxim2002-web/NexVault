-- =============================================================================
-- User-created channels
--
-- * Any logged-in app user can create a channel. It starts as a request
--   (review_status = 'pending') and is invisible to others.
-- * The owner approves it in the admin panel and chooses its audience
--   (all / organic / ads) at the same time, or rejects it.
-- * The creator can post videos/images to their channel once it's approved.
--   Creators can't change a channel's audience or status, and can't set
--   premium: their items are premium by default; the owner decides.
-- =============================================================================

alter table public.channels
  add column review_status text not null default 'approved'
    check (review_status in ('pending', 'approved', 'rejected')),
  add column reviewed_by uuid references auth.users (id) on delete set null,
  add column reviewed_at timestamptz;

create index channels_review_idx on public.channels (review_status, created_at);

create or replace function public.is_channel_creator(p_channel_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.channels
                  where id = p_channel_id and created_by = auth.uid())
$$;

-- Creators may post only in their approved channels.
create or replace function public.can_post_in(p_channel_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.can_manage_channel(p_channel_id) or exists (
    select 1 from public.channels
     where id = p_channel_id and created_by = auth.uid()
       and review_status = 'approved' and status = 'published')
$$;

-- Visible = approved + published + audience allows it (admins see all, creators
-- always see their own).
create or replace function public.channel_visible(p_channel_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.channels c
     where c.id = p_channel_id
       and (public.is_admin()
            or c.created_by = auth.uid()
            or (c.review_status = 'approved' and c.status = 'published'
                and public.can_see(c.audience))))
$$;

-- ---------------------------------------------------------------------------
-- Guards for creators (admins are unrestricted). SECURITY INVOKER on purpose:
-- current_user tells a direct client write apart from an internal one.
-- ---------------------------------------------------------------------------
create or replace function public.guard_channel_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Only direct writes from app users are restricted; internal updates made by
  -- the database's own functions (counters, reviews) and admins pass through.
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if (select count(*) from public.channels
         where created_by = auth.uid() and review_status = 'pending') >= 3 then
      raise exception 'you already have 3 channels waiting for approval';
    end if;
    new.created_by    := auth.uid();
    new.review_status := 'pending';
    new.status        := 'draft';
    new.audience      := 'all';
    new.members_count := 0;
    new.rating        := 0;
    new.reviewed_by   := null;
    new.reviewed_at   := null;
  else
    -- Creators can edit name, handle, description, category and icon only.
    new.created_by    := old.created_by;
    new.review_status := old.review_status;
    new.status        := old.status;
    new.audience      := old.audience;
    new.members_count := old.members_count;
    new.rating        := old.rating;
    new.reviewed_by   := old.reviewed_by;
    new.reviewed_at   := old.reviewed_at;
  end if;
  return new;
end $$;

create trigger channels_guard_write
  before insert or update on public.channels
  for each row execute function public.guard_channel_write();

-- Creator posts follow the channel's audience and are published immediately.
create or replace function public.guard_post_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Only direct writes from app users are restricted; internal updates made by
  -- the database's own functions (counters, reviews) and admins pass through.
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  new.audience := (select audience from public.channels where id = new.channel_id);
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.view_count := 0;
    new.like_count := 0;
    if new.status = 'published' and new.published_at is null then
      new.published_at := now();
    end if;
  else
    new.created_by := old.created_by;
    new.view_count := old.view_count;
    new.like_count := old.like_count;
  end if;
  return new;
end $$;

-- Runs before posts_check_audience (triggers fire in name order).
create trigger posts_aa_guard_write
  before insert or update on public.posts
  for each row execute function public.guard_post_write();

-- Premium is the owner's decision: creator items are premium by default.
create or replace function public.guard_item_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Only direct writes from app users are restricted; internal updates made by
  -- the database's own functions (counters, reviews) and admins pass through.
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.is_premium := true;
  else
    new.is_premium := old.is_premium;
  end if;
  return new;
end $$;

create trigger post_items_guard_write
  before insert or update on public.post_items
  for each row execute function public.guard_item_write();

revoke execute on function public.guard_channel_write() from public, anon, authenticated;
revoke execute on function public.guard_post_write()    from public, anon, authenticated;
revoke execute on function public.guard_item_write()    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------
alter policy channels_select on public.channels
  using (public.is_admin()
         or created_by = (select auth.uid())
         or (review_status = 'approved' and status = 'published' and public.can_see(audience)));
alter policy channels_admin_insert on public.channels
  with check (public.is_admin() or public.is_registered());
alter policy channels_admin_insert on public.channels rename to channels_insert;
alter policy channels_admin_update on public.channels
  using (public.can_manage_channel(id) or created_by = (select auth.uid()))
  with check (public.can_manage_channel(id) or created_by = (select auth.uid()));
alter policy channels_admin_update on public.channels rename to channels_update;
create policy channels_creator_delete on public.channels for delete
  using (created_by = (select auth.uid()) and review_status <> 'approved');

alter policy folders_admin_all on public.channel_folders
  using (public.can_manage_channel(channel_id) or public.is_channel_creator(channel_id))
  with check (public.can_manage_channel(channel_id) or public.is_channel_creator(channel_id));
alter policy folders_admin_all on public.channel_folders rename to folders_manage;

alter policy posts_admin_all on public.posts
  using (public.can_post_in(channel_id)) with check (public.can_post_in(channel_id));
alter policy posts_admin_all on public.posts rename to posts_manage;

alter policy items_admin_all on public.post_items
  using (exists (select 1 from public.posts p
                  where p.id = post_id and public.can_post_in(p.channel_id)))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and public.can_post_in(p.channel_id)));
alter policy items_admin_all on public.post_items rename to items_manage;

-- Storage: creators upload media + thumbnails under posts they can post to,
-- and channel icons under channels/<uid>/.
create or replace function public.can_upload_post_media(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.posts p
     where p.id::text = (string_to_array(p_name, '/'))[2]
       and public.can_post_in(p.channel_id))
$$;

create policy media_creator_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media'
              and (storage.foldername(name))[1] = 'posts'
              and public.can_upload_post_media(name));
create policy media_creator_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media'
         and (storage.foldername(name))[1] = 'posts'
         and public.can_upload_post_media(name));
create policy public_creator_thumbs on storage.objects for insert to authenticated
  with check (bucket_id = 'public'
              and (storage.foldername(name))[1] = 'thumbs'
              and public.can_upload_post_media(name));
create policy public_channel_icons on storage.objects for insert to authenticated
  with check (bucket_id = 'public'
              and (storage.foldername(name))[1] = 'channels'
              and (storage.foldername(name))[2] = (select auth.uid())::text
              and public.is_registered());

-- ---------------------------------------------------------------------------
-- Owner review
-- ---------------------------------------------------------------------------
create or replace function public.review_channel(
  p_channel_id uuid, p_approve boolean, p_audience public.audience default 'all')
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_creator uuid;
begin
  if not public.is_owner() then
    raise exception 'only the owner can review channels';
  end if;
  update public.channels
     set review_status = case when p_approve then 'approved' else 'rejected' end,
         status        = case when p_approve then 'published'::public.content_status else 'draft' end,
         audience      = case when p_approve then p_audience else audience end,
         reviewed_by   = auth.uid(),
         reviewed_at   = now(),
         updated_at    = now()
   where id = p_channel_id
  returning created_by into v_creator;
  if not found then raise exception 'channel not found'; end if;

  -- The creator follows their own channel.
  if p_approve and v_creator is not null then
    insert into public.channel_members (channel_id, user_id)
    values (p_channel_id, v_creator) on conflict do nothing;
  end if;

  insert into public.audit_logs (actor_id, action, target, meta)
  values (auth.uid(), case when p_approve then 'approve_channel' else 'reject_channel' end,
          p_channel_id::text, jsonb_build_object('audience', p_audience));
end $$;

create or replace function public.admin_channel_requests(p_status text default 'pending')
returns table (id uuid, name text, description text, category text, icon_url text,
               creator_id uuid, creator_email text, creator_name text, creator_source text,
               review_status text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'only the owner can list channel requests';
  end if;
  return query
  select c.id, c.name, c.description, c.category, c.icon_url,
         c.created_by, u.email::text, p.display_name, public.source_of(c.created_by),
         c.review_status, c.created_at
    from public.channels c
    left join auth.users u on u.id = c.created_by
    left join public.profiles p on p.id = c.created_by
   where c.review_status = p_status
     and not exists (select 1 from public.admins a where a.user_id = c.created_by)
   order by c.created_at;
end $$;

revoke execute on function public.review_channel(uuid, boolean, public.audience) from public, anon;
revoke execute on function public.admin_channel_requests(text)                    from public, anon;
grant  execute on function public.review_channel(uuid, boolean, public.audience) to authenticated;
grant  execute on function public.admin_channel_requests(text)                    to authenticated;

-- Dashboard: add pending channel requests.
create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  return jsonb_build_object(
    'pending_approvals', (select count(*) from public.profiles where ads_access_status = 'pending'),
    'pending_channels',  (select count(*) from public.channels where review_status = 'pending'),
    'users',             (select count(*) from public.profiles p
                           where not exists (select 1 from public.admins a where a.user_id = p.id)),
    'registered',        (select count(*) from public.profiles p where not p.is_guest
                             and not exists (select 1 from public.admins a where a.user_id = p.id)),
    'premium',           (select count(distinct user_id) from public.subscriptions
                           where now() between starts_at and ends_at),
    'installs_ads',      (select count(*) from public.installs where source = public.ad_source()),
    'installs_organic',  (select count(*) from public.installs where source <> public.ad_source()),
    'channels',          (select count(*) from public.channels where review_status = 'approved'),
    'posts_published',   (select count(*) from public.posts where status = 'published'));
end $$;
