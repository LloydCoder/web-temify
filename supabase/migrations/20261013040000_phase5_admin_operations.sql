-- Phase 5A: keep the administrative audit stream append-only even when
-- project-level default privileges change.
revoke all on table public.audit_events from anon, authenticated, service_role;
grant insert on table public.audit_events to service_role;

comment on table public.audit_events is
  'Append-only administrative and system audit evidence. Trusted server paths may insert; ordinary clients and the service role cannot update or delete historical events.';
