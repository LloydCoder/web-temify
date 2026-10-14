begin;
select plan(20);

select has_table('public', 'settlement_evidence_links', 'evidence-to-import links are persisted separately');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.settlement_evidence_links'::regclass),
  'evidence-to-import links have RLS enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.settlement_evidence_links', 'SELECT'),
  'authenticated clients cannot read evidence-to-import links'
);
select ok(
  not has_table_privilege('authenticated', 'public.settlement_evidence_links', 'INSERT'),
  'authenticated clients cannot create evidence-to-import links directly'
);
select ok(
  not has_table_privilege('service_role', 'public.settlement_evidence_links', 'INSERT'),
  'service role must use the guarded evidence-link RPC rather than direct inserts'
);
select ok(
  has_function_privilege('service_role', 'public.link_settlement_evidence(uuid,uuid,uuid,uuid)', 'EXECUTE'),
  'service role can call the guarded evidence-link RPC'
);
select ok(
  not has_function_privilege('authenticated', 'public.link_settlement_evidence(uuid,uuid,uuid,uuid)', 'EXECUTE'),
  'authenticated clients cannot call the evidence-link RPC'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('8c000000-0000-4000-8000-00000000008c', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'evidence-link-uploader@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('8d000000-0000-4000-8000-00000000008d', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'evidence-link-importer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('8e000000-0000-4000-8000-00000000008e', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'evidence-link-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('8f000000-0000-4000-8000-00000000008f', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'evidence-link-nonadmin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values
  ('8c000000-0000-4000-8000-00000000008c', 'admin'::public.app_role),
  ('8d000000-0000-4000-8000-00000000008d', 'admin'::public.app_role),
  ('8e000000-0000-4000-8000-00000000008e', 'admin'::public.app_role)
on conflict do nothing;

create temporary table phase4d2_link_import_ids(import_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_link_import_ids
    select public.import_settlement_report(
      'sandbox', 'evidence-link-account', 'evidence-link-report',
      '2026-10-13', '2026-10-13', 'UTC', repeat('a',64), true,
      'sandbox_fixture', 'USD', '8d000000-0000-4000-8000-00000000008d',
      jsonb_build_array(jsonb_build_object(
        'rowId','evidence-link-row-01', 'rowType','payment',
        'providerReference','evidence-link-provider-reference',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',100, 'feeMinor',0, 'netMinor',100
      ))
    )
  $sql$,
  'the normalized import fixture is persisted'
);

insert into public.settlement_evidence (
  id, storage_path, source_sha256, mime_type, byte_size, original_filename, uploaded_by
) values (
  '8b000000-0000-4000-8000-00000000008b',
  '8b000000-0000-4000-8000-00000000008b/' || repeat('a',64),
  repeat('a',64), 'text/csv', 100, 'settlement-report.csv',
  '8c000000-0000-4000-8000-00000000008c'
);

create temporary table phase4d2_link_ids(link_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_link_ids
    select public.link_settlement_evidence(
      '8b000000-0000-4000-8000-00000000008b',
      (select import_id from phase4d2_link_import_ids),
      '8e000000-0000-4000-8000-00000000008e',
      '8e000000-0000-4000-8000-00000000008e'
    )
  $sql$,
  'an independent admin can link evidence whose digest matches the import'
);

select is(
  public.link_settlement_evidence(
    '8b000000-0000-4000-8000-00000000008b',
    (select import_id from phase4d2_link_import_ids),
    '8e000000-0000-4000-8000-00000000008e',
    '8e000000-0000-4000-8000-00000000008e'
  ),
  (select link_id from phase4d2_link_ids),
  'replaying the same evidence link returns the original link id'
);

create temporary table phase4d2_other_import_ids(import_id uuid primary key) on commit drop;
select lives_ok(
  $sql$
    insert into phase4d2_other_import_ids
    select public.import_settlement_report(
      'sandbox', 'evidence-link-account', 'evidence-link-other-report',
      '2026-10-13', '2026-10-13', 'UTC', repeat('b',64), true,
      'sandbox_fixture', 'USD', '8d000000-0000-4000-8000-00000000008d',
      jsonb_build_array(jsonb_build_object(
        'rowId','evidence-link-other-row-01', 'rowType','payment',
        'providerReference','evidence-link-other-provider-reference',
        'occurredAt','2026-10-13T10:00:00Z', 'currency','USD',
        'grossMinor',200, 'feeMinor',0, 'netMinor',200
      ))
    )
  $sql$,
  'a second report with different source bytes is persisted'
);

select throws_ok(
  $sql$select public.link_settlement_evidence(
    '8b000000-0000-4000-8000-00000000008b',
    (select import_id from phase4d2_other_import_ids),
    '8e000000-0000-4000-8000-00000000008e',
    '8e000000-0000-4000-8000-00000000008e'
  )$sql$,
  '23514', 'settlement evidence digest does not match settlement import source digest',
  'evidence cannot be linked to an import with a different source digest'
);

select throws_ok(
  $sql$select public.link_settlement_evidence(
    '8b000000-0000-4000-8000-00000000008b',
    (select import_id from phase4d2_link_import_ids),
    '8c000000-0000-4000-8000-00000000008c',
    '8c000000-0000-4000-8000-00000000008c'
  )$sql$,
  '42501', 'settlement evidence linking requires a distinct independent admin',
  'the evidence uploader cannot independently approve their own evidence link'
);

select throws_ok(
  $sql$select public.link_settlement_evidence(
    '8b000000-0000-4000-8000-00000000008b',
    (select import_id from phase4d2_link_import_ids),
    '8f000000-0000-4000-8000-00000000008f',
    '8f000000-0000-4000-8000-00000000008f'
  )$sql$,
  '42501', 'settlement evidence linking requires a distinct independent admin',
  'a non-admin cannot link settlement evidence'
);


select throws_ok(
  $sql$select public.link_settlement_evidence(
    '8b000000-0000-4000-8000-00000000008b',
    (select import_id from phase4d2_link_import_ids),
    '8d000000-0000-4000-8000-00000000008d',
    '8d000000-0000-4000-8000-00000000008d'
  )$sql$,
  '42501', 'settlement evidence linking requires a distinct independent admin',
  'the report importer cannot independently approve their own evidence link'
);

select throws_ok(
  $sql$update public.settlement_evidence_links
  set import_id = (select import_id from phase4d2_other_import_ids)
  where id = (select link_id from phase4d2_link_ids)$sql$,
  '55000', 'settlement evidence link is immutable',
  'an evidence-to-import link cannot be mutated'
);

select throws_ok(
  $sql$delete from public.settlement_evidence_links
  where id = (select link_id from phase4d2_link_ids)$sql$,
  '55000', 'settlement evidence link is immutable',
  'an evidence-to-import link cannot be deleted'
);

select is(
  (select count(*) from public.settlement_evidence_links
   where evidence_id = '8b000000-0000-4000-8000-00000000008b'),
  1::bigint,
  'one evidence object cannot be linked to multiple imports'
);

select is(
  (select source_sha256 from public.settlement_evidence_links
   where id = (select link_id from phase4d2_link_ids)),
  repeat('a',64),
  'the immutable link records the exact matching source digest'
);

select is(
  (select count(*) from public.audit_events
   where action = 'settlement.evidence.linked'
     and entity_id = (select link_id::text from phase4d2_link_ids)),
  1::bigint,
  'successful evidence linkage and its audit event commit atomically'
);

select * from finish();
rollback;
