-- Phase 4D2 integrity guard: a posted financial journal batch may be reconciled
-- to at most one imported settlement row across the entire history, not merely
-- once per reconciliation run. This prevents replaying the same financial event
-- through a second report identity from appearing as a second successful match.
--
-- Fail closed if existing evidence already violates the invariant; do not silently
-- delete or rewrite immutable reconciliation evidence to make the index apply.
do $migration$
begin
  if exists (
    select 1
    from public.settlement_reconciliation_results
    where journal_batch_id is not null
    group by journal_batch_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23514',
      message = 'duplicate historical settlement journal matches require forensic review before migration';
  end if;
end;
$migration$;

drop index if exists public.settlement_reconciliation_one_row_per_batch_uq;

create unique index settlement_reconciliation_one_batch_global_uq
  on public.settlement_reconciliation_results (journal_batch_id)
  where journal_batch_id is not null;

comment on index public.settlement_reconciliation_one_batch_global_uq is
  'A posted financial journal batch can be matched to at most one settlement import row across all reconciliation runs; duplicate evidence must be classified, not double-counted.';
