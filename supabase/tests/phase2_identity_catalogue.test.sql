begin;
select plan(13);
select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'categories', 'categories table exists');
select has_table('public', 'products', 'products table exists');
select has_table('public', 'audit_events', 'audit events table exists');
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profiles RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.categories'::regclass), 'categories RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.products'::regclass), 'products RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_events'::regclass), 'audit events RLS enabled');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
 ('10000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-user-one@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
 ('20000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-user-two@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;
insert into public.profiles (id, display_name) values
 ('10000000-0000-4000-8000-000000000001', 'User One'),
 ('20000000-0000-4000-8000-000000000002', 'User Two')
on conflict (id) do nothing;
insert into public.categories (id, slug, name, is_active) values
 ('30000000-0000-4000-8000-000000000003', 'active-category', 'Active category', true),
 ('40000000-0000-4000-8000-000000000004', 'inactive-category', 'Inactive category', false)
on conflict (id) do nothing;
insert into public.products (id, creator_id, category_id, slug, name, product_type, status)
values
 ('50000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'published-product', 'Published product', 'template', 'published'),
 ('60000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'draft-product', 'Draft product', 'template', 'draft')
on conflict (id) do nothing;

set local role anon;
select is((select count(*) from public.categories), 1::bigint, 'anonymous users see only active categories');
select is((select count(*) from public.products), 1::bigint, 'anonymous users see only published products');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.profiles), 1::bigint, 'authenticated user sees only own profile');
select is((select count(*) from public.products), 1::bigint, 'non-owner sees published product but not another creator draft');
select is((with changed as (update public.profiles set display_name = 'Not allowed' where id = '10000000-0000-4000-8000-000000000001' returning id) select count(*) from changed), 0::bigint, 'non-owner cannot update another profile');
reset role;
select * from finish();
rollback;
