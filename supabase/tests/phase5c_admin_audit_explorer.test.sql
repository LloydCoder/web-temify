begin;
select plan(5);

select has_index('public', 'audit_events', 'audit_events_action_id_desc_idx', 'audit action filter has a supporting index');
select has_index('public', 'audit_events', 'audit_events_entity_type_id_desc_idx', 'audit entity-type filter has a supporting index');
select ok(not has_table_privilege('anon', 'public.audit_events', 'SELECT'), 'anonymous users cannot read the audit stream');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'SELECT'), 'ordinary authenticated users cannot read the audit stream');
select ok(not has_table_privilege('service_role', 'public.audit_events', 'UPDATE') and not has_table_privilege('service_role', 'public.audit_events', 'DELETE'), 'audit history remains append-only');

select * from finish();
rollback;
