-- Payments reports for the owner (admin panel, read-only):
--   * admin_payment_orders_filtered: orders filtered by status / plan / user /
--     date range and sorted by date, amount or plan.
--   * admin_plan_sales: purchases, buyers and revenue per plan.
--   * admin_buyers: one row per paying user with their purchase history, to
--     spot repeat customers.
-- "Purchase" = an approved payment order. Nothing here changes payments.

create or replace function public.admin_payment_orders_filtered(
  p_status text default 'all',
  p_plan   uuid default null,
  p_user   uuid default null,
  p_from   timestamptz default null,
  p_to     timestamptz default null,
  p_sort   text default 'date_desc',
  p_limit  int default 300)
returns table (id uuid, reference text, user_id uuid, email text, display_name text, source text,
               plan_id uuid, plan_name text, amount_paise int, status text, status_reason text,
               upi_response text, client_status text, txn_id text, verification_source text,
               reviewed_by_email text, report_count int, created_at timestamptz,
               updated_at timestamptz, verified_at timestamptz, user_purchases int)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can list payments'; end if;
  perform public.cancel_stale_payment_orders();
  return query
  select o.id, o.reference, o.user_id, u.email::text, p.display_name, public.source_of(o.user_id),
         o.plan_id, pl.name, o.amount_paise, o.status, o.status_reason, o.upi_response, o.client_status,
         o.txn_id, o.verification_source, r.email::text, o.report_count, o.created_at, o.updated_at,
         o.verified_at,
         (select count(*)::int from public.payment_orders x
           where x.user_id = o.user_id and x.status = 'approved')
    from public.payment_orders o
    join auth.users u on u.id = o.user_id
    left join public.profiles p on p.id = o.user_id
    join public.plans pl on pl.id = o.plan_id
    left join auth.users r on r.id = o.reviewed_by
   where (case p_status
           when 'pending' then o.status in ('initiated', 'pending')
           when 'success' then o.status = 'approved'
           when 'failed' then o.status = 'failed'
           when 'cancelled' then o.status = 'cancelled'
           when 'revoked' then o.status = 'revoked'
           else true end)
     and (p_plan is null or o.plan_id = p_plan)
     and (p_user is null or o.user_id = p_user)
     and (p_from is null or o.created_at >= p_from)
     and (p_to is null or o.created_at < p_to)
   order by
     case when p_sort = 'amount_desc' then o.amount_paise end desc nulls last,
     case when p_sort = 'amount_asc'  then o.amount_paise end asc nulls last,
     case when p_sort = 'plan'        then pl.position end asc nulls last,
     case when p_sort = 'plan'        then pl.name end asc nulls last,
     case when p_sort = 'date_asc'    then o.created_at end asc nulls last,
     o.created_at desc
   limit least(greatest(p_limit, 1), 1000);
end $$;

create or replace function public.admin_plan_sales(
  p_from timestamptz default null,
  p_to   timestamptz default null)
returns table (plan_id uuid, plan_name text, price_inr int, active boolean,
               purchases int, buyers int, repeat_buyers int, revenue_paise bigint,
               pending int, failed int, last_purchase_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can see plan sales'; end if;
  return query
  with o as (
    select * from public.payment_orders x
     where (p_from is null or x.created_at >= p_from)
       and (p_to is null or x.created_at < p_to)
  ), per_user as (
    select o.plan_id, o.user_id, count(*) as n
      from o where o.status = 'approved'
     group by o.plan_id, o.user_id
  )
  select pl.id, pl.name, pl.price_inr, pl.active,
         (select count(*)::int from o where o.plan_id = pl.id and o.status = 'approved'),
         (select count(*)::int from per_user pu where pu.plan_id = pl.id),
         (select count(*)::int from per_user pu where pu.plan_id = pl.id and pu.n > 1),
         (select coalesce(sum(o.amount_paise), 0)::bigint from o where o.plan_id = pl.id and o.status = 'approved'),
         (select count(*)::int from o where o.plan_id = pl.id and o.status in ('initiated', 'pending')),
         (select count(*)::int from o where o.plan_id = pl.id and o.status in ('failed', 'cancelled')),
         (select max(o.verified_at) from o where o.plan_id = pl.id and o.status = 'approved')
    from public.plans pl
   order by pl.position, pl.price_inr;
end $$;

-- One row per paying user. p_min_purchases = 2 lists repeat customers only.
-- history: every approved purchase, oldest first.
create or replace function public.admin_buyers(
  p_min_purchases int default 1,
  p_search text default null,
  p_limit int default 300)
returns table (user_id uuid, email text, display_name text, source text, purchases int,
               total_paise bigint, first_purchase_at timestamptz, last_purchase_at timestamptz,
               current_plan text, plan_ends_at timestamptz, history jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can list buyers'; end if;
  return query
  with b as (
    select o.user_id,
           count(*)::int as purchases,
           sum(o.amount_paise)::bigint as total,
           min(coalesce(o.verified_at, o.created_at)) as first_at,
           max(coalesce(o.verified_at, o.created_at)) as last_at,
           jsonb_agg(jsonb_build_object(
             'reference', o.reference,
             'plan', pl.name,
             'amount_paise', o.amount_paise,
             'at', coalesce(o.verified_at, o.created_at),
             'utr', o.txn_id)
             order by coalesce(o.verified_at, o.created_at)) as history
      from public.payment_orders o
      join public.plans pl on pl.id = o.plan_id
     where o.status = 'approved'
     group by o.user_id
  )
  select b.user_id, u.email::text, p.display_name, public.source_of(b.user_id), b.purchases,
         b.total, b.first_at, b.last_at,
         s.plan_name, s.ends_at, b.history
    from b
    join auth.users u on u.id = b.user_id
    left join public.profiles p on p.id = b.user_id
    left join lateral (
      select pl.name as plan_name, sub.ends_at
        from public.subscriptions sub
        join public.plans pl on pl.id = sub.plan_id
       where sub.user_id = b.user_id and sub.ends_at > now()
       order by sub.ends_at desc
       limit 1
    ) s on true
   where b.purchases >= greatest(coalesce(p_min_purchases, 1), 1)
     and (p_search is null or p_search = ''
          or u.email ilike '%' || p_search || '%'
          or p.display_name ilike '%' || p_search || '%')
   order by b.purchases desc, b.last_at desc
   limit least(greatest(p_limit, 1), 1000);
end $$;

revoke execute on function public.admin_payment_orders_filtered(text, uuid, uuid, timestamptz, timestamptz, text, int) from public, anon;
revoke execute on function public.admin_plan_sales(timestamptz, timestamptz) from public, anon;
revoke execute on function public.admin_buyers(int, text, int) from public, anon;
grant execute on function public.admin_payment_orders_filtered(text, uuid, uuid, timestamptz, timestamptz, text, int) to authenticated;
grant execute on function public.admin_plan_sales(timestamptz, timestamptz) to authenticated;
grant execute on function public.admin_buyers(int, text, int) to authenticated;
