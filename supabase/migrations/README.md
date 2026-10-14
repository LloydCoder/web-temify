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
- `20261013030000_phase4b_checkout_webhooks.sql` — atomic server-side checkout and verified, idempotent sandbox event processing.
- `20261013035000_phase4c_financial_journal.sql` — immutable evidence-bound accounting journal, source-specific posting validation, independently approved seller fee schedules and idempotent proceeds allocation.
- `20261013036000_phase4d1_refund_reversals.sql` — item-level refund reversal requests/lines, independent approval/rejection, verified-event-bound reversal journal, cumulative commission/refund guards, and per-seller journal attribution checks.
- `20261013037000_phase4d2_settlement_imports.sql` — immutable settlement report metadata and normalized rows, timezone-aware period validation, operations-actor authorization, service-only idempotent import RPC, replay/conflicting-digest guards, and an initial immutable reconciliation snapshot against already-posted payment/refund journal batches.

- `docs/commerce/phase4d2-settlement-reconciliation.md` — versioned provider-neutral settlement import contract and remaining acceptance gates only; no settlement tables, reconciliation processor, or provider integration are implemented by this document.

## Important maturity boundary

The Phase 4 migrations are a database/workflow invariant layer, not a live commerce integration. The sandbox checkout and verified-event processor are non-production only. Phase 4C adds a balanced immutable journal and seller proceeds allocation under independently approved fee schedules, but does not calculate tax or execute payouts. Phase 4D1 now implements reversal-before-refund posting after proceeds allocation for sandbox/test scope only. Provider settlement, provider fees, chargebacks, reserves, manual adjustments, live provider onboarding, production storage configuration and legal/tax review remain blocked until their dedicated state machines and external evidence are complete. Do not represent checkout, payment, payout, escrow or tax quotes as live.

## Phase 4B — checkout and verified-event processing

Migration 20261013030000_phase4b_checkout_webhooks.sql adds server-only atomic order creation and an idempotent webhook event processor. It depends on the Phase 2–4A schema. Checkout creation and event processing RPCs are granted only to service_role; public, anonymous, and authenticated clients cannot call them. Raw webhook bodies are never stored. The application must verify a provider's raw-body signature before setting signature_verified=true and calling the processor. The implemented adapter is non-production sandbox only; see ../commerce/phase4b-checkout-webhooks-downloads.md.

## Phase 4C — immutable financial journal and proceeds allocation

Migration `20261013035000_phase4c_financial_journal.sql` creates a server-only append-only journal with source-specific posting checks. Payment/refund postings must match verified event evidence and existing ledger transactions; allocation postings must reconcile to a paid order, immutable item totals, independently approved fee schedules, seller payable, platform commission and any tax amount on the order snapshot. The supported posting sources are verified payment, verified refund before proceeds allocation, proceeds allocation, and an approved refund reversal that precedes a verified post-allocation refund outflow. Settlement, provider fees, chargebacks, reserves and manual adjustments fail closed until dedicated workflows are reviewed and tested. See `docs/commerce/phase4c-financial-journal.md`.

## Phase 4D1 — refund reversals after proceeds allocation (complete for tested sandbox-only scope)

Migration `20261013036000_phase4d1_refund_reversals.sql` adds immutable item-level reversal requests and lines, independent approval/rejection RPCs, evidence-bound reversal journal posting before a verified refund outflow, cumulative refund and commission arithmetic, and a retry path after rejection. Foundation CI [38523309374](https://github.com/LloydCoder/web-temify/actions/runs/38523309374) and Security/dependency governance [38523309382](https://github.com/LloydCoder/web-temify/actions/runs/38523309382) passed on implementation head `1aa58cfe7801d03191f8ba15646702c625cb964d`. It is not a live payment integration and does not enable settlement, payout, tax calculation, chargebacks, reserves, manual adjustments or escrow. The detailed forensic audit is in `docs/roadmap/phase-gates.md`. Phase 4D1 is merged and passes for the tested sandbox-only scope. Phase 4 remains in progress until the remaining financial state machines and external provider/business gates are evidenced.

## Phase 4D2 — settlement import evidence (partial implementation)

Migration `20261013037000_phase4d2_settlement_imports.sql` stores immutable report metadata and normalized settlement rows. The import RPC is service-role-only, requires an operations actor, validates the source-authentication assertion, binds a source digest to report identity, returns the existing ID for identical replays, rejects conflicting evidence, and validates row currency, type, amount signs, unique row IDs, and report-period dates in the declared IANA timezone. Public client roles have no table access, and imported evidence cannot be updated or deleted.

This is **not settlement reconciliation**. There is no verified journal matching, settlement/fee journal posting, exception decision workflow, payout, live provider integration, or cryptographic source verifier implemented by this migration. `source_authenticated` records a trusted-ingress assertion and is not proof generated by the database. See `../commerce/phase4d2-settlement-reconciliation.md`; keep Phase 4D2 and Phase 4 blocked until all remaining gates pass.
