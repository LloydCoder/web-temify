-- Tighten the Phase 4D2 evidence write boundary after the upload path moved to
-- the atomic SECURITY DEFINER recording RPC. The service role may read metadata
-- for audited downloads, but must not create rows directly.
revoke insert on public.settlement_evidence from service_role;
grant select on public.settlement_evidence to service_role;

comment on table public.settlement_evidence is
  'Private, immutable metadata for uploaded settlement evidence. Service-role writes are restricted to the atomic recording RPC; source SHA-256 proves byte identity only, not provider authenticity.';
