begin;
select plan(14);

select has_table('public', 'audit_events', 'administrative audit events use the canonical audit table');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_events'::regclass), 'audit events have RLS enabled');
select ok(not has_table_privilege('anon', 'public.audit_events', 'SELECT'), 'anonymous users cannot read audit events');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'SELECT'), 'authenticated users cannot read audit events');
select ok(has_table_privilege('service_role', 'public.audit_events', 'INSERT'), 'trusted server workflows can append audit events');
select ok(not has_table_privilege('service_role', 'public.audit_events', 'UPDATE'), 'audit events cannot be updated by the service role');
select ok(not has_table_privilege('service_role', 'public.audit_events', 'DELETE'), 'audit events cannot be deleted by the service role');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'INSERT'), 'ordinary users cannot forge audit events');
select has_function('public', 'current_user_has_role', array['public.app_role'], 'role-check function exists');
select ok(has_function_privilege('authenticated', 'public.current_user_has_role(public.app_role)', 'EXECUTE'), 'authenticated sessions may check their own role');
select ok(not has_function_privilege('service_role', 'public.current_user_has_role(public.app_role)', 'EXECUTE'), 'service role does not receive unnecessary role-check execution');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
 ('85000000-0000-4000-8000-000000000085', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase5-customer@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase 5 Customer"}'::jsonb),
 ('86000000-0000-4000-8000-000000000086', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase5-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{"name":"Phase 5 Admin"}'::jsonb)
on conflict (id) do nothing;
insert into public.user_roles (user_id, role)
values ('86000000-0000-4000-8000-000000000086', 'admin')
on conflict (user_id, role) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '85000000-0000-4000-8000-000000000085', true);
select ok(not public.current_user_has_role('admin'), 'customer role cannot satisfy the admin authorization check');
select set_config('request.jwt.claim.sub', '86000000-0000-4000-8000-000000000086', true);
select ok(public.current_user_has_role('admin'), 'the explicitly assigned admin role satisfies the database authorization check');
select ok(not has_table_privilege('authenticated', 'public.user_roles', 'UPDATE'), 'authenticated users cannot elevate roles directly');
reset role;

select * from finish();
rollback;
