-- Phase 4D1: evidence-backed refund reversals after seller proceeds allocation.
-- Refund execution remains driven by the verified webhook processor; this migration
-- only permits it after an independently approved, item-level accounting reversal.

alter table public.financial_journal_batches
  drop constraint financial_journal_batches_source_type_check;
alter table public.financial_journal_batches
  add constraint financial_journal_batches_source_type_check
  check (source_type in (
    'payment', 'refund', 'refund_reversal', 'proceeds_allocation', 'provider_settlement',
    'provider_fee', 'chargeback', 'manual_adjustment', 'reserve_hold', 'reserve_release'
  ));

alter table public.financial_journal_batches
  drop constraint financial_batch_source_identity;
alter table public.financial_journal_batches
  add constraint financial_batch_source_identity check (
    (source_type = 'payment' and order_id is not null and payment_attempt_id is not null and refund_id is null and provider is not null and provider_reference is not null)
    or (source_type = 'refund' and order_id is not null and payment_attempt_id is not null and refund_id is not null and provider is not null and provider_reference is not null)
    or (source_type = 'refund_reversal' and order_id is not null and payment_attempt_id is not null and refund_id is not null and provider is not null and provider_reference is not null)
    or (source_type = 'proceeds_allocation' and order_id is not null and payment_attempt_id is null and refund_id is null and provider is null and provider_reference is null)
    or (source_type in ('provider_settlement', 'provider_fee') and provider is not null and provider_reference is not null)
    or (source_type in ('chargeback', 'manual_adjustment', 'reserve_hold', 'reserve_release'))
  );

create table public.refund_reversal_requests (
  id uuid primary key default gen_random_uuid(),
  refund_id uuid not null unique references public.refunds(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  reason text not null check (char_length(reason) between 12 and 500),
  status text not null default 'requested' check (status in ('requested', 'approved', 'rejected', 'posted')),
  requested_by uuid not null references auth.users(id) on delete restrict,
  approved_by uuid references auth.users(id) on delete restrict,
  approved_at timestamptz,
  journal_batch_id uuid unique references public.financial_journal_batches(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint refund_reversal_request_state check (
    (status = 'requested' and approved_by is null and approved_at is null and journal_batch_id is null)
    or (status = 'rejected' and approved_by is not null and approved_at is not null and journal_batch_id is null)
    or (status = 'approved' and approved_by is not null and approved_at is not null and journal_batch_id is null)
    or (status = 'posted' and approved_by is not null and approved_at is not null and journal_batch_id is not null)
  )
);
create index refund_reversal_order_idx on public.refund_reversal_requests (order_id, status, created_at desc);
create unique index financial_journal_one_refund_reversal_uq on public.financial_journal_batches (refund_id) where source_type = 'refund_reversal';

create table public.refund_reversal_lines (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.refund_reversal_requests(id) on delete restrict,
  refund_id uuid not null references public.refunds(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  fee_schedule_id uuid not null references public.seller_fee_schedules(id) on delete restrict,
  gross_refund_minor bigint not null check (gross_refund_minor > 0),
  platform_fee_reversal_minor bigint not null check (platform_fee_reversal_minor >= 0),
  seller_payable_reversal_minor bigint not null check (seller_payable_reversal_minor >= 0),
  tax_reversal_minor bigint not null default 0 check (tax_reversal_minor >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  constraint refund_reversal_line_balances check (
    gross_refund_minor = platform_fee_reversal_minor + seller_payable_reversal_minor + tax_reversal_minor
  ),
  constraint refund_reversal_line_unique_item unique (request_id, order_item_id)
);
create index refund_reversal_lines_refund_idx on public.refund_reversal_lines (refund_id, order_item_id);

alter table public.refund_reversal_requests enable row level security;
alter table public.refund_reversal_lines enable row level security;
revoke all on public.refund_reversal_requests from public, anon, authenticated;
revoke all on public.refund_reversal_lines from public, anon, authenticated;
grant select, insert, update on public.refund_reversal_requests to service_role;
grant select, insert on public.refund_reversal_lines to service_role;

create function public.guard_refund_reversal_request()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'requested' or new.approved_by is not null
      or new.approved_at is not null or new.journal_batch_id is not null
      or not exists (
        select 1 from public.user_roles ur
        where ur.user_id = new.requested_by and ur.role = 'admin'::public.app_role
      ) then
      raise exception using errcode = '23514', message = 'refund reversal requests must start requested by an admin';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception using errcode = '23514', message = 'refund reversal request evidence cannot be deleted';
  end if;

  if new.id is distinct from old.id
    or new.refund_id is distinct from old.refund_id
    or new.order_id is distinct from old.order_id
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.evidence_sha256 is distinct from old.evidence_sha256
    or new.reason is distinct from old.reason
    or new.requested_by is distinct from old.requested_by
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '23514', message = 'refund reversal request evidence is immutable';
  end if;

  if old.status = 'requested' and new.status in ('approved', 'rejected') then
    if new.approved_by is null or new.approved_by = new.requested_by
      or new.approved_at is null or new.journal_batch_id is not null
      or not exists (
        select 1 from public.user_roles ur
        where ur.user_id = new.approved_by and ur.role = 'admin'::public.app_role
      ) then
      raise exception using errcode = '23514', message = 'refund reversal decision requires a distinct database-owned admin';
    end if;
  elsif old.status = 'approved' and new.status = 'posted' then
    if new.approved_by is distinct from old.approved_by
      or new.approved_at is distinct from old.approved_at
      or new.journal_batch_id is null
      or not exists (
        select 1 from public.financial_journal_batches b
        where b.id = new.journal_batch_id and b.source_type = 'refund_reversal'
          and b.refund_id = new.refund_id and b.status = 'posted'
      ) then
      raise exception using errcode = '23514', message = 'posted refund reversal must link to its immutable posted journal';
    end if;
  else
    raise exception using errcode = '23514', message = 'invalid refund reversal request transition';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_refund_reversal_request() from public, anon, authenticated, service_role;
create trigger refund_reversal_request_guard
before insert or update or delete on public.refund_reversal_requests
for each row execute function public.guard_refund_reversal_request();

create function public.guard_refund_reversal_line()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  request_row public.refund_reversal_requests%rowtype;
  allocation_row public.order_proceeds_allocations%rowtype;
  previous_gross numeric;
  previous_fee numeric;
  previous_net numeric;
  previous_tax numeric;
  order_tax bigint;
  fee_bps integer;
begin
  if tg_op <> 'INSERT' then
    raise exception using errcode = '23514', message = 'refund reversal lines are append-only';
  end if;

  select * into request_row
  from public.refund_reversal_requests r
  where r.id = new.request_id
  for update;

  if request_row.id is null or request_row.status <> 'requested'
    or request_row.refund_id <> new.refund_id
    or request_row.order_id <> new.order_id
    or request_row.currency <> new.currency then
    raise exception using errcode = '23514', message = 'refund reversal line must belong to a matching requested reversal';
  end if;

  select * into allocation_row
  from public.order_proceeds_allocations opa
  where opa.order_item_id = new.order_item_id
    and opa.order_id = new.order_id
    and opa.seller_id = new.seller_id
    and opa.fee_schedule_id = new.fee_schedule_id
    and opa.currency = new.currency
  for update;

  select s.platform_fee_bps into fee_bps
  from public.seller_fee_schedules s where s.id = new.fee_schedule_id;

  if allocation_row.id is null or fee_bps is null
    or new.platform_fee_reversal_minor <> floor((new.gross_refund_minor::numeric * fee_bps::numeric) / 10000)::bigint
    or new.seller_payable_reversal_minor <> new.gross_refund_minor - new.platform_fee_reversal_minor - new.tax_reversal_minor
    or new.platform_fee_reversal_minor > allocation_row.platform_fee_minor
    or new.seller_payable_reversal_minor > allocation_row.seller_net_minor then
    raise exception using errcode = '23514', message = 'refund reversal line must reference original proceeds allocation and stay within its item limits';
  end if;

  select coalesce(sum(rl.gross_refund_minor),0),
         coalesce(sum(rl.platform_fee_reversal_minor),0),
         coalesce(sum(rl.seller_payable_reversal_minor),0),
         coalesce(sum(rl.tax_reversal_minor),0)
    into previous_gross, previous_fee, previous_net, previous_tax
  from public.refund_reversal_lines rl
  join public.refund_reversal_requests rr on rr.id = rl.request_id
  where rl.order_item_id = new.order_item_id
    and rr.status in ('requested', 'approved', 'posted');

  if previous_gross + new.gross_refund_minor > allocation_row.gross_minor
    or previous_fee + new.platform_fee_reversal_minor > allocation_row.platform_fee_minor
    or previous_net + new.seller_payable_reversal_minor > allocation_row.seller_net_minor then
    raise exception using errcode = '23514', message = 'cumulative item refunds cannot exceed original allocated gross, fee or seller payable';
  end if;

  select o.tax_minor into order_tax from public.orders o where o.id = new.order_id;
  select coalesce(sum(rl.tax_reversal_minor),0) into previous_tax
  from public.refund_reversal_lines rl
  join public.refund_reversal_requests rr on rr.id = rl.request_id
  where rl.order_id = new.order_id and rr.status in ('requested', 'approved', 'posted');
  if previous_tax + new.tax_reversal_minor > coalesce(order_tax,0) then
    raise exception using errcode = '23514', message = 'cumulative tax reversal cannot exceed the recorded order tax liability';
  end if;

  return new;
end;
$function$;
revoke all on function public.guard_refund_reversal_line() from public, anon, authenticated, service_role;
create trigger refund_reversal_line_guard
before insert or update or delete on public.refund_reversal_lines
for each row execute function public.guard_refund_reversal_line();

create or replace function public.guard_financial_journal_batch()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  entry_count bigint;
  debit_total numeric;
  credit_total numeric;
  mismatched_currency boolean;
  source_amount bigint;
  source_subtotal bigint;
  source_tax bigint;
  source_item_count bigint;
  allocation_count bigint;
  allocation_gross numeric;
  allocation_fee numeric;
  allocation_net numeric;
  allocation_tax numeric;
  fee_bps integer;
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

  if new.source_type = 'payment' then
    select lt.amount_minor into source_amount
    from public.ledger_transactions lt
    where lt.source_type = 'payment' and lt.order_id = new.order_id
      and lt.payment_attempt_id = new.payment_attempt_id
      and lt.reference_key = replace(new.source_key, 'legacy-ledger:payment:', '')
      and lt.currency = new.currency;
    if source_amount is null
      or not exists (
        select 1 from public.payment_webhook_events we
        where we.order_id = new.order_id and we.payment_attempt_id = new.payment_attempt_id
          and we.provider = new.provider and we.event_type = 'payment.succeeded'
          and we.signature_verified and we.processing_status in ('processing', 'processed')
          and we.payload_sha256 = new.evidence_sha256 and we.provider_reference = new.provider_reference
      )
      or entry_count <> 2
      or not exists (select 1 from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'provider_clearing' and e.side = 'debit' and e.amount_minor = source_amount)
      or not exists (select 1 from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'unallocated_order_liability' and e.side = 'credit' and e.amount_minor = source_amount) then
      raise exception using errcode = '23514', message = 'payment journal must match an immutable ledger posting and verified provider event';
    end if;

  elsif new.source_type = 'refund' then
    select lt.amount_minor into source_amount
    from public.ledger_transactions lt
    where lt.source_type = 'refund' and lt.order_id = new.order_id
      and lt.payment_attempt_id = new.payment_attempt_id and lt.refund_id = new.refund_id
      and lt.reference_key = replace(new.source_key, 'legacy-ledger:refund:', '')
      and lt.currency = new.currency;
    if source_amount is null
      or (exists (select 1 from public.order_proceeds_allocations opa where opa.order_id = new.order_id)
        and not exists (
          select 1 from public.financial_journal_batches rb
          join public.financial_journal_entries re on re.batch_id = rb.id
          where rb.source_type = 'refund_reversal' and rb.refund_id = new.refund_id
            and rb.status = 'posted' and re.account = 'unallocated_order_liability'
            and re.side = 'credit' and re.amount_minor = source_amount
        ))
      or not exists (
        select 1 from public.payment_webhook_events we
        where we.order_id = new.order_id and we.payment_attempt_id = new.payment_attempt_id
          and we.refund_id = new.refund_id and we.provider = new.provider
          and we.event_type = 'refund.succeeded' and we.signature_verified
          and we.processing_status in ('processing', 'processed')
          and we.payload_sha256 = new.evidence_sha256 and we.provider_reference = new.provider_reference
      )
      or entry_count <> 2
      or not exists (select 1 from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'unallocated_order_liability' and e.side = 'debit' and e.amount_minor = source_amount)
      or not exists (select 1 from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'provider_clearing' and e.side = 'credit' and e.amount_minor = source_amount) then
      raise exception using errcode = '23514', message = 'refund journal must match verified refund evidence and an approved reversal when proceeds were allocated';
    end if;

  elsif new.source_type = 'refund_reversal' then
    select r.amount_minor into source_amount
    from public.refunds r
    where r.id = new.refund_id and r.order_id = new.order_id
      and r.payment_attempt_id = new.payment_attempt_id and r.currency = new.currency
      and r.status in ('requested', 'pending');
    select count(*), coalesce(sum(rl.gross_refund_minor),0),
           coalesce(sum(rl.platform_fee_reversal_minor),0),
           coalesce(sum(rl.seller_payable_reversal_minor),0),
           coalesce(sum(rl.tax_reversal_minor),0)
      into allocation_count, allocation_gross, allocation_fee, allocation_net, allocation_tax
    from public.refund_reversal_lines rl
    join public.refund_reversal_requests rr on rr.id = rl.request_id
    where rr.refund_id = new.refund_id and rr.status = 'approved';
    if source_amount is null or allocation_count = 0 or allocation_gross <> source_amount
      or allocation_fee + allocation_net + allocation_tax <> source_amount
      or not exists (
        select 1 from public.refund_reversal_requests rr
        where rr.refund_id = new.refund_id and rr.status = 'approved'
          and rr.order_id = new.order_id and rr.amount_minor = source_amount
          and rr.currency = new.currency
      )
      or not exists (
        select 1 from public.payment_webhook_events we
        where we.refund_id = new.refund_id and we.order_id = new.order_id
          and we.payment_attempt_id = new.payment_attempt_id and we.provider = new.provider
          and we.event_type = 'refund.succeeded' and we.signature_verified
          and we.processing_status in ('processing', 'processed')
          and we.payload_sha256 = new.evidence_sha256 and we.provider_reference = new.provider_reference
      )
      or (select coalesce(sum(e.amount_minor),0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'seller_payable' and e.side = 'debit') <> allocation_net
      or (select coalesce(sum(e.amount_minor),0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'platform_revenue' and e.side = 'debit') <> allocation_fee
      or (select coalesce(sum(e.amount_minor),0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'tax_payable' and e.side = 'debit') <> allocation_tax
      or (select coalesce(sum(e.amount_minor),0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'unallocated_order_liability' and e.side = 'credit') <> source_amount
      or exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id and not (
          (e.account in ('seller_payable','platform_revenue','tax_payable') and e.side = 'debit')
          or (e.account = 'unallocated_order_liability' and e.side = 'credit')
        )
      ) then
      raise exception using errcode = '23514', message = 'refund reversal journal must reconcile to approved item-level reversal lines and verified provider evidence';
    end if;

  elsif new.source_type = 'proceeds_allocation' then
    select o.total_minor, o.subtotal_minor, o.tax_minor
      into source_amount, source_subtotal, source_tax
    from public.orders o
    where o.id = new.order_id and o.status in ('paid','partially_refunded') and o.currency = new.currency;
    select count(*) into source_item_count from public.order_items oi where oi.order_id = new.order_id;
    select count(*), coalesce(sum(opa.gross_minor), 0), coalesce(sum(opa.platform_fee_minor), 0), coalesce(sum(opa.seller_net_minor), 0)
      into allocation_count, allocation_gross, allocation_fee, allocation_net
    from public.order_proceeds_allocations opa where opa.journal_batch_id = new.id;
    if source_amount is null or allocation_count <> source_item_count or allocation_count = 0
      or allocation_gross <> source_subtotal or allocation_fee + allocation_net <> allocation_gross
      or (select count(*) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'unallocated_order_liability' and e.side = 'debit' and e.amount_minor = source_amount) <> 1
      or (select coalesce(sum(e.amount_minor), 0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'seller_payable' and e.side = 'credit') <> allocation_net
      or (select coalesce(sum(e.amount_minor), 0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'platform_revenue' and e.side = 'credit') <> allocation_fee
      or (select coalesce(sum(e.amount_minor), 0) from public.financial_journal_entries e where e.batch_id = new.id and e.account = 'tax_payable' and e.side = 'credit') <> source_tax
      or exists (select 1 from public.financial_journal_entries e where e.batch_id = new.id and not ((e.account = 'unallocated_order_liability' and e.side = 'debit') or (e.account in ('seller_payable','platform_revenue','tax_payable') and e.side = 'credit'))) then
      raise exception using errcode = '23514', message = 'proceeds allocation journal must reconcile to paid order, item allocations, approved fees and tax';
    end if;
  else
    raise exception using errcode = '23514', message = 'financial posting source has no approved posting workflow';
  end if;

  new.posted_at := coalesce(new.posted_at, now());
  return new;
end;
$function$;

create function public.reject_refund_reversal_request(p_request_id uuid, p_reviewer uuid)
returns uuid
language plpgsql
set search_path = ''
as $function$
declare
  request_id uuid;
begin
  update public.refund_reversal_requests
  set status = 'rejected', approved_by = p_reviewer, approved_at = now()
  where id = p_request_id and status = 'requested'
    and requested_by <> p_reviewer
    and exists (select 1 from public.user_roles ur where ur.user_id = p_reviewer and ur.role = 'admin'::public.app_role)
  returning id into request_id;
  if request_id is null then
    raise exception using errcode = '23514', message = 'refund reversal rejection requires a distinct database-owned admin and pending request';
  end if;
  return request_id;
end;
$function$;
revoke all on function public.reject_refund_reversal_request(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reject_refund_reversal_request(uuid, uuid) to service_role;

create function public.post_refund_reversal_from_verified_event(p_refund_id uuid, p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  refund_row public.refunds%rowtype;
  request_row public.refund_reversal_requests%rowtype;
  event_row public.payment_webhook_events%rowtype;
  batch_id uuid;
  gross_total bigint;
  fee_total bigint;
  seller_total bigint;
  tax_total bigint;
begin
  select * into refund_row from public.refunds r where r.id = p_refund_id for update;
  select * into request_row from public.refund_reversal_requests rr
  where rr.refund_id = p_refund_id and rr.status = 'approved' for update;
  select * into event_row from public.payment_webhook_events we
  where we.id = p_event_id and we.refund_id = p_refund_id
    and we.event_type = 'refund.succeeded' and we.signature_verified
    and we.processing_status = 'processing'
  for update;

  if refund_row.id is null or request_row.id is null or event_row.id is null
    or refund_row.order_id <> request_row.order_id
    or refund_row.amount_minor <> request_row.amount_minor
    or refund_row.currency <> request_row.currency
    or event_row.order_id <> refund_row.order_id
    or event_row.payment_attempt_id <> refund_row.payment_attempt_id
    or event_row.amount_minor <> refund_row.amount_minor
    or event_row.currency <> refund_row.currency
    or event_row.provider_reference is null then
    raise exception using errcode = '23514', message = 'allocated refund requires a matching approved reversal and verified provider event';
  end if;

  select b.id into batch_id
  from public.financial_journal_batches b
  where b.source_type = 'refund_reversal' and b.refund_id = p_refund_id;
  if batch_id is not null then
    raise exception using errcode = '23514', message = 'refund reversal journal already exists';
  end if;

  select coalesce(sum(rl.gross_refund_minor),0),
         coalesce(sum(rl.platform_fee_reversal_minor),0),
         coalesce(sum(rl.seller_payable_reversal_minor),0),
         coalesce(sum(rl.tax_reversal_minor),0)
    into gross_total, fee_total, seller_total, tax_total
  from public.refund_reversal_lines rl where rl.request_id = request_row.id;

  if gross_total <> refund_row.amount_minor or gross_total = 0
    or fee_total + seller_total + tax_total <> gross_total then
    raise exception using errcode = '23514', message = 'approved refund reversal lines must reconcile exactly to refund amount';
  end if;

  insert into public.financial_journal_batches (
    source_type, source_key, idempotency_key, order_id, payment_attempt_id, refund_id,
    provider, provider_reference, currency, evidence_sha256
  ) values (
    'refund_reversal', 'refund-reversal:' || refund_row.id::text,
    'refund-reversal:' || refund_row.id::text, refund_row.order_id,
    refund_row.payment_attempt_id, refund_row.id, event_row.provider,
    event_row.provider_reference, refund_row.currency, event_row.payload_sha256
  ) returning id into batch_id;

  insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, seller_id, memo)
  select batch_id, 'seller_payable', 'debit', sum(rl.seller_payable_reversal_minor), refund_row.currency,
         rl.seller_id, 'Approved reversal of seller payable for refund'
  from public.refund_reversal_lines rl
  where rl.request_id = request_row.id
  group by rl.seller_id
  having sum(rl.seller_payable_reversal_minor) > 0;

  if fee_total > 0 then
    insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
    values (batch_id, 'platform_revenue', 'debit', fee_total, refund_row.currency, 'Approved reversal of platform commission');
  end if;
  if tax_total > 0 then
    insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
    values (batch_id, 'tax_payable', 'debit', tax_total, refund_row.currency, 'Approved reversal of recorded order tax liability');
  end if;

  insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
  values (batch_id, 'unallocated_order_liability', 'credit', gross_total, refund_row.currency, 'Restore allocated proceeds before verified refund outflow');

  update public.financial_journal_batches set status = 'posted' where id = batch_id;
  update public.refund_reversal_requests set status = 'posted', journal_batch_id = batch_id where id = request_row.id;
  return batch_id;
end;
$function$;
revoke all on function public.post_refund_reversal_from_verified_event(uuid, uuid) from public, anon, authenticated, service_role;

create or replace function public.record_legacy_ledger_journal()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  provider_name text;
  provider_ref text;
  evidence_digest text;
  verified_event_id uuid;
  journal_id uuid;
  journal_source text;
begin
  select pa.provider, pa.provider_reference into provider_name, provider_ref
  from public.payment_attempts pa where pa.id = new.payment_attempt_id and pa.order_id = new.order_id;
  if provider_name is null then
    raise exception using errcode = '23514', message = 'accounting journal requires a matching payment attempt';
  end if;

  if new.source_type = 'payment' then
    select we.id, we.payload_sha256, we.provider_reference
      into verified_event_id, evidence_digest, provider_ref
    from public.payment_webhook_events we
    where we.id::text = replace(new.reference_key, 'payment-event:', '')
      and we.order_id = new.order_id and we.payment_attempt_id = new.payment_attempt_id
      and we.provider = provider_name and we.event_type = 'payment.succeeded'
      and we.signature_verified and we.processing_status in ('processing', 'processed')
    limit 1;
    journal_source := 'legacy-ledger:payment:' || new.reference_key;
  elsif new.source_type = 'refund' then
    select we.id, we.payload_sha256, we.provider_reference
      into verified_event_id, evidence_digest, provider_ref
    from public.payment_webhook_events we
    where we.id::text = replace(new.reference_key, 'refund-event:', '')
      and we.order_id = new.order_id and we.payment_attempt_id = new.payment_attempt_id
      and we.refund_id = new.refund_id and we.provider = provider_name
      and we.event_type = 'refund.succeeded' and we.signature_verified
      and we.processing_status in ('processing', 'processed')
    limit 1;
    if exists (select 1 from public.order_proceeds_allocations opa where opa.order_id = new.order_id) then
      perform public.post_refund_reversal_from_verified_event(new.refund_id, verified_event_id);
    end if;
    journal_source := 'legacy-ledger:refund:' || new.reference_key;
  else
    raise exception using errcode = '23514', message = 'unsupported legacy ledger source';
  end if;

  if evidence_digest is null or verified_event_id is null then
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

create function public.approve_refund_reversal_request(p_request_id uuid, p_approver uuid)
returns uuid
language plpgsql
set search_path = ''
as $function$
declare
  request_row public.refund_reversal_requests%rowtype;
  refund_row public.refunds%rowtype;
  order_row public.orders%rowtype;
  line_count bigint;
  line_gross bigint;
begin
  select * into request_row from public.refund_reversal_requests r where r.id = p_request_id for update;
  if request_row.id is null or request_row.status <> 'requested' then
    raise exception using errcode = '23514', message = 'refund reversal request is not awaiting approval';
  end if;
  select * into refund_row from public.refunds r where r.id = request_row.refund_id for update;
  select * into order_row from public.orders o where o.id = request_row.order_id for update;

  if refund_row.id is null or order_row.id is null
    or refund_row.order_id <> request_row.order_id
    or refund_row.amount_minor <> request_row.amount_minor
    or refund_row.currency <> request_row.currency
    or refund_row.status not in ('requested', 'pending')
    or order_row.status not in ('paid', 'partially_refunded')
    or exists (select 1 from public.ledger_transactions lt where lt.refund_id = refund_row.id) then
    raise exception using errcode = '23514', message = 'refund/order state is not eligible for reversal approval';
  end if;
  if p_approver is null or p_approver = request_row.requested_by
    or not exists (select 1 from public.user_roles ur where ur.user_id = p_approver and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '23514', message = 'refund reversal requires a distinct database-owned admin approver';
  end if;

  select count(*), coalesce(sum(rl.gross_refund_minor),0)
    into line_count, line_gross
  from public.refund_reversal_lines rl where rl.request_id = request_row.id;
  if line_count = 0 or line_gross <> request_row.amount_minor then
    raise exception using errcode = '23514', message = 'item-level reversal lines must reconcile exactly to the refund amount';
  end if;

  update public.refund_reversal_requests
  set status = 'approved', approved_by = p_approver, approved_at = now()
  where id = request_row.id;
  return request_row.id;
end;
$function$;
revoke all on function public.approve_refund_reversal_request(uuid, uuid) from public, anon, authenticated;
grant execute on function public.approve_refund_reversal_request(uuid, uuid) to service_role;
