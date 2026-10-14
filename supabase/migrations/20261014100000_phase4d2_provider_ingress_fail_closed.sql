-- Phase 4D2 safety gate: provider-authentication assertions are not cryptographic proof.
-- Until a provider-specific authenticated ingress exists, only deterministic sandbox
-- fixtures may be imported. This intentionally fails closed for Paystack/Polar reports.
alter table public.settlement_imports
  add constraint settlement_imports_authenticated_ingress_gate
  check (provider = 'sandbox' and source_authentication_method = 'sandbox_fixture');

comment on constraint settlement_imports_authenticated_ingress_gate
  on public.settlement_imports is
  'Temporary fail-closed launch gate: external provider reports are rejected until provider-authenticated ingress verifies origin and records evidence. A boolean assertion and SHA-256 digest are insufficient.';
