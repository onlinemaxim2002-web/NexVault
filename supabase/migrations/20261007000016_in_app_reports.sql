-- In-app reporting of posts and channels (Google Play UGC policy). Reports
-- land in support_requests (admin panel → Requests) as content reports.

create or replace function public.report_content_in_app(
  p_post_id uuid, p_channel_id uuid, p_reason text, p_details text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid   uuid := auth.uid();
  v_email text;
  v_what  text;
  v_id    uuid;
begin
  if v_uid is null then raise exception 'please open the app again and retry'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'choose a reason'; end if;
  if p_post_id is null and p_channel_id is null then raise exception 'nothing to report'; end if;
  if (select count(*) from public.support_requests
       where user_id = v_uid and status = 'open' and created_at > now() - interval '1 day') >= 20 then
    raise exception 'thanks — we already have your reports and are reviewing them';
  end if;

  select email into v_email from auth.users where id = v_uid;
  if p_post_id is not null then
    select format('Post "%s" (%s) in channel "%s" (%s)', p.title, p.id, c.name, c.id)
      into v_what
      from public.posts p join public.channels c on c.id = p.channel_id
     where p.id = p_post_id;
  else
    select format('Channel "%s" (%s)', c.name, c.id) into v_what
      from public.channels c where c.id = p_channel_id;
  end if;
  if v_what is null then raise exception 'this content is no longer available'; end if;

  insert into public.support_requests (kind, email, name, content_url, details, user_id)
  values ('content_report', coalesce(v_email, 'guest (in-app report)'), 'In-app report', v_what,
          left(trim(p_reason) || coalesce(E'\n' || nullif(trim(p_details), ''), ''), 4000), v_uid)
  returning id into v_id;
  return v_id;
end $$;

revoke execute on function public.report_content_in_app(uuid, uuid, text, text) from public, anon;
grant execute on function public.report_content_in_app(uuid, uuid, text, text) to authenticated;
