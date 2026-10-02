-- =============================================================================
-- Trailers + creator access
--
-- * Each video item can have a short trailer (post_items.trailer_key).
-- * Trailers play for users with ads access (installed from ads, or organic
--   users the owner approved) without login or plan.
-- * Full videos still need an active plan when the item is premium.
-- * Creators always play their own content in full; admins see everything.
-- =============================================================================

alter table public.post_items add column trailer_key text;
grant select (trailer_key) on public.post_items to anon, authenticated;

-- The user created this post, or the channel it's in.
create or replace function public.is_post_creator(p_post_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.posts p
      join public.channels c on c.id = p.channel_id
     where p.id = p_post_id
       and auth.uid() is not null
       and (p.created_by = auth.uid() or c.created_by = auth.uid()))
$$;

-- Storage read rule for the media bucket (used by signed URLs).
create or replace function public.can_read_media(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin()
      or exists (
        select 1 from public.post_items i
         where i.media_key = p_key
           and (public.is_post_creator(i.post_id)
                or (public.post_visible(i.post_id)
                    and (not i.is_premium or public.is_premium_user()))))
      or exists (
        select 1 from public.post_items i
         where i.trailer_key = p_key
           and (public.is_post_creator(i.post_id)
                or (public.post_visible(i.post_id) and public.has_ads_access())))
$$;
