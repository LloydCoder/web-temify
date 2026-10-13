begin;
select plan(19);
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
 ('10000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-user-one@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"User One"}'::jsonb),
 ('20000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-user-two@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"User Two"}'::jsonb)
on conflict (id) do nothing;
insert into public.profiles (id, display_name) values
 ('10000000-0000-4000-8000-000000000001', 'User One'),
 ('20000000-0000-4000-8000-000000000002', 'User Two')
on conflict (id) do nothing;
select is((select display_name from public.profiles where id = '10000000-0000-4000-8000-000000000001'), 'User One', 'auth signup creates profile from bounded display-name metadata');
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
update public.profiles set display_name = 'Not allowed' where id = '10000000-0000-4000-8000-000000000001';
reset role;
select is((select display_name from public.profiles where id = '10000000-0000-4000-8000-000000000001'), 'User One', 'non-owner cannot update another profile');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.products), 2::bigint, 'creator can see own draft as well as published products');
update public.profiles set display_name = 'User One Updated' where id = '10000000-0000-4000-8000-000000000001';
reset role;
select is((select display_name from public.profiles where id = '10000000-0000-4000-8000-000000000001'), 'User One Updated', 'owner can update own profile');

select ok(not has_table_privilege('anon', 'public.audit_events', 'SELECT'), 'anonymous clients cannot read audit events');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'INSERT'), 'authenticated clients cannot forge audit events');
select ok(has_table_privilege('service_role', 'public.audit_events', 'INSERT'), 'trusted service role can append audit events');
select * from finish();
rollback;
