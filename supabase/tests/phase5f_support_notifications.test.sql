begin;
select plan(12);
select has_table('public', 'support_notification_jobs', 'support notification outbox exists');
select ok((select relrowsecurity from pg_class where oid = 'public.support_notification_jobs'::regclass), 'notification outbox RLS is enabled');
select ok(not has_table_privilege('authenticated', 'public.support_notification_jobs', 'SELECT'), 'customers cannot read notification jobs');
select ok(not has_table_privilege('authenticated', 'public.support_notification_jobs', 'INSERT'), 'customers cannot enqueue notifications');
select ok(has_table_privilege('service_role', 'public.support_notification_jobs', 'SELECT'), 'worker can inspect notification job state');
select ok(not has_table_privilege('service_role', 'public.support_notification_jobs', 'UPDATE'), 'worker cannot directly mutate job state');
select ok(has_function_privilege('service_role', 'public.claim_support_notification_jobs(integer,uuid)', 'EXECUTE'), 'worker can claim jobs');
select ok(has_function_privilege('service_role', 'public.finish_support_notification_job(uuid,uuid,boolean,text)', 'EXECUTE'), 'worker can finish jobs');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values (
  '91000000-0000-4000-8000-000000000191',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'notify-requester@example.test', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
);

select lives_ok(
  $sql$select public.create_support_case(
    '91000000-0000-4000-8000-000000000191',
    'other',
    'Notification outbox test',
    'Verify case events create notifications without copying private case contents.',
    'phase5f-notify-idempotency-0001',
    '93000000-0000-4000-8000-000000000193'
  )$sql$,
  'support case creation remains successful with the outbox trigger'
);
select is(
  (select count(*)::integer from public.support_notification_jobs),
  2,
  'support case creation enqueues requester and operations notifications'
);
select is(
  (select count(*)::integer from public.support_notification_jobs where recipient_kind = 'requester' and recipient_user_id = '91000000-0000-4000-8000-000000000191'),
  1,
  'requester notification is bound to the authenticated case owner'
);
select is(
  (select count(*)::integer from public.support_notification_jobs where recipient_kind = 'operations' and recipient_user_id is null),
  1,
  'operations notification uses deployment configuration rather than a user-supplied address'
);

select * from finish();
rollback;
