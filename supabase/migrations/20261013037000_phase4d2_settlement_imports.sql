-- Phase 4D2 (slice): immutable settlement report import evidence.
-- This migration persists normalized reports only. It does not reconcile rows,
-- post settlement/fee journals, initiate payouts, or enable live providers.

create table public.settlement_imports (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('paystack', 'polar', 'sandbox')),
  provider_account_reference text not null check (char_length(provider_account_reference) between 1 and 240),
  report_reference text not null check (char_length(report_reference) between 1 and 240),
  report_period_start date not null,
  report_period_end date not null,
  report_timezone text not null check (char_length(report_timezone) between 1 and 100),
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  source_authentication_method text not null check (
    source_authentication_method in ('provider_api_signature', 'authenticated_report_download', 'sandbox_fixture')
  ),
  source_authentication_asserted_at timestamptz not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  imported_by uuid not null references auth.users(id) on delete restrict,
  imported_at timestamptz not null default now(),
  constraint settlement_import_period_valid check (report_period_end >= report_period_start),
  constraint settlement_import_identity_unique unique (provider, provider_account_reference, report_reference),
  constraint settlement_import_digest_unique unique (provider, provider_account_reference, source_sha256)
);

create table public.settlement_import_rows (
  import_id uuid not null references public.settlement_imports(id) on delete restrict,
  row_id text not null check (char_length(row_id) between 1 and 240),
  row_type text not null check (row_type in ('payment', 'refund', 'fee', 'payout', 'adjustment')),
  provider_reference text check (provider_reference is null or char_length(provider_reference) between 1 and 240),
  payment_reference text check (payment_reference is null or char_length(payment_reference) between 1 and 240),
  occurred_at timestamptz not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  gross_minor bigint not null,
  fee_minor bigint not null check (fee_minor >= 0),
  net_minor bigint not null,
  exception_code text check (exception_code is null or exception_code in (
    'missing_internal_match', 'duplicate_reference', 'amount_mismatch',
    'currency_mismatch', 'period_mismatch', 'unsupported_row_type', 'unexplained_adjustment'
  )),
  created_at timestamptz not null default now(),
  primary key (import_id, row_id),
  constraint settlement_row_payment_sign check (row_type <> 'payment' or gross_minor > 0),
  constraint settlement_row_refund_sign check (row_type <> 'refund' or gross_minor < 0),
  constraint settlement_row_fee_sign check (row_type <> 'fee' or net_minor < 0)
);

create index settlement_imports_period_idx
  on public.settlement_imports (provider, report_period_start, report_period_end);
create index settlement_import_rows_provider_ref_idx
  on public.settlement_import_rows (provider_reference)
  where provider_reference is not null;
create index settlement_import_rows_payment_ref_idx
  on public.settlement_import_rows (payment_reference)
  where payment_reference is not null;

alter table public.settlement_imports enable row level security;
alter table public.settlement_import_rows enable row level security;
revoke all on public.settlement_imports from public, anon, authenticated, service_role;
revoke all on public.settlement_import_rows from public, anon, authenticated, service_role;

create function public.reject_settlement_evidence_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'settlement import evidence is immutable';
end;
$function$;
revoke all on function public.reject_settlement_evidence_mutation() from public, anon, authenticated, service_role;

create trigger settlement_imports_immutable
before update or delete on public.settlement_imports
for each row execute function public.reject_settlement_evidence_mutation();
create trigger settlement_import_rows_immutable
before update or delete on public.settlement_import_rows
for each row execute function public.reject_settlement_evidence_mutation();

create function public.import_settlement_report(
  p_provider text,
  p_provider_account_reference text,
  p_report_reference text,
  p_report_period_start date,
  p_report_period_end date,
  p_report_timezone text,
  p_source_sha256 text,
  p_source_authenticated boolean,
  p_source_authentication_method text,
  p_currency text,
  p_imported_by uuid,
  p_rows jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  existing_import public.settlement_imports%rowtype;
  new_import_id uuid;
  row_value jsonb;
  row_id_value text;
  row_type_value text;
  provider_reference_value text;
  payment_reference_value text;
  occurred_at_value timestamptz;
  currency_value text;
  gross_minor_value bigint;
  fee_minor_value bigint;
  net_minor_value bigint;
  exception_code_value text;
begin
  if p_provider is null
    or p_provider not in ('paystack', 'polar', 'sandbox')
    or p_provider_account_reference is null
    or char_length(p_provider_account_reference) not between 1 and 240
    or p_report_reference is null
    or char_length(p_report_reference) not between 1 and 240
    or p_report_period_start is null
    or p_report_period_end is null
    or p_report_period_end < p_report_period_start
    or p_report_timezone is null
    or char_length(p_report_timezone) not between 1 and 100
    or p_source_sha256 is null
    or p_source_sha256 !~ '^[a-f0-9]{64}$'
    or p_source_authenticated is distinct from true
    or p_source_authentication_method is null
    or p_source_authentication_method not in ('provider_api_signature', 'authenticated_report_download', 'sandbox_fixture')
    or p_currency is null
    or p_currency !~ '^[A-Z]{3}$'
    or p_imported_by is null
  then
    raise exception using errcode = '23514', message = 'settlement report metadata failed validation';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_imported_by
      and ur.role in ('admin'::public.app_role, 'moderator'::public.app_role)
  ) then
    raise exception using errcode = '42501', message = 'settlement import requires an authorized operations actor';
  end if;

  if jsonb_typeof(p_rows) is distinct from 'array'
    or jsonb_array_length(p_rows) < 1
    or jsonb_array_length(p_rows) > 100000
  then
    raise exception using errcode = '23514', message = 'settlement report rows must be a bounded non-empty array';
  end if;

  -- Serialize same-report imports so idempotency remains deterministic under concurrency.
  perform pg_advisory_xact_lock(hashtext(
    p_provider || ':' || p_provider_account_reference || ':' || p_report_reference
  ));

  select * into existing_import
  from public.settlement_imports
  where provider = p_provider
    and provider_account_reference = p_provider_account_reference
    and report_reference = p_report_reference;

  if existing_import.id is not null then
    if existing_import.source_sha256 = p_source_sha256
      and existing_import.currency = p_currency
      and existing_import.report_period_start = p_report_period_start
      and existing_import.report_period_end = p_report_period_end
      and existing_import.report_timezone = p_report_timezone
      and existing_import.source_authentication_method = p_source_authentication_method
    then
      if (
        select count(*) from public.settlement_import_rows
        where import_id = existing_import.id
      ) <> jsonb_array_length(p_rows)
      or exists (
        select 1
        from jsonb_to_recordset(p_rows) as incoming(
          "rowId" text,
          "rowType" text,
          "providerReference" text,
          "paymentReference" text,
          "occurredAt" timestamptz,
          currency text,
          "grossMinor" bigint,
          "feeMinor" bigint,
          "netMinor" bigint,
          "exceptionCode" text
        )
        left join public.settlement_import_rows stored
          on stored.import_id = existing_import.id
         and stored.row_id = incoming."rowId"
        where stored.row_id is null
          or stored.row_type is distinct from incoming."rowType"
          or stored.provider_reference is distinct from nullif(incoming."providerReference", '')
          or stored.payment_reference is distinct from nullif(incoming."paymentReference", '')
          or stored.occurred_at is distinct from incoming."occurredAt"
          or stored.currency is distinct from incoming.currency
          or stored.gross_minor is distinct from incoming."grossMinor"
          or stored.fee_minor is distinct from incoming."feeMinor"
          or stored.net_minor is distinct from incoming."netMinor"
          or stored.exception_code is distinct from nullif(incoming."exceptionCode", '')
      ) then
        raise exception using errcode = '23514', message = 'settlement report identity already exists with conflicting evidence';
      end if;
      return existing_import.id;
    end if;
    raise exception using errcode = '23514', message = 'settlement report identity already exists with conflicting evidence';
  end if;

  if exists (
    select 1 from public.settlement_imports
    where provider = p_provider
      and provider_account_reference = p_provider_account_reference
      and source_sha256 = p_source_sha256
  ) then
    raise exception using errcode = '23514', message = 'settlement source digest is already bound to another report identity';
  end if;

  insert into public.settlement_imports (
    provider, provider_account_reference, report_reference,
    report_period_start, report_period_end, report_timezone,
    source_sha256, source_authentication_method, source_authentication_asserted_at,
    currency, imported_by
  ) values (
    p_provider, p_provider_account_reference, p_report_reference,
    p_report_period_start, p_report_period_end, p_report_timezone,
    p_source_sha256, p_source_authentication_method, now(),
    p_currency, p_imported_by
  ) returning id into new_import_id;

  for row_value in select value from jsonb_array_elements(p_rows)
  loop
    if jsonb_typeof(row_value) is distinct from 'object'
      or row_value - array[
        'rowId', 'rowType', 'providerReference', 'paymentReference',
        'occurredAt', 'currency', 'grossMinor', 'feeMinor', 'netMinor', 'exceptionCode'
      ] <> '{}'::jsonb
      or not (row_value ?& array[
        'rowId', 'rowType', 'occurredAt', 'currency',
        'grossMinor', 'feeMinor', 'netMinor'
      ])
    then
      raise exception using errcode = '23514', message = 'settlement row has unknown or missing fields';
    end if;

    row_id_value := row_value ->> 'rowId';
    row_type_value := row_value ->> 'rowType';
    provider_reference_value := nullif(row_value ->> 'providerReference', '');
    payment_reference_value := nullif(row_value ->> 'paymentReference', '');
    occurred_at_value := (row_value ->> 'occurredAt')::timestamptz;
    currency_value := row_value ->> 'currency';
    gross_minor_value := (row_value ->> 'grossMinor')::bigint;
    fee_minor_value := (row_value ->> 'feeMinor')::bigint;
    net_minor_value := (row_value ->> 'netMinor')::bigint;
    exception_code_value := nullif(row_value ->> 'exceptionCode', '');

    if row_id_value is null or char_length(row_id_value) not between 1 and 240
      or row_type_value not in ('payment', 'refund', 'fee', 'payout', 'adjustment')
      or occurred_at_value is null
      or currency_value is distinct from p_currency
      or fee_minor_value < 0
      or (row_type_value = 'payment' and gross_minor_value <= 0)
      or (row_type_value = 'refund' and gross_minor_value >= 0)
      or (row_type_value = 'fee' and net_minor_value >= 0)
      or (occurred_at_value at time zone p_report_timezone)::date < p_report_period_start
      or (occurred_at_value at time zone p_report_timezone)::date > p_report_period_end
      or (exception_code_value is not null and exception_code_value not in (
        'missing_internal_match', 'duplicate_reference', 'amount_mismatch',
        'currency_mismatch', 'period_mismatch', 'unsupported_row_type', 'unexplained_adjustment'
      ))
    then
      raise exception using errcode = '23514', message = 'settlement row failed period, currency, type, amount, or exception validation';
    end if;

    insert into public.settlement_import_rows (
      import_id, row_id, row_type, provider_reference, payment_reference,
      occurred_at, currency, gross_minor, fee_minor, net_minor, exception_code
    ) values (
      new_import_id, row_id_value, row_type_value, provider_reference_value, payment_reference_value,
      occurred_at_value, currency_value, gross_minor_value, fee_minor_value, net_minor_value, exception_code_value
    );
  end loop;

  return new_import_id;
end;
$function$;
revoke all on function public.import_settlement_report(
  text, text, text, date, date, text, text, boolean, text, text, uuid, jsonb
) from public, anon, authenticated;
grant execute on function public.import_settlement_report(
  text, text, text, date, date, text, text, boolean, text, text, uuid, jsonb
) to service_role;

comment on table public.settlement_imports is
  'Immutable settlement source/report metadata. Import is not reconciliation or journal posting.';
comment on table public.settlement_import_rows is
  'Immutable normalized settlement rows. Matching, exceptions, and journal posting require later reviewed Phase 4D2 gates.';
comment on function public.import_settlement_report(
  text, text, text, date, date, text, text, boolean, text, text, uuid, jsonb
) is
  'Service-only, idempotent import of normalized settlement evidence. source_authenticated is a trusted-ingress assertion, not cryptographic verification by this function.';


-- Phase 4D2 (slice 2): immutable reconciliation outcomes against posted journal batches.
-- This records matches/exceptions only; provider-settlement and provider-fee posting remain fail-closed.
create table public.settlement_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  import_id uuid not null unique references public.settlement_imports(id) on delete restrict,
  reconciled_by uuid not null references auth.users(id) on delete restrict,
  matched_rows integer not null check (matched_rows >= 0),
  exception_rows integer not null check (exception_rows >= 0),
  created_at timestamptz not null default now()
);

create table public.settlement_reconciliation_results (
  run_id uuid not null references public.settlement_reconciliation_runs(id) on delete restrict,
  import_id uuid not null,
  row_id text not null,
  result_status text not null check (result_status in ('matched', 'exception')),
  result_code text not null check (result_code in (
    'matched_payment', 'matched_refund', 'missing_internal_match',
    'duplicate_reference', 'amount_mismatch', 'currency_mismatch',
    'unsupported_row_type'
  )),
  journal_batch_id uuid references public.financial_journal_batches(id) on delete restrict,
  reconciled_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (run_id, row_id),
  foreign key (import_id, row_id)
    references public.settlement_import_rows(import_id, row_id) on delete restrict,
  constraint settlement_reconciliation_result_shape check (
    (result_status = 'matched' and result_code in ('matched_payment', 'matched_refund') and journal_batch_id is not null)
    or (result_status = 'exception' and result_code not in ('matched_payment', 'matched_refund') and journal_batch_id is null)
  )
);

create unique index settlement_reconciliation_one_row_per_batch_uq
  on public.settlement_reconciliation_results (run_id, journal_batch_id)
  where journal_batch_id is not null;

alter table public.settlement_reconciliation_runs enable row level security;
alter table public.settlement_reconciliation_results enable row level security;
revoke all on public.settlement_reconciliation_runs from public, anon, authenticated, service_role;
revoke all on public.settlement_reconciliation_results from public, anon, authenticated, service_role;

create function public.reject_settlement_reconciliation_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  -- A run is inserted as a zero-count placeholder so result rows can reference it.
  -- Permit exactly one final count update; all result rows are written in the same transaction.
  if tg_table_name = 'settlement_reconciliation_runs' and tg_op = 'UPDATE' then
    if old.matched_rows = 0
      and old.exception_rows = 0
      and new.id is not distinct from old.id
      and new.import_id is not distinct from old.import_id
      and new.reconciled_by is not distinct from old.reconciled_by
      and new.created_at is not distinct from old.created_at
      and new.matched_rows >= 0
      and new.exception_rows >= 0
      and new.matched_rows + new.exception_rows > 0
    then
      return new;
    end if;
  end if;

  raise exception using errcode = '55000', message = 'settlement reconciliation evidence is immutable';
end;
$function$;
revoke all on function public.reject_settlement_reconciliation_mutation() from public, anon, authenticated, service_role;

create trigger settlement_reconciliation_runs_immutable
before update or delete on public.settlement_reconciliation_runs
for each row execute function public.reject_settlement_reconciliation_mutation();
create trigger settlement_reconciliation_results_immutable
before update or delete on public.settlement_reconciliation_results
for each row execute function public.reject_settlement_reconciliation_mutation();

create function public.reconcile_settlement_import(
  p_import_id uuid,
  p_reconciled_by uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  import_row public.settlement_imports%rowtype;
  existing_run public.settlement_reconciliation_runs%rowtype;
  new_run_id uuid;
  row_value record;
  candidate_count bigint;
  candidate_batch_id uuid;
  candidate_amount numeric;
  result_code_value text;
  matched_count integer := 0;
  exception_count integer := 0;
begin
  if p_import_id is null or p_reconciled_by is null then
    raise exception using errcode = '23514', message = 'settlement reconciliation metadata failed validation';
  end if;

  select * into import_row
  from public.settlement_imports
  where id = p_import_id;
  if import_row.id is null then
    raise exception using errcode = 'P0002', message = 'settlement import was not found';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_reconciled_by
      and ur.role = 'admin'::public.app_role
  ) or p_reconciled_by = import_row.imported_by then
    raise exception using errcode = '42501', message = 'settlement reconciliation requires a distinct admin reviewer';
  end if;

  perform pg_advisory_xact_lock(hashtext('settlement-reconcile:' || p_import_id::text));

  select * into existing_run
  from public.settlement_reconciliation_runs
  where import_id = p_import_id;
  if existing_run.id is not null then
    return existing_run.id;
  end if;

  insert into public.settlement_reconciliation_runs (
    import_id, reconciled_by, matched_rows, exception_rows
  ) values (p_import_id, p_reconciled_by, 0, 0)
  returning id into new_run_id;

  for row_value in
    select * from public.settlement_import_rows
    where import_id = p_import_id
    order by row_id
  loop
    candidate_batch_id := null;
    candidate_amount := null;
    candidate_count := 0;
    result_code_value := null;

    if row_value.row_type not in ('payment', 'refund') then
      result_code_value := 'unsupported_row_type';
    elsif row_value.provider_reference is null then
      result_code_value := 'missing_internal_match';
    else
      select count(*) into candidate_count
      from public.financial_journal_batches b
      where b.provider = import_row.provider
        and b.provider_reference = row_value.provider_reference
        and b.currency = row_value.currency
        and b.status = 'posted'
        and b.source_type = case when row_value.row_type = 'payment' then 'payment' else 'refund' end;

      if candidate_count = 0 then
        result_code_value := 'missing_internal_match';
      elsif candidate_count > 1 then
        result_code_value := 'duplicate_reference';
      else
        select b.id,
               (select coalesce(sum(e.amount_minor), 0)
                from public.financial_journal_entries e
                where e.batch_id = b.id and e.side = 'debit')
          into candidate_batch_id, candidate_amount
        from public.financial_journal_batches b
        where b.provider = import_row.provider
          and b.provider_reference = row_value.provider_reference
          and b.currency = row_value.currency
          and b.status = 'posted'
          and b.source_type = case when row_value.row_type = 'payment' then 'payment' else 'refund' end
        limit 1;

        if exists (
          select 1 from public.settlement_reconciliation_results prior
          where prior.run_id = new_run_id
            and prior.journal_batch_id = candidate_batch_id
        ) then
          result_code_value := 'duplicate_reference';
          candidate_batch_id := null;
        elsif candidate_amount <> abs(row_value.gross_minor) then
          result_code_value := 'amount_mismatch';
          candidate_batch_id := null;
        elsif row_value.row_type = 'payment' and row_value.net_minor <> row_value.gross_minor - row_value.fee_minor then
          result_code_value := 'amount_mismatch';
          candidate_batch_id := null;
        else
          result_code_value := case when row_value.row_type = 'payment'
            then 'matched_payment' else 'matched_refund' end;
        end if;
      end if;
    end if;

    if result_code_value in ('matched_payment', 'matched_refund') then
      matched_count := matched_count + 1;
      insert into public.settlement_reconciliation_results (
        run_id, import_id, row_id, result_status, result_code,
        journal_batch_id, reconciled_by
      ) values (
        new_run_id, p_import_id, row_value.row_id, 'matched', result_code_value,
        candidate_batch_id, p_reconciled_by
      );
    else
      exception_count := exception_count + 1;
      insert into public.settlement_reconciliation_results (
        run_id, import_id, row_id, result_status, result_code,
        journal_batch_id, reconciled_by
      ) values (
        new_run_id, p_import_id, row_value.row_id, 'exception', result_code_value,
        null, p_reconciled_by
      );
    end if;
  end loop;

  update public.settlement_reconciliation_runs
  set matched_rows = matched_count, exception_rows = exception_count
  where id = new_run_id;

  return new_run_id;
end;
$function$;
revoke all on function public.reconcile_settlement_import(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reconcile_settlement_import(uuid, uuid) to service_role;

comment on table public.settlement_reconciliation_runs is
  'Immutable, one-time reconciliation snapshot for imported settlement evidence; does not post money.';
comment on table public.settlement_reconciliation_results is
  'Immutable row-level matches and exceptions against already-posted payment/refund journal batches.';
comment on function public.reconcile_settlement_import(uuid, uuid) is
  'Service-only one-time reconciliation of payment/refund rows to posted journal batches. Provider settlement/fee posting and exception resolution remain disabled.';
