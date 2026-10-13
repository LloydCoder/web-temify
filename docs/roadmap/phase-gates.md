# Phase gates and completion criteria

This roadmap is a sequence of evidence gates, not a percentage-complete estimate. A phase is complete only when its implementation, automated tests, documentation, and CI evidence agree at the same commit SHA. A green CI run over a scaffold does not prove production readiness.

## Phase 0 — Product and engineering foundation
Scope: confirm product boundaries and launch scope; reconcile existing docs and flag conflicts; define architecture, data ownership, security, integration boundaries, test strategy, delivery gates, and repository map.

Exit criteria:
- [ ] Product scope and initial release scope approved.
- [x] Architecture decisions recorded, including migration ownership.
- [ ] Legacy documents reconciled after all planned legacy files are uploaded.
- [x] Domain boundaries and Tinlance integration contract documented.
- [x] Threat model and security baseline documented; formal review remains open.
- [ ] Product areas have phase and maturity status in one canonical inventory.
- [x] No unresolved critical architectural contradiction in the canonical ADRs.

## Phase 1 — Repository and application skeleton
Scope: branch-based delivery, root configuration, accessible App Router shell, strict TypeScript, lint/test/foundation commands, safe environment boundaries, CI checks.

Exit criteria:
- [ ] Clean checkout installs reproducibly with committed lockfile. OPEN BLOCKER: pnpm-lock.yaml is absent and CI currently uses --no-frozen-lockfile.
- [x] Lint, typecheck, foundation tests, and production build pass in CI on the current foundation commit.
- [x] No secrets or local env files are present in the tracked tree.
- [ ] CI results are visible on PR and required checks are configured in repository rules.
- [ ] App shell is tested for accessibility at mobile and desktop sizes.
- [x] Unbuilt payment, AI, vendor, and agent capabilities are not shown as live.
- [ ] Legacy and current architecture documents are fully reconciled.

## Phase 2 — Identity, data, authorization
Scope: establish Supabase Auth profile linkage, base catalogue primitives, RLS, least-privilege grants, audit event storage, and adversarial authorization tests.

Exit criteria:
- [ ] Reviewed migration applies from an empty local Supabase database.
- [ ] RLS enabled on every exposed table; client grants and policies are least-privilege.
- [ ] Anonymous, owner, non-owner, and server-only paths have positive and negative tests.
- [ ] No client-controlled role or privilege escalation path.
- [ ] Migration and RLS tests run in CI and pass.

## Phase 3 — Marketplace vertical slice
Catalogue, categories, product detail/search, moderation state, compatibility metadata, verified rights/licensing, and real product fixtures.

## Phase 4 — Commerce and secure delivery
Provider adapters; signature verification, idempotency, concurrency, amount/currency checks, ledger, refunds, licenses/entitlements, signed download authorization, failure/retry/reconciliation tests.

## Phase 5 — Admin and operations
Least-privilege admin controls, moderation, support, audit, observability, backup/restore, incident response.

## Phase 6 — Seller system and product factory
Vendor rights verification, quality gates, payout eligibility, disputes, artifact scanning, isolated builds/previews. The product factory and product source monorepo must have their own authoritative inventory and CI; do not copy independent products into the marketplace app repository.

## Phase 7 — Tinlance integration
Versioned authenticated APIs/events, capability scopes, tenant context, approvals, idempotency, audit, budgets, timeouts, kill switch. Start read-only/sandbox.

## Phase 8 — Launch readiness
Security/performance/accessibility checks, legal review, monitoring, rollback, support, disaster recovery, staged launch checklist.

Later growth: directory, AI generation, community, affiliate, automation, mobile API, white-label, and regulated/high-risk categories only after core launch evidence and validated demand.
