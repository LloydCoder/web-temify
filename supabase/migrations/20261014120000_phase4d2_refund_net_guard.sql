-- Phase 4D2: validate settlement net arithmetic for both payments and refunds.
-- Provider fees are part of the report reconciliation contract; a refund cannot
-- match an internal refund journal if its reported net does not equal gross minus fees.
-- Preserve cross-currency exception semantics while classifying cross-import replay.
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

    if result_code_value in ('matched_payment','matched_refund') then
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
revoke all on function public.reconcile_settlement_import(uuid,uuid) from public,anon,authenticated;
grant execute on function public.reconcile_settlement_import(uuid,uuid) to service_role;
comment on function public.reconcile_settlement_import(uuid,uuid) is
  'Service-only reconciliation. Cross-import and concurrent duplicate matches become immutable duplicate_reference exceptions; cross-currency collisions remain explicit; no settlement/fee posting or money movement.';
