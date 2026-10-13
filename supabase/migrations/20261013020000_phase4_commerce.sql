-- Phase 4A: commerce ledger, payment-event idempotency, entitlements, and download authorization.
-- No provider is enabled by this migration. All financial writes are server-owned.
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'pending_payment'
    check (status in ('pending_payment', 'paid', 'payment_failed', 'cancelled', 'partially_refunded', 'refunded')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null default 0 check (tax_minor >= 0),
  total_minor bigint generated always as (subtotal_minor + tax_minor) stored,
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, idempotency_key)
);
create index orders_customer_created_idx on public.orders (customer_id, created_at desc);
create index orders_status_created_idx on public.orders (status, created_at);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  product_version_id uuid not null references public.product_versions(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  product_name text not null check (char_length(product_name) between 1 and 180),
  product_slug text not null check (product_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  release_version text not null check (release_version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'),
  license_type text not null check (license_type in ('standard', 'commercial', 'extended', 'open_source', 'custom')),
  artifact_sha256 text not null check (artifact_sha256 ~ '^[a-f0-9]{64}$'),
  unit_amount_minor bigint not null check (unit_amount_minor >= 0),
  quantity integer not null default 1 check (quantity between 1 and 100),
  line_total_minor bigint generated always as (unit_amount_minor * quantity) stored,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now()
);
create index order_items_order_idx on public.order_items (order_id);
create index order_items_customer_product_idx on public.order_items (product_id, product_version_id);

create table public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  provider text not null check (provider in ('paystack', 'flutterwave', 'stripe', 'sandbox')),
  status text not null default 'created'
    check (status in ('created', 'pending', 'succeeded', 'failed', 'cancelled', 'partially_refunded', 'refunded')),
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  provider_reference text check (provider_reference is null or char_length(provider_reference) between 1 and 240),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, idempotency_key)
);
create unique index payment_attempt_provider_reference_uq
  on public.payment_attempts (provider, provider_reference)
  where provider_reference is not null;
create index payment_attempts_order_idx on public.payment_attempts (order_id, created_at desc);

-- Only verified webhook bodies are represented here. Raw payloads and secrets are never persisted.
create table public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('paystack', 'flutterwave', 'stripe', 'sandbox')),
  provider_event_id text not null check (char_length(provider_event_id) between 1 and 240),
  event_type text not null check (char_length(event_type) between 1 and 160),
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  signature_verified boolean not null default true check (signature_verified),
  processing_status text not null default 'received'
    check (processing_status in ('received', 'processing', 'processed', 'ignored', 'failed')),
  order_id uuid references public.orders(id) on delete restrict,
  payment_attempt_id uuid references public.payment_attempts(id) on delete restrict,
  refund_id uuid,
  retry_count integer not null default 0 check (retry_count between 0 and 100),
  failure_code text check (failure_code is null or char_length(failure_code) <= 120),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, provider_event_id),
  constraint payment_webhook_processed_time check (
    (processing_status = 'processed' and processed_at is not null)
    or (processing_status <> 'processed' and processed_at is null)
  )
);
create index payment_webhook_pending_idx
  on public.payment_webhook_events (processing_status, received_at)
  where processing_status in ('received', 'failed');

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  payment_attempt_id uuid not null references public.payment_attempts(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  status text not null default 'requested' check (status in ('requested', 'pending', 'succeeded', 'failed')),
  reason text not null check (char_length(reason) between 1 and 1000),
  idempotency_key text not null unique check (char_length(idempotency_key) between 16 and 200),
  provider_refund_reference text check (provider_refund_reference is null or char_length(provider_refund_reference) between 1 and 240),
  requested_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index refunds_provider_reference_uq
  on public.refunds (provider_refund_reference)
  where provider_refund_reference is not null;
create index refunds_order_idx on public.refunds (order_id, created_at desc);

alter table public.payment_webhook_events
  add constraint payment_webhook_refund_fk foreign key (refund_id) references public.refunds(id) on delete restrict;

-- One row is one balanced double-entry transfer: the same amount is debited and credited.
-- This journal is append-only and is not readable by customer-facing roles.
create table public.ledger_transactions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  payment_attempt_id uuid references public.payment_attempts(id) on delete restrict,
  refund_id uuid references public.refunds(id) on delete restrict,
  source_type text not null check (source_type in ('payment', 'refund', 'chargeback', 'adjustment')),
  debit_account text not null check (debit_account in ('provider_clearing', 'platform_cash', 'seller_payable', 'platform_revenue', 'tax_payable', 'customer_refund', 'chargeback_expense')),
  credit_account text not null check (credit_account in ('provider_clearing', 'platform_cash', 'seller_payable', 'platform_revenue', 'tax_payable', 'customer_refund', 'chargeback_expense')),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  reference_key text not null unique check (char_length(reference_key) between 16 and 240),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  constraint ledger_accounts_must_differ check (debit_account <> credit_account),
  constraint ledger_source_reference check (
    (source_type = 'payment' and payment_attempt_id is not null and refund_id is null)
    or (source_type = 'refund' and payment_attempt_id is not null and refund_id is not null)
    or source_type in ('chargeback', 'adjustment')
  )
);
create index ledger_transactions_order_idx on public.ledger_transactions (order_id, created_at);

create function public.validate_ledger_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  payment_row public.payment_attempts%rowtype;
  refund_row public.refunds%rowtype;
  order_row public.orders%rowtype;
begin
  if new.source_type = 'payment' then
    select * into payment_row from public.payment_attempts where id = new.payment_attempt_id;
    select * into order_row from public.orders where id = new.order_id;
    if payment_row.id is null or order_row.id is null
      or payment_row.status <> 'succeeded'
      or payment_row.order_id <> new.order_id
      or payment_row.amount_minor <> new.amount_minor
      or payment_row.currency <> new.currency
      or order_row.total_minor <> new.amount_minor
      or order_row.currency <> new.currency
      or not exists (
        select 1 from public.payment_webhook_events we
        where we.payment_attempt_id = payment_row.id and we.order_id = order_row.id
          and we.provider = payment_row.provider and we.event_type = 'payment.succeeded'
          and we.signature_verified and we.processing_status in ('processing', 'processed')
      ) then
      raise exception using errcode = '23514', message = 'payment ledger entry requires a verified successful payment matching the order';
    end if;
  elsif new.source_type = 'refund' then
    select * into refund_row from public.refunds where id = new.refund_id;
    if refund_row.id is null or refund_row.status not in ('pending', 'succeeded')
      or refund_row.order_id <> new.order_id
      or refund_row.payment_attempt_id is distinct from new.payment_attempt_id
      or refund_row.amount_minor <> new.amount_minor
      or refund_row.currency <> new.currency
      or not exists (
        select 1 from public.payment_webhook_events we
        where we.refund_id = refund_row.id and we.order_id = refund_row.order_id
          and we.payment_attempt_id = refund_row.payment_attempt_id
          and we.event_type = 'refund.succeeded' and we.signature_verified
          and we.processing_status in ('processing', 'processed')
      ) then
      raise exception using errcode = '23514', message = 'refund ledger entry requires a verified successful refund matching the refund record';
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function public.validate_ledger_transaction() from public, anon, authenticated, service_role;
create trigger ledger_transactions_guard before insert on public.ledger_transactions
for each row execute function public.validate_ledger_transaction();


create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique references public.order_items(id) on delete restrict,
  customer_id uuid not null references auth.users(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  product_version_id uuid not null references public.product_versions(id) on delete restrict,
  status text not null default 'active' check (status in ('active', 'revoked', 'expired')),
  license_key_sha256 text unique check (license_key_sha256 is null or license_key_sha256 ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint entitlement_revocation_consistency check (
    (status = 'revoked' and revoked_at is not null)
    or (status <> 'revoked' and revoked_at is null)
  )
);
create index entitlements_customer_idx on public.entitlements (customer_id, created_at desc);
create index entitlements_product_version_idx on public.entitlements (product_id, product_version_id, status);

-- No storage path or signed URL is persisted or returned to clients. A grant is only an
-- authorization record; a trusted server checks it before signing a short-lived URL.
create table public.download_grants (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references public.entitlements(id) on delete restrict,
  customer_id uuid not null references auth.users(id) on delete restrict,
  product_version_id uuid not null references public.product_versions(id) on delete restrict,
  artifact_sha256 text not null check (artifact_sha256 ~ '^[a-f0-9]{64}$'),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  max_downloads integer not null default 1 check (max_downloads between 1 and 10),
  downloads_used integer not null default 0 check (downloads_used between 0 and 10),
  revoked_at timestamptz,
  constraint download_grant_expiry check (expires_at > issued_at),
  constraint download_grant_count check (downloads_used <= max_downloads)
);
create index download_grants_customer_idx on public.download_grants (customer_id, expires_at desc);

-- State transitions and amount/order matching are database invariants, not UI promises.
create function public.enforce_order_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending_payment' then
      raise exception using errcode = '23514', message = 'orders must begin pending_payment';
    end if;
    return new;
  end if;
  if new.customer_id is distinct from old.customer_id
    or new.currency is distinct from old.currency
    or new.subtotal_minor is distinct from old.subtotal_minor
    or new.tax_minor is distinct from old.tax_minor
    or new.idempotency_key is distinct from old.idempotency_key then
    raise exception using errcode = '23514', message = 'order financial identity is immutable';
  end if;
  if new.status = old.status then return new; end if;
  if not (
    (old.status = 'pending_payment' and new.status in ('paid', 'payment_failed', 'cancelled'))
    or (old.status = 'payment_failed' and new.status in ('pending_payment', 'cancelled'))
    or (old.status = 'paid' and new.status in ('partially_refunded', 'refunded'))
    or (old.status = 'partially_refunded' and new.status = 'refunded')
  ) then
    raise exception using errcode = '23514', message = 'invalid order status transition';
  end if;
  if new.status = 'paid' and not exists (
    select 1
    from public.payment_attempts pa
    join public.payment_webhook_events we
      on we.payment_attempt_id = pa.id
      and we.order_id = new.id
      and we.provider = pa.provider
      and we.event_type = 'payment.succeeded'
      and we.processing_status = 'processed'
      and we.signature_verified
    join public.ledger_transactions lt
      on lt.payment_attempt_id = pa.id
      and lt.order_id = new.id
      and lt.source_type = 'payment'
      and lt.amount_minor = new.total_minor
      and lt.currency = new.currency
    where pa.order_id = new.id
      and pa.status = 'succeeded'
      and pa.amount_minor = new.total_minor
      and pa.currency = new.currency
  ) then
    raise exception using errcode = '23514', message = 'order cannot be paid without a processed verified payment and ledger entry';
  end if;
  if new.status = 'payment_failed' and not exists (
    select 1 from public.payment_attempts pa
    join public.payment_webhook_events we
      on we.payment_attempt_id = pa.id and we.order_id = new.id
      and we.event_type = 'payment.failed' and we.processing_status = 'processed'
      and we.signature_verified
    where pa.order_id = new.id and pa.status = 'failed'
  ) then
    raise exception using errcode = '23514', message = 'order payment_failed requires a processed verified failure event';
  end if;
  if new.status in ('partially_refunded', 'refunded') then
    declare
      refunded_minor bigint;
      required_attempt_status text;
    begin
      select coalesce(sum(r.amount_minor), 0) into refunded_minor
      from public.refunds r
      where r.order_id = new.id and r.status = 'succeeded';
      required_attempt_status := case when new.status = 'partially_refunded' then 'partially_refunded' else 'refunded' end;
      if (new.status = 'partially_refunded' and (refunded_minor <= 0 or refunded_minor >= new.total_minor))
        or (new.status = 'refunded' and refunded_minor <> new.total_minor)
        or not exists (
          select 1 from public.payment_attempts pa
          where pa.order_id = new.id and pa.status = required_attempt_status
            and pa.amount_minor = new.total_minor and pa.currency = new.currency
        ) then
        raise exception using errcode = '23514', message = 'refund order state must match settled refund and payment totals';
      end if;
    end;
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_order_transition() from public, anon, authenticated, service_role;
create trigger orders_state_guard before insert or update on public.orders
for each row execute function public.enforce_order_transition();

create function public.enforce_payment_attempt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  order_row public.orders%rowtype;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'created' then
      raise exception using errcode = '23514', message = 'payment attempts must begin created';
    end if;
    select * into order_row from public.orders where id = new.order_id;
    if not found or order_row.total_minor <> new.amount_minor or order_row.currency <> new.currency
      or order_row.status not in ('pending_payment', 'payment_failed') then
      raise exception using errcode = '23514', message = 'payment attempt must match an eligible order amount and currency';
    end if;
    return new;
  end if;
  if new.order_id is distinct from old.order_id
    or new.provider is distinct from old.provider
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.idempotency_key is distinct from old.idempotency_key then
    raise exception using errcode = '23514', message = 'payment attempt identity is immutable';
  end if;
  if old.provider_reference is not null and new.provider_reference is distinct from old.provider_reference then
    raise exception using errcode = '23514', message = 'provider reference is immutable once assigned';
  end if;
  if new.status <> old.status and not (
    (old.status = 'created' and new.status in ('pending', 'failed', 'cancelled'))
    or (old.status = 'pending' and new.status in ('succeeded', 'failed', 'cancelled'))
    or (old.status = 'succeeded' and new.status in ('partially_refunded', 'refunded'))
    or (old.status = 'partially_refunded' and new.status = 'refunded')
  ) then
    raise exception using errcode = '23514', message = 'invalid payment attempt status transition';
  end if;
  if new.status = 'succeeded' and old.status <> 'succeeded' and not exists (
    select 1 from public.payment_webhook_events we
    where we.payment_attempt_id = new.id and we.order_id = new.order_id
      and we.provider = new.provider and we.event_type = 'payment.succeeded'
      and we.signature_verified and we.processing_status in ('processing', 'processed')
  ) then
    raise exception using errcode = '23514', message = 'successful payment requires a verified provider event';
  end if;
  if new.status in ('partially_refunded', 'refunded') and new.status <> old.status then
    declare
      refunded_minor bigint;
    begin
      select coalesce(sum(r.amount_minor), 0) into refunded_minor
      from public.refunds r where r.payment_attempt_id = new.id and r.status = 'succeeded';
      if (new.status = 'partially_refunded' and (refunded_minor <= 0 or refunded_minor >= new.amount_minor))
        or (new.status = 'refunded' and refunded_minor <> new.amount_minor) then
        raise exception using errcode = '23514', message = 'payment attempt refund state must match settled refund total';
      end if;
    end;
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_payment_attempt() from public, anon, authenticated, service_role;
create trigger payment_attempts_guard before insert or update on public.payment_attempts
for each row execute function public.enforce_payment_attempt();

create function public.enforce_webhook_event_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.processing_status <> 'received' or not new.signature_verified then
      raise exception using errcode = '23514', message = 'only verified webhook events may enter the inbox';
    end if;
    return new;
  end if;
  if new.provider is distinct from old.provider
    or new.provider_event_id is distinct from old.provider_event_id
    or new.payload_sha256 is distinct from old.payload_sha256
    or new.event_type is distinct from old.event_type
    or new.order_id is distinct from old.order_id
    or new.payment_attempt_id is distinct from old.payment_attempt_id
    or new.refund_id is distinct from old.refund_id then
    raise exception using errcode = '23514', message = 'webhook event identity is immutable';
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
  if new.processing_status = 'processed' and new.event_type = 'payment.succeeded' and not exists (
    select 1 from public.payment_attempts pa
    join public.ledger_transactions lt on lt.payment_attempt_id = pa.id
      and lt.order_id = new.order_id and lt.source_type = 'payment'
    where pa.id = new.payment_attempt_id and pa.status = 'succeeded'
      and pa.order_id = new.order_id and pa.amount_minor = lt.amount_minor
      and pa.currency = lt.currency
  ) then
    raise exception using errcode = '23514', message = 'successful payment event requires matching attempt and ledger';
  end if;
  if new.processing_status = 'processed' and new.event_type = 'payment.failed' and not exists (
    select 1 from public.payment_attempts pa
    where pa.id = new.payment_attempt_id and pa.order_id = new.order_id and pa.status = 'failed'
  ) then
    raise exception using errcode = '23514', message = 'failed payment event requires a failed payment attempt';
  end if;
  if new.processing_status = 'processed' and new.event_type = 'refund.succeeded' and not exists (
    select 1 from public.refunds r
    join public.ledger_transactions lt on lt.refund_id = r.id
      and lt.order_id = new.order_id and lt.source_type = 'refund'
    where r.id = new.refund_id and r.order_id = new.order_id
      and r.payment_attempt_id = new.payment_attempt_id and r.status = 'succeeded'
      and r.amount_minor = lt.amount_minor and r.currency = lt.currency
  ) then
    raise exception using errcode = '23514', message = 'successful refund event requires matching refund and ledger';
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
create trigger payment_webhook_events_guard before insert or update on public.payment_webhook_events
for each row execute function public.enforce_webhook_event_transition();

create function public.enforce_refund_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'requested' then
      raise exception using errcode = '23514', message = 'refunds must begin requested';
    end if;
    declare
      order_row public.orders%rowtype;
      payment_row public.payment_attempts%rowtype;
      reserved_minor bigint;
    begin
      select * into order_row from public.orders where id = new.order_id for update;
      select * into payment_row from public.payment_attempts where id = new.payment_attempt_id;
      if order_row.id is null or payment_row.id is null
        or order_row.status not in ('paid', 'partially_refunded')
        or payment_row.order_id <> order_row.id
        or payment_row.status not in ('succeeded', 'partially_refunded')
        or payment_row.currency <> new.currency
        or order_row.currency <> new.currency then
        raise exception using errcode = '23514', message = 'refund must match a paid order and successful payment';
      end if;
      select coalesce(sum(r.amount_minor), 0) into reserved_minor
      from public.refunds r
      where r.order_id = new.order_id and r.status in ('requested', 'pending', 'succeeded');
      if reserved_minor + new.amount_minor > order_row.total_minor then
        raise exception using errcode = '23514', message = 'refund amount exceeds remaining refundable order balance';
      end if;
    end;
    return new;
  end if;
  if new.order_id is distinct from old.order_id
    or new.payment_attempt_id is distinct from old.payment_attempt_id
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.idempotency_key is distinct from old.idempotency_key then
    raise exception using errcode = '23514', message = 'refund financial identity is immutable';
  end if;
  if new.status <> old.status and not (
    (old.status = 'requested' and new.status in ('pending', 'failed'))
    or (old.status = 'pending' and new.status in ('succeeded', 'failed'))
  ) then
    raise exception using errcode = '23514', message = 'invalid refund status transition';
  end if;
  if new.status = 'succeeded' and old.status <> 'succeeded' and not exists (
    select 1 from public.payment_webhook_events we
    join public.ledger_transactions lt on lt.refund_id = new.id
      and lt.order_id = new.order_id and lt.source_type = 'refund'
    where we.refund_id = new.id and we.order_id = new.order_id
      and we.payment_attempt_id = new.payment_attempt_id and we.provider_event_id is not null
      and we.event_type = 'refund.succeeded' and we.signature_verified
      and we.processing_status in ('processing', 'processed')
      and lt.amount_minor = new.amount_minor and lt.currency = new.currency
  ) then
    raise exception using errcode = '23514', message = 'successful refund requires a verified event and ledger entry';
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_refund_transition() from public, anon, authenticated, service_role;
create trigger refunds_state_guard before insert or update on public.refunds
for each row execute function public.enforce_refund_transition();

create function public.validate_order_item_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  product_row public.products%rowtype;
  version_row public.product_versions%rowtype;
  order_row public.orders%rowtype;
begin
  select * into product_row from public.products where id = new.product_id;
  select * into version_row from public.product_versions where id = new.product_version_id and product_id = new.product_id;
  select * into order_row from public.orders where id = new.order_id;
  if product_row.id is null or version_row.id is null or order_row.id is null
    or product_row.status <> 'published'
    or product_row.rights_status <> 'verified'
    or product_row.rights_verified_at is null
    or product_row.rights_verified_by is null
    or not public.product_has_verified_rights(product_row.id, product_row.rights_verified_by, product_row.rights_verified_at)
    or product_row.artifact_sha256 is null
    or product_row.artifact_sha256 <> new.artifact_sha256
    or version_row.release_state <> 'released'
    or version_row.artifact_sha256 <> new.artifact_sha256
    or version_row.artifact_storage_path is null
    or version_row.released_at is null
    or product_row.creator_id <> new.seller_id
    or product_row.name <> new.product_name
    or product_row.slug <> new.product_slug
    or product_row.release_version <> new.release_version
    or version_row.version <> new.release_version
    or product_row.license_type <> new.license_type
    or product_row.price_minor <> new.unit_amount_minor
    or product_row.currency <> new.currency
    or order_row.currency <> new.currency then
    raise exception using errcode = '23514', message = 'order item must snapshot a currently verified release and matching price';
  end if;
  return new;
end;
$function$;
revoke all on function public.validate_order_item_snapshot() from public, anon, authenticated, service_role;
create trigger order_items_snapshot_guard before insert on public.order_items
for each row execute function public.validate_order_item_snapshot();

create function public.assert_order_totals_match_items()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_order_id uuid;
  expected_subtotal bigint;
  actual_subtotal bigint;
  item_count bigint;
begin
  if tg_table_name = 'orders' then
    target_order_id := new.id;
  elsif tg_op = 'DELETE' then
    target_order_id := old.order_id;
  else
    target_order_id := new.order_id;
  end if;
  select subtotal_minor into expected_subtotal from public.orders where id = target_order_id;
  if not found then return null; end if;
  select count(*), coalesce(sum(line_total_minor), 0)
    into item_count, actual_subtotal
    from public.order_items where order_id = target_order_id;
  if item_count = 0 or expected_subtotal <> actual_subtotal then
    raise exception using errcode = '23514', message = 'order subtotal must equal the immutable item snapshot total';
  end if;
  return null;
end;
$function$;
revoke all on function public.assert_order_totals_match_items() from public, anon, authenticated, service_role;
create constraint trigger orders_totals_guard
after insert or update on public.orders
deferrable initially deferred
for each row execute function public.assert_order_totals_match_items();
create constraint trigger order_items_totals_guard
after insert or update or delete on public.order_items
deferrable initially deferred
for each row execute function public.assert_order_totals_match_items();

create function public.enforce_entitlement_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.status <> 'active' or new.revoked_at is not null
    or not exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = new.order_item_id
        and oi.product_id = new.product_id
        and oi.product_version_id = new.product_version_id
        and o.customer_id = new.customer_id
        and o.status = 'paid'
    ) then
    raise exception using errcode = '23514', message = 'entitlement requires a paid order matching the purchased release';
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_entitlement_insert() from public, anon, authenticated, service_role;
create trigger entitlements_insert_guard before insert on public.entitlements
for each row execute function public.enforce_entitlement_insert();

create function public.enforce_download_grant_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.downloads_used <> 0 or new.revoked_at is not null
    or not exists (
      select 1
      from public.entitlements e
      join public.product_versions pv on pv.id = e.product_version_id
      where e.id = new.entitlement_id
        and e.customer_id = new.customer_id
        and e.product_version_id = new.product_version_id
        and e.status = 'active'
        and (e.expires_at is null or e.expires_at > now())
        and pv.release_state = 'released'
        and pv.artifact_sha256 = new.artifact_sha256
        and pv.artifact_storage_path is not null
        and pv.released_at is not null
    ) then
    raise exception using errcode = '23514', message = 'download grant requires an active entitlement for the released artifact';
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_download_grant_insert() from public, anon, authenticated, service_role;
create trigger download_grants_insert_guard before insert on public.download_grants
for each row execute function public.enforce_download_grant_insert();

create function public.enforce_download_grant_update()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.entitlement_id is distinct from old.entitlement_id
    or new.customer_id is distinct from old.customer_id
    or new.product_version_id is distinct from old.product_version_id
    or new.artifact_sha256 is distinct from old.artifact_sha256
    or new.issued_at is distinct from old.issued_at
    or new.expires_at is distinct from old.expires_at
    or new.max_downloads is distinct from old.max_downloads
    or new.downloads_used < old.downloads_used
    or new.downloads_used > old.downloads_used + 1
    or (old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at) then
    raise exception using errcode = '23514', message = 'download grant identity is immutable and usage is monotonic';
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_download_grant_update() from public, anon, authenticated, service_role;
create trigger download_grants_update_guard before update on public.download_grants
for each row execute function public.enforce_download_grant_update();

create function public.consume_download_grant(target_grant_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  consumed boolean;
begin
  if (select auth.uid()) is null then return false; end if;
  update public.download_grants dg
  set downloads_used = downloads_used + 1
  where dg.id = target_grant_id
    and dg.customer_id = (select auth.uid())
    and dg.revoked_at is null
    and dg.expires_at > now()
    and dg.downloads_used < dg.max_downloads
    and exists (
      select 1
      from public.entitlements e
      join public.order_items oi on oi.id = e.order_item_id
      join public.orders o on o.id = oi.order_id
      join public.product_versions pv on pv.id = dg.product_version_id
      where e.id = dg.entitlement_id
        and e.customer_id = dg.customer_id
        and e.product_version_id = dg.product_version_id
        and e.status = 'active'
        and (e.expires_at is null or e.expires_at > now())
        and o.customer_id = dg.customer_id
        and o.status = 'paid'
        and pv.release_state = 'released'
        and pv.artifact_sha256 = dg.artifact_sha256
        and pv.artifact_storage_path is not null
        and pv.released_at is not null
    )
  returning true into consumed;
  return coalesce(consumed, false);
end;
$function$;
revoke all on function public.consume_download_grant(uuid) from public, anon, service_role;
grant execute on function public.consume_download_grant(uuid) to authenticated;

create function public.current_user_owns_order(target_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1 from public.orders o
    where o.id = target_order_id and o.customer_id = (select auth.uid())
  );
$function$;
revoke all on function public.current_user_owns_order(uuid) from public, anon, service_role;
grant execute on function public.current_user_owns_order(uuid) to authenticated;

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.payment_webhook_events enable row level security;
alter table public.refunds enable row level security;
alter table public.ledger_transactions enable row level security;
alter table public.entitlements enable row level security;
alter table public.download_grants enable row level security;

revoke all on public.orders, public.order_items, public.payment_attempts, public.payment_webhook_events,
  public.refunds, public.ledger_transactions, public.entitlements, public.download_grants
  from anon, authenticated, service_role;

grant select (id, status, currency, subtotal_minor, tax_minor, total_minor, created_at, updated_at)
  on public.orders to authenticated;
grant select (id, order_id, product_id, product_name, product_slug, release_version, license_type,
  unit_amount_minor, quantity, line_total_minor, currency, created_at)
  on public.order_items to authenticated;
grant select (id, order_id, provider, status, amount_minor, currency, created_at, updated_at)
  on public.payment_attempts to authenticated;
grant select (id, order_id, amount_minor, currency, status, reason, created_at, updated_at)
  on public.refunds to authenticated;
grant select (id, order_item_id, product_id, product_version_id, status, expires_at, revoked_at, created_at)
  on public.entitlements to authenticated;

grant select, insert, update on public.orders to service_role;
grant select, insert on public.order_items to service_role;
grant select, insert, update on public.payment_attempts to service_role;
grant select, insert, update on public.payment_webhook_events to service_role;
grant select, insert, update on public.refunds to service_role;
grant select, insert on public.ledger_transactions to service_role;
grant select, insert, update on public.entitlements to service_role;
grant select, insert, update on public.download_grants to service_role;

create policy orders_select_own on public.orders
  for select to authenticated using (customer_id = (select auth.uid()));
create policy order_items_select_own on public.order_items
  for select to authenticated using (public.current_user_owns_order(order_id));
create policy payment_attempts_select_own on public.payment_attempts
  for select to authenticated using (public.current_user_owns_order(order_id));
create policy refunds_select_own on public.refunds
  for select to authenticated using (public.current_user_owns_order(order_id));
create policy entitlements_select_own on public.entitlements
  for select to authenticated using (customer_id = (select auth.uid()));
