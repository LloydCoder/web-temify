begin;
select plan(30);

select has_table('public', 'payment_disputes', 'private payment dispute records exist');
select has_table('public', 'payment_dispute_events', 'payment dispute event history exists');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_disputes'::regclass), 'payment disputes have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_dispute_events'::regclass), 'dispute events have RLS enabled');
select ok(not has_table_privilege('anon', 'public.payment_disputes', 'SELECT'), 'anonymous users cannot read disputes');
select ok(not has_table_privilege('authenticated', 'public.payment_disputes', 'SELECT'), 'customers cannot read disputes');
select ok(has_table_privilege('service_role', 'public.payment_disputes', 'SELECT'), 'trusted server can read dispute records');
select ok(not has_table_privilege('service_role', 'public.payment_disputes', 'UPDATE'), 'trusted server cannot bypass dispute RPC');
select ok(has_function_privilege('service_role', 'public.apply_verified_payment_dispute_event(text,text,text,text,text,uuid,uuid,bigint,text,timestamptz,text,uuid)', 'EXECUTE'), 'trusted server can apply verified dispute events');
select ok(not has_function_privilege('authenticated', 'public.apply_verified_payment_dispute_event(text,text,text,text,text,uuid,uuid,bigint,text,timestamptz,text,uuid)', 'EXECUTE'), 'authenticated users cannot apply dispute events');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values (
  '91000000-0000-4000-8000-000000000191',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'dispute-customer@example.test', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
);

insert into public.orders (
  id, customer_id, status, currency, subtotal_minor, tax_minor, idempotency_key
) values (
  'a1000000-0000-4000-8000-000000000101',
  '91000000-0000-4000-8000-000000000191',
  'paid', 'USD', 10000, 0, 'phase5i-dispute-order-key-001'
);

insert into public.payment_attempts (
  id, order_id, provider, status, amount_minor, currency, idempotency_key, provider_reference
) values (
  'b1000000-0000-4000-8000-000000000101',
  'a1000000-0000-4000-8000-000000000101',
  'sandbox', 'succeeded', 10000, 'USD', 'phase5i-dispute-payment-key-001', 'sandbox-payment-dispute-001'
);

insert into public.payment_webhook_events (
  id, provider, provider_event_id, event_type, payload_sha256, signature_verified,
  order_id, payment_attempt_id
) values
  ('c1000000-0000-4000-8000-000000000101', 'sandbox', 'phase5i-event-open-001',
   'charge.dispute.created', repeat('a', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000102', 'sandbox', 'phase5i-event-needs-evidence-001',
   'charge.dispute.updated', repeat('b', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000103', 'sandbox', 'phase5i-event-evidence-submitted-001',
   'charge.dispute.updated', repeat('c', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000104', 'sandbox', 'phase5i-event-won-001',
   'charge.dispute.closed', repeat('d', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000105', 'sandbox', 'phase5i-event-close-001',
   'charge.dispute.closed', repeat('e', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000106', 'sandbox', 'phase5i-event-open-002',
   'charge.dispute.created', repeat('f', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000107', 'sandbox', 'phase5i-event-lost-002',
   'charge.dispute.closed', repeat('1', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000108', 'sandbox', 'phase5i-event-close-002',
   'charge.dispute.closed', repeat('2', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101'),
  ('c1000000-0000-4000-8000-000000000109', 'sandbox', 'phase5i-event-lost-after-close-002',
   'charge.dispute.closed', repeat('3', 64), true,
   'a1000000-0000-4000-8000-000000000101', 'b1000000-0000-4000-8000-000000000101');

create temporary table phase5i_dispute_fixture (
  dispute_id uuid primary key,
  status text not null
) on commit drop;

select lives_ok(
  $sql$insert into phase5i_dispute_fixture
  select dispute_id, status
  from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-open-001', 'sandbox-dispute-001',
    'charge.dispute.created', 'opened',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', now() + interval '5 days', 'needs_response',
    'd1000000-0000-4000-8000-000000000101'
  )$sql$,
  'verified dispute-created event opens a private dispute record'
);
select is((select status from phase5i_dispute_fixture), 'open', 'new dispute begins open');

select is(
  (select duplicate from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-open-001', 'sandbox-dispute-001',
    'charge.dispute.created', 'opened',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', now() + interval '5 days', 'needs_response',
    'd1000000-0000-4000-8000-000000000102'
  )),
  true,
  'replaying the same verified event is idempotent'
);
select throws_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-open-001', 'conflicting-dispute-id',
    'charge.dispute.created', 'opened',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', null, 'needs_response',
    'd1000000-0000-4000-8000-000000000103'
  )$sql$,
  '23505',
  'verified provider event was reused with conflicting dispute data',
  'same provider event cannot be replayed with conflicting dispute identity'
);
select throws_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'missing-verified-event', 'sandbox-dispute-001',
    'charge.dispute.updated', 'needs_evidence',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', null, 'needs_response',
    'd1000000-0000-4000-8000-000000000104'
  )$sql$,
  '42501',
  'payment dispute requires a matching verified webhook event',
  'dispute event without matching verified webhook evidence is rejected'
);
select throws_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-open-001', 'sandbox-dispute-001',
    'charge.dispute.created', 'opened',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    20000, 'USD', null, 'needs_response',
    'd1000000-0000-4000-8000-000000000105'
  )$sql$,
  '22023',
  'dispute amount, currency, provider or payment reference does not match',
  'dispute amount cannot exceed the original successful payment'
);

select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-needs-evidence-001', 'sandbox-dispute-001',
    'charge.dispute.updated', 'needs_evidence',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', now() + interval '4 days', 'needs_response',
    'd1000000-0000-4000-8000-000000000106'
  )$sql$,
  'verified provider event moves dispute to needs_evidence'
);
select is((select status from public.payment_disputes where provider_dispute_id = 'sandbox-dispute-001'), 'needs_evidence', 'evidence deadline state is persisted');

select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-evidence-submitted-001', 'sandbox-dispute-001',
    'charge.dispute.updated', 'evidence_submitted',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', null, 'under_review',
    'd1000000-0000-4000-8000-000000000107'
  )$sql$,
  'verified provider event records evidence-submitted state'
);
select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-won-001', 'sandbox-dispute-001',
    'charge.dispute.closed', 'won',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', null, 'won',
    'd1000000-0000-4000-8000-000000000108'
  )$sql$,
  'verified provider event records a won dispute'
);
select is((select status from public.payment_disputes where provider_dispute_id = 'sandbox-dispute-001'), 'won', 'won result is terminal except for administrative closure');

select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-close-001', 'sandbox-dispute-001',
    'charge.dispute.closed', 'closed',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    7500, 'USD', null, 'closed',
    'd1000000-0000-4000-8000-000000000109'
  )$sql$,
  'verified provider close event closes a won dispute'
);
select ok((select status = 'closed' and closed_at is not null from public.payment_disputes where provider_dispute_id = 'sandbox-dispute-001'), 'closed dispute records its close timestamp');

select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-open-002', 'sandbox-dispute-002',
    'charge.dispute.created', 'opened',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    2500, 'USD', now() + interval '3 days', 'needs_response',
    'd1000000-0000-4000-8000-000000000110'
  )$sql$,
  'second provider dispute can be opened for the same payment'
);
select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-lost-after-close-002', 'sandbox-dispute-002',
    'charge.dispute.closed', 'lost',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    2500, 'USD', null, 'lost',
    'd1000000-0000-4000-8000-000000000111'
  )$sql$,
  'verified provider event records a lost dispute'
);
select lives_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-close-002', 'sandbox-dispute-002',
    'charge.dispute.closed', 'closed',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    2500, 'USD', null, 'closed',
    'd1000000-0000-4000-8000-000000000112'
  )$sql$,
  'verified provider close event closes a lost dispute'
);
select throws_ok(
  $sql$select * from public.apply_verified_payment_dispute_event(
    'sandbox', 'phase5i-event-lost-002', 'sandbox-dispute-002',
    'charge.dispute.closed', 'lost',
    'a1000000-0000-4000-8000-000000000101',
    'b1000000-0000-4000-8000-000000000101',
    2500, 'USD', null, 'lost',
    'd1000000-0000-4000-8000-000000000113'
  )$sql$,
  '55000',
  'invalid payment dispute state transition',
  'terminal disputes cannot be changed by later new events'
);
select throws_ok(
  $sql$update public.payment_dispute_events set event_action = 'lost' where dispute_id = (select id from public.payment_disputes where provider_dispute_id = 'sandbox-dispute-001')$sql$,
  '55000',
  'payment dispute event history is append-only',
  'dispute event history cannot be rewritten'
);
select is(
  (select count(*)::integer from public.payment_dispute_events),
  8,
  'each distinct verified provider event is retained once'
);
select ok(
  (select count(*) >= 8 from public.audit_events where action = 'payment.dispute.event_applied'),
  'each applied provider dispute event emits audit evidence'
);

select * from finish();
rollback;
