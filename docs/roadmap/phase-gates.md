# Phase gates and completion criteria

This roadmap is a sequence of evidence gates, not a percentage-complete estimate. A phase is complete only when implementation, automated tests, documentation, forensic review, and CI evidence agree at the same commit SHA. A green CI run over a scaffold does not prove production readiness. Keep every incomplete exit criterion unchecked; never infer completion from a plan or a passing subset of checks.

## Phase 0 — Product and engineering foundation
Scope: confirm product boundaries and launch scope; reconcile existing docs and flag conflicts; define architecture, data ownership, security, integration boundaries, test strategy, delivery gates, and repository map.

Exit criteria:
- [ ] Product scope and initial release scope approved.
- [x] Architecture decisions recorded, including migration ownership.
- [ ] Legacy documents reconciled after all planned legacy files are uploaded.
- [x] Domain boundaries and Tinlance integration contract documented.
- [x] Threat model and security baseline documented; formal review remains open.
- [x] Product areas have phase and maturity status in the canonical planned inventory, merged and validated in the product-source repository (43 entries; all still planned).
- [x] No unresolved critical architectural contradiction in the canonical ADRs.

## Phase 1 — Repository and application skeleton
Scope: branch-based delivery, root configuration, accessible App Router shell, strict TypeScript, lint/test/foundation commands, safe environment boundaries, CI checks.

Exit criteria:
- [x] Clean checkout installs reproducibly with committed pnpm-lock.yaml and CI enforces --frozen-lockfile.
- [x] Lint, typecheck, foundation tests, and production build passed in CI on the Phase 2 baseline commit.
- [x] No secrets or local env files are present in the tracked tree.
- [ ] CI results are visible on PR; required checks are not yet enforced by repository rules (repository settings gate).
- [x] Playwright validates semantic landmarks and horizontal overflow at 320px and 1440px; full WCAG 2.2 AA audit remains a launch gate.
- [x] Unbuilt payment, AI, vendor, and agent capabilities are not shown as live.
- [ ] Legacy and current architecture documents are fully reconciled.

## Phase 2 — Identity, data, authorization
Scope: establish Supabase Auth profile linkage, server-managed application roles, base catalogue primitives, RLS, least-privilege grants, audit event storage, and adversarial authorization tests.

Exit criteria:
- [x] Reviewed migration applies from an empty local Supabase database.
- [x] RLS enabled on every exposed table in the Phase 2 schema; client grants and policies are least-privilege.
- [x] Anonymous, owner, non-owner, and server-only paths have positive and negative tests.
- [x] No client-controlled role or privilege escalation path.
- [x] Migration and RLS tests passed in CI run 38364828400 (commit evidence: phase 2 baseline).

## Phase 3 — Marketplace catalogue and release-quality gates (complete)
Scope: public catalogue/search/detail routes, compatibility metadata, rights attestations and review state, product version/release evidence, safe publication rules, and domain-contract alignment.

Exit criteria:
- [x] Phase 3 migration applies from an empty local Supabase database and can be replayed deterministically.
- [x] RLS and least-privilege grants cover every new table; rights evidence is not public.
- [x] Product table reads use column-level grants; creator identifiers and review internals are not exposed through PostgREST.
- [x] Creators can submit a rights declaration for their own draft but cannot verify it or promote a release.
- [x] Public catalogue exposes only published products with independently verified rights and a content-addressed artifact.
- [x] Public product versions require a released state, artifact digest, and release timestamp.
- [x] Shared TypeScript/Zod lifecycle states match the canonical database states; domain-contract tests pass.
- [x] Catalogue and product-detail pages fail closed when configuration or verified releases are absent.
- [x] Playwright covers catalogue empty state, unknown/unreleased product denial, semantic landmarks, and responsive widths.
- [x] CI passes migration reset, database/RLS tests, foundation tests, domain tests, typecheck, lint, E2E and production build on the same head SHA.
- [x] A phase-specific forensic audit records files reviewed, policy invariants, test evidence, remaining risk and explicit pass/fail.

### Phase 3 forensic audit record

- **Disposition:** PASS — implementation, deterministic database fixtures, security review, documentation, and CI gates agree.
- **PR:** [#6 — fix: repair Phase 3 catalogue evidence gates and CI fixtures](https://github.com/LloydCoder/web-temify/pull/6), merged.
- **Validated head:** `aafcc5301c72e47b8f75adc856bef0c1ea85c73f`.
- **CI evidence:** Foundation CI run [38419320576](https://github.com/LloydCoder/web-temify/actions/runs/38419320576), run 51; all steps succeeded, including frozen install, foundation/domain tests, typecheck, lint, empty-database Supabase reset, database/RLS tests, Playwright, production build, and service cleanup.
- **Merge commit:** `762a2e07e71ef7961bbc01916886a5770a2b17d6`. The reviewed migration, tests, application routes, and documentation blobs match the validated head.
- **Files reviewed:** `supabase/migrations/20261013010000_phase3_catalogue_quality.sql`; `supabase/tests/phase2_identity_catalogue.test.sql`; `supabase/tests/phase3_catalogue_quality.test.sql`; `src/app/catalog/page.tsx`; `src/app/catalog/[slug]/page.tsx`; `packages/domain-contracts/src/index.ts` and its tests; `.github/workflows/ci.yml`; `docs/security/security-baseline.md`; `docs/security/threat-model.md`; `docs/architecture/domain-boundaries.md`.
- **Security invariants verified:** creator declarations cannot self-approve; creator sessions cannot modify review state or promote releases; public rows require publication, independent rights-review evidence with matching reviewer/timestamp, and a released artifact digest; direct PostgREST access is restricted to approved product columns; catalogue routes use RLS as the authority and fail closed without verified products.
- **Defects found and corrected during audit:** nondeterministic rights-review timestamps in database fixtures; table-wide product SELECT exposing creator/review metadata; redundant UI filters that depended on columns no longer client-readable. Regression tests now enforce deterministic evidence and column-level privacy.
- **Forensic follow-up (PR #9):** behavioral tests initially uncovered that creator rights/version RLS policies queried `public.products` under caller privileges despite deliberately restricted column grants. Migration `20261013015000_phase3_creator_policy_privileges.sql` replaces those subqueries with fixed-`search_path`, `SECURITY DEFINER` boolean ownership predicates. The test proves a creator can declare rights on their own draft but cannot self-verify or insert a released version. Code/test head `8387516294ff6687321a6ef20bdaff5f96518c01` passed Foundation CI run `38422399419`; the PR head after this documentation reconciliation must also pass the full workflow before merge.
- **Residual risks / explicit non-claims:** no real product release is yet published; the trusted moderation/release service, checkout, payments, entitlements, and downloads are not live; production Supabase/Vercel configuration, formal security review, and full WCAG 2.2 AA assessment remain later gates. Phase 3 completion does not mean production launch readiness.
- **Fixture invariant:** `products.rights_verified_at` must exactly equal the independently reviewed attestation's `reviewed_at`; tests use a fixed timestamp to avoid nondeterministic `now()` differences. Never weaken evidence-gated publication policy to make fixtures pass.

## Phase 4 — Commerce and secure delivery (in progress)
Scope: server-owned orders and item snapshots, provider-neutral payment attempts, verified-event inbox, idempotent financial ledger, refunds, paid-order entitlements, and private-download authorization. Provider integrations remain disabled until business eligibility, jurisdiction coverage, fees, webhook semantics, and payout settlement are verified. Chargeback and manual-adjustment ledger sources are explicitly rejected until a dedicated evidence-backed state machine and accounting policy are implemented; unsupported financial states must fail closed. The current ledger only records gross payment/refund transfer evidence and is not a complete commission, seller-payable, tax, or provider-settlement accounting model.

Phase 4A — database invariants:
- [ ] Orders and item snapshots are immutable and price/currency/release evidence is revalidated at insertion.
- [ ] Payment attempts cannot alter order amount/currency and cannot become successful without a verified provider event.
- [ ] Orders cannot become paid without a processed verified success event and matching append-only ledger entry.
- [ ] Provider events are signature-verified, hash-only (no raw payload persistence), unique by provider event ID, and retryable without duplicate effects.
- [ ] Ledger rows are append-only balanced debit/credit transfers with unique idempotency references.
- [ ] Refund amounts are reserved under order locking, cannot exceed the remaining balance, and require verified refund evidence and ledger entries.
- [ ] Entitlements require a paid order and matching release snapshot.
- [ ] Download grants contain no storage path or signed URL; access consumption is atomic, bounded, time-limited, and checks entitlement/order/release state.
- [ ] Customer RLS isolates orders, line items, payment attempts, refunds, and entitlements; financial internals are not client-readable.
- [ ] Empty-database migration reset, adversarial SQL tests, unit/domain tests, typecheck, lint, Playwright and production build pass on one head SHA.
- [ ] Phase 4 forensic audit records exact code, migration, test and CI evidence plus remaining launch risks.

No live payment processing, vendor payouts, or production downloads may be represented as available until a provider-specific adapter and end-to-end sandbox validation pass.

## Phase 5 — Admin and operations
Least-privilege admin controls, moderation queues, support, audit review, financial reconciliation, observability, backup/restore rehearsal, incident response and safe break-glass access.

## Phase 6 — Seller system and product factory
Vendor rights verification, quality gates, payout eligibility, disputes, artifact scanning, isolated builds/previews, product manifests, immutable artifacts, SBOM/provenance, product-specific CI and release evidence. The dedicated source monorepo is [LloydCoder/web-temify-products](https://github.com/LloydCoder/web-temify-products); bootstrap PR #1 was merged after its frozen-install and catalogue-validation CI passed. Its 43-entry inventory is authoritative for planning only; no product-specific source builds or releases are implied. Do not copy independent products into the marketplace app repository without an explicit migration decision.

## Phase 7 — Tinlance integration
Versioned authenticated APIs/events, capability scopes, tenant context, approvals, idempotency, audit, budgets, timeouts, kill switch and isolated execution. Start read-only/sandbox. Web-Temify remains the authority for publication, pricing, payments, refunds, entitlements, licenses and downloads.

## Phase 8 — Launch readiness
Security/performance/accessibility checks, legal and tax review, monitoring, alerting, rollback, customer support, disaster recovery, SLOs, staged launch checklist and verified production deployment. No production launch until each gate has owner, evidence, and explicit disposition.

## Later growth
Directory, AI generation, community, affiliate, automation, mobile API, white-label, and regulated/high-risk categories only after core launch evidence and validated demand. The separate 18 proposed product candidates remain deferred until the core 39 standalone products and 4 launch kits have been implemented and validated in the agreed tier order.
