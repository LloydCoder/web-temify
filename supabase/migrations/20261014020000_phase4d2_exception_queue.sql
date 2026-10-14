-- Phase 4D2: bounded, read-only administrative exception queue.
-- This exposes only normalized exception fields. It never resolves exceptions or posts money.
create function public.list_settlement_exception_queue(
  p_admin_id uuid,
  p_limit integer default 51,
  p_before_created_at timestamptz default null,
  p_before_run_id uuid default null,
  p_before_row_id text default null
)
returns table (
  run_id uuid,
  row_id text,
  result_code text,
  result_created_at timestamptz,
  provider text,
  report_reference text,
  report_period_start date,
  report_period_end date,
  report_timezone text,
  currency text,
  row_type text,
  provider_reference text,
  payment_reference text,
  gross_minor text,
  fee_minor text,
  net_minor text,
  triage_decision text,
  triage_reason text,
  triage_created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_admin_id is null or not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_admin_id
      and ur.role = 'admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'settlement exception queue requires an admin';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 51 then
    raise exception using errcode = '23514', message = 'settlement exception queue limit is outside the allowed range';
  end if;

  if (p_before_created_at is null or p_before_run_id is null or p_before_row_id is null)
    and not (p_before_created_at is null and p_before_run_id is null and p_before_row_id is null)
  then
    raise exception using errcode = '23514', message = 'settlement exception cursor is incomplete';
  end if;

  if p_before_row_id is not null
    and char_length(p_before_row_id) not between 1 and 240
  then
    raise exception using errcode = '23514', message = 'settlement exception cursor row identifier is outside the allowed range';
  end if;

  return query
  select
    rr.run_id,
    rr.row_id,
    rr.result_code,
    rr.created_at,
    si.provider,
    si.report_reference,
    si.report_period_start,
    si.report_period_end,
    si.report_timezone,
    sir.currency,
    sir.row_type,
    sir.provider_reference,
    sir.payment_reference,
    sir.gross_minor::text,
    sir.fee_minor::text,
    sir.net_minor::text,
    sed.decision,
    sed.reason,
    sed.created_at
  from public.settlement_reconciliation_results rr
  join public.settlement_import_rows sir
    on sir.import_id = rr.import_id and sir.row_id = rr.row_id
  join public.settlement_imports si
    on si.id = rr.import_id
  left join public.settlement_exception_decisions sed
    on sed.run_id = rr.run_id and sed.row_id = rr.row_id
  where rr.result_status = 'exception'
    and (
      p_before_created_at is null
      or (rr.created_at, rr.run_id, rr.row_id)
        < (p_before_created_at, p_before_run_id, p_before_row_id)
    )
  order by rr.created_at desc, rr.run_id desc, rr.row_id desc
  limit p_limit;
end;
$function$;

revoke all on function public.list_settlement_exception_queue(uuid, integer, timestamptz, uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function public.list_settlement_exception_queue(uuid, integer, timestamptz, uuid, text)
  to service_role;

comment on function public.list_settlement_exception_queue(uuid, integer, timestamptz, uuid, text) is
  'Bounded read-only admin view of immutable settlement exceptions and triage metadata. Decisions never resolve exceptions or authorize financial posting.';
