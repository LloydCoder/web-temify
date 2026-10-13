begin;
select plan(15);

select has_column('public', 'products', 'summary', 'products have a bounded summary field');
select has_column('public', 'products', 'compatibility', 'products carry structured compatibility metadata');
select has_column('public', 'products', 'rights_status', 'products carry explicit rights review state');
select has_column('public', 'products', 'artifact_sha256', 'products require content-addressed artifact evidence for public visibility');
select has_table('public', 'product_rights_attestations', 'rights attestations are stored separately');
select has_table('public', 'product_versions', 'product releases are versioned');
select ok((select relrowsecurity from pg_class where oid = 'public.product_rights_attestations'::regclass), 'rights attestations have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.product_versions'::regclass), 'product versions have RLS enabled');
select ok(not has_table_privilege('anon', 'public.product_rights_attestations', 'SELECT'), 'anonymous users cannot read rights evidence');
select ok(not has_table_privilege('authenticated', 'public.product_rights_attestations', 'UPDATE'), 'creators cannot self-approve rights evidence');
select ok(not has_table_privilege('authenticated', 'public.product_versions', 'UPDATE'), 'creators cannot promote a release to released');
select ok(not has_table_privilege('anon', 'public.product_versions', 'SELECT'), 'anonymous users cannot read private artifact storage paths');
select ok(has_table_privilege('service_role', 'public.product_versions', 'UPDATE'), 'trusted release path can manage release state');
select ok(has_table_privilege('service_role', 'public.product_rights_attestations', 'UPDATE'), 'trusted review path can manage rights state');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
 ('71000000-0000-4000-8000-000000000071', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase3-catalogue@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase 3 Catalogue"}'::jsonb),
 ('75000000-0000-4000-8000-000000000075', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase3-reviewer@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase 3 Reviewer"}'::jsonb)
on conflict (id) do nothing;
insert into public.categories (id, slug, name, is_active)
values ('72000000-0000-4000-8000-000000000072', 'phase3-category', 'Phase 3 Category', true)
on conflict (id) do nothing;
insert into public.products (id, creator_id, category_id, slug, name, summary, description, product_type, status, rights_status, rights_verified_at, rights_verified_by, artifact_sha256)
values
 ('73000000-0000-4000-8000-000000000073', '71000000-0000-4000-8000-000000000071', '72000000-0000-4000-8000-000000000072', 'phase3-verified-product', 'Phase 3 Verified Product', 'Approved fixture', 'Synthetic fixture used only by database tests.', 'template', 'published', 'verified', now(), '75000000-0000-4000-8000-000000000075', repeat('a', 64)),
 ('74000000-0000-4000-8000-000000000074', '71000000-0000-4000-8000-000000000071', '72000000-0000-4000-8000-000000000072', 'phase3-unverified-product', 'Phase 3 Unverified Product', 'Unapproved fixture', 'Synthetic fixture used only by database tests.', 'template', 'published', 'declared', null, null, repeat('b', 64))
on conflict (id) do nothing;

insert into public.product_versions (product_id, version, release_state, release_notes, artifact_sha256, artifact_storage_path, manifest, compatibility, created_by, released_at)
values ('73000000-0000-4000-8000-000000000073', '1.0.0', 'released', 'Synthetic release fixture', repeat('a', 64), 'private/phase3/verified-product-1.0.0.zip', '{}'::jsonb, '{}'::jsonb, '71000000-0000-4000-8000-000000000071', now())
on conflict (product_id, version) do nothing;

set local role anon;
select is((select count(*) from public.products where slug like 'phase3-%'), 1::bigint, 'public catalogue excludes products without verified rights');
reset role;

select * from finish();
rollback;
