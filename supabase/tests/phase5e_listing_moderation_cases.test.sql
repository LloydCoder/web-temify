begin;
select plan(30);

select has_table('public', 'listing_moderation_cases', 'listing moderation cases exist');
select has_table('public', 'listing_moderation_case_events', 'listing moderation event history exists');
select ok((select relrowsecurity from pg_class where oid = 'public.listing_moderation_cases'::regclass), 'moderation case RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.listing_moderation_case_events'::regclass), 'moderation event RLS is enabled');
select ok(not has_table_privilege('anon', 'public.listing_moderation_cases', 'SELECT'), 'anonymous clients cannot read moderation cases');
select ok(not has_table_privilege('authenticated', 'public.listing_moderation_cases', 'INSERT'), 'authenticated clients cannot directly create moderation cases');
select ok(not has_table_privilege('authenticated', 'public.listing_moderation_case_events', 'SELECT'), 'authenticated clients cannot read internal moderation history');
select ok(has_table_privilege('service_role', 'public.listing_moderation_cases', 'SELECT'), 'trusted server can read cases through scoped routes');
select ok(not has_table_privilege('service_role', 'public.listing_moderation_cases', 'UPDATE'), 'trusted server must mutate through the guarded RPC');
select ok(not has_table_privilege('service_role', 'public.listing_moderation_cases', 'INSERT'), 'trusted server must create cases through the RPC');
select ok(has_table_privilege('service_role', 'public.listing_moderation_case_events', 'SELECT'), 'trusted server can read event history');
select ok(not has_table_privilege('service_role', 'public.listing_moderation_case_events', 'UPDATE'), 'moderation event history cannot be updated');
select ok(has_function_privilege('service_role', 'public.create_listing_moderation_case(uuid,uuid,text,text,text,uuid)', 'EXECUTE'), 'trusted server can create a report');
select ok(not has_function_privilege('authenticated', 'public.create_listing_moderation_case(uuid,uuid,text,text,text,uuid)', 'EXECUTE'), 'authenticated clients cannot invoke the report RPC');
select ok(has_function_privilege('service_role', 'public.admin_transition_listing_moderation_case(uuid,uuid,text,text,text,uuid)', 'EXECUTE'), 'trusted server can request an admin decision');
select ok(not has_function_privilege('authenticated', 'public.admin_transition_listing_moderation_case(uuid,uuid,text,text,text,uuid)', 'EXECUTE'), 'authenticated clients cannot invoke the admin decision RPC');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('a1000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'moderation-reporter@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a2000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'moderation-creator@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a3000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'moderation-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a4000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'moderation-nonadmin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.user_roles (user_id, role)
values ('a3000000-0000-4000-8000-000000000003', 'admin'::public.app_role);

insert into public.products (id, creator_id, slug, name, description, product_type, status)
values ('a5000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000002',
  'moderation-test-product', 'Moderation test product', 'Fixture for moderation workflow tests.',
  'template', 'published');

create temporary table phase5e_case_ids(id uuid primary key) on commit drop;
select lives_ok(
  $sql$insert into phase5e_case_ids select public.create_listing_moderation_case(
    'a1000000-0000-4000-8000-000000000001',
    'a5000000-0000-4000-8000-000000000005',
    'ip_rights',
    'The listing appears to reproduce protected source material without permission.',
    'moderation-idempotency-key-0001',
    'a6000000-0000-4000-8000-000000000006'
  )$sql$,
  'valid report creates a moderation case'
);
select is(
  public.create_listing_moderation_case(
    'a1000000-0000-4000-8000-000000000001',
    'a5000000-0000-4000-8000-000000000005',
    'ip_rights',
    'The listing appears to reproduce protected source material without permission.',
    'moderation-idempotency-key-0001',
    'a7000000-0000-4000-8000-000000000007'
  ),
  (select id from phase5e_case_ids),
  'identical report replay returns the original case'
);
select throws_ok(
  $sql$select public.create_listing_moderation_case(
    'a1000000-0000-4000-8000-000000000001',
    'a5000000-0000-4000-8000-000000000005',
    'privacy',
    'The listing appears to reproduce protected source material without permission.',
    'moderation-idempotency-key-0001',
    'a7000000-0000-4000-8000-000000000007'
  )$sql$,
  '23505',
  'moderation idempotency key reused with conflicting content',
  'conflicting reuse of an idempotency key is rejected'
);
select is((select status from public.listing_moderation_cases where id = (select id from phase5e_case_ids)), 'open', 'new report starts open');

select is(
  (public.admin_transition_listing_moderation_case(
    (select id from phase5e_case_ids), 'a3000000-0000-4000-8000-000000000003',
    'triage', null, 'Reviewed report and assigned it to the moderation queue.',
    'a8000000-0000-4000-8000-000000000008'
  )).status,
  'under_review',
  'admin can triage an open case'
);
select is(
  (public.admin_transition_listing_moderation_case(
    (select id from phase5e_case_ids), 'a3000000-0000-4000-8000-000000000003',
    'require_action', 'rights_review_required', 'Independent rights review is required before this report can be resolved.',
    'a9000000-0000-4000-8000-000000000009'
  )).status,
  'action_required',
  'admin can require a specific follow-up action'
);
select is(
  (public.admin_transition_listing_moderation_case(
    (select id from phase5e_case_ids), 'a3000000-0000-4000-8000-000000000003',
    'close', 'rights_review_required', 'The required rights review was completed and evidence is recorded.',
    'aa000000-0000-4000-8000-00000000000a'
  )).status,
  'closed',
  'admin can close an action-required case using the same resolution code'
);
select is((select count(*)::integer from public.listing_moderation_case_events where case_id = (select id from phase5e_case_ids)), 4, 'report and three transitions create append-only events');
select is((select count(*)::integer from public.audit_events where entity_type = 'listing_moderation_case' and entity_id = (select id::text from phase5e_case_ids)), 4, 'report and admin decisions are audited');
select throws_ok(
  $sql$select public.admin_transition_listing_moderation_case(
    (select id from phase5e_case_ids), 'a4000000-0000-4000-8000-000000000004',
    'triage', null, 'Non-admin must not be able to triage this moderation case.',
    'ab000000-0000-4000-8000-00000000000b'
  )$sql$,
  '42501',
  'administrator role required',
  'non-admin moderation transition is denied'
);
select throws_ok(
  $sql$select public.admin_transition_listing_moderation_case(
    (select id from phase5e_case_ids), 'a3000000-0000-4000-8000-000000000003',
    'dismiss', 'no_violation_found', 'Closed cases cannot be dismissed a second time.',
    'ac000000-0000-4000-8000-00000000000c'
  )$sql$,
  '22023',
  'invalid moderation case transition',
  'invalid state transition is denied'
);
select throws_ok(
  $sql$update public.listing_moderation_case_events set note = 'tampered' where case_id = (select id from phase5e_case_ids)$sql$,
  '55000',
  'moderation case events are append-only',
  'moderation history rejects update'
);
select throws_ok(
  $sql$delete from public.listing_moderation_case_events where case_id = (select id from phase5e_case_ids)$sql$,
  '55000',
  'moderation case events are append-only',
  'moderation history rejects delete'
);
select is((select status from public.products where id = 'a5000000-0000-4000-8000-000000000005'), 'published', 'reporting alone does not silently mutate listing publication state');

select * from finish();
rollback;
