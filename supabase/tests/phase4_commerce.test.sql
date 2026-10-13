begin;
select plan(62);

select has_table('public', 'orders', 'orders table exists');
select has_table('public', 'order_items', 'immutable order item snapshots exist');
select has_table('public', 'payment_attempts', 'payment attempts exist');
select has_table('public', 'payment_webhook_events', 'verified webhook inbox exists');
select has_table('public', 'refunds', 'refund records exist');
select has_table('public', 'ledger_transactions', 'append-only ledger exists');
select has_table('public', 'entitlements', 'entitlements exist');
select has_table('public', 'download_grants', 'download authorization grants exist');

select ok((select relrowsecurity from pg_class where oid = 'public.orders'::regclass), 'orders RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.order_items'::regclass), 'order items RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_attempts'::regclass), 'payment attempts RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_webhook_events'::regclass), 'webhook inbox RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.refunds'::regclass), 'refunds RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.ledger_transactions'::regclass), 'ledger RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.entitlements'::regclass), 'entitlements RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.download_grants'::regclass), 'download grants RLS enabled');

select ok(not has_table_privilege('authenticated', 'public.orders', 'INSERT'), 'customers cannot create or alter orders directly');
select ok(not has_table_privilege('authenticated', 'public.payment_attempts', 'UPDATE'), 'customers cannot alter payment attempts');
select ok(not has_table_privilege('authenticated', 'public.payment_webhook_events', 'SELECT'), 'customers cannot inspect webhook events');
select ok(not has_table_privilege('authenticated', 'public.ledger_transactions', 'SELECT'), 'customers cannot inspect the financial ledger');
select ok(not has_table_privilege('service_role', 'public.ledger_transactions', 'UPDATE'), 'ledger rows are not updateable by the service role');
select ok(not has_table_privilege('service_role', 'public.ledger_transactions', 'DELETE'), 'ledger rows are not deletable by the service role');
select ok(has_column_privilege('authenticated', 'public.orders', 'status', 'SELECT'), 'customers can read their own order status');
select ok(not has_column_privilege('authenticated', 'public.orders', 'customer_id', 'SELECT'), 'customer account identifiers are not exposed as order fields');
select ok(not has_column_privilege('authenticated', 'public.payment_attempts', 'provider_reference', 'SELECT'), 'provider references are not exposed to customers');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
 ('81000000-0000-4000-8000-000000000081', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase4-seller@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase Four Seller"}'::jsonb),
 ('82000000-0000-4000-8000-000000000082', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase4-customer@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase Four Customer"}'::jsonb),
 ('83000000-0000-4000-8000-000000000083', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase4-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase Four Reviewer"}'::jsonb),
 ('84000000-0000-4000-8000-000000000084', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase4-other-customer@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Other Customer"}'::jsonb)
on conflict (id) do nothing;

insert into public.categories (id, slug, name, is_active)
values ('85000000-0000-4000-8000-000000000085', 'phase4-category', 'Phase Four Category', true)
on conflict (id) do nothing;

insert into public.products (
  id, creator_id, category_id, slug, name, description, product_type, status,
  price_minor, currency, rights_status, rights_verified_at, rights_verified_by,
  artifact_sha256, release_version, license_type, summary
) values (
  '86000000-0000-4000-8000-000000000086',
  '81000000-0000-4000-8000-000000000081',
  '85000000-0000-4000-8000-000000000085',
  'phase4-verified-product', 'Phase Four Verified Product', 'Synthetic fixture for commerce database tests.',
  'template', 'published', 1299, 'USD', 'verified',
  '2026-10-13T12:00:00Z'::timestamptz, '83000000-0000-4000-8000-000000000083',
  repeat('c', 64), '1.0.0', 'standard', 'Verified commerce fixture'
) on conflict (id) do nothing;

insert into public.product_rights_attestations (
  product_id, attested_by, rights_basis, statement, evidence_reference, review_status, reviewed_by, reviewed_at
) values (
  '86000000-0000-4000-8000-000000000086',
  '81000000-0000-4000-8000-000000000081',
  'original_work', 'Synthetic rights declaration reviewed independently for database tests.',
  'test-fixture://phase4/rights', 'verified',
  '83000000-0000-4000-8000-000000000083', '2026-10-13T12:00:00Z'::timestamptz
) on conflict do nothing;

insert into public.product_versions (
  id, product_id, version, release_state, release_notes, artifact_sha256,
  artifact_storage_path, manifest, compatibility, created_by, released_at
) values (
  '87000000-0000-4000-8000-000000000087',
  '86000000-0000-4000-8000-000000000086', '1.0.0', 'released',
  'Synthetic released artifact for database tests.', repeat('c', 64),
  'private/phase4/verified-product-1.0.0.zip', '{}'::jsonb, '{}'::jsonb,
  '81000000-0000-4000-8000-000000000081', '2026-10-13T12:05:00Z'::timestamptz
) on conflict (product_id, version) do nothing;

insert into public.orders (id, customer_id, currency, subtotal_minor, tax_minor, idempotency_key)
values (
  '88000000-0000-4000-8000-000000000088',
  '82000000-0000-4000-8000-000000000082', 'USD', 1299, 0,
  'phase4-order-idempotency-0001'
) on conflict (id) do nothing;

insert into public.order_items (
  id, order_id, product_id, product_version_id, seller_id, product_name, product_slug,
  release_version, license_type, artifact_sha256, unit_amount_minor, quantity, currency
) values (
  '89000000-0000-4000-8000-000000000089',
  '88000000-0000-4000-8000-000000000088',
  '86000000-0000-4000-8000-000000000086',
  '87000000-0000-4000-8000-000000000087',
  '81000000-0000-4000-8000-000000000081',
  'Phase Four Verified Product', 'phase4-verified-product', '1.0.0', 'standard',
  repeat('c', 64), 1299, 1, 'USD'
) on conflict (id) do nothing;

set constraints orders_totals_guard, order_items_totals_guard immediate;
select is((select total_minor from public.orders where id = '88000000-0000-4000-8000-000000000088'), 1299::bigint, 'order total is derived from immutable subtotal and tax');
select is((select line_total_minor from public.order_items where id = '89000000-0000-4000-8000-000000000089'), 1299::bigint, 'line total is derived from unit amount and quantity');

select throws_ok(
  $sql$insert into public.payment_attempts (order_id, provider, amount_minor, currency, idempotency_key)
  values ('88000000-0000-4000-8000-000000000088', 'sandbox', 1298, 'USD', 'phase4-bad-amount-key-001')$sql$,
  '23514', null, 'payment attempt cannot change the order amount'
);
select throws_ok(
  $sql$update public.orders set status = 'paid' where id = '88000000-0000-4000-8000-000000000088'$sql$,
  '23514', null, 'order cannot be marked paid without verified event and ledger evidence'
);
select throws_ok(
  $sql$insert into public.entitlements (order_item_id, customer_id, product_id, product_version_id)
  values ('89000000-0000-4000-8000-000000000089', '82000000-0000-4000-8000-000000000082', '86000000-0000-4000-8000-000000000086', '87000000-0000-4000-8000-000000000087')$sql$,
  '23514', null, 'entitlement cannot be granted before order payment'
);

insert into public.payment_attempts (id, order_id, provider, amount_minor, currency, idempotency_key)
values (
  '90000000-0000-4000-8000-000000000090',
  '88000000-0000-4000-8000-000000000088', 'sandbox', 1299, 'USD',
  'phase4-payment-idempotency-0001'
);
update public.payment_attempts set status = 'pending' where id = '90000000-0000-4000-8000-000000000090';
select throws_ok(
  $sql$insert into public.payment_attempts (order_id, provider, amount_minor, currency, idempotency_key)
  values ('88000000-0000-4000-8000-000000000088', 'stripe', 1299, 'USD', 'phase4-second-active-attempt-001')$sql$,
  '23505', null, 'an order cannot have two active or settled payment attempts'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id)
  values ('stripe', 'phase4-mismatched-provider-event-001', 'payment.succeeded', repeat('b', 64), true, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090')$sql$,
  '23514', null, 'provider event must match the referenced payment attempt'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id)
  values ('sandbox', 'phase4-invalid-signature-event-001', 'payment.succeeded', repeat('b', 64), false, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090')$sql$,
  '23514', null, 'unverified provider events cannot enter the inbox'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, order_id, payment_attempt_id)
  values ('sandbox', 'phase4-missing-signature-event-001', 'payment.succeeded', repeat('b', 64), '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090')$sql$,
  '23502', null, 'signature verification must be explicitly asserted by the trusted ingress'
);
insert into public.payment_webhook_events (
  id, provider, provider_event_id, event_type, payload_sha256, order_id, payment_attempt_id
) values (
  '91000000-0000-4000-8000-000000000091', 'sandbox', 'phase4-payment-event-0001',
  'payment.succeeded', repeat('d', 64), true, '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090'
);
update public.payment_webhook_events set processing_status = 'processing'
where id = '91000000-0000-4000-8000-000000000091';
update public.payment_attempts set status = 'succeeded'
where id = '90000000-0000-4000-8000-000000000090';
update public.payment_attempts set provider_reference = 'sandbox-charge-0001'
where id = '90000000-0000-4000-8000-000000000090';
select throws_ok(
  $sql$update public.payment_attempts set provider_reference = 'sandbox-charge-0002' where id = '90000000-0000-4000-8000-000000000090'$sql$,
  '23514', null, 'provider references cannot be rewritten after assignment'
);
insert into public.ledger_transactions (
  order_id, payment_attempt_id, source_type, debit_account, credit_account,
  amount_minor, currency, reference_key
) values (
  '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090',
  'payment', 'provider_clearing', 'platform_cash', 1299, 'USD',
  'phase4-payment-ledger-entry-0001'
);
update public.payment_webhook_events set processing_status = 'processed', processed_at = now()
where id = '91000000-0000-4000-8000-000000000091';
select throws_ok(
  $sql$insert into public.ledger_transactions (order_id, payment_attempt_id, source_type, debit_account, credit_account, amount_minor, currency, reference_key)
  values ('88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 'payment', 'provider_clearing', 'platform_cash', 1299, 'USD', 'phase4-payment-ledger-duplicate-0001')$sql$,
  '23505', null, 'a payment attempt cannot be posted to the ledger twice'
);
select throws_ok(
  $sql$insert into public.ledger_transactions (order_id, source_type, debit_account, credit_account, amount_minor, currency, reference_key)
  values ('88000000-0000-4000-8000-000000000088', 'chargeback', 'chargeback_expense', 'provider_clearing', 1299, 'USD', 'phase4-unmodeled-chargeback-0001')$sql$,
  '23514', null, 'chargeback ledger entries remain rejected until their evidence-backed workflow is implemented'
);
update public.orders set status = 'paid' where id = '88000000-0000-4000-8000-000000000088';
select is((select status from public.orders where id = '88000000-0000-4000-8000-000000000088'), 'paid', 'verified payment and ledger evidence permit the order to become paid');
select throws_ok(
  $sql$update public.orders set status = 'cancelled' where id = '88000000-0000-4000-8000-000000000088'$sql$,
  '23514', null, 'order cannot be cancelled after a payment is settled'
);
select is((select count(*) from public.ledger_transactions where order_id = '88000000-0000-4000-8000-000000000088'), 1::bigint, 'successful payment is journaled exactly once');

select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, order_id, payment_attempt_id)
  values ('sandbox', 'phase4-payment-event-0001', 'payment.succeeded', repeat('e', 64), true, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090')$sql$,
  '23505', null, 'duplicate provider event identifiers are rejected'
);

insert into public.entitlements (id, order_item_id, customer_id, product_id, product_version_id)
values (
  '92000000-0000-4000-8000-000000000092', '89000000-0000-4000-8000-000000000089',
  '82000000-0000-4000-8000-000000000082', '86000000-0000-4000-8000-000000000086',
  '87000000-0000-4000-8000-000000000087'
);
select is((select count(*) from public.entitlements where customer_id = '82000000-0000-4000-8000-000000000082' and status = 'active'), 1::bigint, 'paid order can grant an active entitlement');
select throws_ok(
  $sql$update public.entitlements set status = 'expired' where id = '92000000-0000-4000-8000-000000000092'$sql$,
  '23514', null, 'entitlement cannot expire before its expiry time'
);
select throws_ok(
  $sql$update public.entitlements set customer_id = '84000000-0000-4000-8000-000000000084' where id = '92000000-0000-4000-8000-000000000092'$sql$,
  '23514', null, 'entitlement ownership cannot be reassigned after purchase'
);

insert into public.download_grants (
  id, entitlement_id, customer_id, product_version_id, artifact_sha256, expires_at, max_downloads
) values (
  '93000000-0000-4000-8000-000000000093', '92000000-0000-4000-8000-000000000092',
  '82000000-0000-4000-8000-000000000082', '87000000-0000-4000-8000-000000000087',
  repeat('c', 64), now() + interval '5 minutes', 1
);
select throws_ok(
  $sql$insert into public.download_grants (entitlement_id, customer_id, product_version_id, artifact_sha256, expires_at, max_downloads)
  values ('92000000-0000-4000-8000-000000000092', '82000000-0000-4000-8000-000000000082', '87000000-0000-4000-8000-000000000087', repeat('c', 64), now() + interval '1 hour', 1)$sql$,
  '23514', null, 'download grants must be short-lived'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000082', true);
select is(public.consume_download_grant('93000000-0000-4000-8000-000000000093'), true, 'customer can atomically consume their active download grant');
select is(public.consume_download_grant('93000000-0000-4000-8000-000000000093'), false, 'download grant cannot be consumed beyond its maximum');
reset role;
select is((select downloads_used from public.download_grants where id = '93000000-0000-4000-8000-000000000093'), 1, 'download count increments atomically');

set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000082', true);
select is((select count(*) from public.orders), 1::bigint, 'customer can see their own orders');
select is((select count(*) from public.order_items), 1::bigint, 'customer can see their own order items');
select is((select count(*) from public.payment_attempts), 1::bigint, 'customer can see their own payment attempts');
select is((select count(*) from public.entitlements), 1::bigint, 'customer can see their own entitlements');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-4000-8000-000000000084', true);
select is((select count(*) from public.orders), 0::bigint, 'other customer cannot see the order');
select is((select count(*) from public.order_items), 0::bigint, 'other customer cannot see order items');
select is((select count(*) from public.payment_attempts), 0::bigint, 'other customer cannot see payment attempts');
select is((select count(*) from public.entitlements), 0::bigint, 'other customer cannot see entitlements');
reset role;

select throws_ok(
  $sql$insert into public.refunds (order_id, payment_attempt_id, amount_minor, currency, reason, idempotency_key, requested_by)
  values ('88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1300, 'USD', 'Excess refund test', 'phase4-excess-refund-key-0001', '82000000-0000-4000-8000-000000000082')$sql$,
  '23514', null, 'refund requests cannot exceed the remaining order balance'
);

insert into public.refunds (id, order_id, payment_attempt_id, amount_minor, currency, reason, idempotency_key, requested_by)
values (
  '94000000-0000-4000-8000-000000000094', '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', 500, 'USD', 'Synthetic partial refund test',
  'phase4-partial-refund-key-0001', '82000000-0000-4000-8000-000000000082'
);
update public.refunds set status = 'pending' where id = '94000000-0000-4000-8000-000000000094';
insert into public.payment_webhook_events (
  id, provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, refund_id
) values (
  '95000000-0000-4000-8000-000000000095', 'sandbox', 'phase4-refund-event-0001',
  'refund.succeeded', repeat('f', 64), true, '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', '94000000-0000-4000-8000-000000000094'
);
update public.payment_webhook_events set processing_status = 'processing'
where id = '95000000-0000-4000-8000-000000000095';
insert into public.ledger_transactions (
  order_id, payment_attempt_id, refund_id, source_type, debit_account, credit_account,
  amount_minor, currency, reference_key
) values (
  '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090',
  '94000000-0000-4000-8000-000000000094', 'refund', 'customer_refund', 'provider_clearing',
  500, 'USD', 'phase4-partial-refund-ledger-0001'
);
update public.refunds set status = 'succeeded' where id = '94000000-0000-4000-8000-000000000094';
update public.payment_webhook_events set processing_status = 'processed', processed_at = now()
where id = '95000000-0000-4000-8000-000000000095';
update public.payment_attempts set status = 'partially_refunded'
where id = '90000000-0000-4000-8000-000000000090';
update public.orders set status = 'partially_refunded'
where id = '88000000-0000-4000-8000-000000000088';
select is((select status from public.orders where id = '88000000-0000-4000-8000-000000000088'), 'partially_refunded', 'partial refund requires verified refund evidence and balanced ledger');
set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000082', true);
select is(public.consume_download_grant('93000000-0000-4000-8000-000000000093'), false, 'download is denied after order leaves paid state');
reset role;

insert into public.refunds (id, order_id, payment_attempt_id, amount_minor, currency, reason, idempotency_key, requested_by)
values (
  '96000000-0000-4000-8000-000000000096', '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', 799, 'USD', 'Synthetic final refund test',
  'phase4-final-refund-key-0001', '82000000-0000-4000-8000-000000000082'
);
update public.refunds set status = 'pending' where id = '96000000-0000-4000-8000-000000000096';
insert into public.payment_webhook_events (
  id, provider, provider_event_id, event_type, payload_sha256, order_id, payment_attempt_id, refund_id
) values (
  '97000000-0000-4000-8000-000000000097', 'sandbox', 'phase4-refund-event-0002',
  'refund.succeeded', repeat('a', 64), true, '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', '96000000-0000-4000-8000-000000000096'
);
update public.payment_webhook_events set processing_status = 'processing'
where id = '97000000-0000-4000-8000-000000000097';
insert into public.ledger_transactions (
  order_id, payment_attempt_id, refund_id, source_type, debit_account, credit_account,
  amount_minor, currency, reference_key
) values (
  '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090',
  '96000000-0000-4000-8000-000000000096', 'refund', 'customer_refund', 'provider_clearing',
  799, 'USD', 'phase4-final-refund-ledger-0001'
);
update public.refunds set status = 'succeeded' where id = '96000000-0000-4000-8000-000000000096';
update public.payment_webhook_events set processing_status = 'processed', processed_at = now()
where id = '97000000-0000-4000-8000-000000000097';
update public.payment_attempts set status = 'refunded'
where id = '90000000-0000-4000-8000-000000000090';
update public.orders set status = 'refunded'
where id = '88000000-0000-4000-8000-000000000088';
select is((select status from public.orders where id = '88000000-0000-4000-8000-000000000088'), 'refunded', 'full refund requires the complete verified refund total');
select is((select count(*) from public.ledger_transactions where order_id = '88000000-0000-4000-8000-000000000088'), 3::bigint, 'payment and both refunds are preserved as immutable ledger entries');
update public.entitlements set status = 'revoked', revoked_at = now() where id = '92000000-0000-4000-8000-000000000092';
select throws_ok(
  $sql$update public.entitlements set status = 'active', revoked_at = null where id = '92000000-0000-4000-8000-000000000092'$sql$,
  '23514', null, 'revoked entitlements cannot be reactivated'
);
select * from finish();
rollback;
