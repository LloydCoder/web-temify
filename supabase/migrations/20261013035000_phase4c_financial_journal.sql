-- Phase 4C: immutable accounting journal and evidence-backed seller proceeds allocation.
-- This is an internal accounting primitive, not a payment provider or payout integration.
-- Public Data API roles receive no privileges on these tables.

create table public.financial_journal_batches (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in (
    'payment', 'refund', 'proceeds_allocation', 'provider_settlement',
    'provider_fee', 'chargeback', 'manual_adjustment', 'reserve_hold', 'reserve_release'
  )),
  source_key text not null unique check (char_length(source_key) between 16 and 320),
  idempotency_key text not null unique check (char_length(idempotency_key) between 16 and 320),
  order_id uuid references public.orders(id) on delete restrict,
  payment_attempt_id uuid references public.payment_attempts(id) on delete restrict,
  refund_id uuid references public.refunds(id) on delete restrict,
  provider text check (provider is null or provider in ('paystack', 'flutterwave', 'stripe', 'sandbox')),
  provider_reference text check (provider_reference is null or char_length(provider_reference) between 1 and 240),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  status text not null default 'draft' check (status in ('draft', 'posted')),
  created_at timestamptz not null default now(),
  posted_at timestamptz,
  constraint financial_batch_source_identity check (
    (source_type = 'payment' and order_id is not null and payment_attempt_id is not null and refund_id is null)
    or (source_type = 'refund' and order_id is not null and payment_attempt_id is not null and refund_id is not null)
    or (source_type = 'proceeds_allocation' and order_id is not null and payment_attempt_id is null and refund_id is null)
    or (source_type in ('provider_settlement', 'provider_fee') and provider is not null and provider_reference is not null)
    or (source_type in ('chargeback', 'manual_adjustment', 'reserve_hold', 'reserve_release'))
  ),
  constraint financial_batch_posted_timestamp check (
    (status = 'draft' and posted_at is null)
    or (status = 'posted' and posted_at is not null)
  )
);
create index financial_journal_order_idx
  on public.financial_journal_batches (order_id, created_at desc)
  where order_id is not null;
create index financial_journal_source_idx
  on public.financial_journal_batches (source_type, created_at desc);

create table public.financial_journal_entries (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.financial_journal_batches(id) on delete restrict,
  account text not null check (account in (
    'provider_clearing', 'platform_cash', 'unallocated_order_liability',
    'seller_payable', 'platform_revenue', 'tax_payable', 'customer_refund',
    'chargeback_receivable', 'chargeback_expense', 'provider_fee_expense',
    'settlement_in_transit', 'reserve_liability'
  )),
  side text not null check (side in ('debit', 'credit')),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  seller_id uuid references auth.users(id) on delete restrict,
  order_item_id uuid references public.order_items(id) on delete restrict,
  memo text not null check (char_length(memo) between 1 and 240),
  created_at timestamptz not null default now(),
  constraint seller_payable_requires_seller check (account <> 'seller_payable' or seller_id is not null)
);
create index financial_journal_entries_batch_idx
  on public.financial_journal_entries (batch_id, side);
create index financial_journal_entries_seller_idx
  on public.financial_journal_entries (seller_id, created_at desc)
  where seller_id is not null;

alter table public.financial_journal_batches enable row level security;
alter table public.financial_journal_entries enable row level security;
revoke all on public.financial_journal_batches from public, anon, authenticated;
revoke all on public.financial_journal_entries from public, anon, authenticated;
grant select, insert, update on public.financial_journal_batches to service_role;
grant select, insert on public.financial_journal_entries to service_role;

create function public.guard_financial_journal_batch()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  entry_count bigint;
  debit_total numeric;
  credit_total numeric;
  mismatched_currency boolean;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' or new.posted_at is not null then
      raise exception using errcode = '23514', message = 'financial batches must begin as drafts';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception using errcode = '23514', message = 'financial journal batches are immutable';
  end if;

  if old.status <> 'draft'
    or new.status <> 'posted'
    or new.id is distinct from old.id
    or new.source_type is distinct from old.source_type
    or new.source_key is distinct from old.source_key
    or new.idempotency_key is distinct from old.idempotency_key
    or new.order_id is distinct from old.order_id
    or new.payment_attempt_id is distinct from old.payment_attempt_id
    or new.refund_id is distinct from old.refund_id
    or new.provider is distinct from old.provider
    or new.provider_reference is distinct from old.provider_reference
    or new.currency is distinct from old.currency
    or new.evidence_sha256 is distinct from old.evidence_sha256
    or new.created_at is distinct from old.created_at
    or new.posted_at is distinct from old.posted_at then
    raise exception using errcode = '23514', message = 'only a draft-to-posted transition is permitted for a financial batch';
  end if;

  select count(*),
         coalesce(sum(e.amount_minor) filter (where e.side = 'debit'), 0),
         coalesce(sum(e.amount_minor) filter (where e.side = 'credit'), 0),
         coalesce(bool_or(e.currency <> new.currency), false)
    into entry_count, debit_total, credit_total, mismatched_currency
  from public.financial_journal_entries e
  where e.batch_id = new.id;

  if entry_count < 2 or debit_total <= 0 or debit_total <> credit_total or mismatched_currency then
    raise exception using errcode = '23514', message = 'financial batch must contain balanced entries in one currency before posting';
  end if;

  new.posted_at := coalesce(new.posted_at, now());
  return new;
end;
$function$;
revoke all on function public.guard_financial_journal_batch() from public, anon, authenticated, service_role;

create trigger financial_journal_batch_guard
before insert or update or delete on public.financial_journal_batches
for each row execute function public.guard_financial_journal_batch();

create function public.guard_financial_journal_entry()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  batch_status text;
  batch_currency text;
begin
  if tg_op <> 'INSERT' then
    raise exception using errcode = '23514', message = 'financial journal entries are append-only';
  end if;

  select b.status, b.currency
    into batch_status, batch_currency
  from public.financial_journal_batches b
  where b.id = new.batch_id
  for update;

  if batch_status is distinct from 'draft' then
    raise exception using errcode = '23514', message = 'entries may only be added to a draft financial batch';
  end if;
  if new.currency is distinct from batch_currency then
    raise exception using errcode = '23514', message = 'financial entry currency must match its batch';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_financial_journal_entry() from public, anon, authenticated, service_role;

create trigger financial_journal_entry_guard
before insert or update or delete on public.financial_journal_entries
for each row execute function public.guard_financial_journal_entry();

-- A seller's commercial fee terms must be independently approved before allocation.
create table public.seller_fee_schedules (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete restrict,
  platform_fee_bps integer not null check (platform_fee_bps between 0 and 10000),
  status text not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  approved_by uuid references auth.users(id) on delete restrict,
  approved_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint seller_fee_schedule_expiry check (expires_at is null or expires_at > effective_at),
  constraint seller_fee_schedule_approval check (
    (status = 'pending' and approved_by is null and approved_at is null and revoked_by is null and revoked_at is null)
    or (status = 'active' and approved_by is not null and approved_by <> seller_id and approved_at is not null and revoked_by is null and revoked_at is null)
    or (status = 'revoked' and revoked_by is not null and revoked_by <> seller_id and revoked_at is not null
      and ((approved_by is null and approved_at is null) or (approved_by is not null and approved_by <> seller_id and approved_at is not null and revoked_by <> approved_by)))
  )
);
create unique index seller_fee_schedule_one_active_uq
  on public.seller_fee_schedules (seller_id)
  where status = 'active';
create index seller_fee_schedule_effective_idx
  on public.seller_fee_schedules (seller_id, effective_at desc, expires_at);

alter table public.seller_fee_schedules enable row level security;
revoke all on public.seller_fee_schedules from public, anon, authenticated;
grant select, insert, update on public.seller_fee_schedules to service_role;

create function public.guard_seller_fee_schedule()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending'
      or new.approved_by is not null or new.approved_at is not null
      or new.revoked_by is not null or new.revoked_at is not null then
      raise exception using errcode = '23514', message = 'seller fee schedules must start pending independent approval';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception using errcode = '23514', message = 'seller fee schedule history cannot be deleted';
  end if;

  if new.id is distinct from old.id
    or new.seller_id is distinct from old.seller_id
    or new.platform_fee_bps is distinct from old.platform_fee_bps
    or new.effective_at is distinct from old.effective_at
    or new.expires_at is distinct from old.expires_at
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '23514', message = 'fee schedule commercial terms are immutable';
  end if;

  if old.status = 'pending' and new.status = 'active' then
    if new.approved_by is null or new.approved_by = new.seller_id or new.approved_at is null
      or new.revoked_by is not null or new.revoked_at is not null then
      raise exception using errcode = '23514', message = 'activation requires an independent approver';
    end if;
    if not exists (
      select 1 from public.user_roles ur
      where ur.user_id = new.approved_by and ur.role = 'admin'::public.app_role
    ) then
      raise exception using errcode = '23514', message = 'fee schedule approver must hold the database-owned admin role';
    end if;
  elsif old.status = 'pending' and new.status = 'revoked' then
    if new.revoked_by is null or new.revoked_by = new.seller_id or new.revoked_at is null
      or new.approved_by is not null or new.approved_at is not null then
      raise exception using errcode = '23514', message = 'pending schedule revocation requires an independent actor';
    end if;
    if not exists (
      select 1 from public.user_roles ur
      where ur.user_id = new.revoked_by and ur.role = 'admin'::public.app_role
    ) then
      raise exception using errcode = '23514', message = 'fee schedule revoker must hold the database-owned admin role';
    end if;
  elsif old.status = 'active' and new.status = 'revoked' then
    if new.approved_by is distinct from old.approved_by
      or new.approved_at is distinct from old.approved_at
      or new.revoked_by is null or new.revoked_by = new.seller_id
      or new.revoked_by = new.approved_by or new.revoked_at is null then
      raise exception using errcode = '23514', message = 'active schedule revocation requires a separate actor and preserves original approval evidence';
    end if;
    if not exists (
      select 1 from public.user_roles ur
      where ur.user_id = new.revoked_by and ur.role = 'admin'::public.app_role
    ) then
      raise exception using errcode = '23514', message = 'fee schedule revoker must hold the database-owned admin role';
    end if;
  else
    raise exception using errcode = '23514', message = 'invalid seller fee schedule transition';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_seller_fee_schedule() from public, anon, authenticated, service_role;

create trigger seller_fee_schedule_guard
before insert or update or delete on public.seller_fee_schedules
for each row execute function public.guard_seller_fee_schedule();

create table public.order_proceeds_allocations (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique references public.order_items(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  fee_schedule_id uuid not null references public.seller_fee_schedules(id) on delete restrict,
  journal_batch_id uuid not null references public.financial_journal_batches(id) on delete restrict,
  gross_minor bigint not null check (gross_minor > 0),
  platform_fee_minor bigint not null check (platform_fee_minor >= 0),
  seller_net_minor bigint not null check (seller_net_minor >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  constraint proceeds_allocation_balances check (gross_minor = platform_fee_minor + seller_net_minor)
);
create index order_proceeds_order_idx
  on public.order_proceeds_allocations (order_id, seller_id);
create index order_proceeds_seller_idx
  on public.order_proceeds_allocations (seller_id, created_at desc);

alter table public.order_proceeds_allocations enable row level security;
revoke all on public.order_proceeds_allocations from public, anon, authenticated;
grant select, insert on public.order_proceeds_allocations to service_role;

create function public.guard_order_proceeds_allocation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op <> 'INSERT' then
    raise exception using errcode = '23514', message = 'order proceeds allocations are immutable';
  end if;
  if not exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    join public.seller_fee_schedules s on s.id = new.fee_schedule_id
    join public.financial_journal_batches b on b.id = new.journal_batch_id
    where oi.id = new.order_item_id
      and oi.order_id = new.order_id
      and oi.seller_id = new.seller_id
      and oi.line_total_minor = new.gross_minor
      and oi.currency = new.currency
      and o.status = 'paid'
      and s.seller_id = new.seller_id
      and s.status = 'active'
      and s.approved_by is not null
      and s.approved_by <> s.seller_id
      and b.source_type = 'proceeds_allocation'
      and b.order_id = new.order_id
      and b.status = 'draft'
      and b.currency = new.currency
      and new.platform_fee_minor = floor((new.gross_minor::numeric * s.platform_fee_bps::numeric) / 10000)::bigint
  ) then
    raise exception using errcode = '23514', message = 'proceeds allocation must match a paid order item and independently approved seller fee schedule';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_order_proceeds_allocation() from public, anon, authenticated, service_role;

create trigger order_proceeds_allocation_guard
before insert or update or delete on public.order_proceeds_allocations
for each row execute function public.guard_order_proceeds_allocation();

create function public.record_legacy_ledger_journal()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  provider_name text;
  provider_ref text;
  evidence_digest text;
  journal_id uuid;
  journal_source text;
begin
  select pa.provider, pa.provider_reference
    into provider_name, provider_ref
  from public.payment_attempts pa
  where pa.id = new.payment_attempt_id
    and pa.order_id = new.order_id;

  if provider_name is null then
    raise exception using errcode = '23514', message = 'accounting journal requires a matching payment attempt';
  end if;

  if new.source_type = 'payment' then
    select we.payload_sha256, we.provider_reference into evidence_digest, provider_ref
    from public.payment_webhook_events we
    where we.order_id = new.order_id
      and we.payment_attempt_id = new.payment_attempt_id
      and we.provider = provider_name
      and we.event_type = 'payment.succeeded'
      and we.signature_verified
      and we.processing_status in ('processing', 'processed')
    order by we.received_at desc
    limit 1;
    journal_source := 'legacy-ledger:payment:' || new.reference_key;
  elsif new.source_type = 'refund' then
    if exists (
      select 1 from public.order_proceeds_allocations opa where opa.order_id = new.order_id
    ) then
      raise exception using errcode = '23514', message = 'refund posting is blocked until an evidence-backed proceeds-allocation reversal exists';
    end if;
    select we.payload_sha256, we.provider_reference into evidence_digest, provider_ref
    from public.payment_webhook_events we
    where we.order_id = new.order_id
      and we.payment_attempt_id = new.payment_attempt_id
      and we.refund_id = new.refund_id
      and we.provider = provider_name
      and we.event_type = 'refund.succeeded'
      and we.signature_verified
      and we.processing_status in ('processing', 'processed')
    order by we.received_at desc
    limit 1;
    journal_source := 'legacy-ledger:refund:' || new.reference_key;
  else
    raise exception using errcode = '23514', message = 'unsupported legacy ledger source';
  end if;

  if evidence_digest is null then
    raise exception using errcode = '23514', message = 'accounting journal requires verified webhook evidence';
  end if;

  insert into public.financial_journal_batches (
    source_type, source_key, idempotency_key, order_id, payment_attempt_id, refund_id,
    provider, provider_reference, currency, evidence_sha256
  ) values (
    new.source_type, journal_source, journal_source, new.order_id, new.payment_attempt_id,
    new.refund_id, provider_name, provider_ref, new.currency, evidence_digest
  ) returning id into journal_id;

  if new.source_type = 'payment' then
    insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
    values
      (journal_id, 'provider_clearing', 'debit', new.amount_minor, new.currency, 'Verified gross payment received'),
      (journal_id, 'unallocated_order_liability', 'credit', new.amount_minor, new.currency, 'Gross order proceeds awaiting approved allocation');
  else
    insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
    values
      (journal_id, 'unallocated_order_liability', 'debit', new.amount_minor, new.currency, 'Verified refund against unallocated order proceeds'),
      (journal_id, 'provider_clearing', 'credit', new.amount_minor, new.currency, 'Verified refund outflow');
  end if;

  update public.financial_journal_batches set status = 'posted' where id = journal_id;
  return new;
end;
$function$;
revoke all on function public.record_legacy_ledger_journal() from public, anon, authenticated, service_role;

create trigger ledger_transaction_accounting_journal
after insert on public.ledger_transactions
for each row execute function public.record_legacy_ledger_journal();

create function public.allocate_order_proceeds(
  p_order_id uuid,
  p_idempotency_key text,
  p_evidence_sha256 text
)
returns uuid
language plpgsql
set search_path = ''
as $function$
declare
  order_row public.orders%rowtype;
  batch_id uuid;
  existing_batch public.financial_journal_batches%rowtype;
  item_count bigint;
  covered_item_count bigint;
  payment_journal_count bigint;
  allocated_gross bigint;
  allocated_fee bigint;
begin
  if p_order_id is null
    or p_idempotency_key is null
    or char_length(p_idempotency_key) not between 16 and 200
    or p_evidence_sha256 is null
    or p_evidence_sha256 !~ '^[a-f0-9]{64}$' then
    raise exception using errcode = '22023', message = 'invalid proceeds allocation request';
  end if;

  select * into order_row from public.orders where id = p_order_id for update;
  if order_row.id is null or order_row.status <> 'paid' then
    raise exception using errcode = '23514', message = 'only fully paid orders may be allocated';
  end if;

  select * into existing_batch
  from public.financial_journal_batches b
  where b.source_type = 'proceeds_allocation'
    and b.source_key = 'order-allocation:' || p_order_id::text;

  if existing_batch.id is not null then
    if existing_batch.idempotency_key = p_idempotency_key
      and existing_batch.evidence_sha256 = p_evidence_sha256
      and existing_batch.status = 'posted' then
      return existing_batch.id;
    end if;
    raise exception using errcode = '23514', message = 'order proceeds have already been allocated with different evidence or idempotency';
  end if;

  if exists (
    select 1 from public.refunds r
    where r.order_id = p_order_id and r.status in ('requested', 'pending', 'succeeded')
  ) then
    raise exception using errcode = '23514', message = 'orders with requested or completed refunds cannot be allocated';
  end if;

  select count(*) into payment_journal_count
  from public.financial_journal_batches b
  where b.source_type = 'payment' and b.order_id = p_order_id and b.status = 'posted';
  if payment_journal_count <> 1 then
    raise exception using errcode = '23514', message = 'order proceeds require exactly one posted verified payment journal';
  end if;

  select count(*) into item_count
  from public.order_items oi where oi.order_id = p_order_id;
  if item_count = 0 then
    raise exception using errcode = '23514', message = 'cannot allocate an order without items';
  end if;

  select count(*) into covered_item_count
  from public.order_items oi
  join lateral (
    select s.id
    from public.seller_fee_schedules s
    where s.seller_id = oi.seller_id
      and s.status = 'active'
      and s.approved_by is not null
      and s.approved_by <> s.seller_id
      and s.effective_at <= now()
      and (s.expires_at is null or s.expires_at > now())
    order by s.effective_at desc, s.created_at desc
    limit 1
  ) approved_schedule on true
  where oi.order_id = p_order_id;

  if covered_item_count <> item_count then
    raise exception using errcode = '23514', message = 'every seller requires a current independently approved fee schedule';
  end if;

  insert into public.financial_journal_batches (
    source_type, source_key, idempotency_key, order_id, currency, evidence_sha256
  ) values (
    'proceeds_allocation', 'order-allocation:' || p_order_id::text,
    p_idempotency_key, p_order_id, order_row.currency, p_evidence_sha256
  ) returning id into batch_id;

  insert into public.order_proceeds_allocations (
    order_item_id, order_id, seller_id, fee_schedule_id, journal_batch_id,
    gross_minor, platform_fee_minor, seller_net_minor, currency
  )
  select
    oi.id,
    oi.order_id,
    oi.seller_id,
    schedule.id,
    batch_id,
    oi.line_total_minor,
    floor((oi.line_total_minor::numeric * schedule.platform_fee_bps::numeric) / 10000)::bigint,
    oi.line_total_minor - floor((oi.line_total_minor::numeric * schedule.platform_fee_bps::numeric) / 10000)::bigint,
    oi.currency
  from public.order_items oi
  join lateral (
    select s.id, s.platform_fee_bps
    from public.seller_fee_schedules s
    where s.seller_id = oi.seller_id
      and s.status = 'active'
      and s.approved_by is not null
      and s.approved_by <> s.seller_id
      and s.effective_at <= now()
      and (s.expires_at is null or s.expires_at > now())
    order by s.effective_at desc, s.created_at desc
    limit 1
  ) schedule on true
  where oi.order_id = p_order_id;

  insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
  values (batch_id, 'unallocated_order_liability', 'debit', order_row.total_minor, order_row.currency, 'Allocate gross order liability');

  insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, seller_id, memo)
  select batch_id, 'seller_payable', 'credit', sum(opa.seller_net_minor), order_row.currency, opa.seller_id,
         'Seller net payable under approved fee schedule'
  from public.order_proceeds_allocations opa
  where opa.journal_batch_id = batch_id
  group by opa.seller_id
  having sum(opa.seller_net_minor) > 0;

  select coalesce(sum(opa.platform_fee_minor), 0), coalesce(sum(opa.gross_minor), 0)
    into allocated_fee, allocated_gross
  from public.order_proceeds_allocations opa
  where opa.journal_batch_id = batch_id;

  if allocated_fee > 0 then
    insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
    values (batch_id, 'platform_revenue', 'credit', allocated_fee, order_row.currency, 'Platform commission under approved seller fee schedules');
  end if;

  if order_row.tax_minor > 0 then
    insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
    values (batch_id, 'tax_payable', 'credit', order_row.tax_minor, order_row.currency, 'Order tax liability recorded from order snapshot');
  end if;

  if allocated_gross <> order_row.subtotal_minor then
    raise exception using errcode = '23514', message = 'order item gross does not reconcile to the immutable order subtotal';
  end if;

  update public.financial_journal_batches set status = 'posted' where id = batch_id;
  return batch_id;
end;
$function$;
revoke all on function public.allocate_order_proceeds(uuid, text, text) from public, anon, authenticated;
grant execute on function public.allocate_order_proceeds(uuid, text, text) to service_role;
