begin;
select plan(23);

select has_table('public', 'payment_dispute_evidence', 'private dispute evidence metadata exists');
select has_table('public', 'payment_dispute_evidence_scan_results', 'immutable dispute evidence scan attestations exist');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_dispute_evidence'::regclass), 'dispute evidence metadata has RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.payment_dispute_evidence_scan_results'::regclass), 'dispute evidence scan results have RLS enabled');
select ok(not has_table_privilege('anon', 'public.payment_dispute_evidence', 'SELECT'), 'anonymous clients cannot read dispute evidence metadata');
select ok(not has_table_privilege('authenticated', 'public.payment_dispute_evidence', 'SELECT'), 'authenticated clients cannot read dispute evidence metadata');
select ok(not has_table_privilege('service_role', 'public.payment_dispute_evidence', 'SELECT'), 'service role cannot bypass audited evidence access RPC');
select ok(not has_table_privilege('service_role', 'public.payment_dispute_evidence', 'INSERT'), 'service role cannot directly insert evidence metadata');
select ok(not has_table_privilege('service_role', 'public.payment_dispute_evidence', 'UPDATE'), 'service role cannot update immutable evidence metadata');
select ok(not has_table_privilege('anon', 'public.payment_dispute_evidence_scan_results', 'SELECT'), 'anonymous clients cannot read scan attestations');
select ok(not has_table_privilege('authenticated', 'public.payment_dispute_evidence_scan_results', 'SELECT'), 'authenticated clients cannot read scan attestations');
select ok(not has_table_privilege('service_role', 'public.payment_dispute_evidence_scan_results', 'SELECT'), 'service role cannot directly read scan attestations');
select ok(has_function_privilege('service_role', 'public.record_payment_dispute_evidence(uuid,uuid,text,text,text,bigint,text,uuid,uuid)', 'EXECUTE'), 'service role can call the atomic evidence-recording RPC');
select ok(not has_function_privilege('authenticated', 'public.record_payment_dispute_evidence(uuid,uuid,text,text,text,bigint,text,uuid,uuid)', 'EXECUTE'), 'authenticated clients cannot record evidence');
select ok(has_function_privilege('service_role', 'public.record_payment_dispute_evidence_scan_result(uuid,text,text,text,text,timestamptz,uuid)', 'EXECUTE'), 'service role can record scan attestations');
select ok(not has_function_privilege('authenticated', 'public.record_payment_dispute_evidence_scan_result(uuid,text,text,text,text,timestamptz,uuid)', 'EXECUTE'), 'authenticated clients cannot forge scan attestations');
select ok(has_function_privilege('service_role', 'public.get_payment_dispute_evidence_for_admin(uuid,uuid,uuid,uuid)', 'EXECUTE'), 'service role can use the audited evidence-access RPC');
select ok(not has_function_privilege('authenticated', 'public.get_payment_dispute_evidence_for_admin(uuid,uuid,uuid,uuid)', 'EXECUTE'), 'authenticated clients cannot request audited evidence-access records');
select ok((select b.public = false from storage.buckets b where b.id = 'payment-dispute-evidence'), 'dispute evidence storage bucket is private');
select is((select b.file_size_limit from storage.buckets b where b.id = 'payment-dispute-evidence'), 5242880::bigint, 'dispute evidence bucket caps objects at 5 MiB');

select throws_ok(
  $sql$select public.record_payment_dispute_evidence(
    'a4000000-0000-4000-8000-000000000401',
    'a2000000-0000-4000-8000-000000000402',
    'a2000000-0000-4000-8000-000000000402/a4000000-0000-4000-8000-000000000401/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    repeat('a', 64), 'application/pdf', 1, 'evidence.pdf',
    'a3000000-0000-4000-8000-000000000403',
    'a5000000-0000-4000-8000-000000000404'
  )$sql$,
  '42501',
  'payment dispute evidence upload requires an admin',
  'evidence metadata RPC rejects an actor without the admin role'
);

select throws_ok(
  $sql$select public.record_payment_dispute_evidence_scan_result(
    'a4000000-0000-4000-8000-000000000401',
    'not-a-sha256-digest', 'clean', 'clamav', '1.5.4',
    clock_timestamp(), 'a5000000-0000-4000-8000-000000000405'
  )$sql$,
  '23514',
  'payment dispute evidence scan metadata failed validation',
  'scan RPC rejects malformed source digests'
);

select throws_ok(
  $sql$select * from public.get_payment_dispute_evidence_for_admin(
    'a2000000-0000-4000-8000-000000000402',
    'a4000000-0000-4000-8000-000000000401',
    'a3000000-0000-4000-8000-000000000403',
    'a5000000-0000-4000-8000-000000000406'
  )$sql$,
  '42501',
  'payment dispute evidence access requires an admin',
  'audited access RPC rejects an actor without the admin role'
);

select * from finish();
rollback;
