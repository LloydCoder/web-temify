begin;
select plan(7);

select has_column('public', 'audit_events', 'id_text', 'audit event bigint identifiers have an exact text projection');
select has_index('public', 'audit_events', 'audit_events_action_id_desc_idx', 'audit action filter has a supporting index');
select has_index('public', 'audit_events', 'audit_events_entity_type_id_desc_idx', 'audit entity-type filter has a supporting index');
insert into public.audit_events (action, entity_type) values ('phase5c.cursor-test', 'audit_cursor_test');
select is((select id_text from public.audit_events where action = 'phase5c.cursor-test' limit 1), (select id::text from public.audit_events where action = 'phase5c.cursor-test' limit 1), 'bigint audit cursor projection preserves the exact identifier');
select ok(not has_table_privilege('anon', 'public.audit_events', 'SELECT'), 'anonymous users cannot read the audit stream');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'SELECT'), 'ordinary authenticated users cannot read the audit stream');
select ok(not has_table_privilege('service_role', 'public.audit_events', 'UPDATE') and not has_table_privilege('service_role', 'public.audit_events', 'DELETE'), 'audit history remains append-only');

select * from finish();
rollback;
