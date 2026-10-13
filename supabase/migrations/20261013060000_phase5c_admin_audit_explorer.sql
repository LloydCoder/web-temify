-- Phase 5C: support bounded exact-match filters in the admin audit explorer.
-- Preserve BIGINT identifiers as exact text when JSON crosses into JavaScript,
-- where integers above Number.MAX_SAFE_INTEGER cannot be represented exactly.
-- This generated projection is read-only and does not change audit semantics.
alter table public.audit_events
  add column if not exists id_text text generated always as (id::text) stored;

-- These indexes do not change grants, RLS, or the append-only audit contract.
create index if not exists audit_events_action_id_desc_idx
  on public.audit_events (action, id desc);

create index if not exists audit_events_entity_type_id_desc_idx
  on public.audit_events (entity_type, id desc);
