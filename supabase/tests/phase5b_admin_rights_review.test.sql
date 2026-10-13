begin;
select plan(29);

select ok((select n.nspname = 'public' from pg_proc f join pg_namespace n on n.oid = f.pronamespace where f.oid = 'public.admin_review_product_rights(uuid,uuid,uuid,text,text,uuid)'::regprocedure), 'RPC is in the exposed schema for server-side PostgREST access');
select has_function('public', 'admin_review_product_rights', array['uuid','uuid','uuid','text','text','uuid'], 'admin rights-review RPC exists');
select ok(has_function_privilege('service_role', 'public.admin_review_product_rights(uuid,uuid,uuid,text,text,uuid)', 'EXECUTE'), 'trusted server role can call the rights-review RPC');
select ok(not has_function_privilege('authenticated', 'public.admin_review_product_rights(uuid,uuid,uuid,text,text,uuid)', 'EXECUTE'), 'authenticated clients cannot call the rights-review RPC');
select ok(not has_function_privilege('anon', 'public.admin_review_product_rights(uuid,uuid,uuid,text,text,uuid)', 'EXECUTE'), 'anonymous clients cannot call the rights-review RPC');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
 ('87000000-0000-4000-8000-000000000087', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase5b-creator@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Rights Creator"}'),
 ('88000000-0000-4000-8000-000000000088', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase5b-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Rights Reviewer"}')
on conflict (id) do nothing;
insert into public.user_roles (user_id, role)
values ('88000000-0000-4000-8000-000000000088', 'admin')
on conflict (user_id, role) do nothing;

insert into public.products (id, creator_id, slug, name, product_type, status, price_minor, currency)
values
 ('89000000-0000-4000-8000-000000000089', '87000000-0000-4000-8000-000000000087', 'phase5b-review-verified', 'Rights review verified fixture', 'template', 'pending_review', 0, 'USD'),
 ('89000000-0000-4000-8000-000000000090', '87000000-0000-4000-8000-000000000087', 'phase5b-review-pending', 'Rights review pending fixture', 'template', 'pending_review', 0, 'USD'),
 ('89000000-0000-4000-8000-000000000091', '87000000-0000-4000-8000-000000000087', 'phase5b-review-rejected', 'Rights review rejected fixture', 'template', 'pending_review', 0, 'USD'),
 ('89000000-0000-4000-8000-000000000092', '88000000-0000-4000-8000-000000000088', 'phase5b-review-self', 'Rights review self fixture', 'template', 'pending_review', 0, 'USD')
on conflict (id) do nothing;

insert into public.product_rights_attestations (id, product_id, attested_by, rights_basis, statement, review_status)
values
 ('89100000-0000-4000-8000-000000000089', '89000000-0000-4000-8000-000000000089', '87000000-0000-4000-8000-000000000087', 'original_work', 'I confirm I created this work and have rights to all included assets.', 'declared'),
 ('89100000-0000-4000-8000-000000000090', '89000000-0000-4000-8000-000000000090', '87000000-0000-4000-8000-000000000087', 'original_work', 'I confirm I created this work and have rights to all included assets.', 'declared'),
 ('89100000-0000-4000-8000-000000000091', '89000000-0000-4000-8000-000000000091', '87000000-0000-4000-8000-000000000087', 'original_work', 'I confirm I created this work and have rights to all included assets.', 'declared'),
 ('89100000-0000-4000-8000-000000000092', '89000000-0000-4000-8000-000000000092', '88000000-0000-4000-8000-000000000088', 'original_work', 'I confirm I created this work and have rights to all included assets.', 'declared')
on conflict (id) do nothing;

set local role service_role;
select lives_ok($$select public.admin_review_product_rights('89000000-0000-4000-8000-000000000089', '89100000-0000-4000-8000-000000000089', '88000000-0000-4000-8000-000000000088', 'verified', 'Reviewed the declared rights and evidence reference.', '89200000-0000-4000-8000-000000000089')$$, 'verified decision applies transactionally');
select lives_ok($$select public.admin_review_product_rights('89000000-0000-4000-8000-000000000090', '89100000-0000-4000-8000-000000000090', '88000000-0000-4000-8000-000000000088', 'under_review', 'Requesting additional evidence before final review.', '89200000-0000-4000-8000-000000000090')$$, 'under-review decision remains unresolved');
select lives_ok($$select public.admin_review_product_rights('89000000-0000-4000-8000-000000000091', '89100000-0000-4000-8000-000000000091', '88000000-0000-4000-8000-000000000088', 'rejected', 'The submitted rights evidence is insufficient for approval.', '89200000-0000-4000-8000-000000000091')$$, 'rejected decision applies transactionally');
reset role;

select is((select review_status from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000089'), 'verified', 'verified attestation state persists');
select is((select reviewed_by from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000089'), '88000000-0000-4000-8000-000000000088'::uuid, 'verified attestation records independent reviewer');
select ok((select reviewed_at is not null from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000089'), 'verified attestation records review timestamp');
select is((select rights_status from public.products where id = '89000000-0000-4000-8000-000000000089'), 'verified', 'product rights status follows verified attestation');
select is((select rights_verified_by from public.products where id = '89000000-0000-4000-8000-000000000089'), '88000000-0000-4000-8000-000000000088'::uuid, 'product records reviewer identity');
select ok(exists (select 1 from public.audit_events where action = 'admin.product_rights.reviewed' and entity_id = '89000000-0000-4000-8000-000000000089' and metadata ->> 'decision' = 'verified'), 'verified decision has an append-only audit record');

select is((select review_status from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000090'), 'under_review', 'under-review state persists');
select is((select reviewed_by from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000090'), null::uuid, 'under-review state does not claim a final reviewer');
select is((select reviewed_at from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000090'), null::timestamptz, 'under-review state has no final review timestamp');
select is((select rights_status from public.products where id = '89000000-0000-4000-8000-000000000090'), 'under_review', 'product rights state remains under review');

select is((select review_status from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000091'), 'rejected', 'rejected attestation state persists');
select is((select reviewed_by from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000091'), '88000000-0000-4000-8000-000000000088'::uuid, 'rejection records reviewer identity');
select ok((select reviewed_at is not null from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000091'), 'rejection records review timestamp');
select is((select rights_status from public.products where id = '89000000-0000-4000-8000-000000000091'), 'rejected', 'product rights state follows rejection');
select is((select rights_verified_at from public.products where id = '89000000-0000-4000-8000-000000000091'), null::timestamptz, 'rejected product has no verification timestamp');

select throws_ok(
  $$select public.admin_review_product_rights('89000000-0000-4000-8000-000000000092', '89100000-0000-4000-8000-000000000092', '88000000-0000-4000-8000-000000000088', 'verified', 'Attempt to review my own evidence.', '89200000-0000-4000-8000-000000000092')$$,
  '42501',
  'Reviewers cannot review their own rights evidence.',
  'creator cannot review their own rights evidence'
);

select throws_ok(
  $$select public.admin_review_product_rights('89000000-0000-4000-8000-000000000092', '89100000-0000-4000-8000-000000000092', '87000000-0000-4000-8000-000000000087', 'verified', 'Non-admin must not review this evidence.', '89200000-0000-4000-8000-000000000093')$$,
  '42501',
  'Reviewer must have the admin role.',
  'non-admin identity cannot submit a review'
);

select throws_ok(
  $$select public.admin_review_product_rights('89000000-0000-4000-8000-000000000089', '89100000-0000-4000-8000-000000000089', '88000000-0000-4000-8000-000000000088', 'verified', 'Attempt to change an already resolved decision.', '89200000-0000-4000-8000-000000000094')$$,
  'P0002',
  'Rights attestation is already resolved.',
  'resolved evidence cannot be silently re-reviewed'
);

-- Simulate audit persistence failure. The rights decision must roll back with it.
revoke insert on public.audit_events from service_role;
set local role service_role;
select throws_ok(
  $select public.admin_review_product_rights('89000000-0000-4000-8000-000000000090', '89100000-0000-4000-8000-000000000090', '88000000-0000-4000-8000-000000000088', 'verified', 'Attempt must roll back when audit persistence is unavailable.', '89200000-0000-4000-8000-000000000095')$,
  '42501',
  'permission denied for table audit_events',
  'review decision fails when append-only audit persistence is unavailable'
);
reset role;
grant insert on public.audit_events to service_role;
select is((select review_status from public.product_rights_attestations where id = '89100000-0000-4000-8000-000000000090'), 'under_review', 'failed audit insert rolls back the attestation transition');
select is((select rights_status from public.products where id = '89000000-0000-4000-8000-000000000090'), 'under_review', 'failed audit insert rolls back the product rights transition');

select * from finish();
rollback;
