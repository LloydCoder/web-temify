begin;
select plan(212);

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
  $sql$update public.payment_attempts set status = 'succeeded' where id = '90000000-0000-4000-8000-000000000090'$sql$,
  '23514', null, 'payment attempt cannot succeed without a verified provider event'
);
select throws_ok(
  $sql$update public.orders set status = 'cancelled' where id = '88000000-0000-4000-8000-000000000088'$sql$,
  '23514', null, 'order cannot be cancelled while a payment attempt is active'
);
select throws_ok(
  $sql$insert into public.payment_attempts (order_id, provider, amount_minor, currency, idempotency_key)
  values ('88000000-0000-4000-8000-000000000088', 'stripe', 1299, 'USD', 'phase4-second-active-attempt-001')$sql$,
  '23505', null, 'an order cannot have two active or settled payment attempts'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, amount_minor, currency, provider_reference)
  values ('stripe', 'phase4-mismatched-provider-event-001', 'payment.succeeded', repeat('b', 64), true, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1299, 'USD', 'stripe-invalid-ref')$sql$,
  '23514', null, 'provider event must match the referenced payment attempt'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, amount_minor, currency, provider_reference)
  values ('sandbox', 'phase4-mismatched-amount-event-001', 'payment.succeeded', repeat('b', 64), true, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1298, 'USD', 'sandbox-wrong-amount')$sql$,
  '23514', null, 'verified event amount must match the canonical payment attempt'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, amount_minor, currency)
  values ('sandbox', 'phase4-missing-provider-ref-event-001', 'payment.succeeded', repeat('b', 64), true, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1299, 'USD')$sql$,
  '23514', null, 'financial events require a provider reference'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, amount_minor, currency, provider_reference)
  values ('sandbox', 'phase4-invalid-signature-event-001', 'payment.succeeded', repeat('b', 64), false, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1299, 'USD', 'sandbox-invalid-ref')$sql$,
  '23514', null, 'unverified provider events cannot enter the inbox'
);
select throws_ok(
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, order_id, payment_attempt_id, amount_minor, currency, provider_reference)
  values ('sandbox', 'phase4-missing-signature-event-001', 'payment.succeeded', repeat('b', 64), '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1299, 'USD', 'sandbox-missing-signature-ref')$sql$,
  '23502', null, 'signature verification must be explicitly asserted by the trusted ingress'
);
insert into public.payment_webhook_events (
  id, provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, amount_minor, currency, provider_reference
) values (
  '91000000-0000-4000-8000-000000000091', 'sandbox', 'phase4-payment-event-0001',
  'payment.succeeded', repeat('d', 64), true, '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', 1299, 'USD', 'sandbox-charge-0001'
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
  $sql$insert into public.payment_webhook_events (provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, amount_minor, currency, provider_reference)
  values ('sandbox', 'phase4-payment-event-0001', 'payment.succeeded', repeat('e', 64), true, '88000000-0000-4000-8000-000000000088', '90000000-0000-4000-8000-000000000090', 1299, 'USD', 'sandbox-charge-0001')$sql$,
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
select throws_ok(
  $sql$insert into public.download_grants (entitlement_id, customer_id, product_version_id, artifact_sha256, issued_at, expires_at, max_downloads)
  values ('92000000-0000-4000-8000-000000000092', '82000000-0000-4000-8000-000000000082', '87000000-0000-4000-8000-000000000087', repeat('c', 64), now() - interval '10 minutes', now() - interval '1 minute', 1)$sql$,
  '23514', null, 'expired download grants are rejected at creation'
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
  id, provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, refund_id, amount_minor, currency, provider_reference
) values (
  '95000000-0000-4000-8000-000000000095', 'sandbox', 'phase4-refund-event-0001',
  'refund.succeeded', repeat('f', 64), true, '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', '94000000-0000-4000-8000-000000000094', 500, 'USD', 'sandbox-refund-0001'
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
select is(public.consume_download_grant('93000000-0000-4000-8000-000000000093'), false, 'exhausted download grant remains unusable after partial refund');
reset role;

insert into public.refunds (id, order_id, payment_attempt_id, amount_minor, currency, reason, idempotency_key, requested_by)
values (
  '96000000-0000-4000-8000-000000000096', '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', 799, 'USD', 'Synthetic final refund test',
  'phase4-final-refund-key-0001', '82000000-0000-4000-8000-000000000082'
);
update public.refunds set status = 'pending' where id = '96000000-0000-4000-8000-000000000096';
insert into public.payment_webhook_events (
  id, provider, provider_event_id, event_type, payload_sha256, signature_verified, order_id, payment_attempt_id, refund_id, amount_minor, currency, provider_reference
) values (
  '97000000-0000-4000-8000-000000000097', 'sandbox', 'phase4-refund-event-0002',
  'refund.succeeded', repeat('a', 64), true, '88000000-0000-4000-8000-000000000088',
  '90000000-0000-4000-8000-000000000090', '96000000-0000-4000-8000-000000000096', 799, 'USD', 'sandbox-refund-0002'
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
set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000082', true);
select is((select count(*) from public.refunds), 2::bigint, 'customer can read only their own refund records');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-4000-8000-000000000084', true);
select is((select count(*) from public.refunds), 0::bigint, 'other customer cannot read refund records');
reset role;
select ok(
  not has_table_privilege('authenticated', 'public.ledger_transactions', 'SELECT')
  and not has_table_privilege('authenticated', 'public.payment_webhook_events', 'SELECT'),
  'financial ledger and webhook evidence are not client-readable'
);
select ok(
  not has_table_privilege('service_role', 'public.order_items', 'UPDATE')
  and not has_table_privilege('service_role', 'public.order_items', 'DELETE'),
  'order item snapshots cannot be mutated or deleted by application service role'
);
select ok(
  not has_table_privilege('service_role', 'public.ledger_transactions', 'UPDATE')
  and not has_table_privilege('service_role', 'public.ledger_transactions', 'DELETE'),
  'ledger entries are append-only for the application service role'
);
update public.entitlements set status = 'revoked', revoked_at = now() where id = '92000000-0000-4000-8000-000000000092';
select throws_ok(
  $sql$update public.entitlements set status = 'active', revoked_at = null where id = '92000000-0000-4000-8000-000000000092'$sql$,
  '23514', null, 'revoked entitlements cannot be reactivated'
);
-- Phase 4B: exercise the atomic server-only checkout RPC and durable payment-event processor.
select has_function('public', 'create_order_for_checkout', array['uuid','jsonb','text'], 'server-only checkout RPC exists');
select ok(
  not has_function_privilege('authenticated', 'public.create_order_for_checkout(uuid,jsonb,text)', 'EXECUTE'),
  'customers cannot invoke privileged checkout creation directly'
);
create temporary table phase4b_checkout_order_ids(order_id uuid primary key) on commit drop;
set constraints orders_totals_guard, order_items_totals_guard deferred;
select lives_ok(
  $sql$insert into phase4b_checkout_order_ids
    select order_id from public.create_order_for_checkout(
      '82000000-0000-4000-8000-000000000082',
      '[{"product_version_id":"87000000-0000-4000-8000-000000000087","quantity":1}]'::jsonb,
      'phase4b-checkout-idempotency-0001'
    )$sql$,
  'checkout RPC creates a server-priced order and immutable item snapshot'
);
select lives_ok(
  $sql$insert into phase4b_checkout_order_ids
    select order_id from public.create_order_for_checkout(
      '82000000-0000-4000-8000-000000000082',
      '[{"product_version_id":"87000000-0000-4000-8000-000000000087","quantity":1}]'::jsonb,
      'phase4b-checkout-idempotency-0001'
    ) on conflict do nothing$sql$,
  'repeated checkout request with the same idempotency key is safe'
);
select is((select count(*) from phase4b_checkout_order_ids), 1::bigint, 'checkout replay returns the original order');
select throws_ok(
  $sql$select * from public.create_order_for_checkout(
    '82000000-0000-4000-8000-000000000082',
    '[{"product_version_id":"87000000-0000-4000-8000-000000000087","quantity":2}]'::jsonb,
    'phase4b-checkout-idempotency-0001'
  )$sql$,
  '23505', null, 'idempotency key cannot be reused with a different basket'
);
select is(
  (select o.total_minor from public.orders o join phase4b_checkout_order_ids t on t.order_id = o.id),
  1299::bigint, 'checkout total is derived from canonical product pricing'
);
select lives_ok(
  $sql$insert into public.payment_attempts (order_id, provider, amount_minor, currency, idempotency_key)
    select o.id, 'sandbox', o.total_minor, o.currency, 'phase4b-payment-attempt-key-0001'
    from public.orders o join phase4b_checkout_order_ids t on t.order_id = o.id$sql$,
  'checkout can create a provider-neutral payment attempt'
);
select lives_ok(
  $sql$update public.payment_attempts set status = 'pending'
    where order_id = (select order_id from phase4b_checkout_order_ids)$sql$,
  'payment attempt can enter pending state'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4b-verified-payment-event-0001', 'payment.succeeded', repeat('b',64), true,
    o.id, pa.id, o.total_minor, o.currency, 'phase4b-provider-charge-0001'
  from public.orders o
  join phase4b_checkout_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'verified event is durably inserted without retaining the raw payload'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-payment-event-0001'),
  true, 'verified payment event processes idempotently'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-payment-event-0001'),
  true, 'replaying a processed event returns safely without duplicate posting'
);
select is(
  (select o.status from public.orders o join phase4b_checkout_order_ids t on t.order_id = o.id),
  'paid', 'processor marks order paid only after verified event and ledger evidence'
);
select is(
  (select count(*) from public.ledger_transactions lt
   join phase4b_checkout_order_ids t on t.order_id = lt.order_id),
  1::bigint, 'processor posts exactly one immutable payment ledger entry'
);
select is(
  (select count(*) from public.entitlements e
   join public.order_items oi on oi.id = e.order_item_id
   join phase4b_checkout_order_ids t on t.order_id = oi.order_id),
  1::bigint, 'processor grants entitlement only after the order is paid'
);
select has_function('public', 'issue_download_grant', array['uuid','uuid'], 'server-only download grant issuance exists');
select ok(
  not has_function_privilege('authenticated', 'public.issue_download_grant(uuid,uuid)', 'EXECUTE'),
  'customers cannot invoke privileged grant issuance directly'
);
create temporary table phase4b_download_grant_ids(grant_id uuid primary key, expires_at timestamptz) on commit drop;
grant select on phase4b_download_grant_ids to authenticated;
select lives_ok(
  $sql$insert into phase4b_download_grant_ids
    select grant_id, expires_at from public.issue_download_grant(
      '82000000-0000-4000-8000-000000000082',
      (select e.id from public.entitlements e
       join public.order_items oi on oi.id = e.order_item_id
       join phase4b_checkout_order_ids t on t.order_id = oi.order_id)
    )$sql$,
  'paid entitlement receives a short-lived private download grant'
);
select is((select count(*) from phase4b_download_grant_ids), 1::bigint, 'one reusable download grant is issued');
select is(
  (select dg.max_downloads from public.download_grants dg
   join phase4b_download_grant_ids t on t.grant_id = dg.id),
  3, 'download grant has a bounded use count'
);
select is(
  (select we.processing_status from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-payment-event-0001'),
  'processed', 'verified payment event reaches a durable terminal state'
);
select lives_ok(
  $sql$set constraints orders_totals_guard, order_items_totals_guard immediate$sql$,
  'deferred order/item total constraints pass after atomic checkout'
);

-- Exercise the refund-success processor path, including ledger and state reconciliation.
select lives_ok(
  $sql$insert into public.refunds (id, order_id, payment_attempt_id, amount_minor, currency, reason, idempotency_key, requested_by)
    select '98000000-0000-4000-8000-000000000098', o.id, pa.id, 500, o.currency, 'Phase 4B test refund request', 'phase4b-refund-idem-0001', o.customer_id
    from public.orders o
    join phase4b_checkout_order_ids t on t.order_id = o.id
    join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'refund request is created against the paid sandbox order'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, refund_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4b-verified-refund-event-0001', 'refund.succeeded', repeat('c',64), true,
    r.order_id, r.payment_attempt_id, r.id, r.amount_minor, r.currency, 'phase4b-provider-refund-0001'
  from public.refunds r
  where r.id = '98000000-0000-4000-8000-000000000098'$sql$,
  'verified refund event is stored with exact refund amount and provider reference'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-refund-event-0001'),
  true, 'refund-success event processes'
);
select is(
  (select r.status from public.refunds r where r.id = '98000000-0000-4000-8000-000000000098'),
  'succeeded', 'refund becomes succeeded only after ledger evidence'
);
select is(
  (select pa.status from public.payment_attempts pa
   join phase4b_checkout_order_ids t on t.order_id = pa.order_id),
  'partially_refunded', 'payment attempt reconciles to partially refunded'
);
select is(
  (select o.status from public.orders o join phase4b_checkout_order_ids t on t.order_id = o.id),
  'partially_refunded', 'order reconciles to partially refunded'
);
select is(
  (select count(*) from public.ledger_transactions lt
   join public.refunds r on r.id = lt.refund_id
   where r.id = '98000000-0000-4000-8000-000000000098'),
  1::bigint, 'refund processor posts exactly one refund ledger entry'
);
select is(
  (select count(*) from public.financial_journal_batches b
   join public.refunds r on r.id = b.refund_id
   where r.id = '98000000-0000-4000-8000-000000000098'
     and b.source_type = 'refund' and b.status = 'posted'),
  1::bigint, 'verified refund produces exactly one posted accounting journal batch'
);
select is(
  (select b.provider_reference from public.financial_journal_batches b
   join public.refunds r on r.id = b.refund_id
   where r.id = '98000000-0000-4000-8000-000000000098'),
  'phase4b-provider-refund-0001', 'refund journal preserves the verified provider refund reference'
);
select ok(
  (select sum(e.amount_minor) filter (where e.side = 'debit')
          = sum(e.amount_minor) filter (where e.side = 'credit')
   from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join public.refunds r on r.id = b.refund_id
   where r.id = '98000000-0000-4000-8000-000000000098'),
  'verified refund accounting batch is balanced'
);
select is(
  (select we.processing_status from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-refund-event-0001'),
  'processed', 'refund event reaches a durable terminal state'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-refund-event-0001'),
  true, 'replaying a processed refund event is safe'
);
select is(
  (select count(*) from public.ledger_transactions lt
   join phase4b_checkout_order_ids t on t.order_id = lt.order_id),
  2::bigint, 'payment and refund replays do not duplicate ledger postings'
);
select lives_ok(
  $sql$insert into phase4b_download_grant_ids
    select grant_id, expires_at from public.issue_download_grant(
      '82000000-0000-4000-8000-000000000082',
      (select e.id from public.entitlements e
       join public.order_items oi on oi.id = e.order_item_id
       join phase4b_checkout_order_ids t on t.order_id = oi.order_id)
    ) on conflict (grant_id) do nothing$sql$,
  'partial refund keeps an active entitlement grant reusable'
);
select is((select count(*) from phase4b_download_grant_ids), 1::bigint, 'partial-refund grant reuse does not create duplicate grants');
set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000082', true);
select is(
  public.consume_download_grant((select grant_id from phase4b_download_grant_ids)),
  true, 'active entitlement remains downloadable after a partial refund'
);
reset role;

-- A full refund revokes entitlements and grants and prevents any new download consumption.
select lives_ok(
  $sql$insert into public.refunds (order_id, payment_attempt_id, amount_minor, currency, reason, idempotency_key, requested_by)
    select o.id, pa.id, 799, o.currency, 'Final Phase 4B test refund', 'phase4b-final-refund-idempotency-0001', o.customer_id
    from public.orders o
    join phase4b_checkout_order_ids t on t.order_id = o.id
    join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'final refund request reserves the remaining refundable amount'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, refund_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4b-verified-final-refund-event-0001', 'refund.succeeded', repeat('e',64), true,
    r.order_id, r.payment_attempt_id, r.id, r.amount_minor, r.currency, 'phase4b-provider-final-refund-0001'
  from public.refunds r
  where r.idempotency_key = 'phase4b-final-refund-idempotency-0001'$sql$,
  'final refund event is recorded with matching provider evidence'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-final-refund-event-0001'),
  true, 'final refund event processes'
);
select is(
  (select r.status from public.refunds r where r.idempotency_key = 'phase4b-final-refund-idempotency-0001'),
  'succeeded', 'final refund is settled in the ledger-backed state machine'
);
select is(
  (select pa.status from public.payment_attempts pa
   join phase4b_checkout_order_ids t on t.order_id = pa.order_id),
  'refunded', 'fully refunded payment attempt reaches refunded state'
);
select is(
  (select o.status from public.orders o join phase4b_checkout_order_ids t on t.order_id = o.id),
  'refunded', 'fully refunded order reaches refunded state'
);
select is(
  (select e.status from public.entitlements e
   join public.order_items oi on oi.id = e.order_item_id
   join phase4b_checkout_order_ids t on t.order_id = oi.order_id),
  'revoked', 'full refund revokes purchased entitlements'
);
select ok(
  (select dg.revoked_at is not null from public.download_grants dg
   join phase4b_download_grant_ids t on t.grant_id = dg.id),
  'full refund revokes outstanding download grants'
);
select is(
  (select r.provider_refund_reference from public.refunds r
   where r.idempotency_key = 'phase4b-final-refund-idempotency-0001'),
  'phase4b-provider-final-refund-0001', 'provider refund reference is retained for reconciliation'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000082', true);
select is(
  public.consume_download_grant((select grant_id from phase4b_download_grant_ids)),
  false, 'revoked entitlement cannot consume a download grant'
);
reset role;
select is(
  (select we.processing_status from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-final-refund-event-0001'),
  'processed', 'final refund event reaches a durable terminal state'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-final-refund-event-0001'),
  true, 'replaying final refund event is safe'
);
select is(
  (select count(*) from public.ledger_transactions lt
   join phase4b_checkout_order_ids t on t.order_id = lt.order_id),
  3::bigint, 'full refund replay does not duplicate ledger postings'
);

-- Exercise the failed-payment path and prove that it never grants an entitlement.
create temporary table phase4b_failed_order_ids(order_id uuid primary key) on commit drop;
set constraints orders_totals_guard, order_items_totals_guard deferred;
select lives_ok(
  $sql$insert into phase4b_failed_order_ids
    select order_id from public.create_order_for_checkout(
      '82000000-0000-4000-8000-000000000082',
      '[{"product_version_id":"87000000-0000-4000-8000-000000000087","quantity":1}]'::jsonb,
      'phase4b-failed-checkout-idempotency-0001'
    )$sql$,
  'failed-payment test order is created atomically'
);
select lives_ok(
  $sql$set constraints orders_totals_guard, order_items_totals_guard immediate$sql$,
  'failed-payment order/item totals are valid'
);
select lives_ok(
  $sql$insert into public.payment_attempts (order_id, provider, amount_minor, currency, idempotency_key)
    select o.id, 'sandbox', o.total_minor, o.currency, 'phase4b-failed-attempt-key-0001'
    from public.orders o join phase4b_failed_order_ids t on t.order_id = o.id$sql$,
  'failed-payment attempt is created'
);
select lives_ok(
  $sql$update public.payment_attempts set status = 'pending'
    where order_id = (select order_id from phase4b_failed_order_ids)$sql$,
  'failed-payment attempt enters pending state'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4b-verified-failed-event-0001', 'payment.failed', repeat('d',64), true,
    o.id, pa.id, o.total_minor, o.currency, 'phase4b-provider-failed-ref-0001'
  from public.orders o
  join phase4b_failed_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'verified failed-payment event is durably recorded'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-failed-event-0001'),
  true, 'failed-payment event processes'
);
select is(
  (select o.status from public.orders o join phase4b_failed_order_ids t on t.order_id = o.id),
  'payment_failed', 'failed payment transitions order to payment_failed'
);
select is(
  (select pa.status from public.payment_attempts pa
   join phase4b_failed_order_ids t on t.order_id = pa.order_id),
  'failed', 'failed payment transitions the attempt to failed'
);
select is(
  (select count(*) from public.entitlements e
   join public.order_items oi on oi.id = e.order_item_id
   join phase4b_failed_order_ids t on t.order_id = oi.order_id),
  0::bigint, 'failed payment never creates an entitlement'
);
select is(
  (select we.processing_status from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-failed-event-0001'),
  'processed', 'failed-payment event reaches a durable terminal state'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4b-verified-failed-event-0001'),
  true, 'replaying a processed failure event is safe'
);


-- Phase 4C: reconcile gross payment postings and allocate proceeds only under independently approved terms.
select has_table('public', 'financial_journal_batches', 'immutable financial journal batches exist');
select has_table('public', 'financial_journal_entries', 'financial journal entries exist');
select has_table('public', 'seller_fee_schedules', 'seller fee schedules require independent approval');
select has_table('public', 'order_proceeds_allocations', 'seller proceeds allocations are recorded per order item');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.financial_journal_batches'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.financial_journal_entries'::regclass),
  'financial journal tables have RLS enabled'
);
select ok(
  not has_table_privilege('anon', 'public.financial_journal_batches', 'SELECT')
  and not has_table_privilege('authenticated', 'public.financial_journal_batches', 'SELECT')
  and not has_table_privilege('authenticated', 'public.financial_journal_entries', 'INSERT'),
  'financial journal data is not exposed to public or customer roles'
);
select ok(
  not has_function_privilege('authenticated', 'public.allocate_order_proceeds(uuid,text,text)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.allocate_order_proceeds(uuid,text,text)', 'EXECUTE'),
  'proceeds allocation is restricted to the trusted server role'
);

create temporary table phase4c_allocation_order_ids(order_id uuid primary key) on commit drop;
set constraints orders_totals_guard, order_items_totals_guard deferred;
select lives_ok(
  $sql$insert into phase4c_allocation_order_ids
    select order_id from public.create_order_for_checkout(
      '82000000-0000-4000-8000-000000000082',
      '[{"product_version_id":"87000000-0000-4000-8000-000000000087","quantity":1}]'::jsonb,
      'phase4c-allocation-idempotency-0001'
    )$sql$,
  'accounting fixture order is created from canonical catalogue pricing'
);
select lives_ok(
  $sql$set constraints orders_totals_guard, order_items_totals_guard immediate$sql$,
  'accounting fixture order and item totals reconcile'
);
select lives_ok(
  $sql$insert into public.payment_attempts (order_id, provider, amount_minor, currency, idempotency_key)
    select o.id, 'sandbox', o.total_minor, o.currency, 'phase4c-payment-attempt-key-0001'
    from public.orders o join phase4c_allocation_order_ids t on t.order_id = o.id$sql$,
  'accounting fixture payment attempt is created'
);
select lives_ok(
  $sql$update public.payment_attempts set status = 'pending'
    where order_id = (select order_id from phase4c_allocation_order_ids)$sql$,
  'accounting fixture payment enters pending state'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4c-verified-payment-event-0001', 'payment.succeeded', repeat('e',64), true,
    o.id, pa.id, o.total_minor, o.currency, 'phase4c-provider-charge-0001'
  from public.orders o
  join phase4c_allocation_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'accounting fixture payment event carries verified matching financial evidence'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4c-verified-payment-event-0001'),
  true, 'accounting fixture payment processes through the verified event processor'
);
select is(
  (select count(*) from public.financial_journal_batches b
   join phase4c_allocation_order_ids t on t.order_id = b.order_id
   where b.source_type = 'payment' and b.status = 'posted'),
  1::bigint, 'verified payment automatically creates exactly one posted accounting batch'
);
select ok(
  (select sum(e.amount_minor) filter (where e.side = 'debit')
          = sum(e.amount_minor) filter (where e.side = 'credit')
   from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join phase4c_allocation_order_ids t on t.order_id = b.order_id
   where b.source_type = 'payment'),
  'gross payment accounting batch is balanced'
);

insert into public.user_roles (user_id, role, granted_by)
values
  ('83000000-0000-4000-8000-000000000083', 'admin', null),
  ('84000000-0000-4000-8000-000000000084', 'admin', '83000000-0000-4000-8000-000000000083')
on conflict (user_id, role) do nothing;

select lives_ok(
  $sql$insert into public.seller_fee_schedules (seller_id, platform_fee_bps)
    values ('81000000-0000-4000-8000-000000000081', 1000)$sql$,
  'seller fee terms start as pending and are not self-approved'
);
select lives_ok(
  $sql$update public.seller_fee_schedules
    set status = 'active', approved_by = '83000000-0000-4000-8000-000000000083', approved_at = now()
    where seller_id = '81000000-0000-4000-8000-000000000081' and status = 'pending' and platform_fee_bps = 1000$sql$,
  'independent reviewer activates the seller fee schedule'
);
create temporary table phase4c_allocation_batch_ids(batch_id uuid primary key) on commit drop;
select lives_ok(
  $sql$insert into phase4c_allocation_batch_ids
    select public.allocate_order_proceeds(
      (select order_id from phase4c_allocation_order_ids),
      'phase4c-allocation-posting-key-0001',
      repeat('f',64)
    )$sql$,
  'proceeds allocate atomically using independently approved fee terms and evidence'
);
select is(
  (select count(*) from public.order_proceeds_allocations opa
   join phase4c_allocation_order_ids t on t.order_id = opa.order_id),
  1::bigint, 'each order item receives exactly one proceeds allocation'
);
select is(
  (select opa.gross_minor from public.order_proceeds_allocations opa
   join phase4c_allocation_order_ids t on t.order_id = opa.order_id),
  1299::bigint, 'allocation preserves the immutable gross item amount'
);
select is(
  (select opa.platform_fee_minor from public.order_proceeds_allocations opa
   join phase4c_allocation_order_ids t on t.order_id = opa.order_id),
  129::bigint, 'platform commission uses integer basis-point arithmetic'
);
select is(
  (select opa.seller_net_minor from public.order_proceeds_allocations opa
   join phase4c_allocation_order_ids t on t.order_id = opa.order_id),
  1170::bigint, 'seller payable equals gross less the approved platform fee'
);
select is(
  (select b.status from public.financial_journal_batches b
   join phase4c_allocation_batch_ids t on t.batch_id = b.id),
  'posted', 'proceeds allocation batch is posted only after balanced journal validation'
);
select ok(
  (select sum(e.amount_minor) filter (where e.side = 'debit')
          = sum(e.amount_minor) filter (where e.side = 'credit')
   from public.financial_journal_entries e
   join phase4c_allocation_batch_ids t on t.batch_id = e.batch_id),
  'proceeds allocation journal balances seller payable and platform revenue'
);
select is(
  public.allocate_order_proceeds(
    (select order_id from phase4c_allocation_order_ids),
    'phase4c-allocation-posting-key-0001',
    repeat('f',64)
  ),
  (select batch_id from phase4c_allocation_batch_ids),
  'same allocation idempotency key and evidence returns the original journal batch'
);
select throws_ok(
  $sql$select public.allocate_order_proceeds(
    (select order_id from phase4c_allocation_order_ids),
    'phase4c-allocation-different-key-0001',
    repeat('f',64)
  )$sql$,
  '23514', null, 'an allocated order cannot be reposted with a different idempotency key'
);
select throws_ok(
  $sql$update public.financial_journal_batches set status = 'draft'
    where id = (select batch_id from phase4c_allocation_batch_ids)$sql$,
  '23514', null, 'posted financial batches cannot be reopened or rewritten'
);
select throws_ok(
  $sql$delete from public.financial_journal_entries
    where batch_id = (select batch_id from phase4c_allocation_batch_ids)$sql$,
  '23514', null, 'financial journal entries cannot be deleted'
);
select throws_ok(
  $sql$update public.order_proceeds_allocations set gross_minor = 1
    where order_id = (select order_id from phase4c_allocation_order_ids)$sql$,
  '23514', null, 'proceeds allocation evidence is immutable'
);
select lives_ok(
  $sql$insert into public.seller_fee_schedules (seller_id, platform_fee_bps)
    values ('81000000-0000-4000-8000-000000000081', 2000)$sql$,
  'replacement fee terms remain pending until independently approved'
);
select throws_ok(
  $sql$update public.seller_fee_schedules
    set status = 'active', approved_by = seller_id, approved_at = now()
    where seller_id = '81000000-0000-4000-8000-000000000081' and status = 'pending' and platform_fee_bps = 2000$sql$,
  '23514', null, 'seller cannot approve their own commercial fee schedule'
);
select lives_ok(
  $sql$update public.seller_fee_schedules
    set status = 'revoked', revoked_by = '84000000-0000-4000-8000-000000000084', revoked_at = now()
    where seller_id = '81000000-0000-4000-8000-000000000081' and status = 'active' and platform_fee_bps = 1000$sql$,
  'independent reviewer can revoke a fee schedule without rewriting its approval evidence'
);
select is(
  (select status from public.seller_fee_schedules
   where seller_id = '81000000-0000-4000-8000-000000000081' and platform_fee_bps = 1000),
  'revoked', 'revoked fee schedule is no longer eligible for future allocations'
);

-- A trusted server role must not be able to post arbitrary balanced financial batches.
insert into public.financial_journal_batches (
  source_type, source_key, idempotency_key, order_id, payment_attempt_id,
  provider, provider_reference, currency, evidence_sha256
)
select 'payment', 'legacy-ledger:payment:test-fake-reference-0001',
  'test-fake-payment-posting-0001', o.id, pa.id, 'sandbox',
  'test-fake-provider-reference', o.currency, repeat('a',64)
from public.orders o
join phase4c_allocation_order_ids t on t.order_id = o.id
join public.payment_attempts pa on pa.order_id = o.id;
insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
select b.id, 'provider_clearing', 'debit', 1299, 'USD', 'Synthetic bypass attempt'
from public.financial_journal_batches b
where b.source_key = 'legacy-ledger:payment:test-fake-reference-0001';
insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
select b.id, 'unallocated_order_liability', 'credit', 1299, 'USD', 'Synthetic bypass attempt'
from public.financial_journal_batches b
where b.source_key = 'legacy-ledger:payment:test-fake-reference-0001';
select throws_ok(
  $sql$update public.financial_journal_batches set status = 'posted'
    where source_key = 'legacy-ledger:payment:test-fake-reference-0001'$sql$,
  '23514', null, 'balanced payment batch cannot post without its own verified ledger and webhook evidence'
);

insert into public.financial_journal_batches (
  source_type, source_key, idempotency_key, currency, evidence_sha256
) values (
  'manual_adjustment', 'test-manual-adjustment-0001',
  'test-manual-adjustment-0001', 'USD', repeat('b',64)
);
insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
select b.id, 'platform_cash', 'debit', 100, 'USD', 'Synthetic unapproved adjustment'
from public.financial_journal_batches b
where b.source_key = 'test-manual-adjustment-0001';
insert into public.financial_journal_entries (batch_id, account, side, amount_minor, currency, memo)
select b.id, 'platform_revenue', 'credit', 100, 'USD', 'Synthetic unapproved adjustment'
from public.financial_journal_batches b
where b.source_key = 'test-manual-adjustment-0001';
select throws_ok(
  $sql$update public.financial_journal_batches set status = 'posted'
    where source_key = 'test-manual-adjustment-0001'$sql$,
  '23514', null, 'manual financial adjustments remain blocked until a dedicated approved workflow exists'
);


-- Phase 4D1: a refund after proceeds allocation requires independently approved item-level reversal.
select has_table('public', 'refund_reversal_requests', 'refund reversal requests preserve independent approval evidence');
select has_table('public', 'refund_reversal_lines', 'refund reversal lines reconcile item gross, fee, seller payable and tax');
select ok(
  not has_function_privilege('authenticated', 'public.approve_refund_reversal_request(uuid,uuid)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.approve_refund_reversal_request(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.reject_refund_reversal_request(uuid,uuid)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.reject_refund_reversal_request(uuid,uuid)', 'EXECUTE')
  and not has_table_privilege('service_role', 'public.refund_reversal_requests', 'UPDATE'),
  'refund reversal state transitions use restricted server RPCs rather than direct table updates'
);
select lives_ok(
  $sql$insert into public.refunds (
    id, order_id, payment_attempt_id, amount_minor, currency, status, reason, idempotency_key, requested_by
  )
  select '99000000-0000-4000-8000-000000000099', o.id, pa.id, 333, o.currency, 'pending',
    'Phase 4D1 approved partial refund', 'test-refund-reversal-0001', o.customer_id
  from public.orders o
  join phase4c_allocation_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'partial refund fixture is created against an already allocated paid order'
);
create temporary table phase4d1_request_ids(request_id uuid primary key, refund_id uuid not null) on commit drop;
select lives_ok(
  $sql$with request_row as (
    insert into public.refund_reversal_requests (
      refund_id, order_id, amount_minor, currency, evidence_sha256, reason, requested_by
    )
    select r.id, r.order_id, r.amount_minor, r.currency, repeat('c',64),
      'Approved item-level reversal required before refund', '83000000-0000-4000-8000-000000000083'
    from public.refunds r where r.id = '99000000-0000-4000-8000-000000000099'
    returning id, refund_id
  )
  insert into phase4d1_request_ids select id, refund_id from request_row$sql$,
  'reversal request is created by a database-owned admin'
);
select lives_ok(
  $sql$insert into public.refund_reversal_lines (
    request_id, refund_id, order_id, order_item_id, seller_id, fee_schedule_id,
    gross_refund_minor, platform_fee_reversal_minor, seller_payable_reversal_minor, tax_reversal_minor, currency
  )
  select rr.id, rr.refund_id, opa.order_id, opa.order_item_id, opa.seller_id, opa.fee_schedule_id,
    333, 33, 300, 0, opa.currency
  from phase4d1_request_ids ids
  join public.refund_reversal_requests rr on rr.id = ids.request_id
  join public.order_proceeds_allocations opa on opa.order_id = rr.order_id$sql$,
  'item-level reversal line matches original seller proceeds allocation and fee arithmetic'
);
select throws_ok(
  $sql$select public.approve_refund_reversal_request(
    (select request_id from phase4d1_request_ids),
    '83000000-0000-4000-8000-000000000083'
  )$sql$,
  '23514', null, 'refund reversal requester cannot approve their own request'
);
select is(
  public.approve_refund_reversal_request(
    (select request_id from phase4d1_request_ids),
    '84000000-0000-4000-8000-000000000084'
  ),
  (select request_id from phase4d1_request_ids),
  'a distinct database-owned admin approves the item-level refund reversal'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, refund_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4d1-verified-refund-event-0001', 'refund.succeeded', repeat('d',64), true,
    r.order_id, r.payment_attempt_id, r.id, r.amount_minor, r.currency, 'phase4d1-provider-refund-0001'
  from public.refunds r where r.id = '99000000-0000-4000-8000-000000000099'$sql$,
  'verified refund webhook is stored with provider reference and payload evidence'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4d1-verified-refund-event-0001'),
  true, 'refund webhook posts approved reversal before posting refund outflow'
);
select is(
  (select public.process_payment_webhook_event(we.id)
   from public.payment_webhook_events we
   where we.provider_event_id = 'phase4d1-verified-refund-event-0001'),
  true, 'reprocessing a completed refund event is idempotent'
);
select is(
  (select rr.status from public.refund_reversal_requests rr
   join phase4d1_request_ids ids on ids.request_id = rr.id),
  'posted', 'approved reversal request is linked to its immutable posted journal'
);
select is(
  (select count(*) from public.financial_journal_batches b
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund_reversal' and b.status = 'posted'),
  1::bigint, 'exactly one reversal journal is posted for the refund'
);
select is(
  (select b.provider_reference from public.financial_journal_batches b
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund_reversal'),
  'phase4d1-provider-refund-0001', 'reversal journal preserves the verified provider refund reference'
);
select ok(
  (select sum(e.amount_minor) filter (where e.side = 'debit')
          = sum(e.amount_minor) filter (where e.side = 'credit')
   from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund_reversal'),
  'refund reversal journal is balanced'
);
select is(
  (select sum(e.amount_minor) from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund_reversal' and e.account = 'seller_payable' and e.side = 'debit'),
  300::numeric, 'reversal debits the seller payable by the approved seller-net amount'
);
select is(
  (select sum(e.amount_minor) from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund_reversal' and e.account = 'platform_revenue' and e.side = 'debit'),
  33::numeric, 'reversal debits the approved commission reversal'
);
select is(
  (select sum(e.amount_minor) from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund_reversal' and e.account = 'unallocated_order_liability' and e.side = 'credit'),
  333::numeric, 'reversal restores gross proceeds liability before the refund outflow'
);
select is(
  (select count(*) from public.financial_journal_batches b
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund' and b.status = 'posted'),
  1::bigint, 'verified refund outflow posts exactly one journal after the reversal'
);
select ok(
  (select sum(e.amount_minor) filter (where e.side = 'debit')
          = sum(e.amount_minor) filter (where e.side = 'credit')
   from public.financial_journal_entries e
   join public.financial_journal_batches b on b.id = e.batch_id
   join phase4d1_request_ids ids on ids.refund_id = b.refund_id
   where b.source_type = 'refund'),
  'refund outflow journal remains balanced after proceeds reversal'
);
select is(
  (select r.status from public.refunds r
   join phase4d1_request_ids ids on ids.refund_id = r.id),
  'succeeded', 'refund status advances only after reversal and refund journals post'
);
select is(
  (select o.status from public.orders o
   where o.id = (
     select rr.order_id from public.refund_reversal_requests rr
     join phase4d1_request_ids ids on ids.request_id = rr.id
   )),
  'partially_refunded', 'partial refund updates the order state after accounting is posted'
);
select is(
  (select count(*) from public.ledger_transactions lt
   join phase4d1_request_ids ids on ids.refund_id = lt.refund_id
   where lt.source_type = 'refund'),
  1::bigint, 'verified reversal-backed refund creates exactly one legacy transfer ledger row'
);

-- Partial refunds must reverse commission using cumulative rounding rather than isolated per-refund rounding.
select lives_ok(
  $sql$insert into public.refunds (
    id, order_id, payment_attempt_id, amount_minor, currency, status, reason, idempotency_key, requested_by
  )
  select '99200000-0000-4000-8000-000000000099', o.id, pa.id, 667, o.currency, 'pending',
    'Cumulative commission rounding fixture', 'test-refund-reversal-rounding-0001', o.customer_id
  from public.orders o
  join phase4c_allocation_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'second partial refund is created for cumulative commission rounding'
);
create temporary table phase4d1_rounding_request_ids(request_id uuid primary key, refund_id uuid not null) on commit drop;
select lives_ok(
  $sql$with request_row as (
    insert into public.refund_reversal_requests (
      refund_id, order_id, amount_minor, currency, evidence_sha256, reason, requested_by
    )
    select r.id, r.order_id, r.amount_minor, r.currency, repeat('f',64),
      'Cumulative commission rounding reversal', '83000000-0000-4000-8000-000000000083'
    from public.refunds r where r.id = '99200000-0000-4000-8000-000000000099'
    returning id, refund_id
  )
  insert into phase4d1_rounding_request_ids select id, refund_id from request_row$sql$,
  'second partial refund reversal request is recorded'
);
select lives_ok(
  $sql$insert into public.refund_reversal_lines (
    request_id, refund_id, order_id, order_item_id, seller_id, fee_schedule_id,
    gross_refund_minor, platform_fee_reversal_minor, seller_payable_reversal_minor, tax_reversal_minor, currency
  )
  select rr.id, rr.refund_id, opa.order_id, opa.order_item_id, opa.seller_id, opa.fee_schedule_id,
    667, 67, 600, 0, opa.currency
  from phase4d1_rounding_request_ids ids
  join public.refund_reversal_requests rr on rr.id = ids.request_id
  join public.order_proceeds_allocations opa on opa.order_id = rr.order_id$sql$,
  'partial refund commission is calculated from cumulative refunded gross, avoiding isolated-rounding drift'
);
select is(
  public.reject_refund_reversal_request(
    (select request_id from phase4d1_rounding_request_ids),
    '84000000-0000-4000-8000-000000000084'
  ),
  (select request_id from phase4d1_rounding_request_ids),
  'rounding fixture can be rejected after its line arithmetic is verified'
);
create temporary table phase4d1_retry_request_ids(request_id uuid primary key) on commit drop;
select lives_ok(
  $sql$with request_row as (
    insert into public.refund_reversal_requests (
      refund_id, order_id, amount_minor, currency, evidence_sha256, reason, requested_by
    )
    select r.id, r.order_id, r.amount_minor, r.currency, repeat('a',64),
      'Retry after prior reversal rejection', '83000000-0000-4000-8000-000000000083'
    from public.refunds r where r.id = '99200000-0000-4000-8000-000000000099'
    returning id
  )
  insert into phase4d1_retry_request_ids select id from request_row$sql$,
  'a rejected immutable reversal request can be retried with a new audit record'
);
select is(
  public.reject_refund_reversal_request(
    (select request_id from phase4d1_retry_request_ids),
    '84000000-0000-4000-8000-000000000084'
  ),
  (select request_id from phase4d1_retry_request_ids),
  'replacement reversal request remains independently rejectable'
);

-- A second reversal cannot consume more than the remaining allocated item gross/fee/net.
select lives_ok(
  $sql$insert into public.refunds (
    id, order_id, payment_attempt_id, amount_minor, currency, status, reason, idempotency_key, requested_by
  )
  select '99100000-0000-4000-8000-000000000099', o.id, pa.id, 1000, o.currency, 'pending',
    'Over-allocation rejection fixture', 'test-refund-reversal-overflow-0001', o.customer_id
  from public.orders o
  join phase4c_allocation_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'over-refund fixture is created for cumulative allocation guard'
);
select lives_ok(
  $sql$insert into public.refund_reversal_requests (
    refund_id, order_id, amount_minor, currency, evidence_sha256, reason, requested_by
  )
  select r.id, r.order_id, r.amount_minor, r.currency, repeat('e',64),
    'Reject reversal that exceeds remaining allocated proceeds', '83000000-0000-4000-8000-000000000083'
  from public.refunds r where r.id = '99100000-0000-4000-8000-000000000099'$sql$,
  'over-refund request is recorded pending review'
);
select throws_ok(
  $sql$insert into public.refund_reversal_lines (
    request_id, refund_id, order_id, order_item_id, seller_id, fee_schedule_id,
    gross_refund_minor, platform_fee_reversal_minor, seller_payable_reversal_minor, tax_reversal_minor, currency
  )
  select rr.id, rr.refund_id, opa.order_id, opa.order_item_id, opa.seller_id, opa.fee_schedule_id,
    1000, 100, 900, 0, opa.currency
  from public.refund_reversal_requests rr
  join public.order_proceeds_allocations opa on opa.order_id = rr.order_id
  where rr.refund_id = '99100000-0000-4000-8000-000000000099'$sql$,
  '23514', null, 'cumulative refund reversal cannot exceed original allocated item gross, fee or seller payable'
);
select is(
  public.reject_refund_reversal_request(
    (select id from public.refund_reversal_requests where refund_id = '99100000-0000-4000-8000-000000000099'),
    '84000000-0000-4000-8000-000000000084'
  ),
  (select id from public.refund_reversal_requests where refund_id = '99100000-0000-4000-8000-000000000099'),
  'independent admin can reject a reversal request and release its reserved allocation'
);
select is(
  (select status from public.refund_reversal_requests where refund_id = '99100000-0000-4000-8000-000000000099'),
  'rejected', 'rejected reversal request is retained as immutable audit history'
);

-- Financial journal source validation must preserve seller attribution, not only aggregate balance.
select lives_ok(
  $sql$insert into public.refunds (
    id, order_id, payment_attempt_id, amount_minor, currency, status, reason, idempotency_key, requested_by
  )
  select '99300000-0000-4000-8000-000000000099', o.id, pa.id, 100, o.currency, 'pending',
    'Misassigned seller journal fixture', 'test-refund-reversal-seller-guard-0001', o.customer_id
  from public.orders o
  join phase4c_allocation_order_ids t on t.order_id = o.id
  join public.payment_attempts pa on pa.order_id = o.id$sql$,
  'refund fixture is created for seller-attribution guard'
);
create temporary table phase4d1_misassigned_request_ids(request_id uuid primary key, refund_id uuid not null) on commit drop;
select lives_ok(
  $sql$with request_row as (
    insert into public.refund_reversal_requests (
      refund_id, order_id, amount_minor, currency, evidence_sha256, reason, requested_by
    )
    select r.id, r.order_id, r.amount_minor, r.currency, repeat('a',64),
      'Seller attribution must match original allocation', '83000000-0000-4000-8000-000000000083'
    from public.refunds r where r.id = '99300000-0000-4000-8000-000000000099'
    returning id, refund_id
  )
  insert into phase4d1_misassigned_request_ids select id, refund_id from request_row$sql$,
  'seller-attribution reversal request is recorded'
);
select lives_ok(
  $sql$insert into public.refund_reversal_lines (
    request_id, refund_id, order_id, order_item_id, seller_id, fee_schedule_id,
    gross_refund_minor, platform_fee_reversal_minor, seller_payable_reversal_minor, tax_reversal_minor, currency
  )
  select rr.id, rr.refund_id, opa.order_id, opa.order_item_id, opa.seller_id, opa.fee_schedule_id,
    100, 10, 90, 0, opa.currency
  from phase4d1_misassigned_request_ids ids
  join public.refund_reversal_requests rr on rr.id = ids.request_id
  join public.order_proceeds_allocations opa on opa.order_id = rr.order_id$sql$,
  'approved reversal line matches the original seller allocation'
);
select is(
  public.approve_refund_reversal_request(
    (select request_id from phase4d1_misassigned_request_ids),
    '84000000-0000-4000-8000-000000000084'
  ),
  (select request_id from phase4d1_misassigned_request_ids),
  'distinct admin approves seller-attribution guard fixture'
);
select lives_ok(
  $sql$insert into public.payment_webhook_events (
    provider, provider_event_id, event_type, payload_sha256, signature_verified,
    order_id, payment_attempt_id, refund_id, amount_minor, currency, provider_reference
  )
  select 'sandbox', 'phase4d1-misassigned-refund-event-0001', 'refund.succeeded', repeat('b',64), true,
    r.order_id, r.payment_attempt_id, r.id, r.amount_minor, r.currency, 'phase4d1-provider-refund-misassigned'
  from public.refunds r where r.id = '99300000-0000-4000-8000-000000000099'$sql$,
  'verified event fixture is stored for seller-attribution guard'
);
select lives_ok(
  $sql$update public.payment_webhook_events set processing_status = 'processing'
    where provider_event_id = 'phase4d1-misassigned-refund-event-0001'$sql$,
  'verified event enters the processor state for guarded journal validation'
);
create temporary table phase4d1_bad_seller_batch_ids(batch_id uuid primary key) on commit drop;
select lives_ok(
  $sql$with batch_row as (
    insert into public.financial_journal_batches (
      source_type, source_key, idempotency_key, order_id, payment_attempt_id, refund_id,
      provider, provider_reference, currency, evidence_sha256
    )
    select 'refund_reversal', 'phase4d1-misassigned-seller-batch-0001',
      'phase4d1-misassigned-seller-idem-0001', r.order_id, r.payment_attempt_id, r.id,
      'sandbox', 'phase4d1-provider-refund-misassigned', r.currency, repeat('b',64)
    from public.refunds r where r.id = '99300000-0000-4000-8000-000000000099'
    returning id
  )
  insert into phase4d1_bad_seller_batch_ids select id from batch_row$sql$,
  'balanced draft reversal journal is created with a deliberately wrong seller recipient'
);
select lives_ok(
  $sql$insert into public.financial_journal_entries (
    batch_id, account, side, amount_minor, currency, seller_id, order_item_id, memo
  )
  select ids.batch_id, 'seller_payable', 'debit', 90, 'USD',
    '84000000-0000-4000-8000-000000000084', opa.order_item_id, 'Deliberately misassigned seller payable'
  from phase4d1_bad_seller_batch_ids ids
  join public.order_proceeds_allocations opa on opa.order_id = (
    select rr.order_id from public.refund_reversal_requests rr
    join phase4d1_misassigned_request_ids req on req.request_id = rr.id
  );
  insert into public.financial_journal_entries (
    batch_id, account, side, amount_minor, currency, memo
  )
  select batch_id, 'platform_revenue', 'debit', 10, 'USD', 'Commission reversal'
  from phase4d1_bad_seller_batch_ids;
  insert into public.financial_journal_entries (
    batch_id, account, side, amount_minor, currency, memo
  )
  select batch_id, 'unallocated_order_liability', 'credit', 100, 'USD', 'Gross reversal'
  from phase4d1_bad_seller_batch_ids$sql$,
  'balanced reversal entries are inserted before posting validation'
);
select throws_ok(
  $sql$update public.financial_journal_batches set status = 'posted'
    where id = (select batch_id from phase4d1_bad_seller_batch_ids)$sql$,
  '23514', null, 'financial journal rejects a balanced reversal assigned to the wrong seller'
);

select * from finish();
rollback;
