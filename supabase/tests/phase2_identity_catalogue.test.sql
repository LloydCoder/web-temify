begin;
select plan(31);
select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'categories', 'categories table exists');
select has_table('public', 'products', 'products table exists');
select has_table('public', 'audit_events', 'audit events table exists');
select has_table('public', 'user_roles', 'user roles table exists');
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profiles RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.categories'::regclass), 'categories RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.products'::regclass), 'products RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_events'::regclass), 'audit events RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.user_roles'::regclass), 'user roles RLS enabled');

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
select is((select role::text from public.user_roles where user_id = '10000000-0000-4000-8000-000000000001'), 'customer', 'signup assigns only the default customer role');
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
insert into public.products (creator_id, category_id, slug, name, product_type, status)
values ('10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'user-created-draft', 'User-created draft', 'template', 'draft');
select is((select count(*) from public.products where slug = 'user-created-draft'), 1::bigint, 'creator can create own draft');
select throws_ok($sql$update public.products set status = 'published' where slug = 'user-created-draft'$sql$, '42501', null, 'creator cannot self-publish a draft');
select is((select status from public.products where slug = 'user-created-draft'), 'draft', 'rejected self-publish leaves product in draft');
select ok(public.current_user_has_role('customer'::public.app_role), 'authenticated user can check own customer role');
select ok(not public.current_user_has_role('admin'::public.app_role), 'authenticated user cannot self-assert admin role');
update public.profiles set display_name = 'User One Updated' where id = '10000000-0000-4000-8000-000000000001';
reset role;
select is((select display_name from public.profiles where id = '10000000-0000-4000-8000-000000000001'), 'User One Updated', 'owner can update own profile');

select ok(not has_table_privilege('anon', 'public.audit_events', 'SELECT'), 'anonymous clients cannot read audit events');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'INSERT'), 'authenticated clients cannot forge audit events');
select ok(has_table_privilege('service_role', 'public.audit_events', 'INSERT'), 'trusted service role can append audit events');
select ok(not has_table_privilege('authenticated', 'public.user_roles', 'SELECT'), 'authenticated clients cannot inspect role assignments directly');
select ok(not has_table_privilege('authenticated', 'public.user_roles', 'INSERT'), 'authenticated clients cannot grant themselves roles');
select ok(has_table_privilege('service_role', 'public.user_roles', 'INSERT'), 'trusted service role can administer role assignments');
select ok(has_table_privilege('service_role', 'public.user_roles', 'SELECT'), 'trusted service role can audit role assignments');
select * from finish();
rollback;
