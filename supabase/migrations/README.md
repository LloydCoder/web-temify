# Canonical SQL migration history

Supabase SQL migrations are the sole authoritative schema history for Web-Temify. The ordered migrations in this directory are applied by the local Supabase stack and CI from an empty database; they must remain replayable and deterministic.

## Rules
- Create new migrations with `supabase migration new descriptive_name`.
- Never introduce Prisma Migrate or a second hand-maintained schema history.
- Review SQL for least privilege, explicit grants, RLS, safe `search_path` on privileged functions, and a documented forward-fix strategy.
- Add pgTAP coverage for schema constraints, grants, RLS, allowed actions, denied actions, and concurrency-sensitive invariants.
- Validate with `supabase db reset`, `supabase db lint --local`, and `supabase test db` before merge; CI repeats these checks against an empty local database.
- Never use production credentials or production personal data in migration tests.

## Current migration set
- `20261013000000_phase2_identity_catalogue.sql` — identity, role baseline, catalogue primitives, and RLS.
- `20261013010000_phase3_catalogue_quality.sql` — product compatibility, independent rights attestations, content-addressed release evidence, and evidence-gated public visibility.
- `20261013015000_phase3_creator_policy_privileges.sql` — fixed-search-path, security-definer ownership predicates so creator RLS policies work with restricted column grants.
- `20261013020000_phase4_commerce.sql` — provider-neutral order/payment/refund state invariants, append-only transfer ledger, entitlements, and atomic private-download authorization grants.

## Important maturity boundary
The Phase 4 migration is a database invariant layer, not a live commerce integration. There is no production payment provider, cryptographic webhook ingress, checkout API, payout workflow, signed-download URL issuer, or live storage policy enabled by this migration. The current ledger records gross payment/refund transfer evidence only; commission, seller payable allocation, taxes, provider settlement, chargebacks, and manual adjustments need their own evidence-backed accounting model before a live provider can be enabled. Do not represent checkout, payment, payout, or downloads as live until those later gates pass.


## Phase 4B — checkout and verified-event processing

Migration 20261013030000_phase4b_checkout_webhooks.sql adds server-only atomic order creation and an idempotent webhook event processor. It depends on the Phase 2–4A schema. Checkout creation and event processing RPCs are granted only to service_role; public, anonymous, and authenticated clients cannot call them. Raw webhook bodies are never stored. The application must verify a provider's raw-body signature before setting signature_verified=true and calling the processor. The implemented adapter is non-production sandbox only; see ../commerce/phase4b-checkout-webhooks-downloads.md.
