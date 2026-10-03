-- =============================================================================
-- UPI Intent payments
--
-- Flow: app → create_order(plan) → opens upi://pay … → UPI app answers on the
-- phone → app → report_result(order, raw answer) → checks → activate_payment().
--
-- * Amount always comes from the plans table (server), never from the app.
-- * activate_payment() is the ONLY function that grants a plan. The app cannot
--   call it; report_result (after checks), the owner (Mark as paid with UTR) and
--   a future bank/provider hook (source 'provider_api') can.
-- * Every UTR / UPI transaction id can approve one order only.
-- * A UPI app's "SUCCESS" is produced on the customer's phone and can be forged.
--   The checks below reduce the risk; bank-statement checks + Revoke remain
--   necessary until a bank/provider status API is connected.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Settings (UPI ID + payee name editable by the owner)
-- ---------------------------------------------------------------------------
create table public.payment_settings (
  id          int primary key default 1 check (id = 1),
  upi_id      text not null,
  payee_name  text not null,
  enabled     boolean not null default true,
  updated_at  timestamptz not null default now()
);
insert into public.payment_settings (upi_id, payee_name) values ('2728412a@bandhan', 'Cloud Storage');

alter table public.payment_settings enable row level security;
create policy payment_settings_owner on public.payment_settings for all
  using (public.is_owner()) with check (public.is_owner());

-- ---------------------------------------------------------------------------
-- Orders + event log
-- ---------------------------------------------------------------------------
create table public.payment_orders (
  id                   uuid primary key default gen_random_uuid(),
  reference            text not null unique check (reference ~ '^[A-Z0-9]{1,35}$'),
  user_id              uuid not null references auth.users (id) on delete cascade,
  plan_id              uuid not null references public.plans (id),
  amount_paise         int not null check (amount_paise > 0),
  status               text not null default 'initiated'
                         check (status in ('initiated', 'pending', 'approved', 'failed', 'cancelled', 'revoked')),
  upi_response         text,          -- raw answer from the UPI app (latest, while open)
  client_status        text,          -- parsed Status= from that answer
  txn_id               text,          -- UTR / UPI transaction id that approved the order
  verified_at          timestamptz,
  verification_source  text check (verification_source in ('upi_app', 'admin', 'provider_api')),
  reviewed_by          uuid references auth.users (id) on delete set null,
  status_reason        text,          -- why it is pending/failed/revoked (shown to the owner)
  subscription_id      uuid references public.subscriptions (id) on delete set null,
  report_count         int not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- Each UTR / transaction id can be used once, ever (revoked orders keep theirs).
create unique index payment_orders_txn_unique on public.payment_orders (upper(txn_id)) where txn_id is not null;
create index payment_orders_user_idx on public.payment_orders (user_id, created_at desc);
create index payment_orders_status_idx on public.payment_orders (status, created_at desc);

create table public.payment_events (
  id          bigint generated always as identity primary key,
  order_id    uuid not null references public.payment_orders (id) on delete cascade,
  kind        text not null,   -- created | reported | approved | failed | cancelled | revoked | rejected
  detail      text,
  actor_id    uuid,
  created_at  timestamptz not null default now()
);
create index payment_events_order_idx on public.payment_events (order_id, id);

alter table public.payment_orders enable row level security;
alter table public.payment_events enable row level security;

-- Users read only their own orders; nobody writes directly (functions only).
create policy payment_orders_select on public.payment_orders for select
  using (user_id = (select auth.uid()) or public.is_owner());
create policy payment_events_owner on public.payment_events for select
  using (public.is_owner());

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- 'Status=SUCCESS&txnRef=…' → {"status":"SUCCESS","txnref":"…"} (keys lower-cased)
create or replace function public.parse_upi_response(p_raw text)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  v jsonb := '{}'::jsonb;
  kv text;
  val text;
begin
  foreach kv in array string_to_array(coalesce(p_raw, ''), '&') loop
    continue when strpos(kv, '=') < 2;
    val := substr(kv, strpos(kv, '=') + 1);
    begin
      val := public.url_decode(val);
    exception when others then
      null;   -- keep the undecoded value; a bad answer must never stop it being saved
    end;
    v := v || jsonb_build_object(lower(trim(split_part(kv, '=', 1))), trim(val));
  end loop;
  return v;
end $$;

create or replace function public.normalize_upi_status(p_status text)
returns text language sql immutable set search_path = '' as $$
  select case
    when upper(coalesce(p_status, '')) = 'SUCCESS' then 'SUCCESS'
    when upper(coalesce(p_status, '')) in ('FAILURE', 'FAILED', 'FAIL') then 'FAILURE'
    when upper(coalesce(p_status, '')) in ('SUBMITTED', 'PENDING') then 'SUBMITTED'
    when upper(coalesce(p_status, '')) = 'NO_RESPONSE' then 'NO_RESPONSE'
    when coalesce(p_status, '') = '' then 'UNKNOWN'
    else upper(p_status)
  end
$$;

-- Orders still open after 24 h are cancelled (also run by pg_cron when available).
create or replace function public.cancel_stale_payment_orders()
returns int language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  with c as (
    update public.payment_orders
       set status = 'cancelled', status_reason = 'not paid within 24 hours', updated_at = now()
     where status in ('initiated', 'pending') and created_at < now() - interval '24 hours'
    returning id)
  insert into public.payment_events (order_id, kind, detail)
  select id, 'cancelled', 'auto-cancel after 24 h' from c;
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Create order (signed-in, non-guest users)
-- ---------------------------------------------------------------------------
create or replace function public.create_payment_order(p_plan_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid      uuid := auth.uid();
  v_plan     public.plans;
  v_settings public.payment_settings;
  v_order    public.payment_orders;
begin
  if v_uid is null or not public.is_registered() then
    raise exception 'login required';
  end if;
  select * into v_settings from public.payment_settings where id = 1;
  if not found or not v_settings.enabled then
    raise exception 'payments are not available right now';
  end if;
  select * into v_plan from public.plans where id = p_plan_id and active;
  if not found then raise exception 'plan not available'; end if;

  perform public.cancel_stale_payment_orders();

  -- Reuse the open order for the same plan (24 h) if its price is unchanged.
  select * into v_order from public.payment_orders
   where user_id = v_uid and plan_id = p_plan_id and status in ('initiated', 'pending')
     and amount_paise = v_plan.price_inr * 100
     and created_at > now() - interval '24 hours'
   order by created_at desc limit 1;

  -- Close the user's other open orders.
  with c as (
    update public.payment_orders
       set status = 'cancelled', status_reason = 'replaced by a new order', updated_at = now()
     where user_id = v_uid and status in ('initiated', 'pending')
       and (v_order.id is null or id <> v_order.id)
    returning id)
  insert into public.payment_events (order_id, kind, detail, actor_id)
  select id, 'cancelled', 'replaced by a new order', v_uid from c;

  if v_order.id is null then
    insert into public.payment_orders (reference, user_id, plan_id, amount_paise)
    values ('CS' || to_char(now() at time zone 'Asia/Kolkata', 'YYMMDD')
                 || upper(substr(md5(gen_random_uuid()::text), 1, 12)),
            v_uid, v_plan.id, v_plan.price_inr * 100)
    returning * into v_order;
    insert into public.payment_events (order_id, kind, detail, actor_id)
    values (v_order.id, 'created', v_plan.code, v_uid);
  end if;

  return jsonb_build_object(
    'order_id',   v_order.id,
    'reference',  v_order.reference,
    'amount',     to_char(v_order.amount_paise / 100.0, 'FM999999990.00'),
    'plan_name',  v_plan.name,
    'upi_id',     v_settings.upi_id,
    'payee_name', v_settings.payee_name,
    'status',     v_order.status);
end $$;

-- ---------------------------------------------------------------------------
-- 5. Activate (the only function that grants access). Not callable by the app.
-- ---------------------------------------------------------------------------
create or replace function public.activate_payment(
  p_order_id uuid, p_amount_paise int, p_utr text, p_source text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_order public.payment_orders;
  v_plan  public.plans;
  v_utr   text := upper(trim(coalesce(p_utr, '')));
  v_start timestamptz;
  v_sub   uuid;
begin
  if p_source not in ('upi_app', 'admin', 'provider_api') then
    raise exception 'invalid source';
  end if;

  select * into v_order from public.payment_orders where id = p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  -- Idempotent: an approved order is never granted twice.
  if v_order.status = 'approved' then
    return jsonb_build_object('status', 'approved', 'already', true);
  end if;
  if p_amount_paise is distinct from v_order.amount_paise then
    raise exception 'amount does not match the order (expected ₹%)', to_char(v_order.amount_paise / 100.0, 'FM999999990.00');
  end if;
  if v_utr !~ '^[A-Z0-9]{6,40}$' then
    raise exception 'a valid UTR / transaction id (6-40 letters or digits) is required';
  end if;
  if exists (select 1 from public.payment_orders
              where upper(txn_id) = v_utr and id <> v_order.id) then
    raise exception 'this UTR / transaction id was already used for another order';
  end if;

  select * into v_plan from public.plans where id = v_order.plan_id;

  -- Time plans stack: new expiry = max(now, current expiry) + plan length.
  select greatest(now(), coalesce(max(ends_at), now())) into v_start
    from public.subscriptions where user_id = v_order.user_id;
  insert into public.subscriptions (user_id, plan_id, source, starts_at, ends_at, granted_by)
  values (v_order.user_id, v_plan.id, 'payment', v_start,
          v_start + make_interval(days => v_plan.duration_days), auth.uid())
  returning id into v_sub;

  update public.payment_orders
     set status = 'approved', txn_id = v_utr, verified_at = now(),
         verification_source = p_source,
         reviewed_by = case when p_source = 'admin' then auth.uid() else reviewed_by end,
         status_reason = null, subscription_id = v_sub, updated_at = now()
   where id = v_order.id;
  insert into public.payment_events (order_id, kind, detail, actor_id)
  values (v_order.id, 'approved', p_source || ' ' || v_utr, auth.uid());

  return jsonb_build_object('status', 'approved', 'already', false);
end $$;

-- ---------------------------------------------------------------------------
-- 4. Report the UPI app's answer (order owner only)
-- ---------------------------------------------------------------------------
create or replace function public.report_payment_result(p_order_id uuid, p_raw text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_order  public.payment_orders;
  v_kv     jsonb := public.parse_upi_response(p_raw);
  v_status text;
  v_ref    text;
  v_txn    text;
  v_reason text;
begin
  select * into v_order from public.payment_orders where id = p_order_id for update;
  if not found or v_order.user_id is distinct from auth.uid() then
    raise exception 'order not found';
  end if;

  v_status := public.normalize_upi_status(v_kv->>'status');
  insert into public.payment_events (order_id, kind, detail, actor_id)
  values (v_order.id, 'reported', left(coalesce(p_raw, ''), 2000), auth.uid());

  -- Answers for closed orders are logged but change nothing.
  if v_order.status not in ('initiated', 'pending') then
    return jsonb_build_object('status', v_order.status, 'reason', v_order.status_reason);
  end if;

  update public.payment_orders
     set upi_response = left(coalesce(p_raw, ''), 2000), client_status = v_status,
         report_count = report_count + 1, updated_at = now()
   where id = v_order.id;

  if v_status = 'FAILURE' then
    update public.payment_orders
       set status = 'failed', status_reason = 'UPI app reported failure', updated_at = now()
     where id = v_order.id;
    insert into public.payment_events (order_id, kind, detail) values (v_order.id, 'failed', 'UPI app reported failure');
    return jsonb_build_object('status', 'failed');
  end if;

  if v_status = 'SUCCESS' then
    v_ref := coalesce(v_kv->>'txnref', v_kv->>'tr');
    v_txn := upper(coalesce(nullif(v_kv->>'approvalrefno', ''), nullif(v_kv->>'txnid', ''), ''));
    v_reason := case
      when v_ref is not null and upper(v_ref) <> v_order.reference then 'txnRef does not match this order'
      when v_txn !~ '^[A-Z0-9]{6,40}$' then 'no valid transaction id in the UPI answer'
      when exists (select 1 from public.payment_orders where upper(txn_id) = v_txn and id <> v_order.id)
        then 'transaction id already used'
      when v_order.created_at < now() - interval '2 hours' then 'order older than 2 hours'
      else null end;

    if v_reason is null then
      begin
        perform public.activate_payment(v_order.id, v_order.amount_paise, v_txn, 'upi_app');
        return jsonb_build_object('status', 'approved');
      exception when others then
        v_reason := sqlerrm;   -- keep the saved answer; leave pending for review
      end;
    end if;
  else
    v_reason := case v_status
      when 'NO_RESPONSE' then 'no answer from the UPI app (closed or cancelled)'
      when 'SUBMITTED' then 'UPI app says the payment is still processing'
      else 'unrecognised UPI answer' end;
  end if;

  update public.payment_orders
     set status = 'pending', status_reason = v_reason, updated_at = now()
   where id = v_order.id;
  insert into public.payment_events (order_id, kind, detail) values (v_order.id, 'rejected', v_reason);
  return jsonb_build_object('status', 'pending', 'reason', v_reason, 'client_status', v_status);
end $$;

-- ---------------------------------------------------------------------------
-- 7. Owner actions
-- ---------------------------------------------------------------------------
create or replace function public.admin_mark_payment_paid(p_order_id uuid, p_utr text, p_amount_rupees numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can mark payments as paid'; end if;
  return public.activate_payment(p_order_id, round(p_amount_rupees * 100)::int, p_utr, 'admin');
end $$;

create or replace function public.admin_revoke_payment(p_order_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_order public.payment_orders;
begin
  if not public.is_owner() then raise exception 'only the owner can revoke payments'; end if;
  select * into v_order from public.payment_orders where id = p_order_id for update;
  if not found then raise exception 'order not found'; end if;
  if v_order.status <> 'approved' then raise exception 'only approved payments can be revoked'; end if;

  -- Take the access back: end the plan this order granted (now, or never started).
  update public.subscriptions
     set ends_at = greatest(starts_at, least(ends_at, now()))
   where id = v_order.subscription_id;

  update public.payment_orders
     set status = 'revoked', status_reason = coalesce(nullif(p_reason, ''), 'revoked by owner'),
         reviewed_by = auth.uid(), updated_at = now()
   where id = v_order.id;
  insert into public.payment_events (order_id, kind, detail, actor_id)
  values (v_order.id, 'revoked', coalesce(nullif(p_reason, ''), 'revoked by owner'), auth.uid());
end $$;

create or replace function public.admin_payment_orders(p_status text default 'all', p_limit int default 200)
returns table (id uuid, reference text, user_id uuid, email text, display_name text, source text,
               plan_name text, amount_paise int, status text, status_reason text, upi_response text,
               client_status text, txn_id text, verification_source text, reviewed_by_email text,
               report_count int, created_at timestamptz, updated_at timestamptz, verified_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_owner() then raise exception 'only the owner can list payments'; end if;
  perform public.cancel_stale_payment_orders();
  return query
  select o.id, o.reference, o.user_id, u.email::text, p.display_name, public.source_of(o.user_id),
         pl.name, o.amount_paise, o.status, o.status_reason, o.upi_response, o.client_status, o.txn_id,
         o.verification_source, r.email::text, o.report_count, o.created_at, o.updated_at, o.verified_at
    from public.payment_orders o
    join auth.users u on u.id = o.user_id
    left join public.profiles p on p.id = o.user_id
    join public.plans pl on pl.id = o.plan_id
    left join auth.users r on r.id = o.reviewed_by
   where case p_status
           when 'pending' then o.status in ('initiated', 'pending')
           when 'success' then o.status = 'approved'
           when 'failed' then o.status = 'failed'
           when 'cancelled' then o.status = 'cancelled'
           when 'revoked' then o.status = 'revoked'
           else true end
   order by o.created_at desc
   limit least(p_limit, 500);
end $$;

-- ---------------------------------------------------------------------------
-- Bank / provider hook (source 'provider_api'). For a future Edge Function that
-- receives your bank's payment callback or polls its transaction-status API.
-- Only the service role can call it.
-- ---------------------------------------------------------------------------
create or replace function public.provider_confirm_payment(p_reference text, p_amount_paise int, p_utr text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  select id into v_id from public.payment_orders where reference = upper(trim(p_reference));
  if not found then raise exception 'order not found'; end if;
  return public.activate_payment(v_id, p_amount_paise, p_utr, 'provider_api');
end $$;

-- ---------------------------------------------------------------------------
-- Grants: the app may only create orders and report answers.
-- ---------------------------------------------------------------------------
revoke execute on function public.activate_payment(uuid, int, text, text)            from public, anon, authenticated;
revoke execute on function public.provider_confirm_payment(text, int, text)           from public, anon, authenticated;
revoke execute on function public.cancel_stale_payment_orders()                       from public, anon, authenticated;
revoke execute on function public.create_payment_order(uuid)                          from public, anon;
revoke execute on function public.report_payment_result(uuid, text)                   from public, anon;
revoke execute on function public.admin_mark_payment_paid(uuid, text, numeric)        from public, anon;
revoke execute on function public.admin_revoke_payment(uuid, text)                    from public, anon;
revoke execute on function public.admin_payment_orders(text, int)                     from public, anon;
grant  execute on function public.create_payment_order(uuid)                          to authenticated;
grant  execute on function public.report_payment_result(uuid, text)                   to authenticated;
grant  execute on function public.admin_mark_payment_paid(uuid, text, numeric)        to authenticated;
grant  execute on function public.admin_revoke_payment(uuid, text)                    to authenticated;
grant  execute on function public.admin_payment_orders(text, int)                     to authenticated;
grant  execute on function public.provider_confirm_payment(text, int, text)           to service_role;
grant  execute on function public.activate_payment(uuid, int, text, text)             to service_role;
revoke insert, update, delete on public.payment_orders from anon, authenticated;
revoke insert, update, delete on public.payment_events from anon, authenticated;

-- Dashboard: pending payments for the owner's badge.
create or replace function public.admin_pending_payments()
returns int language sql stable security definer set search_path = '' as $$
  select case when public.is_owner()
    then (select count(*)::int from public.payment_orders where status in ('initiated', 'pending')
            and created_at > now() - interval '24 hours'
            and upi_response is not null)
    else 0 end
$$;
revoke execute on function public.admin_pending_payments() from public, anon;
grant  execute on function public.admin_pending_payments() to authenticated;

-- Auto-cancel every 30 minutes where pg_cron is available (Supabase); the
-- functions above also cancel stale orders whenever they run.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('cancel-stale-payment-orders', '*/30 * * * *',
                        'select public.cancel_stale_payment_orders()');
exception when others then
  raise notice 'pg_cron not available: %', sqlerrm;
end $$;
