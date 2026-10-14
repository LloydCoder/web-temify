begin;
select plan(37);

select has_table('public', 'support_cases', 'support cases are persisted');
select has_table('public', 'support_case_events', 'support case event history is persisted');
select ok((select relrowsecurity from pg_class where oid = 'public.support_cases'::regclass), 'support case RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.support_case_events'::regclass), 'support case event RLS is enabled');
select ok(not has_table_privilege('authenticated', 'public.support_cases', 'SELECT'), 'customers cannot bypass ownership-scoped server routes');
select ok(not has_table_privilege('authenticated', 'public.support_cases', 'INSERT'), 'customers cannot directly insert support cases');
select ok(not has_table_privilege('authenticated', 'public.support_case_events', 'SELECT'), 'customers cannot read internal support event history directly');
select ok(has_table_privilege('service_role', 'public.support_cases', 'SELECT'), 'trusted server can read cases for ownership-scoped routes');
select ok(not has_table_privilege('service_role', 'public.support_cases', 'UPDATE'), 'trusted server cannot directly mutate case state');
select ok(not has_table_privilege('service_role', 'public.support_cases', 'INSERT'), 'trusted server must use the create RPC');
select ok(has_table_privilege('service_role', 'public.support_case_events', 'SELECT'), 'trusted server can read case events');
select ok(not has_table_privilege('service_role', 'public.support_case_events', 'UPDATE'), 'case event history is not directly mutable');
select ok(has_function_privilege('service_role', 'public.create_support_case(uuid,text,text,text,text,uuid)', 'EXECUTE'), 'trusted server can create a support case');
select ok(not has_function_privilege('authenticated', 'public.create_support_case(uuid,text,text,text,text,uuid)', 'EXECUTE'), 'authenticated clients cannot invoke the service-only create RPC');
select ok(has_function_privilege('service_role', 'public.admin_transition_support_case(uuid,uuid,text,text,uuid,uuid)', 'EXECUTE'), 'trusted server can request an admin transition');
select ok(not has_function_privilege('authenticated', 'public.admin_transition_support_case(uuid,uuid,text,text,uuid,uuid)', 'EXECUTE'), 'authenticated clients cannot invoke the admin transition RPC');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('91000000-0000-4000-8000-000000000091', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'support-requester@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('92000000-0000-4000-8000-000000000092', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'support-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('93000000-0000-4000-8000-000000000093', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'support-nonadmin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.user_roles (user_id, role)
values ('92000000-0000-4000-8000-000000000092', 'admin'::public.app_role);

create temporary table phase5d_support_case_ids(id uuid primary key) on commit drop;

select lives_ok(
  $sql$
    insert into phase5d_support_case_ids
    select public.create_support_case(
      '91000000-0000-4000-8000-000000000091',
      'product_access',
      'Cannot access purchased product',
      'The download page says my entitlement is unavailable after payment.',
      'support-idempotency-key-0001',
      '94000000-0000-4000-8000-000000000094'
    )
  $sql$,
  'authenticated server flow can create a validated support case'
);

select is(
  public.create_support_case(
    '91000000-0000-4000-8000-000000000091',
    'product_access',
    'Cannot access purchased product',
    'The download page says my entitlement is unavailable after payment.',
    'support-idempotency-key-0001',
    '95000000-0000-4000-8000-000000000095'
  ),
  (select id from phase5d_support_case_ids),
  'identical support-case replay returns the original case'
);

select throws_ok(
  $sql$select public.create_support_case(
    '91000000-0000-4000-8000-000000000091',
    'billing',
    'Different issue content',
    'This content conflicts with the first use of the same idempotency key.',
    'support-idempotency-key-0001',
    '95000000-0000-4000-8000-000000000095'
  )$sql$,
  '23505',
  'support case idempotency key reused with conflicting content',
  'reusing an idempotency key with different content is rejected'
);

select is(
  (select status from public.support_cases where id = (select id from phase5d_support_case_ids)),
  'open',
  'new support case begins open'
);
select is(
  (select count(*)::integer from public.support_case_events where case_id = (select id from phase5d_support_case_ids)),
  1,
  'case creation writes one immutable event'
);

select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'triage',
    'Reviewed the request and started investigation.',
    null,
    '96000000-0000-4000-8000-000000000096'
  )$sql$,
  'admin can triage an open case'
);
select is(
  (select status from public.support_cases where id = (select id from phase5d_support_case_ids)),
  'triaged',
  'triage transition is persisted'
);

select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'assign',
    'Assigning this case to the on-duty administrator.',
    '92000000-0000-4000-8000-000000000092',
    '97000000-0000-4000-8000-000000000097'
  )$sql$,
  'admin can assign a case to an administrator'
);
select is(
  (select assigned_to from public.support_cases where id = (select id from phase5d_support_case_ids)),
  '92000000-0000-4000-8000-000000000092'::uuid,
  'assignment is persisted only to a database-owned admin'
);

select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'request_info',
    'Please provide the order reference and a screenshot of the error.',
    null,
    '98000000-0000-4000-8000-000000000098'
  )$sql$,
  'admin can request additional information'
);
select is(
  (select status from public.support_cases where id = (select id from phase5d_support_case_ids)),
  'waiting_on_requester',
  'request-info transition moves case to waiting state'
);

select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'escalate',
    'Escalating because the first-line investigation did not resolve it.',
    null,
    '99000000-0000-4000-8000-000000000099'
  )$sql$,
  'admin can escalate a waiting case'
);
select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'resolve',
    'Verified that the customer can now access the purchased product.',
    null,
    'a1000000-0000-4000-8000-0000000000a1'
  )$sql$,
  'admin can resolve an escalated case with a note'
);
select is(
  (select resolved_at is not null from public.support_cases where id = (select id from phase5d_support_case_ids)),
  true,
  'resolution timestamp is set atomically with resolution'
);
select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'close',
    'Resolution confirmed and the support case is ready to close.',
    null,
    'a2000000-0000-4000-8000-0000000000a2'
  )$sql$,
  'admin can close a resolved case'
);
select lives_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'reopen',
    'Customer replied that the issue has returned and needs review.',
    null,
    'a3000000-0000-4000-8000-0000000000a3'
  )$sql$,
  'admin can reopen a closed case with an auditable reason'
);
select is(
  (select status from public.support_cases where id = (select id from phase5d_support_case_ids)),
  'open',
  'reopened case returns to open and clears terminal timestamps'
);
select is(
  (select resolved_at is null and closed_at is null from public.support_cases where id = (select id from phase5d_support_case_ids)),
  true,
  'reopening clears resolution and closure timestamps'
);

select throws_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '92000000-0000-4000-8000-000000000092',
    'close',
    'Cannot close a case that has been reopened.',
    null,
    'a4000000-0000-4000-8000-0000000000a4'
  )$sql$,
  '22023',
  'invalid support case transition',
  'invalid close transition from open is rejected'
);
select throws_ok(
  $sql$select public.admin_transition_support_case(
    (select id from phase5d_support_case_ids),
    '93000000-0000-4000-8000-000000000093',
    'triage',
    'Non-admin users must not transition cases.',
    null,
    'a5000000-0000-4000-8000-0000000000a5'
  )$sql$,
  '42501',
  'support case action requires an admin',
  'non-admin case transition is denied'
);
select throws_ok(
  $sql$update public.support_case_events set note = 'tampered event' where case_id = (select id from phase5d_support_case_ids)$sql$,
  '55000',
  'support case events are append-only',
  'support case events cannot be edited'
);
select throws_ok(
  $sql$delete from public.support_case_events where case_id = (select id from phase5d_support_case_ids)$sql$,
  '55000',
  'support case events are append-only',
  'support case events cannot be deleted'
);
select is(
  (select count(*)::integer from public.support_case_events where case_id = (select id from phase5d_support_case_ids)),
  8,
  'every support case state and assignment change is preserved as an event'
);
select is(
  (select count(*)::integer from public.audit_events where entity_type = 'support_case' and entity_id = (select id::text from phase5d_support_case_ids)),
  8,
  'case creation and every admin action append audit evidence'
);

select * from finish();
rollback;
