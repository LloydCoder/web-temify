begin;
select plan(39);

select has_table('public', 'settlement_evidence_retention_settings', 'retention activation settings exist');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_evidence_retention_settings'::regclass),
  'retention activation settings have RLS enabled'
);
select has_table('public', 'settlement_evidence_retention_holds', 'append-only legal hold history exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_evidence_retention_holds'::regclass),
  'legal hold history has RLS enabled'
);
select has_table('public', 'settlement_evidence_retention_jobs', 'retention deletion queue exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_evidence_retention_jobs'::regclass),
  'retention deletion queue has RLS enabled'
);
select ok(
  not has_table_privilege('service_role', 'public.settlement_evidence_retention_jobs', 'SELECT'),
  'service role must use retention RPCs instead of reading queue rows directly'
);
select ok(
  has_function_privilege('service_role', 'public.claim_settlement_evidence_retention_jobs(integer,text,uuid)', 'EXECUTE'),
  'service role can claim retention jobs'
);
select ok(
  not has_function_privilege('authenticated', 'public.claim_settlement_evidence_retention_jobs(integer,text,uuid)', 'EXECUTE'),
  'authenticated clients cannot claim retention jobs'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('a1000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'retention-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values ('a1000000-0000-4000-8000-000000000001', 'admin'::public.app_role)
on conflict do nothing;

create temporary table phase4d2_retention_imports (
  label text primary key,
  import_id uuid not null
) on commit drop;
insert into phase4d2_retention_imports values
  ('resolved', 'a2000000-0000-4000-8000-000000000001'),
  ('unresolved', 'a2000000-0000-4000-8000-000000000002');

insert into public.settlement_imports (
  id, provider, provider_account_reference, report_reference,
  report_period_start, report_period_end, report_timezone,
  source_sha256, source_authentication_method, source_authentication_asserted_at,
  currency, imported_by
) values
  ('a2000000-0000-4000-8000-000000000001', 'sandbox', 'retention-account',
   'retention-resolved-report', '2025-01-01', '2025-01-01', 'UTC',
   repeat('1',64), 'sandbox_fixture', now(), 'USD',
   'a1000000-0000-4000-8000-000000000001'),
  ('a2000000-0000-4000-8000-000000000002', 'sandbox', 'retention-account',
   'retention-unresolved-report', '2025-01-02', '2025-01-02', 'UTC',
   repeat('2',64), 'sandbox_fixture', now(), 'USD',
   'a1000000-0000-4000-8000-000000000001');

insert into public.settlement_reconciliation_runs (
  id, import_id, reconciled_by, matched_rows, exception_rows
) values
  ('a3000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001',
   'a1000000-0000-4000-8000-000000000001', 0, 0),
  ('a3000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000002',
   'a1000000-0000-4000-8000-000000000001', 0, 1);

insert into public.settlement_evidence (
  id, import_id, storage_path, source_sha256, mime_type, byte_size,
  original_filename, uploaded_by, uploaded_at, retention_until
) values
  ('a4000000-0000-4000-8000-000000000001', null,
   'a4000000-0000-4000-8000-000000000001/' || repeat('a',64),
   repeat('a',64), 'text/csv', 100, 'eligible-unlinked.csv',
   'a1000000-0000-4000-8000-000000000001', now() - interval '400 days', now() - interval '1 day'),
  ('a4000000-0000-4000-8000-000000000002', null,
   'a4000000-0000-4000-8000-000000000002/' || repeat('b',64),
   repeat('b',64), 'text/csv', 100, 'eligible-linked.csv',
   'a1000000-0000-4000-8000-000000000001', now() - interval '400 days', now() - interval '1 day'),
  ('a4000000-0000-4000-8000-000000000003', null,
   'a4000000-0000-4000-8000-000000000003/' || repeat('c',64),
   repeat('c',64), 'text/csv', 100, 'unresolved-linked.csv',
   'a1000000-0000-4000-8000-000000000001', now() - interval '400 days', now() - interval '1 day'),
  ('a4000000-0000-4000-8000-000000000004', null,
   'a4000000-0000-4000-8000-000000000004/' || repeat('d',64),
   repeat('d',64), 'text/csv', 100, 'held-evidence.csv',
   'a1000000-0000-4000-8000-000000000001', now() - interval '400 days', now() - interval '1 day');

insert into public.settlement_evidence_links (
  evidence_id, import_id, source_sha256, linked_by, request_id
) values
  ('a4000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000001', repeat('b',64),
   'a1000000-0000-4000-8000-000000000001', gen_random_uuid()),
  ('a4000000-0000-4000-8000-000000000003',
   'a2000000-0000-4000-8000-000000000002', repeat('c',64),
   'a1000000-0000-4000-8000-000000000001', gen_random_uuid());

select is(
  (select enabled from public.settlement_evidence_retention_settings where singleton = true),
  false,
  'automated deletion is disabled by default'
);
select is(
  (select count(*) from public.claim_settlement_evidence_retention_jobs(10, 'test-worker', gen_random_uuid())),
  0::bigint,
  'no retention jobs are claimed before explicit activation'
);
select lives_ok(
  $sql$select public.set_settlement_evidence_retention_enabled(
    true, 'Reviewed financial record schedule and privacy retention basis',
    'a1000000-0000-4000-8000-000000000001', gen_random_uuid()
  )$sql$,
  'admin can activate retention with an explicit reviewed basis'
);
select is(
  (select enabled from public.settlement_evidence_retention_settings where singleton = true),
  true,
  'retention activation is persisted'
);
select lives_ok(
  $sql$select public.set_settlement_evidence_legal_hold(
    'a4000000-0000-4000-8000-000000000004',
    'placed', 'Preserve evidence for an active legal matter',
    'a1000000-0000-4000-8000-000000000001', gen_random_uuid()
  )$sql$,
  'admin can place an audited legal hold'
);

create temporary table phase4d2_retention_claims (
  job_id uuid,
  evidence_id uuid,
  storage_path text,
  source_sha256 text,
  claim_token uuid,
  attempt_count integer,
  scheduled_for timestamptz
) on commit drop;
insert into phase4d2_retention_claims
select * from public.claim_settlement_evidence_retention_jobs(
  10, 'test-worker', gen_random_uuid()
);

select is(
  (select count(*) from phase4d2_retention_claims),
  2::bigint,
  'only due evidence without legal holds or unresolved reconciliation exceptions is claimed'
);
select ok(
  exists (select 1 from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000001')
  and exists (select 1 from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000002')
  and not exists (select 1 from phase4d2_retention_claims where evidence_id in (
    'a4000000-0000-4000-8000-000000000003',
    'a4000000-0000-4000-8000-000000000004'
  )),
  'eligible unlinked and fully reconciled evidence is claimed; unresolved and held evidence is excluded'
);
select is(
  (select count(*) from public.settlement_evidence_retention_jobs
   where evidence_id in ('a4000000-0000-4000-8000-000000000003','a4000000-0000-4000-8000-000000000004')),
  0::bigint,
  'unresolved and held evidence does not receive a deletion job'
);
select is(
  (select count(*) from public.authorize_settlement_evidence_retention_deletion(
    (select job_id from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000001'),
    gen_random_uuid(), gen_random_uuid()
  )),
  0::bigint,
  'deletion authorization rejects an invalid claim token'
);
select lives_ok(
  $sql$select public.set_settlement_evidence_legal_hold(
    'a4000000-0000-4000-8000-000000000001',
    'placed', 'Preserve evidence pending counsel review',
    'a1000000-0000-4000-8000-000000000001', gen_random_uuid()
  )$sql$,
  'a legal hold can revoke a claimed job before deletion authorization'
);
select is(
  (select count(*) from public.authorize_settlement_evidence_retention_deletion(
    (select job_id from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000001'),
    (select claim_token from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000001'),
    gen_random_uuid()
  )),
  0::bigint,
  'a claimed job with a newly placed legal hold cannot be authorized'
);
select is(
  (select status from public.settlement_evidence_retention_jobs
   where evidence_id = 'a4000000-0000-4000-8000-000000000001'),
  'blocked',
  'placing a legal hold blocks the job and invalidates its claim token'
);
select is(
  (select count(*) from public.authorize_settlement_evidence_retention_deletion(
    (select job_id from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000002'),
    (select claim_token from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000002'),
    gen_random_uuid()
  )),
  1::bigint,
  'a valid due job can be authorized immediately before storage deletion'
);
select lives_ok(
  $sql$select public.complete_settlement_evidence_retention_job(
    (select job_id from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000002'),
    (select claim_token from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000002'),
    true, null, gen_random_uuid()
  )$sql$,
  'successful object deletion can be committed to the retention ledger'
);
select is(
  (select status from public.settlement_evidence_retention_jobs
   where evidence_id = 'a4000000-0000-4000-8000-000000000002'),
  'deleted',
  'successful deletion is marked completed without deleting immutable evidence metadata'
);
select is(
  (select count(*) from public.audit_events
   where action = 'settlement.evidence.retention_deleted'
     and entity_id = 'a4000000-0000-4000-8000-000000000002'),
  1::bigint,
  'successful deletion creates a correlated audit event'
);
select is(
  (select count(*) from public.claim_settlement_evidence_retention_jobs(10, 'test-worker', gen_random_uuid())),
  0::bigint,
  'held and unresolved jobs are not reclaimed'
);
select lives_ok(
  $sql$select public.set_settlement_evidence_legal_hold(
    'a4000000-0000-4000-8000-000000000001',
    'released', 'Counsel confirmed the evidence may follow normal retention',
    'a1000000-0000-4000-8000-000000000001', gen_random_uuid()
  )$sql$,
  'admin can release a legal hold with an immutable history entry'
);
create temporary table phase4d2_retention_retry (
  job_id uuid,
  evidence_id uuid,
  storage_path text,
  source_sha256 text,
  claim_token uuid,
  attempt_count integer,
  scheduled_for timestamptz
) on commit drop;
insert into phase4d2_retention_retry
select * from public.claim_settlement_evidence_retention_jobs(
  10, 'test-worker', gen_random_uuid()
);
select is(
  (select count(*) from phase4d2_retention_retry),
  1::bigint,
  'releasing the hold makes the due job eligible for a fresh claim'
);
select ok(
  (select claim_token from phase4d2_retention_retry)
    <> (select claim_token from phase4d2_retention_claims where evidence_id = 'a4000000-0000-4000-8000-000000000001'),
  'a fresh claim receives a new token'
);
select lives_ok(
  $sql$select public.complete_settlement_evidence_retention_job(
    (select job_id from phase4d2_retention_retry),
    (select claim_token from phase4d2_retention_retry),
    false, 'storage_delete_failed', gen_random_uuid()
  )$sql$,
  'failed object deletion is recorded for retry'
);
select is(
  (select status from public.settlement_evidence_retention_jobs
   where evidence_id = 'a4000000-0000-4000-8000-000000000001'),
  'pending',
  'transient deletion failure returns the job to pending'
);
create temporary table phase4d2_retention_retry_again (
  job_id uuid,
  evidence_id uuid,
  storage_path text,
  source_sha256 text,
  claim_token uuid,
  attempt_count integer,
  scheduled_for timestamptz
) on commit drop;
insert into phase4d2_retention_retry_again
select * from public.claim_settlement_evidence_retention_jobs(
  10, 'test-worker', gen_random_uuid()
);
select is(
  (select attempt_count from phase4d2_retention_retry_again),
  3,
  'retry attempts are counted monotonically'
);
select lives_ok(
  $sql$select public.complete_settlement_evidence_retention_job(
    (select job_id from phase4d2_retention_retry_again),
    (select claim_token from phase4d2_retention_retry_again),
    true, null, gen_random_uuid()
  )$sql$,
  'a retried deletion can complete successfully'
);
select is(
  (select count(*) from public.settlement_evidence_retention_jobs where status = 'deleted'),
  2::bigint,
  'completed jobs remain as an immutable-lifecycle ledger'
);
select throws_ok(
  $sql$update public.settlement_evidence_retention_holds
  set reason = 'mutated hold reason'
  where evidence_id = 'a4000000-0000-4000-8000-000000000001'$sql$,
  '55000', 'settlement evidence retention hold history is immutable',
  'legal hold history cannot be edited'
);
select throws_ok(
  $sql$delete from public.settlement_evidence_retention_holds
  where evidence_id = 'a4000000-0000-4000-8000-000000000001'$sql$,
  '55000', 'settlement evidence retention hold history is immutable',
  'legal hold history cannot be deleted'
);
select lives_ok(
  $sql$select public.set_settlement_evidence_retention_enabled(
    false, 'Retention paused pending renewed legal review',
    'a1000000-0000-4000-8000-000000000001', gen_random_uuid()
  )$sql$,
  'admin can disable automated deletion'
);
select is(
  (select count(*) from public.claim_settlement_evidence_retention_jobs(10, 'test-worker', gen_random_uuid())),
  0::bigint,
  'disabling retention prevents further claims'
);
select is(
  (select count(*) from public.audit_events
   where action in ('settlement.evidence.retention_enabled','settlement.evidence.retention_disabled')),
  2::bigint,
  'retention activation and deactivation are both audited'
);

select * from finish();
rollback;
