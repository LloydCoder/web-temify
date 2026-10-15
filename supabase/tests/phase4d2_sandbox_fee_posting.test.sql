begin;
select plan(34);

select has_table('public', 'settlement_journal_postings', 'settlement journal posting evidence table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_journal_postings'::regclass),
  'settlement journal posting evidence has RLS enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.settlement_journal_postings', 'SELECT'),
  'authenticated clients cannot read settlement journal posting evidence'
);
select ok(
  not has_table_privilege('service_role', 'public.settlement_journal_postings', 'INSERT'),
  'service role must use the posting RPC instead of inserting posting evidence directly'
);
select ok(
  has_function_privilege('service_role', 'public.post_sandbox_settlement_fee_row(uuid,text,uuid,uuid)', 'EXECUTE'),
  'service role can execute the sandbox fee posting function'
);
select ok(
  not has_function_privilege('authenticated', 'public.post_sandbox_settlement_fee_row(uuid,text,uuid,uuid)', 'EXECUTE'),
  'authenticated clients cannot execute the sandbox fee posting function'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('89000000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'fee-importer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89200000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'fee-uploader@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89300000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'fee-linker@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89400000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'fee-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values
  ('89000000-0000-4000-8000-000000000089', 'admin'::public.app_role),
  ('89200000-0000-4000-8000-000000000089', 'admin'::public.app_role),
  ('89300000-0000-4000-8000-000000000089', 'admin'::public.app_role),
  ('89400000-0000-4000-8000-000000000089', 'admin'::public.app_role)
on conflict do nothing;

create temporary table phase4d2_fee_imports (
  label text primary key,
  import_id uuid not null
) on commit drop;
create temporary table phase4d2_fee_runs (
  label text primary key,
  run_id uuid not null
) on commit drop;

select lives_ok(
  $sql$
    insert into phase4d2_fee_imports
    select 'verified', public.import_settlement_report(
      'sandbox', 'sandbox-fee-account', 'fee-report-verified',
      '2026-10-13', '2026-10-13', 'UTC', repeat('a',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','fee-row-01', 'rowType','fee',
        'providerReference','fee-provider-reference-01',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',0, 'feeMinor',300, 'netMinor',-300
      ))
    )
  $sql$,
  'valid sandbox fee row imports with exact minor-unit arithmetic'
);

select lives_ok(
  $sql$
    select public.record_settlement_evidence(
      '8b000000-0000-4000-8000-00000000008b',
      '8b000000-0000-4000-8000-00000000008b/' || repeat('a',64),
      repeat('a',64), 'text/csv', 4, 'fee-report.csv',
      '89200000-0000-4000-8000-000000000089', gen_random_uuid()
    )
  $sql$,
  'private evidence metadata can be recorded by an admin uploader'
);

select public.record_settlement_evidence_scan_result(
  '8b000000-0000-4000-8000-00000000008b',
  repeat('a',64), 'clean', 'test-scanner', '1.0.0', now(), gen_random_uuid()
);

select lives_ok(
  $sql$
    select public.link_settlement_evidence(
      '8b000000-0000-4000-8000-00000000008b',
      (select import_id from phase4d2_fee_imports where label = 'verified'),
      '89300000-0000-4000-8000-000000000089', gen_random_uuid()
    )
  $sql$,
  'a distinct admin links evidence whose digest matches the imported report'
);

select lives_ok(
  $sql$
    insert into phase4d2_fee_runs
    select 'verified', public.reconcile_settlement_import(
      (select import_id from phase4d2_fee_imports where label = 'verified'),
      '89400000-0000-4000-8000-000000000089'
    )
  $sql$,
  'independent reconciliation posts a verified sandbox fee row atomically'
);

select is(
  (select result_code from public.settlement_reconciliation_results
   where import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
     and row_id = 'fee-row-01'),
  'matched_fee',
  'fee row reconciles to a dedicated provider-fee journal batch'
);
select is(
  (select matched_rows from public.settlement_reconciliation_runs
   where id = (select run_id from phase4d2_fee_runs where label = 'verified')),
  1,
  'the fee posting is included in the immutable matched-row count'
);
select is(
  (select exception_rows from public.settlement_reconciliation_runs
   where id = (select run_id from phase4d2_fee_runs where label = 'verified')),
  0,
  'a valid fee posting does not leave an unsupported-row exception'
);
select is(
  (select b.status from public.financial_journal_batches b
   join public.settlement_journal_postings p on p.journal_batch_id = b.id
   where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
     and p.row_id = 'fee-row-01'),
  'posted',
  'the fee journal is posted only after the posting-evidence link exists'
);
select is(
  (select sum(e.amount_minor) from public.financial_journal_entries e
   join public.settlement_journal_postings p on p.journal_batch_id = e.batch_id
   where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
     and e.side = 'debit'),
  300::numeric,
  'the fee journal debits provider fee expense for the exact fee amount'
);
select is(
  (select sum(e.amount_minor) from public.financial_journal_entries e
   join public.settlement_journal_postings p on p.journal_batch_id = e.batch_id
   where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
     and e.side = 'credit'),
  300::numeric,
  'the fee journal credits provider clearing for the same amount'
);
select ok(
  exists (
    select 1 from public.financial_journal_entries e
    join public.settlement_journal_postings p on p.journal_batch_id = e.batch_id
    where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
      and e.account = 'provider_fee_expense' and e.side = 'debit' and e.amount_minor = 300
  )
  and exists (
    select 1 from public.financial_journal_entries e
    join public.settlement_journal_postings p on p.journal_batch_id = e.batch_id
    where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
      and e.account = 'provider_clearing' and e.side = 'credit' and e.amount_minor = 300
  ),
  'the posted batch uses only the approved fee-expense and provider-clearing accounts'
);
select ok(
  exists (
    select 1 from public.settlement_journal_postings p
    join public.settlement_imports i on i.id = p.import_id
    where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
      and p.evidence_sha256 = i.source_sha256
      and p.posted_by = '89400000-0000-4000-8000-000000000089'
  ),
  'the journal posting preserves report digest and independent reviewer identity'
);
select ok(
  exists (
    select 1 from public.audit_events ae
    join public.settlement_journal_postings p on p.journal_batch_id::text = ae.entity_id
    where p.import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
      and ae.action = 'settlement.provider_fee.posted'
      and ae.request_id = p.reconciliation_run_id::text
  ),
  'fee posting and its correlated audit event are committed together'
);
select is(
  (select count(*) from public.settlement_journal_postings
   where import_id = (select import_id from phase4d2_fee_imports where label = 'verified')),
  1::bigint,
  'exactly one immutable posting record exists for the fee row'
);
select is(
  public.reconcile_settlement_import(
    (select import_id from phase4d2_fee_imports where label = 'verified'),
    '89400000-0000-4000-8000-000000000089'
  ),
  (select run_id from phase4d2_fee_runs where label = 'verified'),
  'reconciliation replay returns the original run without duplicating the journal'
);
select throws_ok(
  $sql$
    update public.settlement_journal_postings
    set row_id = 'mutated-row'
    where import_id = (select import_id from phase4d2_fee_imports where label = 'verified')
  $sql$,
  '55000', 'settlement journal posting evidence is immutable',
  'posting evidence cannot be updated after commit'
);

select lives_ok(
  $sql$
    insert into phase4d2_fee_imports
    select 'missing-evidence', public.import_settlement_report(
      'sandbox', 'sandbox-fee-account', 'fee-report-missing-evidence',
      '2026-10-13', '2026-10-13', 'UTC', repeat('b',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','fee-row-02', 'rowType','fee',
        'providerReference','fee-provider-reference-02',
        'occurredAt','2026-10-13T11:00:00Z', 'currency','USD',
        'grossMinor',0, 'feeMinor',250, 'netMinor',-250
      ))
    )
  $sql$,
  'a second valid fee report can be imported before evidence is linked'
);
select throws_ok(
  $sql$
    select public.reconcile_settlement_import(
      (select import_id from phase4d2_fee_imports where label = 'missing-evidence'),
      '89400000-0000-4000-8000-000000000089'
    )
  $sql$,
  '23514', 'settlement fee posting requires independently linked evidence with matching source digest',
  'fee reconciliation fails closed when the private evidence is not linked'
);
select is(
  (select count(*) from public.settlement_reconciliation_runs
   where import_id = (select import_id from phase4d2_fee_imports where label = 'missing-evidence')),
  0::bigint,
  'failed evidence validation rolls back the reconciliation run'
);
select is(
  (select count(*) from public.settlement_journal_postings
   where import_id = (select import_id from phase4d2_fee_imports where label = 'missing-evidence')),
  0::bigint,
  'failed evidence validation creates no journal posting'
);
select throws_ok(
  $sql$
    select public.import_settlement_report(
      'sandbox', 'sandbox-fee-account', 'fee-report-invalid-arithmetic',
      '2026-10-13', '2026-10-13', 'UTC', repeat('c',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','bad-fee-row', 'rowType','fee',
        'providerReference','bad-fee-provider-reference',
        'occurredAt','2026-10-13T12:00:00Z', 'currency','USD',
        'grossMinor',100, 'feeMinor',300, 'netMinor',-300
      ))
    )
  $sql$,
  '23514', null,
  'fee rows with gross or net arithmetic inconsistent with the fee amount are rejected'
);

select lives_ok(
  $sql$
    select public.record_settlement_evidence(
      '8c000000-0000-4000-8000-00000000008c',
      '8c000000-0000-4000-8000-00000000008c/' || repeat('b',64),
      repeat('b',64), 'text/csv', 4, 'fee-report-02.csv',
      '89200000-0000-4000-8000-000000000089', gen_random_uuid()
    )
  $sql$,
  'evidence can be uploaded for the previously blocked fee report'
);

select public.record_settlement_evidence_scan_result(
  '8c000000-0000-4000-8000-00000000008c',
  repeat('b',64), 'clean', 'test-scanner', '1.0.0', gen_random_uuid()
);
select lives_ok(
  $sql$
    select public.link_settlement_evidence(
      '8c000000-0000-4000-8000-00000000008c',
      (select import_id from phase4d2_fee_imports where label = 'missing-evidence'),
      '89300000-0000-4000-8000-000000000089', gen_random_uuid()
    )
  $sql$,
  'a distinct reviewer can link the second report evidence after the initial failure'
);
select throws_ok(
  $sql$
    select public.reconcile_settlement_import(
      (select import_id from phase4d2_fee_imports where label = 'missing-evidence'),
      '89200000-0000-4000-8000-000000000089'
    )
  $sql$,
  '42501', 'settlement fee posting requires a reviewer independent of import, upload, and evidence linking',
  'the evidence uploader cannot also approve the fee journal'
);
select is(
  (select count(*) from public.settlement_reconciliation_runs
   where import_id = (select import_id from phase4d2_fee_imports where label = 'missing-evidence')),
  0::bigint,
  'a rejected reviewer attempt leaves no partial reconciliation run'
);
select lives_ok(
  $sql$
    insert into phase4d2_fee_runs
    select 'missing-evidence', public.reconcile_settlement_import(
      (select import_id from phase4d2_fee_imports where label = 'missing-evidence'),
      '89400000-0000-4000-8000-000000000089'
    )
  $sql$,
  'the same report can reconcile after evidence is linked and a distinct reviewer approves'
);
select is(
  (select result_code from public.settlement_reconciliation_results
   where import_id = (select import_id from phase4d2_fee_imports where label = 'missing-evidence')
     and row_id = 'fee-row-02'),
  'matched_fee',
  'the retried report posts and matches the fee only after evidence and reviewer gates pass'
);
select is(
  (select count(*) from public.settlement_journal_postings),
  2::bigint,
  'only the two independently verified fee rows produced journal postings'
);

select * from finish();
rollback;
