-- Phase 4B: atomic server-owned checkout creation and durable verified-event processing.
-- This adds application workflow primitives only. The only supported adapter is non-production sandbox.
alter table public.payment_webhook_events
  add column amount_minor bigint,
  add column currency text,
  add column provider_reference text;

alter table public.payment_webhook_events
  add constraint payment_webhook_amount_nonnegative
    check (amount_minor is null or amount_minor >= 0),
  add constraint payment_webhook_currency_format
    check (currency is null or currency ~ '^[A-Z]{3}$'),
  add constraint payment_webhook_provider_reference_length
    check (provider_reference is null or char_length(provider_reference) between 1 and 240),
  add constraint payment_webhook_financial_event_fields
    check (
      event_type not in ('payment.succeeded', 'payment.failed', 'refund.succeeded')
      or (amount_minor is not null and currency is not null)
    );

create or replace function public.enforce_webhook_event_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.processing_status <> 'received' or not new.signature_verified then
      raise exception using errcode = '23514', message = 'only verified webhook events may enter the inbox';
    end if;
    if new.event_type in ('payment.succeeded', 'payment.failed') then
      if new.amount_minor is null or new.currency is null
        or not exists (
          select 1 from public.payment_attempts pa
          where pa.id = new.payment_attempt_id and pa.order_id = new.order_id
            and pa.provider = new.provider and pa.amount_minor = new.amount_minor
            and pa.currency = new.currency
        ) then
        raise exception using errcode = '23514', message = 'payment event must match the provider attempt, order, amount and currency';
      end if;
    elsif new.event_type = 'refund.succeeded' then
      if new.amount_minor is null or new.currency is null
        or not exists (
          select 1 from public.refunds r
          join public.payment_attempts pa on pa.id = r.payment_attempt_id
          where r.id = new.refund_id and r.order_id = new.order_id
            and r.payment_attempt_id = new.payment_attempt_id and pa.provider = new.provider
            and r.amount_minor = new.amount_minor and r.currency = new.currency
        ) then
        raise exception using errcode = '23514', message = 'refund event must match provider refund, attempt, order, amount and currency';
      end if;
    end if;
    return new;
  end if;

  if new.provider is distinct from old.provider
    or new.provider_event_id is distinct from old.provider_event_id
    or new.payload_sha256 is distinct from old.payload_sha256
    or new.event_type is distinct from old.event_type
    or new.order_id is distinct from old.order_id
    or new.payment_attempt_id is distinct from old.payment_attempt_id
    or new.refund_id is distinct from old.refund_id
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.provider_reference is distinct from old.provider_reference
    or new.signature_verified is distinct from old.signature_verified
    or (old.processed_at is not null and new.processed_at is distinct from old.processed_at)
    or (new.retry_count is distinct from old.retry_count
      and not (old.processing_status = 'failed' and new.processing_status = 'processing'
        and new.retry_count = old.retry_count + 1)) then
    raise exception using errcode = '23514', message = 'webhook event identity and verification evidence are immutable';
  end if;

  if new.processing_status <> old.processing_status and not (
    (old.processing_status = 'received' and new.processing_status in ('processing', 'ignored', 'failed'))
    or (old.processing_status = 'failed' and new.processing_status = 'processing')
    or (old.processing_status = 'processing' and new.processing_status in ('processed', 'failed', 'ignored'))
  ) then
    raise exception using errcode = '23514', message = 'invalid webhook processing transition';
  end if;

  if new.processing_status = 'processed' and new.processed_at is null then
    raise exception using errcode = '23514', message = 'processed webhook event requires processed_at';
  end if;
  if new.processing_status <> 'processed' and new.processed_at is not null then
    raise exception using errcode = '23514', message = 'unprocessed webhook event cannot have processed_at';
  end if;
  if new.processing_status = 'processing' and old.processing_status = 'failed' then
    new.retry_count := old.retry_count + 1;
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_webhook_event_transition() from public, anon, authenticated, service_role;

create function public.create_order_for_checkout(
  p_customer_id uuid,
  p_items jsonb,
  p_idempotency_key text
)
returns table(order_id uuid, status text, total_minor bigint, currency text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  input_count bigint;
  matching_count bigint;
  calculated_total bigint;
  currency_min text;
  currency_max text;
  existing_order public.orders%rowtype;
  created_order_id uuid;
begin
  if p_customer_id is null
    or p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) < 1
    or jsonb_array_length(p_items) > 20
    or p_idempotency_key is null
    or char_length(p_idempotency_key) not between 16 and 200 then
    raise exception using errcode = '22023', message = 'invalid checkout request';
  end if;

  select count(*) into input_count
  from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer);
  if input_count < 1 or exists (
    select 1 from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer)
    where item.product_version_id is null or item.quantity is null or item.quantity not between 1 and 100
  ) or (
    select count(distinct item.product_version_id)
    from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer)
  ) <> input_count then
    raise exception using errcode = '22023', message = 'checkout items must have unique release IDs and quantities between 1 and 100';
  end if;

  select count(*), coalesce(sum(p.price_minor * item.quantity), 0),
         min(p.currency), max(p.currency)
    into matching_count, calculated_total, currency_min, currency_max
  from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer)
  join public.product_versions pv on pv.id = item.product_version_id
  join public.products p on p.id = pv.product_id
  where p.status = 'published'
    and p.rights_status = 'verified'
    and p.rights_verified_at is not null
    and p.rights_verified_by is not null
    and p.artifact_sha256 is not null
    and pv.release_state = 'released'
    and pv.artifact_sha256 = p.artifact_sha256
    and pv.artifact_storage_path is not null
    and pv.released_at is not null
    and p.price_minor > 0
    and public.product_has_verified_rights(p.id, p.rights_verified_by, p.rights_verified_at);

  if matching_count <> input_count or currency_min is null or currency_min <> currency_max
    or calculated_total <= 0 or calculated_total > 9000000000000000 then
    raise exception using errcode = '23514', message = 'checkout requires available verified releases with a positive total and one currency';
  end if;

  select * into existing_order
  from public.orders o
  where o.customer_id = p_customer_id and o.idempotency_key = p_idempotency_key
  for update;

  if found then
    if exists (
      select item.product_version_id, item.quantity
      from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer)
      except
      select oi.product_version_id, oi.quantity
      from public.order_items oi where oi.order_id = existing_order.id
    ) or exists (
      select oi.product_version_id, oi.quantity
      from public.order_items oi where oi.order_id = existing_order.id
      except
      select item.product_version_id, item.quantity
      from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer)
    ) then
      raise exception using errcode = '23505', message = 'idempotency key was already used with a different checkout request';
    end if;
    return query select existing_order.id, existing_order.status, existing_order.total_minor, existing_order.currency;
    return;
  end if;

  insert into public.orders (customer_id, status, currency, subtotal_minor, tax_minor, idempotency_key)
  values (p_customer_id, 'pending_payment', currency_min, calculated_total, 0, p_idempotency_key)
  returning id into created_order_id;

  insert into public.order_items (
    order_id, product_id, product_version_id, seller_id, product_name, product_slug,
    release_version, license_type, artifact_sha256, unit_amount_minor, quantity, currency
  )
  select created_order_id, p.id, pv.id, p.creator_id, p.name, p.slug,
         pv.version, p.license_type, pv.artifact_sha256, p.price_minor, item.quantity, p.currency
  from jsonb_to_recordset(p_items) as item(product_version_id uuid, quantity integer)
  join public.product_versions pv on pv.id = item.product_version_id
  join public.products p on p.id = pv.product_id
  order by pv.id;

  return query select o.id, o.status, o.total_minor, o.currency
  from public.orders o where o.id = created_order_id;
end;
$function$;
revoke all on function public.create_order_for_checkout(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.create_order_for_checkout(uuid, jsonb, text) to service_role;

create function public.process_payment_webhook_event(target_event_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  event_row public.payment_webhook_events%rowtype;
  attempt_row public.payment_attempts%rowtype;
  refund_row public.refunds%rowtype;
  order_row public.orders%rowtype;
  refunded_minor bigint;
  next_refund_state text;
begin
  select * into event_row
  from public.payment_webhook_events
  where id = target_event_id
  for update;

  if not found then return false; end if;
  if event_row.processing_status = 'processed' then return true; end if;
  if event_row.processing_status = 'ignored' then return true; end if;
  if event_row.processing_status not in ('received', 'failed') then return false; end if;

  update public.payment_webhook_events
  set processing_status = 'processing', failure_code = null
  where id = target_event_id;

  begin
    if event_row.event_type = 'payment.succeeded' then
      select * into attempt_row from public.payment_attempts
      where id = event_row.payment_attempt_id for update;
      select * into order_row from public.orders where id = event_row.order_id for update;

      if attempt_row.id is null or order_row.id is null
        or attempt_row.provider <> event_row.provider
        or attempt_row.order_id <> event_row.order_id
        or attempt_row.amount_minor <> event_row.amount_minor
        or attempt_row.currency <> event_row.currency
        or order_row.total_minor <> event_row.amount_minor
        or order_row.currency <> event_row.currency
        or order_row.status not in ('pending_payment', 'payment_failed')
        or attempt_row.status not in ('created', 'pending') then
        raise exception using errcode = '23514', message = 'payment event does not match an eligible order and attempt';
      end if;

      update public.payment_attempts
      set status = 'succeeded',
          provider_reference = coalesce(provider_reference, event_row.provider_reference)
      where id = attempt_row.id;

      insert into public.ledger_transactions (
        order_id, payment_attempt_id, source_type, debit_account, credit_account,
        amount_minor, currency, reference_key
      ) values (
        order_row.id, attempt_row.id, 'payment', 'provider_clearing', 'platform_cash',
        event_row.amount_minor, event_row.currency, 'payment-event:' || event_row.id::text
      );

      update public.payment_webhook_events
      set processing_status = 'processed', processed_at = now(), failure_code = null
      where id = target_event_id;

      update public.orders set status = 'paid' where id = order_row.id;

      insert into public.entitlements (order_item_id, customer_id, product_id, product_version_id)
      select oi.id, order_row.customer_id, oi.product_id, oi.product_version_id
      from public.order_items oi
      where oi.order_id = order_row.id
      on conflict (order_item_id) do nothing;

    elsif event_row.event_type = 'payment.failed' then
      select * into attempt_row from public.payment_attempts
      where id = event_row.payment_attempt_id for update;
      select * into order_row from public.orders where id = event_row.order_id for update;

      if attempt_row.id is null or order_row.id is null
        or attempt_row.provider <> event_row.provider
        or attempt_row.order_id <> event_row.order_id
        or attempt_row.amount_minor <> event_row.amount_minor
        or attempt_row.currency <> event_row.currency
        or attempt_row.status not in ('created', 'pending')
        or order_row.status not in ('pending_payment', 'payment_failed') then
        raise exception using errcode = '23514', message = 'payment failure event does not match an eligible order and attempt';
      end if;

      update public.payment_attempts set status = 'failed'
      where id = attempt_row.id;

      update public.payment_webhook_events
      set processing_status = 'processed', processed_at = now(), failure_code = null
      where id = target_event_id;

      update public.orders set status = 'payment_failed' where id = order_row.id;

    elsif event_row.event_type = 'refund.succeeded' then
      select * into refund_row from public.refunds
      where id = event_row.refund_id for update;
      select * into attempt_row from public.payment_attempts
      where id = event_row.payment_attempt_id for update;
      select * into order_row from public.orders where id = event_row.order_id for update;

      if refund_row.id is null or attempt_row.id is null or order_row.id is null
        or refund_row.status not in ('requested', 'pending')
        or refund_row.order_id <> order_row.id
        or refund_row.payment_attempt_id <> attempt_row.id
        or attempt_row.provider <> event_row.provider
        or attempt_row.order_id <> order_row.id
        or refund_row.amount_minor <> event_row.amount_minor
        or refund_row.currency <> event_row.currency
        or order_row.status not in ('paid', 'partially_refunded') then
        raise exception using errcode = '23514', message = 'refund event does not match an eligible refund and paid order';
      end if;

      if refund_row.status = 'requested' then
        update public.refunds set status = 'pending' where id = refund_row.id;
      end if;

      insert into public.ledger_transactions (
        order_id, payment_attempt_id, refund_id, source_type, debit_account, credit_account,
        amount_minor, currency, reference_key
      ) values (
        order_row.id, attempt_row.id, refund_row.id, 'refund', 'platform_cash', 'customer_refund',
        event_row.amount_minor, event_row.currency, 'refund-event:' || event_row.id::text
      );

      update public.refunds set status = 'succeeded'
      where id = refund_row.id;

      select coalesce(sum(r.amount_minor), 0) into refunded_minor
      from public.refunds r
      where r.payment_attempt_id = attempt_row.id and r.status = 'succeeded';
      next_refund_state := case when refunded_minor = attempt_row.amount_minor then 'refunded' else 'partially_refunded' end;

      update public.payment_attempts set status = next_refund_state
      where id = attempt_row.id;

      update public.payment_webhook_events
      set processing_status = 'processed', processed_at = now(), failure_code = null
      where id = target_event_id;

      update public.orders set status = next_refund_state
      where id = order_row.id and status is distinct from next_refund_state;

    else
      update public.payment_webhook_events
      set processing_status = 'ignored', failure_code = 'unsupported_event_type'
      where id = target_event_id;
    end if;
  exception when others then
    update public.payment_webhook_events
    set processing_status = 'failed', processed_at = null, failure_code = 'processing_failed'
    where id = target_event_id and processing_status = 'processing';
    return false;
  end;

  return true;
end;
$function$;
revoke all on function public.process_payment_webhook_event(uuid) from public, anon, authenticated;
grant execute on function public.process_payment_webhook_event(uuid) to service_role;

comment on function public.create_order_for_checkout(uuid, jsonb, text) is
  'Server-only atomic order creation. Prices, currency, rights and release evidence are read from the canonical database; zero-value checkout and tax calculation are intentionally unsupported.';
comment on function public.process_payment_webhook_event(uuid) is
  'Server-only idempotent processor for cryptographically verified inbox events. Never call before provider-specific raw-body verification.';
