-- Admin panel: who created each channel (email, name, ads/organic source).
-- Admins only; emails are never exposed to app users.
create or replace function public.admin_channel_creators()
returns table (channel_id uuid, creator_id uuid, email text, display_name text, source text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  return query
  select c.id, c.created_by, u.email::text, p.display_name,
         case when c.created_by is null then null else public.source_of(c.created_by) end
    from public.channels c
    left join auth.users u on u.id = c.created_by
    left join public.profiles p on p.id = c.created_by;
end $$;

revoke execute on function public.admin_channel_creators() from public, anon;
grant  execute on function public.admin_channel_creators() to authenticated;
