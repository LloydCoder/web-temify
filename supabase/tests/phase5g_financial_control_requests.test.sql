begin;
select plan(43);

select has_table('public', 'financial_control_requests', 'financial control requests exist');
select has_table('public', 'financial_control_approvals', 'approval evidence exists');
select has_table('public', 'financial_control_events', 'financial control history exists');
select has_table('public', 'seller_payout_holds', 'seller payout holds exist');
select ok((select relrowsecurity from pg_class where oid = 'public.financial_control_requests'::regclass), 'financial control requests have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.financial_control_approvals'::regclass), 'financial control approvals have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.financial_control_events'::regclass), 'financial control events have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.seller_payout_holds'::regclass), 'payout holds have RLS enabled');
select ok(not has_table_privilege('authenticated', 'public.financial_control_requests', 'SELECT'), 'authenticated users cannot read financial control requests');
select ok(not has_table_privilege('authenticated', 'public.financial_control_requests', 'INSERT'), 'authenticated users cannot create financial control requests directly');
select ok(has_table_privilege('service_role', 'public.financial_control_requests', 'SELECT'), 'trusted server can read financial control requests');
select ok(not has_table_privilege('service_role', 'public.financial_control_requests', 'UPDATE'), 'trusted server cannot bypass financial control RPCs');
select ok(has_function_privilege('service_role', 'public.create_financial_control_request(uuid,text,uuid,uuid,uuid,bigint,text,text,text,text,uuid)', 'EXECUTE'), 'trusted server can create financial control requests');
select ok(not has_function_privilege('authenticated', 'public.create_financial_control_request(uuid,text,uuid,uuid,uuid,bigint,text,text,text,text,uuid)', 'EXECUTE'), 'authenticated users cannot create financial control requests');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('91000000-0000-4000-8000-000000000501', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'finance-maker@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('92000000-0000-4000-8000-000000000502', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'finance-approver-one@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('93000000-0000-4000-8000-000000000503', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'finance-approver-two@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('94000000-0000-4000-8000-000000000504', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'finance-seller@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.user_roles (user_id, role)
values
  ('91000000-0000-4000-8000-000000000501', 'admin'::public.app_role),
  ('92000000-0000-4000-8000-000000000502', 'admin'::public.app_role),
  ('93000000-0000-4000-8000-000000000503', 'admin'::public.app_role);

create temporary table phase5g_cancel_request(id uuid primary key) on commit drop;
insert into phase5g_cancel_request
select public.create_financial_control_request(
  '91000000-0000-4000-8000-000000000501',
  'manual_adjustment', '94000000-0000-4000-8000-000000000504',
  null, null, 1800, 'USD', repeat('e', 64),
  'Request cancelled before any reviewer acted.',
  'phase5g-cancel-adjustment-0001', 'a0000000-0000-4000-8000-000000000501'
);
select is(
  public.cancel_financial_control_request(
    (select id from phase5g_cancel_request),
    '91000000-0000-4000-8000-000000000501',
    'Maker cancels before review starts.',
    'a0100000-0000-4000-8000-000000000501'
  ),
  'cancelled',
  'maker can cancel only before review begins'
);
select is(
  (select status from public.financial_control_requests where id = (select id from phase5g_cancel_request)),
  'cancelled',
  'cancellation is persisted as an immutable state transition'
);

create temporary table phase5g_manual_request(id uuid primary key) on commit drop;
select lives_ok(
  $sql$insert into phase5g_manual_request
  select public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'manual_adjustment', '94000000-0000-4000-8000-000000000504',
    null, null, 2500, 'USD', repeat('a', 64),
    'Manual adjustment requires independent financial review.',
    'phase5g-manual-adjustment-0001', 'a1000000-0000-4000-8000-000000000501'
  )$sql$,
  'admin can submit an immutable manual adjustment request'
);
select is((select status from public.financial_control_requests where id = (select id from phase5g_manual_request)), 'requested', 'new request begins in requested state');
select is(
  public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'manual_adjustment', '94000000-0000-4000-8000-000000000504',
    null, null, 2500, 'USD', repeat('a', 64),
    'Manual adjustment requires independent financial review.',
    'phase5g-manual-adjustment-0001', 'a1100000-0000-4000-8000-000000000501'
  ),
  (select id from phase5g_manual_request),
  'identical request replay returns the original request'
);
select throws_ok(
  $sql$select public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'manual_adjustment', '94000000-0000-4000-8000-000000000504',
    null, null, 2600, 'USD', repeat('a', 64),
    'Manual adjustment requires independent financial review.',
    'phase5g-manual-adjustment-0001', 'a1200000-0000-4000-8000-000000000501'
  )$sql$,
  '23505',
  'financial control idempotency key reused with conflicting content',
  'idempotency key cannot be reused for different financial content'
);
select throws_ok(
  $sql$select public.review_financial_control_request(
    (select id from phase5g_manual_request),
    '91000000-0000-4000-8000-000000000501',
    'approve', 'Requester cannot approve their own adjustment.', 'a2000000-0000-4000-8000-000000000501'
  )$sql$,
  '42501',
  'requester cannot approve their own financial control request',
  'maker cannot approve their own request'
);
select is(
  public.review_financial_control_request(
    (select id from phase5g_manual_request),
    '92000000-0000-4000-8000-000000000502',
    'approve', 'Independent first approval recorded.', 'a3000000-0000-4000-8000-000000000501'
  ),
  'under_review',
  'first distinct approval does not finalize a high-risk request'
);
select is((select count(*)::integer from public.financial_control_approvals where request_id = (select id from phase5g_manual_request)), 1, 'first approval is append-only evidence');
select is(
  public.review_financial_control_request(
    (select id from phase5g_manual_request),
    '93000000-0000-4000-8000-000000000503',
    'approve', 'Independent second approval recorded.', 'a4000000-0000-4000-8000-000000000501'
  ),
  'approved',
  'second distinct approval approves the request'
);
select is((select status from public.financial_control_requests where id = (select id from phase5g_manual_request)), 'approved', 'approved status is set only after two distinct admins');
create temporary table phase5g_rejected_request(id uuid primary key) on commit drop;
insert into phase5g_rejected_request
select public.create_financial_control_request(
  '91000000-0000-4000-8000-000000000501',
  'manual_adjustment', '94000000-0000-4000-8000-000000000504',
  null, null, 3300, 'USD', repeat('f', 64),
  'Adjustment rejected after independent review.',
  'phase5g-rejected-adjustment-0001', 'a1300000-0000-4000-8000-000000000501'
);
select is(
  public.review_financial_control_request((select id from phase5g_rejected_request), '92000000-0000-4000-8000-000000000502', 'approve', 'First review approval recorded.', 'a1400000-0000-4000-8000-000000000501'),
  'under_review',
  'first approval moves rejected-test request into review'
);
select is(
  public.review_financial_control_request((select id from phase5g_rejected_request), '93000000-0000-4000-8000-000000000503', 'reject', 'Second reviewer rejects the request.', 'a1500000-0000-4000-8000-000000000501'),
  'rejected',
  'a second reviewer can reject after one approval'
);
select is((select status from public.financial_control_requests where id = (select id from phase5g_rejected_request)), 'rejected', 'rejection is terminal');
select is((select count(*)::integer from public.financial_control_approvals where request_id = (select id from phase5g_rejected_request)), 2, 'approval and rejection decisions are both preserved');

select throws_ok(
  $sql$select public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'negative_balance_review', '94000000-0000-4000-8000-000000000504',
    null, null, 100, 'USD', repeat('b', 64),
    'Review a negative balance amount that does not exist.',
    'phase5g-negative-balance-invalid-0001', 'a5000000-0000-4000-8000-000000000501'
  )$sql$,
  '22023',
  'negative-balance review must match the current posted seller-payable deficit',
  'negative-balance review cannot be opened for a nonexistent deficit'
);

create temporary table phase5g_hold_request(id uuid primary key) on commit drop;
select lives_ok(
  $sql$insert into phase5g_hold_request
  select public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'payout_hold', '94000000-0000-4000-8000-000000000504',
    null, null, 5000, 'USD', repeat('c', 64),
    'Temporary payout hold pending evidence review.',
    'phase5g-payout-hold-0001', 'a6000000-0000-4000-8000-000000000501'
  )$sql$,
  'admin can request an internal payout hold'
);
select is(
  public.review_financial_control_request((select id from phase5g_hold_request), '92000000-0000-4000-8000-000000000502', 'approve', 'First hold approval recorded.', 'a7000000-0000-4000-8000-000000000501'),
  'under_review',
  'payout hold remains inactive after only one approval'
);
select is(
  public.review_financial_control_request((select id from phase5g_hold_request), '93000000-0000-4000-8000-000000000503', 'approve', 'Second hold approval recorded.', 'a8000000-0000-4000-8000-000000000501'),
  'approved',
  'payout hold request becomes approved after two admins'
);
select is((select count(*)::integer from public.seller_payout_holds where source_request_id = (select id from phase5g_hold_request) and released_at is null), 1, 'two approvals create one active payout hold');
select throws_ok(
  $sql$update public.seller_payout_holds set amount_minor = amount_minor + 1 where source_request_id = (select id from phase5g_hold_request)$sql$,
  '55000',
  'payout hold may only transition once from active to released',
  'payout hold amount cannot be edited directly'
);

create temporary table phase5g_release_request(id uuid primary key) on commit drop;
select lives_ok(
  $sql$insert into phase5g_release_request
  select public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'payout_hold_release', '94000000-0000-4000-8000-000000000504',
    null, (select id from public.seller_payout_holds where source_request_id = (select id from phase5g_hold_request)),
    5000, 'USD', repeat('d', 64),
    'Release hold after the underlying risk was reviewed.',
    'phase5g-payout-hold-release-0001', 'a9000000-0000-4000-8000-000000000501'
  )$sql$,
  'admin can request release of a matching active hold'
);
select is(
  public.review_financial_control_request((select id from phase5g_release_request), '92000000-0000-4000-8000-000000000502', 'approve', 'First release approval recorded.', 'aa000000-0000-4000-8000-000000000501'),
  'under_review',
  'hold release remains pending after one approval'
);
select is(
  public.review_financial_control_request((select id from phase5g_release_request), '93000000-0000-4000-8000-000000000503', 'approve', 'Second release approval recorded.', 'ab000000-0000-4000-8000-000000000501'),
  'approved',
  'two distinct admins approve hold release'
);
select is((select count(*)::integer from public.seller_payout_holds where source_request_id = (select id from phase5g_hold_request) and released_at is not null), 1, 'approved release closes the hold exactly once');
select throws_ok(
  $sql$select public.create_financial_control_request(
    '91000000-0000-4000-8000-000000000501',
    'payout_hold_release', '94000000-0000-4000-8000-000000000504',
    null, (select id from public.seller_payout_holds where source_request_id = (select id from phase5g_hold_request)),
    5000, 'USD', repeat('d', 64),
    'Try to release the already released payout hold.',
    'phase5g-payout-hold-release-duplicate-0001', 'ac000000-0000-4000-8000-000000000501'
  )$sql$,
  '22023',
  'payout hold release must match an active hold exactly',
  'a released hold cannot be released a second time'
);
select is((select count(*)::integer from public.financial_journal_batches where source_type = 'manual_adjustment'), 0, 'approval workflow never posts a manual adjustment journal');
select ok((select count(*) >= 11 from public.financial_control_events), 'all request and hold transitions have immutable event evidence');
select ok((select count(*) >= 8 from public.audit_events where action like 'financial_control.%'), 'financial control actions append audit events');

select * from finish();
rollback;
