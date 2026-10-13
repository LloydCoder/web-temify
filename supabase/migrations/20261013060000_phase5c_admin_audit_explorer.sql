-- Phase 5C: support bounded exact-match filters in the admin audit explorer.
-- These indexes do not change grants, RLS, or the append-only audit contract.
create index if not exists audit_events_action_id_desc_idx
  on public.audit_events (action, id desc);

create index if not exists audit_events_entity_type_id_desc_idx
  on public.audit_events (entity_type, id desc);
