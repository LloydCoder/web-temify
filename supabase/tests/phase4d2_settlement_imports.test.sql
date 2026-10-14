begin;
select plan(69);

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
  ('81000000-0000-4000-8000-000000000081', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-seller@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase 4D2 Seller"}'::jsonb),
  ('89000000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89100000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-customer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89200000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('89300000-0000-4000-8000-000000000089', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase4d2-independent-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values
  ('89000000-0000-4000-8000-000000000089', 'admin'::public.app_role),
  ('89200000-0000-4000-8000-000000000089', 'admin'::public.app_role),
  ('89300000-0000-4000-8000-000000000089', 'admin'::public.app_role)
on conflict do nothing;

-- Build one verified sandbox payment journal so reconciliation tests exercise a real match.
insert into public.categories (id, slug, name, is_active)
values ('85000000-0000-4000-8000-000000000085', 'phase4d2-category', 'Phase 4D2 Category', true)
on conflict (id) do nothing;

insert into public.products (
  id, creator_id, category_id, slug, name, description, product_type, status,
  price_minor, currency, rights_status, rights_verified_at, rights_verified_by,
  artifact_sha256, release_version, license_type, summary
) values (
  '86000000-0000-4000-8000-000000000086',
  '81000000-0000-4000-8000-000000000081',
  '85000000-0000-4000-8000-000000000085',
  'phase4d2-verified-product', 'Phase 4D2 Verified Product', 'Synthetic fixture for settlement reconciliation tests.',
  'template', 'published', 1299, 'USD', 'verified',
  '2026-10-13T12:00:00Z'::timestamptz, '89000000-0000-4000-8000-000000000089',
  repeat('c', 64), '1.0.0', 'standard', 'Verified settlement fixture'
) on conflict (id) do nothing;

insert into public.product_rights_attestations (
  product_id, attested_by, rights_basis, statement, evidence_reference, review_status, reviewed_by, reviewed_at
) values (
  '86000000-0000-4000-8000-000000000086',
  '81000000-0000-4000-8000-000000000081',
  'original_work', 'Synthetic rights declaration reviewed independently for database tests.',
  'test-fixture://phase4d2/rights', 'verified',
  '89000000-0000-4000-8000-000000000089', '2026-10-13T12:00:00Z'::timestamptz
) on conflict do nothing;

insert into public.product_versions (
  id, product_id, version, release_state, release_notes, artifact_sha256,
  artifact_storage_path, manifest, compatibility, created_by, released_at
) values (
  '87000000-0000-4000-8000-000000000087',
  '86000000-0000-4000-8000-000000000086', '1.0.0', 'released',
  'Synthetic settlement test artifact.', repeat('c', 64),
  'private/phase4d2/verified-product-1.0.0.zip', '{}'::jsonb, '{}'::jsonb,
  '81000000-0000-4000-8000-000000000081', '2026-10-13T12:05:00Z'::timestamptz
) on conflict (product_id, version) do nothing;

set constraints orders_totals_guard, order_items_totals_guard deferred;
insert into public.orders (id, customer_id, currency, subtotal_minor, tax_minor, idempotency_key)
values (
  '88000000-0000-4000-8000-000000000088',
  '89100000-0000-4000-8000-000000000089', 'USD', 1299, 0,
  'phase4d2-match-order-idempotency-01'
) on conflict (id) do nothing;

insert into public.order_items (
  id, order_id, product_id, product_version_id, seller_id, product_name, product_slug,
  release_version, license_type, artifact_sha256, unit_amount_minor, quantity, currency
) values (
  '88900000-0000-4000-8000-000000000088',
  '88000000-0000-4000-8000-000000000088',
  '86000000-0000-4000-8000-000000000086',
  '87000000-0000-4000-8000-000000000087',
  '81000000-0000-4000-8000-000000000081',
  'Phase 4D2 Verified Product', 'phase4d2-verified-product', '1.0.0', 'standard',
  repeat('c', 64), 1299, 1, 'USD'
) on conflict (id) do nothing;
set constraints orders_totals_guard, order_items_totals_guard immediate;

insert into public.payment_attempts (id, order_id, provider, amount_minor, currency, idempotency_key)
values (
  '90000000-0000-4000-8000-000000000090',
  '88000000-0000-4000-8000-000000000088', 'sandbox', 1299, 'USD',
  'phase4d2-match-payment-attempt-01'
) on conflict (id) do nothing;
update public.payment_attempts set status = 'pending'
where id = '90000000-0000-4000-8000-000000000090';

insert into public.payment_webhook_events (
  provider, provider_event_id, event_type, payload_sha256, signature_verified,
  order_id, payment_attempt_id, amount_minor, currency, provider_reference
) values (
  'sandbox', 'phase4d2-verified-payment-event-01', 'payment.succeeded', repeat('a',64), true,
  '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090',
  1299, 'USD', 'phase4d2-provider-payment-match-01'
) on conflict do nothing;

select is(
  public.process_payment_webhook_event(we.id),
  true,
  'verified sandbox payment creates a posted journal batch for settlement matching'
)
from public.payment_webhook_events we
where we.provider_event_id = 'phase4d2-verified-payment-event-01';

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

-- Exact provider reference and amount must match a posted batch.
create temporary table phase4d2_matched_import_ids(import_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_matched_import_ids
    select public.import_settlement_report(
      'sandbox', 'sandbox-account-01', 'settlement-matched-batch-2026-10-13',
      '2026-10-13', '2026-10-13', 'UTC', repeat('1',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','matched-payment-row-01', 'rowType','payment',
        'providerReference','phase4d2-provider-payment-match-01',
        'paymentReference','phase4d2-order-payment-match-01',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',1299, 'feeMinor',39, 'netMinor',1260
      ))
    )
  $sql$,
  'matched payment settlement report imports successfully'
);
select public.reconcile_settlement_import(
  (select import_id from phase4d2_matched_import_ids),
  '89200000-0000-4000-8000-000000000089'
);
select is(
  (select rr.result_code
   from public.settlement_reconciliation_results rr
   where rr.run_id = (
     select sr.id from public.settlement_reconciliation_runs sr
     where sr.import_id = (select import_id from phase4d2_matched_import_ids)
   )
   and rr.row_id = 'matched-payment-row-01'),
  'matched_payment',
  'settlement row matches the exact posted payment journal'
);
select is(
  (select rr.journal_batch_id is not null
   from public.settlement_reconciliation_results rr
   where rr.run_id = (
     select sr.id from public.settlement_reconciliation_runs sr
     where sr.import_id = (select import_id from phase4d2_matched_import_ids)
   )
     and rr.row_id = 'matched-payment-row-01'),
  true,
  'matched settlement result retains the immutable journal batch reference'
);

create temporary table phase4d2_currency_import_ids(import_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_currency_import_ids
    select public.import_settlement_report(
      'sandbox', 'sandbox-account-01', 'settlement-currency-mismatch-2026-10-13',
      '2026-10-13', '2026-10-13', 'UTC', repeat('2',64), true,
      'sandbox_fixture', 'EUR', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','currency-mismatch-row-01', 'rowType','payment',
        'providerReference','phase4d2-provider-payment-match-01',
        'paymentReference','phase4d2-order-payment-match-01',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','EUR',
        'grossMinor',1299, 'feeMinor',39, 'netMinor',1260
      ))
    )
  $sql$,
  'cross-currency settlement report imports as evidence without being treated as matched'
);
select public.reconcile_settlement_import(
  (select import_id from phase4d2_currency_import_ids),
  '89200000-0000-4000-8000-000000000089'
);
select is(
  (select rr.result_code
   from public.settlement_reconciliation_results rr
   where rr.run_id = (
     select sr.id from public.settlement_reconciliation_runs sr
     where sr.import_id = (select import_id from phase4d2_currency_import_ids)
   )
   and rr.row_id = 'currency-mismatch-row-01'),
  'currency_mismatch',
  'matching provider reference in another currency is classified as currency mismatch'
);

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


select has_table('public', 'settlement_exception_decisions', 'exception decisions are persisted separately from reconciliation evidence');
select ok(has_function_privilege('service_role', 'public.decide_settlement_exception(uuid,text,text,text,text,uuid)', 'EXECUTE'), 'trusted service role can call the exception decision RPC');
select ok(not has_function_privilege('authenticated', 'public.decide_settlement_exception(uuid,text,text,text,text,uuid)', 'EXECUTE'), 'authenticated clients cannot call the exception decision RPC');
create temporary table phase4d2_decision_ids(decision_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_decision_ids
    select public.decide_settlement_exception(
      (select run_id from phase4d2_reconciliation_ids),
      'payment-row-01',
      'manual_review_required',
      'Provider reference needs independent verification',
      null,
      '89300000-0000-4000-8000-000000000089'
    )
  $sql$,
  'a third independent admin can record a triage decision without resolving the exception'
);
select is(
  public.decide_settlement_exception(
    (select run_id from phase4d2_reconciliation_ids),
    'payment-row-01',
    'manual_review_required',
    'Provider reference needs independent verification',
    null,
    '89300000-0000-4000-8000-000000000089'
  ),
  (select decision_id from phase4d2_decision_ids),
  'identical exception-decision replay returns the original decision'
);
select is(
  (select result_status from public.settlement_reconciliation_results
   where run_id = (select run_id from phase4d2_reconciliation_ids)
     and row_id = 'payment-row-01'),
  'exception',
  'triage decisions do not turn accounting exceptions into matches'
);
select throws_ok(
  $sql$update public.settlement_exception_decisions set decision = 'reimport_required'
    where id = (select decision_id from phase4d2_decision_ids)$sql$,
  '55000', 'settlement reconciliation evidence is immutable',
  'exception decisions cannot be mutated after creation'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.list_settlement_exception_queue(uuid,integer,timestamp with time zone,uuid,text)',
    'EXECUTE'
  ),
  'trusted service role can read the bounded settlement exception queue'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.list_settlement_exception_queue(uuid,integer,timestamp with time zone,uuid,text)',
    'EXECUTE'
  ),
  'authenticated clients cannot read the settlement exception queue RPC'
);
select is(
  (select q.result_code
   from public.list_settlement_exception_queue(
     '89000000-0000-4000-8000-000000000089', 51, null, null, null
   ) q
   where q.run_id = (select run_id from phase4d2_reconciliation_ids)
     and q.row_id = 'payment-row-01'),
  'missing_internal_match',
  'admin queue exposes the immutable exception classification'
);
select is(
  (select q.triage_decision
   from public.list_settlement_exception_queue(
     '89000000-0000-4000-8000-000000000089', 51, null, null, null
   ) q
   where q.run_id = (select run_id from phase4d2_reconciliation_ids)
     and q.row_id = 'payment-row-01'),
  'manual_review_required',
  'admin queue shows triage separately without resolving the accounting exception'
);
select is(
  (select q.gross_minor
   from public.list_settlement_exception_queue(
     '89000000-0000-4000-8000-000000000089', 51, null, null, null
   ) q
   where q.run_id = (select run_id from phase4d2_reconciliation_ids)
     and q.row_id = 'payment-row-01'),
  '10000',
  'queue serializes gross minor units as exact decimal text'
);
select is(
  (select q.net_minor
   from public.list_settlement_exception_queue(
     '89000000-0000-4000-8000-000000000089', 51, null, null, null
   ) q
   where q.run_id = (select run_id from phase4d2_reconciliation_ids)
     and q.row_id = 'payment-row-01'),
  '9700',
  'queue serializes net minor units as exact decimal text'
);
select throws_ok(
  $sql$select count(*) from public.list_settlement_exception_queue(
    '81000000-0000-4000-8000-000000000081', 51, null, null, null
  )$sql$,
  '42501', 'settlement exception queue requires an admin',
  'non-admin identity cannot read settlement exception details'
);
select throws_ok(
  $sql$select count(*) from public.list_settlement_exception_queue(
    '89000000-0000-4000-8000-000000000089', 52, null, null, null
  )$sql$,
  '23514', 'settlement exception queue limit is outside the allowed range',
  'queue refuses an unbounded or oversized page request'
);
select throws_ok(
  $sql$select count(*) from public.list_settlement_exception_queue(
    '89000000-0000-4000-8000-000000000089', 51, now(), null, null
  )$sql$,
  '23514', 'settlement exception cursor is incomplete',
  'queue rejects partially supplied cursor tuples'
);
select throws_ok(
  $sql$select count(*) from public.list_settlement_exception_queue(
    '89000000-0000-4000-8000-000000000089', 51, now(), gen_random_uuid(), ''
  )$sql$,
  '23514', 'settlement exception cursor row identifier is outside the allowed range',
  'queue rejects empty row identifiers in cursor tuples'
);
select is(
  (
    with first_page as (
      select q.run_id, q.row_id, q.result_created_at
      from public.list_settlement_exception_queue(
        '89000000-0000-4000-8000-000000000089', 1, null, null, null
      ) q
      order by q.result_created_at desc, q.run_id desc, q.row_id desc
      limit 1
    )
    select count(*)
    from first_page fp
    cross join lateral public.list_settlement_exception_queue(
      '89000000-0000-4000-8000-000000000089', 51,
      fp.result_created_at, fp.run_id, fp.row_id
    ) q
    where q.run_id = fp.run_id and q.row_id = fp.row_id
  ),
  0::bigint,
  'pagination cursor excludes the previous page boundary row'
);


-- A matching provider reference with a different gross amount must be an exception.
create temporary table phase4d2_amount_mismatch_import_ids(import_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_amount_mismatch_import_ids
    select public.import_settlement_report(
      'sandbox', 'sandbox-account-01', 'settlement-amount-mismatch-2026-10-13',
      '2026-10-13', '2026-10-13', 'UTC', repeat('3',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(jsonb_build_object(
        'rowId','amount-mismatch-row-01', 'rowType','payment',
        'providerReference','phase4d2-provider-payment-match-01',
        'paymentReference','phase4d2-order-payment-match-01',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',1298, 'feeMinor',39, 'netMinor',1259
      ))
    )
  $sql$,
  'amount-mismatched settlement row imports as immutable evidence'
);
select lives_ok(
  $sql$
    select public.reconcile_settlement_import(
      (select import_id from phase4d2_amount_mismatch_import_ids),
      '89200000-0000-4000-8000-000000000089'
    )
  $sql$,
  'amount-mismatched settlement row can be classified without posting money'
);
select is(
  (select rr.result_code
   from public.settlement_reconciliation_results rr
   join public.settlement_reconciliation_runs sr on sr.id = rr.run_id
   where sr.import_id = (select import_id from phase4d2_amount_mismatch_import_ids)
     and rr.row_id = 'amount-mismatch-row-01'),
  'amount_mismatch',
  'a matching provider reference with a different amount is explicitly classified'
);
select is(
  (select rr.result_status
   from public.settlement_reconciliation_results rr
   join public.settlement_reconciliation_runs sr on sr.id = rr.run_id
   where sr.import_id = (select import_id from phase4d2_amount_mismatch_import_ids)
     and rr.row_id = 'amount-mismatch-row-01'),
  'exception',
  'amount mismatches remain unresolved exceptions rather than being treated as matches'
);


-- Explicit import exception classifications must override otherwise matching references.
create temporary table phase4d2_explicit_exception_import_ids(import_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_explicit_exception_import_ids
    select public.import_settlement_report(
      'sandbox', 'sandbox-account-01', 'settlement-explicit-exceptions-2026-10-13',
      '2026-10-13', '2026-10-13', 'UTC', repeat('4',64), true,
      'sandbox_fixture', 'USD', '89000000-0000-4000-8000-000000000089',
      jsonb_build_array(
        jsonb_build_object(
          'rowId','unexplained-adjustment-row-01', 'rowType','payment',
          'providerReference','phase4d2-provider-payment-match-01',
          'paymentReference','phase4d2-order-payment-match-01',
          'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
          'grossMinor',1299, 'feeMinor',39, 'netMinor',1260,
          'exceptionCode','unexplained_adjustment'
        ),
        jsonb_build_object(
          'rowId','period-mismatch-row-01', 'rowType','payment',
          'providerReference','phase4d2-provider-payment-match-01',
          'paymentReference','phase4d2-order-payment-match-01',
          'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
          'grossMinor',1299, 'feeMinor',39, 'netMinor',1260,
          'exceptionCode','period_mismatch'
        )
      )
    )
  $sql$,
  'explicit settlement exceptions import as immutable evidence'
);
select lives_ok(
  $sql$
    select public.reconcile_settlement_import(
      (select import_id from phase4d2_explicit_exception_import_ids),
      '89200000-0000-4000-8000-000000000089'
    )
  $sql$,
  'explicit settlement exceptions reconcile without being promoted to matches'
);
select is(
  (select rr.result_code
   from public.settlement_reconciliation_results rr
   join public.settlement_reconciliation_runs sr on sr.id = rr.run_id
   where sr.import_id = (select import_id from phase4d2_explicit_exception_import_ids)
     and rr.row_id = 'unexplained-adjustment-row-01'),
  'unexplained_adjustment',
  'an explicitly unexplained adjustment remains classified as an exception'
);
select is(
  (select rr.result_status
   from public.settlement_reconciliation_results rr
   join public.settlement_reconciliation_runs sr on sr.id = rr.run_id
   where sr.import_id = (select import_id from phase4d2_explicit_exception_import_ids)
     and rr.row_id = 'period-mismatch-row-01'),
  'exception',
  'an explicitly period-mismatched row cannot be reported as a matched payment'
);


select is(
  (select q.result_code
   from public.list_settlement_exception_queue(
     '89000000-0000-4000-8000-000000000089', 51, null, null, null
   ) q
   join public.settlement_reconciliation_runs sr on sr.id = q.run_id
   where sr.import_id = (select import_id from phase4d2_explicit_exception_import_ids)
     and q.row_id = 'unexplained-adjustment-row-01'),
  'unexplained_adjustment',
  'exception queue exposes explicit unexplained-adjustment classifications'
);
select is(
  (select q.result_code
   from public.list_settlement_exception_queue(
     '89000000-0000-4000-8000-000000000089', 51, null, null, null
   ) q
   join public.settlement_reconciliation_runs sr on sr.id = q.run_id
   where sr.import_id = (select import_id from phase4d2_explicit_exception_import_ids)
     and q.row_id = 'period-mismatch-row-01'),
  'period_mismatch',
  'exception queue exposes explicit period-mismatch classifications'
);

select * from finish();
rollback;
