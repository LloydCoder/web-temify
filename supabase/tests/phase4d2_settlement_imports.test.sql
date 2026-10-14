begin;
select plan(34);

select has_table('public', 'settlement_imports', 'settlement report metadata is persisted');
select has_table('public', 'settlement_import_rows', 'normalized settlement rows are persisted');
select ok((select relrowsecurity from pg_class where oid = 'public.settlement_imports'::regclass), 'settlement import RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.settlement_import_rows'::regclass), 'settlement row RLS is enabled');
select ok(not has_table_privilege('authenticated', 'public.settlement_imports', 'SELECT'), 'authenticated clients cannot read settlement reports');
select ok(not has_table_privilege('authenticated', 'public.settlement_imports', 'INSERT'), 'authenticated clients cannot import settlement reports');
select ok(not has_table_privilege('service_role', 'public.settlement_imports', 'UPDATE'), 'service role cannot directly update settlement reports');
select ok(not has_table_privilege('service_role', 'public.settlement_import_rows', 'DELETE'), 'service role cannot directly delete settlement rows');
select ok(has_function_privilege('service_role', 'public.import_settlement_report(text,text,text,date,date,text,text,boolean,text,text,uuid,jsonb)', 'EXECUTE'), 'trusted service role can call the import RPC');
select ok(not has_function_privilege('authenticated', 'public.import_settlement_report(text,text,text,date,date,text,text,boolean,text,text,uuid,jsonb)', 'EXECUTE'), 'authenticated clients cannot call the import RPC');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('89000000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89100000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-customer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89200000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values
  ('89000000-0000-4000-8000-000000000089', 'admin'::public.app_role),
  ('89200000-0000-4000-8000-000000000089', 'admin'::public.app_role)
on conflict do nothing;

create temporary table phase4d2_import_ids(import_id uuid primary key) on commit drop;

select lives_ok(
  $sql$
    insert into phase4d2_import_ids
    select public.import_settlement_report(
      'sandbox', 'sandbox-account-01', 'settlement-batch-2026-10-13',
      '2026-10-13', '2026-10-13', 'UTC', repeat('d',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','payment-row-01', 'rowType','payment',
        'providerReference','provider-payment-01', 'paymentReference','order-payment-01',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',10000, 'feeMinor',300, 'netMinor',9700
      ))
    )
  $sql$,
  'authorized operations actor can import a valid normalized settlement report'
);

select is((select count(*) from public.settlement_imports), 1::bigint, 'one report metadata row is persisted');
select is((select count(*) from public.settlement_import_rows), 1::bigint, 'one normalized settlement row is persisted');

select is(
  public.import_settlement_report(
    'sandbox', 'sandbox-account-01', 'settlement-batch-2026-10-13',
    '2026-10-13', '2026-10-13', 'UTC', repeat('d',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-01', 'rowType','payment',
      'providerReference','provider-payment-01', 'paymentReference','order-payment-01',
      'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
      'grossMinor',10000, 'feeMinor',300, 'netMinor',9700
    ))
  ),
  (select import_id from phase4d2_import_ids),
  'identical report replay returns the original import id'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-01', 'settlement-batch-2026-10-13',
    '2026-10-13', '2026-10-13', 'UTC', repeat('e',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-01', 'rowType','payment',
      'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
      'grossMinor',10000, 'feeMinor',300, 'netMinor',9700
    ))
  )$sql$,
  '23514', 'settlement report identity already exists with conflicting evidence',
  'same report identity with a different source digest is rejected'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-01', 'settlement-batch-2026-10-13',
    '2026-10-13', '2026-10-13', 'Europe/Berlin', repeat('d',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-01', 'rowType','payment',
      'providerReference','provider-payment-01', 'paymentReference','order-payment-01',
      'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
      'grossMinor',10000, 'feeMinor',300, 'netMinor',9700
    ))
  )$sql$,
  '23514', 'settlement report identity already exists with conflicting evidence',
  'same source digest with conflicting timezone metadata is rejected'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-01', 'settlement-batch-2026-10-13',
    '2026-10-13', '2026-10-13', 'UTC', repeat('d',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-01', 'rowType','payment',
      'providerReference','provider-payment-01', 'paymentReference','order-payment-01',
      'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
      'grossMinor',9999, 'feeMinor',300, 'netMinor',9699
    ))
  )$sql$,
  '23514', 'settlement report identity already exists with conflicting evidence',
  'same source digest with changed normalized row amounts is rejected'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-02', 'unauthenticated-report',
    '2026-10-13', '2026-10-13', 'UTC', repeat('f',64), false,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-02', 'rowType','payment',
      'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
      'grossMinor',10000, 'feeMinor',300, 'netMinor',9700
    ))
  )$sql$,
  '23514', 'settlement report metadata failed validation',
  'an import without a trusted source-authentication assertion is rejected'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-03', 'currency-mismatch-report',
    '2026-10-13', '2026-10-13', 'UTC', repeat('a',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-03', 'rowType','payment',
      'occurredAt','2026-10-13T10:00:00Z', 'currency','EUR',
      'grossMinor',10000, 'feeMinor',300, 'netMinor',9700
    ))
  )$sql$,
  '23514', 'settlement row failed period, currency, type, amount, or exception validation',
  'a row with a different currency is rejected'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-04', 'duplicate-row-report',
    '2026-10-13', '2026-10-13', 'UTC', repeat('b',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(
      jsonb_build_object('rowId','duplicate-row','rowType','payment',
        'occurredAt','2026-10-13T10:00:00Z','currency','USD','grossMinor',10000,'feeMinor',300,'netMinor',9700),
      jsonb_build_object('rowId','duplicate-row','rowType','payment',
        'occurredAt','2026-10-13T10:00:00Z','currency','USD','grossMinor',10000,'feeMinor',300,'netMinor',9700)
    )
  )$sql$,
  '23505', null,
  'duplicate row identifiers roll back the whole report import'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-05', 'out-of-period-report',
    '2026-10-13', '2026-10-13', 'Europe/Berlin', repeat('c',64), true,
    'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','late-row','rowType','payment','occurredAt','2026-10-13T23:30:00Z',
      'currency','USD','grossMinor',10000,'feeMinor',300,'netMinor',9700
    ))
  )$sql$,
  '23514', 'settlement row failed period, currency, type, amount, or exception validation',
  'report-period validation uses the declared timezone'
);

select throws_ok(
  $sql$select public.import_settlement_report(
    'sandbox', 'sandbox-account-06', 'unauthorized-actor-report',
    '2026-10-13', '2026-10-13', 'UTC', repeat('9',64), true,
    'sandbox_fixture', 'USD', '89100000-0000-4000-8000-000000000089',
    jsonb_build_array(jsonb_build_object(
      'rowId','payment-row-06','rowType','payment','occurredAt','2026-10-13T10:00:00Z',
      'currency','USD','grossMinor',10000,'feeMinor',300,'netMinor',9700
    ))
  )$sql$,
  '42501', 'settlement import requires an authorized operations actor',
  'a non-operations actor cannot import a report'
);

select throws_ok(
  $sql$update public.settlement_imports set report_reference = 'mutated'
    where id = (select import_id from phase4d2_import_ids)$sql$,
  '55000', 'settlement import evidence is immutable',
  'settlement report metadata cannot be updated'
);
select throws_ok(
  $sql$delete from public.settlement_imports
    where id = (select import_id from phase4d2_import_ids)$sql$,
  '55000', 'settlement import evidence is immutable',
  'settlement report metadata cannot be deleted'
);
select throws_ok(
  $sql$update public.settlement_import_rows set fee_minor = 999
    where import_id = (select import_id from phase4d2_import_ids)$sql$,
  '55000', 'settlement import evidence is immutable',
  'normalized settlement rows cannot be updated'
);
select throws_ok(
  $sql$delete from public.settlement_import_rows
    where import_id = (select import_id from phase4d2_import_ids)$sql$,
  '55000', 'settlement import evidence is immutable',
  'normalized settlement rows cannot be deleted'
);


select has_table('public', 'settlement_reconciliation_runs', 'reconciliation runs are persisted');
select has_table('public', 'settlement_reconciliation_results', 'row-level reconciliation results are persisted');
select ok(not has_table_privilege('authenticated', 'public.settlement_reconciliation_runs', 'SELECT'), 'authenticated clients cannot read reconciliation runs');
select ok(has_function_privilege('service_role', 'public.reconcile_settlement_import(uuid,uuid)', 'EXECUTE'), 'trusted service role can call reconciliation RPC');
select ok(not has_function_privilege('authenticated', 'public.reconcile_settlement_import(uuid,uuid)', 'EXECUTE'), 'authenticated clients cannot call reconciliation RPC');

create temporary table phase4d2_reconciliation_ids(run_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_reconciliation_ids
    select public.reconcile_settlement_import(
      (select import_id from phase4d2_import_ids),
      '89200000-0000-4000-8000-000000000089'
    )
  $sql$,
  'a distinct admin can reconcile an imported report against posted journal evidence'
);
select is(
  public.reconcile_settlement_import(
    (select import_id from phase4d2_import_ids),
    '89200000-0000-4000-8000-000000000089'
  ),
  (select run_id from phase4d2_reconciliation_ids),
  'reconciliation replay returns the original immutable run'
);
select is(
  (select result_code from public.settlement_reconciliation_results
   where run_id = (select run_id from phase4d2_reconciliation_ids)
     and row_id = 'payment-row-01'),
  'missing_internal_match',
  'a settlement row without a posted matching journal is recorded as an exception'
);
select throws_ok(
  $sql$update public.settlement_reconciliation_results set result_code = 'matched_payment'
    where run_id = (select run_id from phase4d2_reconciliation_ids)$sql$,
  '55000', 'settlement reconciliation evidence is immutable',
  'reconciliation results cannot be mutated after creation'
);

select * from finish();
rollback;
