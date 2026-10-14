begin;
select plan(34);

select has_table('public', 'settlement_evidence_retention_jobs', 'retention work queue exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_evidence_retention_jobs'::regclass),
  'retention work queue has RLS enabled'
);
select ok(not has_table_privilege('authenticated', 'public.settlement_evidence_retention_jobs', 'SELECT'),
  'authenticated clients cannot inspect retention jobs');
select ok(has_table_privilege('service_role', 'public.settlement_evidence_retention_jobs', 'SELECT'),
  'service role can read retention status for protected download handling');
select ok(not has_table_privilege('service_role', 'public.settlement_evidence_retention_jobs', 'INSERT'),
  'service role cannot insert retention jobs directly');
select ok(not has_table_privilege('service_role', 'public.settlement_evidence_retention_jobs', 'UPDATE'),
  'service role cannot mutate retention jobs directly');
select ok(not has_table_privilege('service_role', 'public.settlement_evidence_retention_jobs', 'DELETE'),
  'service role cannot delete retention history');
select ok(has_function_privilege('service_role', 'public.claim_expired_settlement_evidence(integer,uuid)', 'EXECUTE'),
  'service role can claim expired evidence');
select ok(not has_function_privilege('authenticated', 'public.claim_expired_settlement_evidence(integer,uuid)', 'EXECUTE'),
  'authenticated clients cannot claim retention work');
select ok(has_function_privilege('service_role', 'public.finish_settlement_evidence_retention(uuid,uuid,boolean,text)', 'EXECUTE'),
  'service role can finish retention work');
select ok(not has_function_privilege('authenticated', 'public.finish_settlement_evidence_retention(uuid,uuid,boolean,text)', 'EXECUTE'),
  'authenticated clients cannot finish retention work');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('80000000-0000-4000-8000-000000000080', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'retention-importer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('80100000-0000-4000-8000-000000000080', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'retention-uploader@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('80200000-0000-4000-8000-000000000080', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'retention-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values
  ('80000000-0000-4000-8000-000000000080', 'admin'::public.app_role),
  ('80100000-0000-4000-8000-000000000080', 'admin'::public.app_role),
  ('80200000-0000-4000-8000-000000000080', 'admin'::public.app_role)
on conflict do nothing;

create temporary table phase4d2_retention_imports (
  label text primary key,
  import_id uuid not null
) on commit drop;

select lives_ok(
  $sql$
    insert into phase4d2_retention_imports
    select 'expired', public.import_settlement_report(
      'sandbox', 'retention-account', 'retention-expired-report',
      '2026-10-13', '2026-10-13', 'UTC', repeat('a',64), true,
      'sandbox_fixture', 'USD', '80000000-0000-4000-8000-000000000080',
      jsonb_build_array(jsonb_build_object(
        'rowId','retention-expired-row', 'rowType','payment',
        'providerReference','retention-expired-reference',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',100, 'feeMinor',0, 'netMinor',100
      ))
    )
  $sql$,
  'a sandbox report can be prepared for expired-link denial'
);

select lives_ok(
  $sql$
    insert into phase4d2_retention_imports
    select 'linked', public.import_settlement_report(
      'sandbox', 'retention-account', 'retention-linked-report',
      '2026-10-13', '2026-10-13', 'UTC', repeat('c',64), true,
      'sandbox_fixture', 'USD', '80000000-0000-4000-8000-000000000080',
      jsonb_build_array(jsonb_build_object(
        'rowId','retention-linked-row', 'rowType','payment',
        'providerReference','retention-linked-reference',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',100, 'feeMinor',0, 'netMinor',100
      ))
    )
  $sql$,
  'a separate sandbox report can be prepared for linked-evidence retention'
);

insert into public.settlement_evidence (
  id, storage_path, source_sha256, mime_type, byte_size, original_filename,
  uploaded_by, uploaded_at, retention_until
) values
  ('81000000-0000-4000-8000-000000000080',
   '81000000-0000-4000-8000-000000000080/' || repeat('a',64),
   repeat('a',64), 'text/csv', 100, 'expired-unlinked-a.csv',
   '80100000-0000-4000-8000-000000000080', now() - interval '400 days', now() - interval '35 days'),
  ('81100000-0000-4000-8000-000000000080',
   '81100000-0000-4000-8000-000000000080/' || repeat('b',64),
   repeat('b',64), 'text/csv', 100, 'expired-unlinked-b.csv',
   '80100000-0000-4000-8000-000000000080', now() - interval '400 days', now() - interval '35 days'),
  ('81200000-0000-4000-8000-000000000080',
   '81200000-0000-4000-8000-000000000080/' || repeat('c',64),
   repeat('c',64), 'text/csv', 100, 'expired-linked.csv',
   '80100000-0000-4000-8000-000000000080', now() - interval '400 days', now() - interval '35 days'),
  ('81300000-0000-4000-8000-000000000080',
   '81300000-0000-4000-8000-000000000080/' || repeat('d',64),
   repeat('d',64), 'text/csv', 100, 'fresh-evidence.csv',
   '80100000-0000-4000-8000-000000000080', now(), now() + interval '365 days');

select public.record_settlement_evidence_scan_result(
  '81000000-0000-4000-8000-000000000080', repeat('a',64), 'clean',
  'test-scanner', '1.0.0', gen_random_uuid()
);
select public.record_settlement_evidence_scan_result(
  '81200000-0000-4000-8000-000000000080', repeat('c',64), 'clean',
  'test-scanner', '1.0.0', gen_random_uuid()
);
-- Seed an existing historical link: the row is expired now, but the link was
-- established before its retention deadline. This models legacy linked evidence.
insert into public.settlement_evidence_links (
  evidence_id, import_id, source_sha256, linked_by, request_id
) values (
  '81200000-0000-4000-8000-000000000080',
  (select import_id from phase4d2_retention_imports where label = 'linked'),
  repeat('c',64), '80200000-0000-4000-8000-000000000080', gen_random_uuid()
);

select is(
  (select count(*)::integer from public.settlement_evidence_links
   where evidence_id = '81200000-0000-4000-8000-000000000080'),
  1,
  'the fixture confirms that the expired linked object is protected by an immutable link'
);
select is(
  (select count(*)::integer from public.claim_expired_settlement_evidence(25, '81400000-0000-4000-8000-000000000080')),
  2,
  'claim returns only expired evidence that is not already linked'
);
select is(
  (select count(*)::integer from public.settlement_evidence_retention_jobs where status = 'processing'),
  2,
  'claimed evidence receives an active bounded lease'
);
update public.settlement_evidence_retention_jobs
set lease_expires_at = now() - interval '1 minute'
where evidence_id = '81000000-0000-4000-8000-000000000080';

select is(
  (select count(*)::integer
   from public.claim_expired_settlement_evidence(25, '81500000-0000-4000-8000-000000000080')
   where evidence_id = '81000000-0000-4000-8000-000000000080'),
  1,
  'an expired worker lease can be safely reclaimed'
);
select throws_ok(
  $sql$select public.finish_settlement_evidence_retention(
    '81000000-0000-4000-8000-000000000080',
    '81400000-0000-4000-8000-000000000080', false, 'storage_delete_failed'
  )$sql$,
  '55000', 'settlement evidence retention claim is stale',
  'a stale worker cannot overwrite a newer claim outcome'
);
select is(
  (select attempts from public.settlement_evidence_retention_jobs
   where evidence_id = '81000000-0000-4000-8000-000000000080'),
  2,
  'lease recovery increments the attempt count'
);
select is(
  (select count(*)::integer from public.settlement_evidence_retention_jobs
   where evidence_id = '81200000-0000-4000-8000-000000000080'),
  0,
  'expired evidence linked to an import is preserved'
);
select is(
  (select count(*)::integer from public.settlement_evidence_retention_jobs
   where evidence_id = '81300000-0000-4000-8000-000000000080'),
  0,
  'evidence inside its retention period is not claimed'
);
select is(
  (select count(*)::integer from public.audit_events
   where action = 'settlement.evidence.retention_delete_requested'),
  3,
  'each claimed deletion has a correlated audit event'
);
select throws_ok(
  $sql$select public.link_settlement_evidence(
    '81000000-0000-4000-8000-000000000080',
    (select import_id from phase4d2_retention_imports where label = 'expired'),
    '80200000-0000-4000-8000-000000000080', gen_random_uuid()
  )$sql$,
  '23514', 'expired settlement evidence cannot be linked',
  'expired evidence cannot be linked after its clean scan'
);

select lives_ok(
  $sql$select public.finish_settlement_evidence_retention(
    '81000000-0000-4000-8000-000000000080', '81500000-0000-4000-8000-000000000080', true, null
  )$sql$,
  'a successful storage removal can be recorded'
);
select is(
  (select status from public.settlement_evidence_retention_jobs
   where evidence_id = '81000000-0000-4000-8000-000000000080'),
  'deleted',
  'successful retention completion leaves an immutable tombstone'
);
select ok(
  exists (select 1 from public.settlement_evidence
          where id = '81000000-0000-4000-8000-000000000080'
            and source_sha256 = repeat('a',64)),
  'source metadata and digest remain available after object deletion'
);
select is(
  (select count(*)::integer from public.audit_events
   where action = 'settlement.evidence.retention_deleted'
     and entity_id = '81000000-0000-4000-8000-000000000080'),
  1,
  'successful deletion is audited without deleting audit history'
);

select is(
  public.finish_settlement_evidence_retention(
    '81100000-0000-4000-8000-000000000080', '81400000-0000-4000-8000-000000000080', false, 'storage_delete_failed'
  ),
  'retryable',
  'a failed storage removal is eligible for bounded retry'
);
select is(
  (select count(*)::integer from public.claim_expired_settlement_evidence(25, gen_random_uuid())),
  1,
  'a failed deletion is retried without reclaiming the completed tombstone'
);
select is(
  (select attempts from public.settlement_evidence_retention_jobs
   where evidence_id = '81100000-0000-4000-8000-000000000080'),
  2,
  'retry attempts are counted transactionally'
);
select lives_ok(
  $sql$
    do $block$
    declare
      claimed_count integer;
      attempt_request uuid;
    begin
      for i in 1..3 loop
        attempt_request := gen_random_uuid();
        select count(*) into claimed_count
        from public.claim_expired_settlement_evidence(25, attempt_request)
        where evidence_id = '81100000-0000-4000-8000-000000000080';
        if claimed_count <> 1 then
          raise exception 'expected one retry claim on attempt %', i;
        end if;
        perform public.finish_settlement_evidence_retention(
          '81100000-0000-4000-8000-000000000080',
          attempt_request, false, 'storage_delete_failed'
        );
      end loop;
    end
    $block$
  $sql$,
  'repeated storage failures are bounded and eventually stop retrying'
);
select is(
  (select status from public.settlement_evidence_retention_jobs
   where evidence_id = '81100000-0000-4000-8000-000000000080'),
  'blocked',
  'five failed attempts block deletion for operator review'
);
select is(
  (select count(*)::integer from public.claim_expired_settlement_evidence(25, gen_random_uuid())),
  0,
  'blocked and deleted evidence cannot be reclaimed'
);
select throws_ok(
  $sql$select * from public.claim_expired_settlement_evidence(26, gen_random_uuid())$sql$,
  '22023', 'settlement evidence retention claim limit or request id is invalid',
  'claim limits cannot be raised above 25'
);

select * from finish();
rollback;
