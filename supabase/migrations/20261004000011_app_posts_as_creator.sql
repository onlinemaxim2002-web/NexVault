-- Posts and uploads made from the mobile app follow the creator rules even
-- when the account is an admin: the post takes the channel's audience and
-- records its creator, and app uploads are premium by default.
-- The admin panel always sends created_by (posts) and is_premium (items),
-- so it is unchanged.
create or replace function public.guard_post_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Admin posting from the app (no created_by): treat like a creator post.
  if tg_op = 'INSERT' and new.created_by is null
     and current_user in ('authenticated', 'anon') and public.is_admin() then
    new.created_by := auth.uid();
    new.audience   := (select audience from public.channels where id = new.channel_id);
    if new.status = 'published' and new.published_at is null then
      new.published_at := now();
    end if;
    return new;
  end if;

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

-- App uploads never send is_premium; the admin panel always does.
alter table public.post_items alter column is_premium set default true;
