-- =============================================================================
-- Storage (Supabase Storage for now; Cloudflare R2 later), personal cloud files,
-- plan requests, and an app status RPC.
--
-- Buckets
--   media   private  post videos/images. Readable (signed URL) only when the post
--                    is visible to the user AND the item is free or the user is premium
--   public  public   thumbnails, channel icons, avatars
--   cloud   private  personal cloud files at <user_id>/..., premium users only
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('media',  'media',  false, 52428800, array['video/*', 'image/*']),
  ('public', 'public', true,  10485760, array['image/*']),
  ('cloud',  'cloud',  false, 52428800, null)
on conflict (id) do nothing;

-- Media keys are only object paths; access is decided by the storage policies below.
grant select (media_key) on public.post_items to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage policies
-- ---------------------------------------------------------------------------
create or replace function public.can_read_media(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or exists (
    select 1 from public.post_items i
     where i.media_key = p_key
       and public.post_visible(i.post_id)
       and (not i.is_premium or public.is_premium_user()))
$$;

create policy media_read on storage.objects for select to authenticated
  using (bucket_id = 'media' and public.can_read_media(name));
create policy media_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.is_admin());
create policy media_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'media' and public.is_admin());
create policy media_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and public.is_admin());

-- public bucket: admins write thumbs/ and channels/; users write their own avatars/<uid>/
create policy public_admin_write on storage.objects for insert to authenticated
  with check (bucket_id = 'public' and public.is_admin());
create policy public_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'public' and public.is_admin());
create policy public_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'public' and public.is_admin());
create policy public_avatar_write on storage.objects for insert to authenticated
  with check (bucket_id = 'public'
              and (storage.foldername(name))[1] = 'avatars'
              and (storage.foldername(name))[2] = (select auth.uid())::text);

-- cloud bucket: own folder only; uploading needs an active plan
create policy cloud_read_own on storage.objects for select to authenticated
  using (bucket_id = 'cloud' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy cloud_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'cloud'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and public.is_premium_user());
create policy cloud_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'cloud' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------------------
-- Personal cloud files
-- ---------------------------------------------------------------------------
create or replace function public.quota_bytes(p_user_id uuid)
returns bigint language sql stable security definer set search_path = '' as $$
  select case when exists (select 1 from public.subscriptions
                            where user_id = p_user_id and now() between starts_at and ends_at)
              then 2199023255552::bigint   -- 2 TB for premium
              else 0::bigint end
$$;

create table public.cloud_files (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  parent_id    uuid references public.cloud_files (id) on delete cascade,
  name         text not null check (length(name) between 1 and 255),
  is_folder    boolean not null default false,
  storage_key  text,                 -- cloud/<user_id>/<uuid>-<name>; null for folders
  mime         text,
  size         bigint not null default 0 check (size >= 0),
  created_at   timestamptz not null default now(),
  check (is_folder = (storage_key is null))
);

create index cloud_files_user_parent_idx on public.cloud_files (user_id, parent_id, is_folder desc, name);

-- Keep used_bytes in sync and enforce the quota on new files.
create or replace function public.cloud_files_usage()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.parent_id is not null and not exists (
         select 1 from public.cloud_files
          where id = new.parent_id and user_id = new.user_id and is_folder) then
      raise exception 'parent folder not found';
    end if;
    if not new.is_folder then
      if (select used_bytes from public.profiles where id = new.user_id) + new.size
         > public.quota_bytes(new.user_id) then
        raise exception 'storage quota exceeded';
      end if;
      update public.profiles set used_bytes = used_bytes + new.size where id = new.user_id;
    end if;
    return new;
  else
    if not old.is_folder then
      update public.profiles set used_bytes = greatest(0, used_bytes - old.size) where id = old.user_id;
    end if;
    return old;
  end if;
end $$;

create trigger cloud_files_usage_trg
  after insert or delete on public.cloud_files
  for each row execute function public.cloud_files_usage();

alter table public.cloud_files enable row level security;

create policy cloud_files_select on public.cloud_files for select
  using (user_id = (select auth.uid()));
create policy cloud_files_insert on public.cloud_files for insert
  with check (user_id = (select auth.uid()) and public.is_premium_user());
create policy cloud_files_update on public.cloud_files for update
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy cloud_files_delete on public.cloud_files for delete
  using (user_id = (select auth.uid()));

-- Only renaming / moving is allowed after creation.
revoke update on public.cloud_files from anon, authenticated;
grant update (name, parent_id) on public.cloud_files to authenticated;

-- Storage keys of a folder and everything inside it (to delete the objects first).
create or replace function public.cloud_folder_keys(p_folder_id uuid)
returns setof text language sql stable as $$
  with recursive tree as (
    select id, storage_key from public.cloud_files where id = p_folder_id
    union all
    select c.id, c.storage_key from public.cloud_files c join tree t on c.parent_id = t.id
  )
  select storage_key from tree where storage_key is not null
$$;
alter function public.cloud_folder_keys(uuid) set search_path = '';

-- ---------------------------------------------------------------------------
-- Plan requests (payments are deferred: users request a plan, the owner grants it)
-- ---------------------------------------------------------------------------
create table public.plan_requests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  plan_id     uuid not null references public.plans (id),
  status      text not null default 'open' check (status in ('open', 'granted', 'dismissed')),
  created_at  timestamptz not null default now()
);

create index plan_requests_status_idx on public.plan_requests (status, created_at desc);
create unique index plan_requests_one_open on public.plan_requests (user_id) where status = 'open';

alter table public.plan_requests enable row level security;

create policy plan_requests_select on public.plan_requests for select
  using (user_id = (select auth.uid()) or public.is_owner());
create policy plan_requests_insert on public.plan_requests for insert
  with check (user_id = (select auth.uid()) and public.is_registered());
create policy plan_requests_owner_update on public.plan_requests for update
  using (public.is_owner()) with check (public.is_owner());

-- Granting a plan closes the user's open request.
create or replace function public.close_plan_requests()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.plan_requests set status = 'granted'
   where user_id = new.user_id and status = 'open';
  return new;
end $$;

create trigger subscriptions_close_requests
  after insert on public.subscriptions
  for each row execute function public.close_plan_requests();

revoke execute on function public.close_plan_requests() from public, anon, authenticated;
revoke execute on function public.cloud_files_usage()   from public, anon, authenticated;

-- Owner view of open requests, with email.
create or replace function public.admin_plan_requests()
returns table (id uuid, user_id uuid, email text, display_name text, source text,
               plan_code text, plan_name text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'only the owner can list plan requests';
  end if;
  return query
  select r.id, r.user_id, u.email::text, p.display_name, public.source_of(r.user_id),
         pl.code, pl.name, r.created_at
    from public.plan_requests r
    join auth.users u on u.id = r.user_id
    join public.profiles p on p.id = r.user_id
    join public.plans pl on pl.id = r.plan_id
   where r.status = 'open'
   order by r.created_at;
end $$;

revoke execute on function public.admin_plan_requests() from public, anon;
grant  execute on function public.admin_plan_requests() to authenticated;

-- ---------------------------------------------------------------------------
-- App status in one call
-- ---------------------------------------------------------------------------
create or replace function public.my_status()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_id',        p.id,
    'display_name',   p.display_name,
    'avatar_url',     p.avatar_url,
    'is_guest',       p.is_guest,
    'source',         public.source_of(p.id),
    'has_ads_access', public.has_ads_access(),
    'is_premium',     public.is_premium_user(),
    'plan_name',      cur.name,
    'plan_ends_at',   cur.ends_at,
    'used_bytes',     p.used_bytes,
    'quota_bytes',    public.quota_bytes(p.id),
    'open_request',   (select pl.name from public.plan_requests r join public.plans pl on pl.id = r.plan_id
                        where r.user_id = p.id and r.status = 'open' limit 1))
    from public.profiles p
    left join lateral (
      select pl.name, s.ends_at from public.subscriptions s join public.plans pl on pl.id = s.plan_id
       where s.user_id = p.id and now() between s.starts_at and s.ends_at
       order by s.ends_at desc limit 1) cur on true
   where p.id = auth.uid()
$$;

-- Account deletion is handled by the delete-account Edge Function (Auth admin API).
