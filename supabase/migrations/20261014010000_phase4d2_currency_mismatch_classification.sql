-- Phase 4D2 follow-up: classify a unique cross-currency reference as a currency mismatch.
-- This changes exception classification only. It never posts journals or moves funds.
create or replace function public.reconcile_settlement_import(
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
      -- Count every posted batch with this provider reference before filtering by
      -- currency. Otherwise a cross-currency reference collision is misreported
      -- as a missing match and can hide a material reconciliation exception.
      select count(*) into candidate_count
      from public.financial_journal_batches b
      where b.provider = import_row.provider
        and b.provider_reference = row_value.provider_reference
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

        if candidate_batch_id is null then
          result_code_value := 'currency_mismatch';
        elsif exists (
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
