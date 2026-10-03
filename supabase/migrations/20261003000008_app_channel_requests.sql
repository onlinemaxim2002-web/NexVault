-- Channels created from the mobile app are always approval requests, even
-- when the person is an admin testing with their account. The admin panel
-- always sends created_by, the app never does, so a missing created_by marks
-- an app request. Admin-panel channels are unchanged.
create or replace function public.guard_channel_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Admin creating from the app: record them as creator and queue for review.
  if tg_op = 'INSERT' and new.created_by is null
     and current_user in ('authenticated', 'anon') and public.is_admin() then
    new.created_by    := auth.uid();
    new.review_status := 'pending';
    new.status        := 'draft';
    new.audience      := 'all';
    return new;
  end if;

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

-- Show every pending request, including ones an admin made from the app
-- (admin-panel channels are created approved, so they never appear here).
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
   order by c.created_at;
end $$;
