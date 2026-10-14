-- Phase 4D2: classify cross-import and concurrent duplicate journal matches.
-- The global unique index is the final integrity backstop. This BEFORE INSERT
-- trigger converts a replay into an immutable exception instead of aborting the
-- entire reconciliation transaction. A transaction-scoped advisory lock makes
-- the check and insert serial with respect to the same journal batch.
create function public.classify_duplicate_settlement_journal_match()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.result_status = 'matched' and new.journal_batch_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'settlement-journal-match:' || new.journal_batch_id::text,
        0
      )
    );

    if exists (
      select 1
      from public.settlement_reconciliation_results prior
      where prior.journal_batch_id = new.journal_batch_id
        and prior.result_status = 'matched'
    ) then
      new.result_status := 'exception';
      new.result_code := 'duplicate_reference';
      new.journal_batch_id := null;
    end if;
  end if;

  return new;
end;
$function$;

revoke all on function public.classify_duplicate_settlement_journal_match()
  from public, anon, authenticated, service_role;

create trigger settlement_reconciliation_duplicate_match_guard
before insert on public.settlement_reconciliation_results
for each row execute function public.classify_duplicate_settlement_journal_match();

comment on function public.classify_duplicate_settlement_journal_match() is
  'Serializes matching by journal batch and classifies cross-import replays as immutable duplicate_reference exceptions; the global unique index remains the final integrity guard.';
