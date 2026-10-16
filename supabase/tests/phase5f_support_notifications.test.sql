begin;
select plan(24);
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

create temporary table phase5f_claimed_jobs (
  id uuid primary key,
  attempts integer not null,
  last_request_id uuid not null
) on commit drop;

select lives_ok(
  $sql$insert into phase5f_claimed_jobs
  select job_id, attempts, '94000000-0000-4000-8000-000000000194'::uuid
  from public.claim_support_notification_jobs(
    2, '94000000-0000-4000-8000-000000000194'
  )$sql$,
  'worker claims a bounded batch of queued notifications'
);
select is(
  (select count(*)::integer from phase5f_claimed_jobs),
  2,
  'claim returns both requester and operations jobs'
);
select is(
  (select count(*)::integer from public.support_notification_jobs
   where status = 'processing' and attempts = 1
     and last_request_id = '94000000-0000-4000-8000-000000000194'),
  2,
  'claim atomically increments attempts and assigns the lease owner'
);
select throws_ok(
  $sql$select public.finish_support_notification_job(
    (select id from phase5f_claimed_jobs order by id limit 1),
    '94000000-0000-4000-8000-000000000195',
    true,
    null
  )$sql$,
  '55000',
  'support notification lease is not owned by this worker',
  'a stale or foreign worker cannot complete another worker lease'
);
select is(
  public.finish_support_notification_job(
    (select id from phase5f_claimed_jobs order by id limit 1),
    '94000000-0000-4000-8000-000000000194',
    false,
    'email_provider_unavailable'
  ),
  'retryable',
  'provider failure moves the claimed job to retryable'
);
select ok(
  (select available_at > now() and last_error_code = 'email_provider_unavailable'
   from public.support_notification_jobs
   where id = (select id from phase5f_claimed_jobs order by id limit 1)),
  'retryable failure records an error code and schedules backoff'
);

update public.support_notification_jobs
set status = 'processing',
    lease_expires_at = now() - interval '1 second',
    last_request_id = '94000000-0000-4000-8000-000000000194',
    attempts = 1
where id = (select id from phase5f_claimed_jobs order by id desc limit 1);

select lives_ok(
  $sql$select * from public.claim_support_notification_jobs(
    1, '94000000-0000-4000-8000-000000000196'
  )$sql$,
  'worker reclaims an expired lease'
);
select is(
  (select attempts from public.support_notification_jobs
   where id = (select id from phase5f_claimed_jobs order by id desc limit 1)),
  2,
  'expired lease reclaim increments attempt count'
);
select is(
  public.finish_support_notification_job(
    (select id from phase5f_claimed_jobs order by id desc limit 1),
    '94000000-0000-4000-8000-000000000196',
    true,
    null
  ),
  'sent',
  'successful provider delivery finishes the current lease'
);
select ok(
  (select status = 'sent' and sent_at is not null and lease_expires_at is null
   from public.support_notification_jobs
   where id = (select id from phase5f_claimed_jobs order by id desc limit 1)),
  'successful delivery clears lease and records sent timestamp'
);

update public.support_notification_jobs
set status = 'processing',
    attempts = 5,
    lease_expires_at = now() - interval '1 second',
    last_request_id = '94000000-0000-4000-8000-000000000197'
where id = (select id from phase5f_claimed_jobs order by id limit 1);

select lives_ok(
  $sql$select * from public.claim_support_notification_jobs(
    2, '94000000-0000-4000-8000-000000000198'
  )$sql$,
  'claim worker safely blocks exhausted expired leases'
);
select ok(
  (select status = 'blocked' and attempts = 5
      and lease_expires_at is null
      and last_error_code = 'worker_lease_exhausted'
   from public.support_notification_jobs
   where id = (select id from phase5f_claimed_jobs order by id limit 1)),
  'expired lease at retry ceiling transitions to blocked'
);
select is(
  (select count(*)::integer from public.audit_events
   where action = 'support.notification.delivery_failed'
     and entity_type = 'support_notification_job'),
  2,
  'provider failure and exhausted lease both produce audit evidence'
);

select * from finish();
rollback;
