# Phase gates and completion criteria

This roadmap is a sequence of evidence gates, not a percentage-complete estimate.

## Phase 0 — Product and engineering foundation
Scope: confirm product boundaries and launch scope; reconcile existing docs and flag conflicts; define architecture, data ownership, security, integration boundaries, test strategy, delivery gates, and repository map.

Exit criteria:
- [ ] Product scope and initial release scope approved.
- [ ] Architecture decisions recorded, including migration ownership.
- [ ] Legacy documents reconciled after all planned legacy files are uploaded.
- [ ] Domain boundaries and Tinlance integration contract reviewed.
- [ ] Threat model and security baseline reviewed.
- [ ] Product areas have phase and maturity status.
- [ ] No unresolved critical architectural contradiction.

## Phase 1 — Repository and application skeleton
Scope: branch-based delivery, root configuration, accessible App Router shell, strict TypeScript, lint/test/foundation commands, safe environment boundaries, CI checks.

Exit criteria:
- [ ] Clean checkout installs reproducibly with committed lockfile.
- [ ] Lint, typecheck, foundation tests, and production build pass in CI.
- [ ] No secrets or local env files tracked.
- [ ] CI results visible on PR and required checks identified.
- [ ] App shell runs and is accessible at mobile and desktop sizes.
- [ ] Unbuilt payment, AI, vendor, and agent capabilities are not shown as live.
- [ ] Architecture and initial phase PR are reviewed.

## Phase 2 — Identity, data, authorization
Resolve Supabase Auth session handling; select one schema migration authority; implement migrations, RLS, roles/tenants, audit events, and adversarial isolation tests.

## Phase 3 — Marketplace vertical slice
Catalogue, categories, product detail/search, moderation state, compatibility metadata, verified rights/licensing, and real product fixtures.

## Phase 4 — Commerce and secure delivery
Provider adapters; signature verification, idempotency, concurrency, amount/currency checks, ledger, refunds, licenses/entitlements, signed download authorization, failure/retry/reconciliation tests.

## Phase 5 — Admin and operations
Least-privilege admin controls, moderation, support, audit, observability, backup/restore, incident response.

## Phase 6 — Seller system and product factory
Vendor rights verification, quality gates, payout eligibility, disputes, artifact scanning, isolated builds/previews.

## Phase 7 — Tinlance integration
Versioned authenticated APIs/events, capability scopes, tenant context, approvals, idempotency, audit, budgets, timeouts, kill switch. Start read-only/sandbox.

## Phase 8 — Launch readiness
Security/performance/accessibility checks, legal review, monitoring, rollback, support, disaster recovery, staged launch checklist.

Later growth: directory, AI generation, community, affiliate, automation, mobile API, white-label, and regulated/high-risk categories only after core launch evidence and validated demand.