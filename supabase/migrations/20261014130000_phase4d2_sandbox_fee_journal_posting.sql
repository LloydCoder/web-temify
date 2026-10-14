-- Phase 4D2 follow-up: post provider-fee rows only after independent evidence linkage.
-- This is sandbox-only accounting; it is not provider settlement, payout, or money movement.

alter table public.settlement_import_rows
  add constraint settlement_row_fee_arithmetic
  check (
    row_type <> 'fee'
    or (gross_minor = 0 and fee_minor > 0 and net_minor = -fee_minor)
  ) not valid;

alter table public.settlement_reconciliation_results
  drop constraint settlement_reconciliation_results_result_code_check;
alter table public.settlement_reconciliation_results
  add constraint settlement_reconciliation_results_result_code_check
  check (result_code in (
    'matched_payment', 'matched_refund', 'matched_fee',
    'missing_internal_match', 'duplicate_reference', 'amount_mismatch',
    'currency_mismatch', 'period_mismatch', 'unsupported_row_type',
    'unexplained_adjustment'
  ));

alter table public.settlement_reconciliation_results
  drop constraint settlement_reconciliation_result_shape;
alter table public.settlement_reconciliation_results
  add constraint settlement_reconciliation_result_shape check (
    (result_status = 'matched'
      and result_code in ('matched_payment', 'matched_refund', 'matched_fee')
      and journal_batch_id is not null)
    or (result_status = 'exception'
      and result_code not in ('matched_payment', 'matched_refund', 'matched_fee')
      and journal_batch_id is null)
  );

create table public.settlement_journal_postings (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null,
  row_id text not null,
  journal_batch_id uuid not null unique references public.financial_journal_batches(id) on delete restrict,
  reconciliation_run_id uuid not null references public.settlement_reconciliation_runs(id) on delete restrict,
  posting_type text not null check (posting_type in ('provider_fee')),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  posted_by uuid not null references auth.users(id) on delete restrict,
  posted_at timestamptz not null default now(),
  request_id text not null check (char_length(request_id) between 1 and 120),
  foreign key (import_id, row_id)
    references public.settlement_import_rows(import_id, row_id) on delete restrict,
  constraint settlement_journal_posting_one_per_row unique (import_id, row_id)
);

create index settlement_journal_postings_import_idx
  on public.settlement_journal_postings (import_id, posted_at desc);

alter table public.settlement_journal_postings enable row level security;
revoke all on public.settlement_journal_postings from public, anon, authenticated, service_role;

create function public.reject_settlement_journal_posting_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'settlement journal posting evidence is immutable';
end;
$function$;
revoke all on function public.reject_settlement_journal_posting_mutation() from public, anon, authenticated, service_role;
create trigger settlement_journal_postings_immutable
before update or delete on public.settlement_journal_postings
for each row execute function public.reject_settlement_journal_posting_mutation();

create function public.post_sandbox_settlement_fee_row(
  p_import_id uuid,
  p_row_id text,
  p_reconciled_by uuid,
  p_reconciliation_run_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  import_row public.settlement_imports%rowtype;
  fee_row public.settlement_import_rows%rowtype;
  evidence_link public.settlement_evidence_links%rowtype;
  evidence_row public.settlement_evidence%rowtype;
  run_row public.settlement_reconciliation_runs%rowtype;
  existing_posting public.settlement_journal_postings%rowtype;
  new_batch_id uuid;
  source_key_value text;
  provider_reference_value text;
begin
  if p_import_id is null or p_row_id is null or char_length(p_row_id) not between 1 and 240
    or p_reconciled_by is null or p_reconciliation_run_id is null
  then
    raise exception using errcode = '23514', message = 'settlement fee posting metadata failed validation';
  end if;

  select * into import_row from public.settlement_imports where id = p_import_id;
  if import_row.id is null then
    raise exception using errcode = 'P0002', message = 'settlement import was not found';
  end if;
  if import_row.provider <> 'sandbox'
    or import_row.source_authentication_method <> 'sandbox_fixture'
  then
    raise exception using errcode = '23514', message = 'provider fee posting is restricted to sandbox fixtures';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_reconciled_by and ur.role = 'admin'::public.app_role
  ) or p_reconciled_by = import_row.imported_by then
    raise exception using errcode = '42501', message = 'settlement fee posting requires an independent admin reviewer';
  end if;

  select * into fee_row
  from public.settlement_import_rows
  where import_id = p_import_id and row_id = p_row_id;
  if fee_row.import_id is null then
    raise exception using errcode = 'P0002', message = 'settlement fee row was not found';
  end if;
  if fee_row.row_type <> 'fee' or fee_row.exception_code is not null
    or fee_row.gross_minor <> 0 or fee_row.fee_minor <= 0
    or fee_row.net_minor <> -fee_row.fee_minor
    or fee_row.currency <> import_row.currency
  then
    raise exception using errcode = '23514', message = 'settlement fee row arithmetic or classification is invalid';
  end if;

  select * into run_row
  from public.settlement_reconciliation_runs
  where id = p_reconciliation_run_id
    and import_id = p_import_id
    and reconciled_by = p_reconciled_by;
  if run_row.id is null then
    raise exception using errcode = '23514', message = 'settlement fee posting must belong to its reconciliation run';
  end if;

  select link.* into evidence_link
  from public.settlement_evidence_links link
  join public.settlement_evidence evidence on evidence.id = link.evidence_id
  where link.import_id = p_import_id
    and link.source_sha256 = import_row.source_sha256
    and evidence.source_sha256 = import_row.source_sha256
  order by link.linked_at desc
  limit 1;
  if evidence_link.id is null then
    raise exception using errcode = '23514', message = 'settlement fee posting requires independently linked evidence with matching source digest';
  end if;

  select * into evidence_row
  from public.settlement_evidence
  where id = evidence_link.evidence_id;
  if evidence_row.id is null
    or p_reconciled_by = evidence_row.uploaded_by
    or p_reconciled_by = evidence_link.linked_by
  then
    raise exception using errcode = '42501', message = 'settlement fee posting requires a reviewer independent of import, upload, and evidence linking';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('settlement-fee-post:' || p_import_id::text || ':' || p_row_id, 0)
  );

  select * into existing_posting
  from public.settlement_journal_postings
  where import_id = p_import_id and row_id = p_row_id;
  if existing_posting.id is not null then
    if existing_posting.evidence_sha256 = import_row.source_sha256
      and existing_posting.reconciliation_run_id = p_reconciliation_run_id
      and existing_posting.posted_by = p_reconciled_by
      and exists (
        select 1 from public.financial_journal_batches b
        where b.id = existing_posting.journal_batch_id
          and b.status = 'posted'
          and b.source_type = 'provider_fee'
          and b.evidence_sha256 = import_row.source_sha256
      )
    then
      return existing_posting.journal_batch_id;
    end if;
    raise exception using errcode = '23514', message = 'settlement fee row already has conflicting posting evidence';
  end if;

  source_key_value := 'settlement-fee:' || p_import_id::text || ':' || p_row_id;
  provider_reference_value := coalesce(fee_row.provider_reference, fee_row.row_id);

  insert into public.financial_journal_batches (
    source_type, source_key, idempotency_key, provider, provider_reference,
    currency, evidence_sha256, status
  ) values (
    'provider_fee', source_key_value, source_key_value, import_row.provider,
    provider_reference_value, fee_row.currency, import_row.source_sha256, 'draft'
  ) returning id into new_batch_id;

  insert into public.financial_journal_entries (
    batch_id, account, side, amount_minor, currency, memo
  ) values
    (new_batch_id, 'provider_fee_expense', 'debit', fee_row.fee_minor, fee_row.currency,
      'Sandbox settlement fee row ' || fee_row.row_id),
    (new_batch_id, 'provider_clearing', 'credit', fee_row.fee_minor, fee_row.currency,
      'Sandbox settlement fee row ' || fee_row.row_id);

  insert into public.settlement_journal_postings (
    import_id, row_id, journal_batch_id, reconciliation_run_id,
    posting_type, evidence_sha256, posted_by, request_id
  ) values (
    p_import_id, p_row_id, new_batch_id, p_reconciliation_run_id,
    'provider_fee', import_row.source_sha256, p_reconciled_by, p_reconciliation_run_id::text
  );

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_reconciled_by, 'settlement.provider_fee.posted', 'financial_journal_batch',
    new_batch_id::text, p_reconciliation_run_id::text,
    jsonb_build_object(
      'import_id', p_import_id,
      'row_id', p_row_id,
      'currency', fee_row.currency,
      'fee_minor', fee_row.fee_minor,
      'evidence_sha256', import_row.source_sha256,
      'reconciliation_run_id', p_reconciliation_run_id
    )
  );

  update public.financial_journal_batches
  set status = 'posted'
  where id = new_batch_id;

  return new_batch_id;
end;
$function$;

revoke all on function public.post_sandbox_settlement_fee_row(uuid, text, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.post_sandbox_settlement_fee_row(uuid, text, uuid, uuid)
  to service_role;

comment on function public.post_sandbox_settlement_fee_row(uuid, text, uuid, uuid) is
  'Posts a balanced provider-fee journal only during independent reconciliation of a sandbox fixture with privately stored, independently linked evidence. Never enables live-provider processing or payout execution.';

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
  settlement_posting public.settlement_journal_postings%rowtype;
  settlement_import public.settlement_imports%rowtype;
  settlement_row public.settlement_import_rows%rowtype;
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
    where lt.source_type = 'payment'
      and lt.order_id = new.order_id
      and lt.payment_attempt_id = new.payment_attempt_id
      and lt.reference_key = replace(new.source_key, 'legacy-ledger:payment:', '')
      and lt.currency = new.currency;

    if source_amount is null
      or not exists (
        select 1
        from public.payment_webhook_events we
        where we.order_id = new.order_id
          and we.payment_attempt_id = new.payment_attempt_id
          and we.provider = new.provider
          and we.event_type = 'payment.succeeded'
          and we.signature_verified
          and we.processing_status in ('processing', 'processed')
          and we.payload_sha256 = new.evidence_sha256
          and we.provider_reference = new.provider_reference
      )
      or entry_count <> 2
      or not exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id and e.account = 'provider_clearing'
          and e.side = 'debit' and e.amount_minor = source_amount
      )
      or not exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id and e.account = 'unallocated_order_liability'
          and e.side = 'credit' and e.amount_minor = source_amount
      ) then
      raise exception using errcode = '23514', message = 'payment journal must match an immutable ledger posting and verified provider event';
    end if;

  elsif new.source_type = 'refund' then
    select lt.amount_minor into source_amount
    from public.ledger_transactions lt
    where lt.source_type = 'refund'
      and lt.order_id = new.order_id
      and lt.payment_attempt_id = new.payment_attempt_id
      and lt.refund_id = new.refund_id
      and lt.reference_key = replace(new.source_key, 'legacy-ledger:refund:', '')
      and lt.currency = new.currency;

    if source_amount is null
      or exists (
        select 1 from public.order_proceeds_allocations opa where opa.order_id = new.order_id
      )
      or not exists (
        select 1
        from public.payment_webhook_events we
        where we.order_id = new.order_id
          and we.payment_attempt_id = new.payment_attempt_id
          and we.refund_id = new.refund_id
          and we.provider = new.provider
          and we.event_type = 'refund.succeeded'
          and we.signature_verified
          and we.processing_status in ('processing', 'processed')
          and we.payload_sha256 = new.evidence_sha256
          and we.provider_reference = new.provider_reference
      )
      or entry_count <> 2
      or not exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id and e.account = 'unallocated_order_liability'
          and e.side = 'debit' and e.amount_minor = source_amount
      )
      or not exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id and e.account = 'provider_clearing'
          and e.side = 'credit' and e.amount_minor = source_amount
      ) then
      raise exception using errcode = '23514', message = 'refund journal must match a verified refund event and cannot bypass allocation reversal';
    end if;

  elsif new.source_type = 'proceeds_allocation' then
    select o.total_minor, o.subtotal_minor, o.tax_minor
      into source_amount, source_subtotal, source_tax
    from public.orders o
    where o.id = new.order_id and o.status = 'paid' and o.currency = new.currency;

    select count(*) into source_item_count
    from public.order_items oi where oi.order_id = new.order_id;

    select count(*), coalesce(sum(opa.gross_minor), 0),
           coalesce(sum(opa.platform_fee_minor), 0), coalesce(sum(opa.seller_net_minor), 0)
      into allocation_count, allocation_gross, allocation_fee, allocation_net
    from public.order_proceeds_allocations opa
    where opa.journal_batch_id = new.id;

    if source_amount is null
      or allocation_count <> source_item_count
      or allocation_count = 0
      or allocation_gross <> source_subtotal
      or allocation_fee + allocation_net <> allocation_gross
      or (select count(*) from public.financial_journal_entries e
          where e.batch_id = new.id and e.account = 'unallocated_order_liability'
            and e.side = 'debit' and e.amount_minor = source_amount) <> 1
      or (select coalesce(sum(e.amount_minor), 0) from public.financial_journal_entries e
          where e.batch_id = new.id and e.account = 'seller_payable' and e.side = 'credit') <> allocation_net
      or (select coalesce(sum(e.amount_minor), 0) from public.financial_journal_entries e
          where e.batch_id = new.id and e.account = 'platform_revenue' and e.side = 'credit') <> allocation_fee
      or (select coalesce(sum(e.amount_minor), 0) from public.financial_journal_entries e
          where e.batch_id = new.id and e.account = 'tax_payable' and e.side = 'credit') <> source_tax
      or exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id
          and not (
            (e.account = 'unallocated_order_liability' and e.side = 'debit')
            or (e.account in ('seller_payable', 'platform_revenue', 'tax_payable') and e.side = 'credit')
          )
      ) then
      raise exception using errcode = '23514', message = 'proceeds allocation journal must reconcile to paid order, item allocations, approved fees and tax';
    end if;

  elsif new.source_type = 'provider_fee' then
    select * into settlement_posting
    from public.settlement_journal_postings
    where journal_batch_id = new.id;

    if settlement_posting.id is null then
      raise exception using errcode = '23514', message = 'provider fee posting requires immutable settlement posting evidence';
    end if;

    select * into settlement_import
    from public.settlement_imports
    where id = settlement_posting.import_id;

    select * into settlement_row
    from public.settlement_import_rows
    where import_id = settlement_posting.import_id
      and row_id = settlement_posting.row_id;

    if settlement_import.id is null
      or settlement_row.import_id is null
      or settlement_posting.posting_type <> 'provider_fee'
      or settlement_import.provider <> 'sandbox'
      or settlement_import.source_authentication_method <> 'sandbox_fixture'
      or settlement_import.source_sha256 <> settlement_posting.evidence_sha256
      or settlement_import.source_sha256 <> new.evidence_sha256
      or settlement_row.row_type <> 'fee'
      or settlement_row.exception_code is not null
      or settlement_row.gross_minor <> 0
      or settlement_row.fee_minor <= 0
      or settlement_row.net_minor <> -settlement_row.fee_minor
      or settlement_row.currency <> settlement_import.currency
      or settlement_row.currency <> new.currency
      or new.provider <> settlement_import.provider
      or new.provider_reference <> coalesce(settlement_row.provider_reference, settlement_row.row_id)
      or new.source_key <> 'settlement-fee:' || settlement_posting.import_id::text || ':' || settlement_posting.row_id
      or new.idempotency_key <> 'settlement-fee:' || settlement_posting.import_id::text || ':' || settlement_posting.row_id
      or entry_count <> 2
      or debit_total <> settlement_row.fee_minor
      or credit_total <> settlement_row.fee_minor
      or mismatched_currency
      or not exists (
        select 1
        from public.settlement_evidence_links link
        join public.settlement_evidence evidence on evidence.id = link.evidence_id
        where link.import_id = settlement_posting.import_id
          and link.source_sha256 = settlement_import.source_sha256
          and evidence.source_sha256 = settlement_import.source_sha256
          and link.linked_by <> settlement_posting.posted_by
          and evidence.uploaded_by <> settlement_posting.posted_by
      )
      or not exists (
        select 1
        from public.user_roles ur
        where ur.user_id = settlement_posting.posted_by
          and ur.role = 'admin'::public.app_role
      )
      or settlement_posting.posted_by = settlement_import.imported_by
      or not exists (
        select 1
        from public.settlement_reconciliation_runs run
        where run.id = settlement_posting.reconciliation_run_id
          and run.import_id = settlement_posting.import_id
          and run.reconciled_by = settlement_posting.posted_by
      )
      or (select count(*) from public.financial_journal_entries e
          where e.batch_id = new.id
            and e.account = 'provider_fee_expense'
            and e.side = 'debit'
            and e.amount_minor = settlement_row.fee_minor) <> 1
      or (select count(*) from public.financial_journal_entries e
          where e.batch_id = new.id
            and e.account = 'provider_clearing'
            and e.side = 'credit'
            and e.amount_minor = settlement_row.fee_minor) <> 1
      or exists (
        select 1 from public.financial_journal_entries e
        where e.batch_id = new.id
          and not (
            (e.account = 'provider_fee_expense' and e.side = 'debit')
            or (e.account = 'provider_clearing' and e.side = 'credit')
          )
      )
    then
      raise exception using errcode = '23514', message = 'provider fee journal must match linked sandbox evidence and balanced fee-row amounts';
    end if;

  else
    raise exception using errcode = '23514', message = 'financial posting source has no approved posting workflow';
  end if;

  new.posted_at := coalesce(new.posted_at, now());
  return new;
end;
$function$;

revoke all on function public.guard_financial_journal_batch() from public, anon, authenticated, service_role;

create or replace function public.reconcile_settlement_import(
  p_import_id uuid,
  p_reconciled_by uuid
)
returns uuid language plpgsql security definer set search_path = ''
as $function$
declare
  import_row public.settlement_imports%rowtype;
  existing_run public.settlement_reconciliation_runs%rowtype;
  new_run_id uuid;
  row_value record;
  candidate_lock record;
  candidate_count bigint;
  candidate_batch_id uuid;
  candidate_currency text;
  candidate_amount numeric;
  result_code_value text;
  matched_count integer := 0;
  exception_count integer := 0;
begin
  if p_import_id is null or p_reconciled_by is null then
    raise exception using errcode = '23514', message = 'settlement reconciliation metadata failed validation';
  end if;
  select * into import_row from public.settlement_imports where id = p_import_id;
  if import_row.id is null then
    raise exception using errcode = 'P0002', message = 'settlement import was not found';
  end if;
  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_reconciled_by and ur.role = 'admin'::public.app_role
  ) or p_reconciled_by = import_row.imported_by then
    raise exception using errcode = '42501', message = 'settlement reconciliation requires a distinct admin reviewer';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('settlement-reconcile:' || p_import_id::text, 0)
  );
  select * into existing_run from public.settlement_reconciliation_runs where import_id = p_import_id;
  if existing_run.id is not null then return existing_run.id; end if;
  insert into public.settlement_reconciliation_runs(import_id,reconciled_by,matched_rows,exception_rows)
  values(p_import_id,p_reconciled_by,0,0) returning id into new_run_id;

  -- Acquire candidate journal locks in a stable UUID order. This prevents
  -- two reports that contain the same journal batches in different row order
  -- from deadlocking while preserving per-batch concurrency isolation.
  for candidate_lock in
    select distinct b.id
    from public.settlement_import_rows ir
    join public.financial_journal_batches b
      on b.provider = import_row.provider
     and b.provider_reference = ir.provider_reference
     and b.status = 'posted'
     and b.source_type = case when ir.row_type = 'payment' then 'payment' else 'refund' end
    where ir.import_id = p_import_id
      and ir.row_type in ('payment', 'refund')
      and ir.provider_reference is not null
    order by b.id
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('settlement-journal-match:' || candidate_lock.id::text, 0)
    );
  end loop;

  for row_value in select * from public.settlement_import_rows where import_id = p_import_id order by row_id loop
    candidate_batch_id := null;
    candidate_currency := null;
    candidate_amount := null;
    candidate_count := 0;
    result_code_value := null;

    if row_value.exception_code is not null then
      -- Explicit provider/report exception classifications must never be
      -- overwritten by an otherwise matching internal journal reference.
      result_code_value := row_value.exception_code;
    elsif row_value.row_type = 'fee' then
      candidate_batch_id := public.post_sandbox_settlement_fee_row(
        p_import_id, row_value.row_id, p_reconciled_by, new_run_id
      );
      result_code_value := 'matched_fee';
    elsif row_value.row_type not in ('payment','refund') then
      result_code_value := 'unsupported_row_type';
    elsif row_value.provider_reference is null then
      result_code_value := 'missing_internal_match';
    else
      select count(*) into candidate_count
      from public.financial_journal_batches b
      where b.provider = import_row.provider and b.provider_reference = row_value.provider_reference
        and b.status = 'posted'
        and b.source_type = case when row_value.row_type = 'payment' then 'payment' else 'refund' end;
      if candidate_count = 0 then
        result_code_value := 'missing_internal_match';
      elsif candidate_count > 1 then
        result_code_value := 'duplicate_reference';
      else
        select b.id,b.currency,
          (select coalesce(sum(e.amount_minor),0) from public.financial_journal_entries e
           where e.batch_id=b.id and e.side='debit')
        into candidate_batch_id,candidate_currency,candidate_amount
        from public.financial_journal_batches b
        where b.provider=import_row.provider and b.provider_reference=row_value.provider_reference
          and b.status='posted'
          and b.source_type=case when row_value.row_type='payment' then 'payment' else 'refund' end
        limit 1;

        if candidate_currency is distinct from row_value.currency then
          result_code_value := 'currency_mismatch';
          candidate_batch_id := null;
        elsif candidate_amount <> abs(row_value.gross_minor) then
          result_code_value := 'amount_mismatch';
          candidate_batch_id := null;
        elsif row_value.net_minor <> row_value.gross_minor - row_value.fee_minor then
          result_code_value := 'amount_mismatch';
          candidate_batch_id := null;
        else
          perform pg_catalog.pg_advisory_xact_lock(
            pg_catalog.hashtextextended('settlement-journal-match:' || candidate_batch_id::text,0)
          );
          if exists (
            select 1 from public.settlement_reconciliation_results prior
            where prior.journal_batch_id=candidate_batch_id and prior.result_status='matched'
          ) then
            result_code_value := 'duplicate_reference';
            candidate_batch_id := null;
          else
            result_code_value := case when row_value.row_type='payment'
              then 'matched_payment' else 'matched_refund' end;
          end if;
        end if;
      end if;
    end if;

    if result_code_value in ('matched_payment','matched_refund','matched_fee') then
      matched_count := matched_count+1;
      insert into public.settlement_reconciliation_results
        (run_id,import_id,row_id,result_status,result_code,journal_batch_id,reconciled_by)
      values(new_run_id,p_import_id,row_value.row_id,'matched',result_code_value,candidate_batch_id,p_reconciled_by);
    else
      exception_count := exception_count+1;
      insert into public.settlement_reconciliation_results
        (run_id,import_id,row_id,result_status,result_code,journal_batch_id,reconciled_by)
      values(new_run_id,p_import_id,row_value.row_id,'exception',result_code_value,null,p_reconciled_by);
    end if;
  end loop;
  update public.settlement_reconciliation_runs
  set matched_rows=matched_count,exception_rows=exception_count where id=new_run_id;
  return new_run_id;
end;
$function$;

comment on function public.reconcile_settlement_import(uuid, uuid) is
  'Idempotent independent reconciliation. Payment/refund rows match immutable posted journals; fee rows post a balanced sandbox-only provider-fee journal after independently linked evidence. Live provider settlement, payout, and money movement remain disabled.';
