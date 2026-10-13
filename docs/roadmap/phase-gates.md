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
- [ ] Product areas have phase and maturity status in one canonical inventory, merged and validated in the product-source repository.
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

## Phase 3 — Marketplace catalogue and release-quality gates (in progress)
Scope: public catalogue/search/detail routes, compatibility metadata, rights attestations and review state, product version/release evidence, safe publication rules, and domain-contract alignment.

Exit criteria:
- [ ] Phase 3 migration applies from an empty local Supabase database and can be replayed deterministically.
- [ ] RLS and least-privilege grants cover every new table; rights evidence is not public.
- [ ] Creators can submit a rights declaration for their own draft but cannot verify it or promote a release.
- [ ] Public catalogue exposes only published products with independently verified rights and a content-addressed artifact.
- [ ] Public product versions require a released state, artifact digest, and release timestamp.
- [ ] Shared TypeScript/Zod lifecycle states match the canonical database states; domain-contract tests pass.
- [ ] Catalogue and product-detail pages fail closed when configuration or verified releases are absent.
- [ ] Playwright covers catalogue empty state, unknown/unreleased product denial, semantic landmarks, and responsive widths.
- [ ] CI passes migration reset, database/RLS tests, foundation tests, domain tests, typecheck, lint, E2E and production build on the same head SHA.
- [ ] A phase-specific forensic audit records files reviewed, policy invariants, test evidence, remaining risk and explicit pass/fail.

## Phase 4 — Commerce and secure delivery
Provider adapters; signature verification against raw webhook bodies, idempotency, concurrency, amount/currency/order matching, double-entry or equivalent auditable ledger, refunds/chargebacks, licenses/entitlements, private storage, authorized download issuance, failure/retry/reconciliation tests. No live provider is selected until payout eligibility, sandbox behavior, jurisdiction coverage and fees are verified.

## Phase 5 — Admin and operations
Least-privilege admin controls, moderation queues, support, audit review, financial reconciliation, observability, backup/restore rehearsal, incident response and safe break-glass access.

## Phase 6 — Seller system and product factory
Vendor rights verification, quality gates, payout eligibility, disputes, artifact scanning, isolated builds/previews, product manifests, immutable artifacts, SBOM/provenance, product-specific CI and release evidence. The dedicated source monorepo is [LloydCoder/web-temify-products](https://github.com/LloydCoder/web-temify-products); its bootstrap PR must pass CI before it becomes the merged inventory authority. Do not copy independent products into the marketplace app repository without an explicit migration decision.

## Phase 7 — Tinlance integration
Versioned authenticated APIs/events, capability scopes, tenant context, approvals, idempotency, audit, budgets, timeouts, kill switch and isolated execution. Start read-only/sandbox. Web-Temify remains the authority for publication, pricing, payments, refunds, entitlements, licenses and downloads.

## Phase 8 — Launch readiness
Security/performance/accessibility checks, legal and tax review, monitoring, alerting, rollback, customer support, disaster recovery, SLOs, staged launch checklist and verified production deployment. No production launch until each gate has owner, evidence, and explicit disposition.

## Later growth
Directory, AI generation, community, affiliate, automation, mobile API, white-label, and regulated/high-risk categories only after core launch evidence and validated demand. The separate 18 proposed product candidates remain deferred until the core 39 standalone products and 4 launch kits have been implemented and validated in the agreed tier order.
