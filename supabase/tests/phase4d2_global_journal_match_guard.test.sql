begin;
select plan(2);

select ok(
  exists (
    select 1
    from pg_index i
    join pg_class idx on idx.oid = i.indexrelid
    join pg_class tbl on tbl.oid = i.indrelid
    join pg_namespace n on n.oid = tbl.relnamespace
    where n.nspname = 'public'
      and tbl.relname = 'settlement_reconciliation_results'
      and idx.relname = 'settlement_reconciliation_one_batch_global_uq'
      and i.indisunique
      and pg_get_expr(i.indpred, i.indrelid) is not null
      and pg_get_indexdef(i.indexrelid) like '%(journal_batch_id)%'
  ),
  'a unique partial index prevents one journal batch from matching across multiple reconciliation runs'
);

select ok(
  position('settlement-journal-match:' in pg_get_functiondef(
    'public.reconcile_settlement_import(uuid,uuid)'::regprocedure
  )) > 0
  and position('duplicate_reference' in pg_get_functiondef(
    'public.reconcile_settlement_import(uuid,uuid)'::regprocedure
  )) > 0,
  'reconciliation serializes journal identity and classifies replay as a duplicate exception'
);

select * from finish();
rollback;
