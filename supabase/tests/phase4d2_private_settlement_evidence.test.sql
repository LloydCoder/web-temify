begin;
select plan(13);

select has_table('public', 'settlement_evidence', 'private settlement evidence metadata table exists');
select ok(
  (select not public from storage.buckets where id = 'settlement-evidence'),
  'settlement evidence bucket is private'
);
select is(
  (select file_size_limit::bigint from storage.buckets where id = 'settlement-evidence'),
  5242880::bigint,
  'settlement evidence bucket enforces a 5 MiB maximum'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_evidence'::regclass),
  'settlement evidence metadata has RLS enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.settlement_evidence', 'SELECT'),
  'authenticated clients cannot read settlement evidence metadata'
);
select ok(
  not has_table_privilege('authenticated', 'public.settlement_evidence', 'INSERT'),
  'authenticated clients cannot create settlement evidence metadata directly'
);
select ok(
  not has_table_privilege('service_role', 'public.settlement_evidence', 'UPDATE'),
  'service role cannot update immutable evidence metadata'
);
select ok(
  not has_table_privilege('service_role', 'public.settlement_evidence', 'DELETE'),
  'service role cannot delete immutable evidence metadata'
);
select ok(
  not has_table_privilege('service_role', 'public.settlement_evidence', 'INSERT'),
  'service role must use the atomic recording RPC instead of direct evidence inserts'
);
select ok(
  has_function_privilege('service_role', 'public.record_settlement_evidence(uuid,text,text,text,bigint,text,uuid,uuid)', 'EXECUTE'),
  'service role can call the atomic evidence recording RPC'
);
select ok(
  not has_function_privilege('authenticated', 'public.record_settlement_evidence(uuid,text,text,text,bigint,text,uuid,uuid)', 'EXECUTE'),
  'authenticated clients cannot call the evidence recording RPC'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values (
  '8a000000-0000-4000-8000-00000000008a',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'evidence-admin@example.test', '',
  now(), now(), now(), '{}'::jsonb, '{}'::jsonb
) on conflict (id) do nothing;

insert into public.settlement_evidence (
  id, storage_path, source_sha256, mime_type, byte_size, original_filename, uploaded_by
) values (
  '8b000000-0000-4000-8000-00000000008b',
  '8b000000-0000-4000-8000-00000000008b/' || repeat('a', 64),
  repeat('a', 64), 'text/csv', 4, 'report.csv',
  '8a000000-0000-4000-8000-00000000008a'
);

select throws_ok(
  $sql$update public.settlement_evidence set original_filename = 'changed.csv'
  where id = '8b000000-0000-4000-8000-00000000008b'$sql$,
  '23514', null, 'evidence metadata cannot be updated'
);
select throws_ok(
  $sql$delete from public.settlement_evidence
  where id = '8b000000-0000-4000-8000-00000000008b'$sql$,
  '23514', null, 'evidence metadata cannot be deleted'
);

select * from finish();
rollback;
