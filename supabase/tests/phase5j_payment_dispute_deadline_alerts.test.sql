begin;
select plan(22);

select has_table('public', 'payment_dispute_alert_jobs', 'payment dispute alert outbox exists');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_dispute_alert_jobs'::regclass), 'dispute alert outbox has RLS enabled');
select ok(not has_table_privilege('anon', 'public.payment_dispute_alert_jobs', 'SELECT'), 'anonymous users cannot read dispute alerts');
select ok(not has_table_privilege('authenticated', 'public.payment_dispute_alert_jobs', 'SELECT'), 'authenticated users cannot read dispute alerts');
select ok(has_table_privilege('service_role', 'public.payment_dispute_alert_jobs', 'SELECT'), 'worker can inspect dispute alert jobs');
select ok(not has_table_privilege('service_role', 'public.payment_dispute_alert_jobs', 'UPDATE'), 'worker cannot directly mutate alert jobs');
select ok(has_function_privilege('service_role', 'public.enqueue_payment_dispute_deadline_alerts(timestamptz)', 'EXECUTE'), 'worker can enqueue deadline alerts');
select ok(has_function_privilege('service_role', 'public.claim_payment_dispute_alert_jobs(integer,uuid)', 'EXECUTE'), 'worker can claim deadline alerts');
select ok(has_function_privilege('service_role', 'public.finish_payment_dispute_alert_job(uuid,uuid,boolean,text)', 'EXECUTE'), 'worker can finish deadline alerts');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values (
  '91000000-0000-4000-8000-000000000291',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'dispute-alert-customer@example.test', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
);

insert into public.orders (
  id, customer_id, status, currency, subtotal_minor, tax_minor, idempotency_key
) values (
  'a1000000-0000-4000-8000-000000000291',
  '91000000-0000-4000-8000-000000000291',
  'pending_payment', 'USD', 10000, 0, 'phase5j-alert-order-key-0291'
);

insert into public.payment_attempts (
  id, order_id, provider, status, amount_minor, currency, idempotency_key, provider_reference
) values (
  'b1000000-0000-4000-8000-000000000291',
  'a1000000-0000-4000-8000-000000000291',
  'sandbox', 'created', 10000, 'USD', 'phase5j-alert-payment-key-0291', null
);

insert into public.payment_disputes (
  id, provider, provider_dispute_id, order_id, payment_attempt_id,
  amount_minor, currency, status, evidence_due_at
) values (
  'd1000000-0000-4000-8000-000000000291',
  'sandbox', 'phase5j-dispute-0291',
  'a1000000-0000-4000-8000-000000000291',
  'b1000000-0000-4000-8000-000000000291',
  2500, 'USD', 'open', now() + interval '24 hours'
);

select ok(
  exists(select 1 from public.payment_disputes where id = 'd1000000-0000-4000-8000-000000000291'),
  'open dispute fixture with a near deadline can be created'
);

select is(public.enqueue_payment_dispute_deadline_alerts(now()), 1, 'near-deadline dispute creates one alert job');
select is(public.enqueue_payment_dispute_deadline_alerts(now()), 0, 'repeated scans do not duplicate the same deadline alert');

create temporary table phase5j_claimed_alert (job_id uuid, request_id uuid) on commit drop;
insert into phase5j_claimed_alert
select job_id, 'd2000000-0000-4000-8000-000000000291'::uuid
from public.claim_payment_dispute_alert_jobs(3, 'd2000000-0000-4000-8000-000000000291');

select is((select count(*)::integer from phase5j_claimed_alert), 1, 'eligible alert can be claimed');
select is((select status from public.payment_dispute_alert_jobs where id = (select job_id from phase5j_claimed_alert)), 'processing', 'claimed alert receives a processing lease');
select is((select attempts from public.payment_dispute_alert_jobs where id = (select job_id from phase5j_claimed_alert)), 1, 'claim increments attempt count');

select throws_ok(
  $sql$select public.finish_payment_dispute_alert_job(
    (select job_id from phase5j_claimed_alert),
    'd3000000-0000-4000-8000-000000000291',
    true, null
  )$sql$,
  '42501',
  'dispute alert lease owner mismatch',
  'another request cannot finish a claimed alert'
);

select is(
  public.finish_payment_dispute_alert_job(
    (select job_id from phase5j_claimed_alert),
    'd2000000-0000-4000-8000-000000000291',
    false, 'email_provider_unavailable'
  ),
  'retryable',
  'provider failure schedules bounded retry'
);

update public.payment_dispute_alert_jobs
set available_at = now() - interval '1 second'
where id = (select job_id from phase5j_claimed_alert);

select is(
  (select attempts from public.claim_payment_dispute_alert_jobs(3, 'd4000000-0000-4000-8000-000000000291')),
  2,
  'retry claim increments attempt count'
);

select is(
  public.finish_payment_dispute_alert_job(
    (select job_id from phase5j_claimed_alert),
    'd4000000-0000-4000-8000-000000000291',
    true, null
  ),
  'sent',
  'successful delivery marks alert sent'
);
select is((select count(*)::integer from public.payment_dispute_alert_jobs where status = 'sent' and sent_at is not null), 1, 'sent alert has delivery timestamp');
select is(public.enqueue_payment_dispute_deadline_alerts(now()), 0, 'sent alert is not recreated on later scans');
select ok(
  (select count(*) >= 1 from public.audit_events where action = 'payment.dispute.deadline_alert_failed'),
  'failed delivery writes audit evidence'
);

select * from finish();
rollback;
