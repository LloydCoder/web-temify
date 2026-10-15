# Web-Temify — Final Enterprise-Grade Build Roadmap (Master Edition)

**Status as of 2026-10-14:** This is the canonical forward roadmap. Phase status must be derived from implementation and evidence at an exact commit, never from this plan alone. The detailed evidence register is `docs/roadmap/phase-gates.md`. This document reconciles the earlier condensed Phase 0–8 gate register with the agreed 20-phase programme and the three additional marketplace verticals.

## Operating rules

1. Execute phases serially. Do not start a dependent phase until the current phase has a green CI run on its exact reviewed head, a phase-specific forensic audit, reconciled documentation, and an explicit disposition.
2. Never equate a passing workflow with enterprise readiness. Test the feature and its security/accounting invariants, not just the scaffold.
3. Use a modular monolith: Next.js App Router + strict TypeScript; pnpm workspaces/Turborepo; Zod domain contracts; Supabase Postgres/Auth/RLS/private Storage; reviewed SQL migrations as the only canonical schema history; Vitest/unit and integration tests; pgTAP/RLS; Playwright; GitHub Actions. Add workers/queues only for durable asynchronous work.
4. Web-Temify owns commercial truth: listings/publication, sellers, prices, contracts, orders, payment/refund states, ledger, entitlements, licenses, downloads, disputes and payouts. Tinlance Agent System owns agent identity/runtime/policy/approvals/tool execution/budgets/evidence. Neither system may bypass the other's boundary.
5. Tinlance is an ordinary eligible seller/provider. No privileged verification, ranking, self-review, publication, financial actions or bypass of marketplace controls.
6. “Verified” must identify the evidence and criteria used, verifier, timestamp, expiry/recheck policy and appeal path. Do not imply guarantees or certifications that are not proven.
7. Provider/payment choices remain gated on business onboarding, supported seller jurisdictions, settlement, refunds, fees, currencies, tax treatment, webhook verification and operational support. Do not label a payment arrangement “escrow” unless the legal and provider arrangement truly is escrow.
8. Initial launch is narrow. Each new vertical needs its own acceptance criteria, risk assessment and pilot; do not launch all verticals merely because shared plumbing exists.

## Phase sequence and exit gates

### Phase 0 — Product scope, architecture and governance

Define launch scope, threat model, ADRs, data ownership, domain boundaries, test strategy, product inventory and reconciliation protocol. **Current evidence:** foundational documentation exists; product scope approval and formal security review remain explicit governance items.

### Phase 1 — Reproducible engineering foundation

Pinned pnpm lockfile, frozen install, strict TS, lint/format, tests, safe env handling, CI, build, accessibility/browser smoke checks, branch protection. Require CI on every PR and enforce required checks in repository settings.

### Phase 2 — Identity, database and authorization

Reviewed SQL migrations, Supabase Auth/profile linkage, server-owned roles, RLS on exposed tables, least-privilege table/column grants, admin role predicates, append-only audit stream, positive and negative authorization tests, fresh-database reset. Fail closed by default.

### Phase 3 — Canonical catalogue and release-quality gates

Stable IDs, categories, search, product versions, compatibility, changelog, dependencies, licenses, support policy, rights/provenance, review state and artifact evidence. Public discovery must show only independently reviewed, published releases with immutable artifact digests. Product source inventory is planning data, not proof that products are built or released.

### Phase 4 — Core commerce and secure delivery

Server-owned order creation and immutable item snapshots; payment-provider abstraction; cryptographically verified webhooks; durable event inbox/outbox and idempotency; financial ledger; refund reservation/evidence; order-linked entitlements/licenses; private artifacts and bounded, short-lived downloads. No redirect or client-side flag may prove payment. Keep live providers disabled until eligibility and production controls are verified.

**Phase 4C implementation update (merged, CI verified):** the platform now has an immutable, evidence-bound accounting journal, verified payment/refund journal posting, independently approved seller fee schedules, and idempotent proceeds allocation. Post-allocation refund outflow is permitted only after an approved reversal journal; settlement, provider-fee, chargeback, reserve and manual-adjustment sources remain fail-closed. This is still not a live provider, tax calculator, payout or production financial-readiness approval. See `docs/commerce/phase4c-financial-journal.md` and the exact-head evidence in `docs/roadmap/phase-gates.md`.

### Phase 4D — settlement, chargebacks, refund reversals and financial adjustments (in progress; execute as audited sub-gates)

Build evidence-backed state machines for provider settlement reconciliation, refund reversals after proceeds allocation, chargeback/dispute evidence, reserve holds/releases and independently approved manual adjustments. Keep money movement disabled until those paths have balanced journal postings, adversarial pgTAP tests, idempotency, audit evidence and explicit business-policy approval. This phase cannot be declared complete without a chosen provider, supported jurisdiction/settlement evidence and the required external onboarding.

#### Phase 4D1 — refund reversals after proceeds allocation (complete for tested sandbox-only scope)

PR #27 implements immutable item-level reversal requests/lines, distinct-admin approval/rejection through restricted server RPCs, verified-event-bound reversal journals, cumulative refund caps, cumulative commission rounding, per-seller journal attribution, and retry after a rejected request. The exact implementation head `1aa58cfe7801d03191f8ba15646702c625cb964d` passed [Foundation CI run 38523309374](https://github.com/LloydCoder/web-temify/actions/runs/38523309374) and [Security/dependency governance run 38523309382](https://github.com/LloydCoder/web-temify/actions/runs/38523309382). The forensic audit is recorded in `docs/roadmap/phase-gates.md`. This is a sandbox/test-only database workflow; it does not enable live providers, payouts, settlement reconciliation, tax calculation, chargebacks, reserves, manual adjustments or escrow.

#### Phase 4D2 — provider settlement reconciliation (in progress; scanner-freshness code sub-gate merged, operational/onboarding gates open)

Define a provider-neutral settlement evidence contract and idempotent reconciliation against verified payment/refund journal batches. A sandbox-only provider-fee journal path now requires exact fee arithmetic, a digest-linked private evidence record, and independent admin review; it posts balanced provider-fee expense/provider-clearing entries without moving funds. Source-specific provider-settlement/payout posting, provider-authenticated ingress, production scheduling/alerting and policy approval for retention of linked evidence, production deployment/configuration and operational verification of the ClamAV scanner gateway, production signature freshness monitoring/alerting, concurrent-race tests, escalation/expiry and external onboarding evidence remain open. Post-merge verification is complete: merge commit `5e0acdfc84046ee674634ade0173549bfb9f526d` passed [Foundation CI run 38733674367](https://github.com/LloydCoder/web-temify/actions/runs/38733674367) and [Security/dependency governance run 38733674369](https://github.com/LloydCoder/web-temify/actions/runs/38733674369); current `main` head `982cc75f480e0ea2fd39801ee988e0799018b5ce` passed [Foundation CI run 38739977107](https://github.com/LloydCoder/web-temify/actions/runs/38739977107) and [Security/dependency governance run 38739977256](https://github.com/LloydCoder/web-temify/actions/runs/38739977256). The repository reports `main` as unprotected with required checks unenforced, which remains a release-control blocker. PR #57's scanner-freshness implementation passed Foundation CI run 38732109726 and Security/dependency governance run 38732109750 on exact reviewed head `1842f85f26b11e11ab2227ada38ed90633166fe9`, then merged as `5e0acdfc84046ee674634ade0173549bfb9f526d`. Keep live provider processing disabled. The accepted role strategy is recorded in `docs/commerce/provider-strategy.md`: Polar is the primary MoR candidate, Paystack is a candidate for an explicitly approved Nigeria/local direct-payment route, Sellra remains an unverified secondary candidate, and Grey is treasury/FX only. This reconciles earlier provider discussions but does not approve live activation. The scanner signature-freshness gate now requires a latest digest-matched clean scan backed by signature definitions updated within 48 hours at both evidence-link and provider-fee posting time; stale scan history remains immutable but cannot authorize accounting. The first-launch route, Web-Temify account/KYB approval, marketplace contractual permission, supported seller jurisdictions, settlement evidence and external onboarding remain mandatory prerequisites; public provider documentation alone is insufficient.

### Phase 5 — Admin, seller operations and trust workflows

Admin authorization and audit trail; independent rights review; bounded audit explorer; support cases; listing moderation/takedowns/appeals; financial reconciliation and exception queues; disputes/chargebacks; audited sensitive actions; dual approval for high-risk financial actions; safe break-glass policy. Metrics must distinguish gross orders, refunds, provider settlement, platform fees, seller payable and tax liabilities.

### Phase 6 — Seller system and product factory

Seller onboarding and evidence-based verification; product submissions and version replacement; artifact quarantine/malware scanning; isolated build/test/preview; content-addressed artifacts; manifests, SBOM/provenance, release signatures and product-specific CI; payout eligibility, reserves/holds, fraud review, fees, refunds and chargeback reconciliation. The separate `LloydCoder/web-temify-products` repository remains the canonical product source/inventory owner. Never advertise planned products as available.

### Phase 7 — Governed Tinlance Agent System integration

Versioned authenticated adapter, tenant/actor context, scoped capabilities, approvals, idempotency, correlation IDs, audit/evidence, budgets, timeouts, secret isolation, sandboxing and kill switches. Begin read-only and sandbox-only. Agent-assisted work may draft, test, review and propose; humans approve publication, production deploys, customer communications, permission changes and financial actions. Agents cannot self-verify their seller/listings or self-approve.

### Phase 8 — Launch readiness and controlled core launch

Production environment configuration; provider and settlement verification; legal/tax/privacy/seller review; security and accessibility assessments; observability/SLOs/on-call; backup and restore drills; incident response; rollback and staged rollout; customer support; operational owners and launch evidence. Release only after every blocker has an owner and explicit disposition.

### Phase 9 — Automation Marketplace domain and quality model

Add automation/workflow/AI-agent/integration listings on shared identity, catalogue, seller, rights and commerce primitives. Every listing must state supported systems, versions, prerequisites, scopes/permissions, data flows, secret handling, tests, setup/rollback, maintenance and support. Agent listings must define capabilities and hard limits. Do not run submitted automation in the marketplace control plane.

### Phase 10 — Automation sandbox, verification and delivery

Build isolated, resource-bounded validation environments; signed/content-addressed packages; dependency and secret scans; workflow test fixtures; permission manifests; compatibility checks; version/rollback semantics; security evidence and reviewer workflows. Reject packages requiring uncontrolled credentials, unrestricted egress or unsafe privilege. Make execution an opt-in customer-side or separately governed runtime action.

### Phase 11 — Specialist Supplier Directory

Supplier profiles, capabilities, geographies, certifications/evidence, service boundaries, pricing model, delivery history and support terms. Define verification criteria, evidence expiry, appeals and anti-fraud controls. Start with discovery and qualified leads; disclose paid placement and do not equate subscription/payment with verification.

### Phase 12 — Lead qualification and supplier trust operations

Consent-aware lead intake, explicit buyer requirements, lead ownership and attribution, duplicate/fraud controls, supplier response SLA tracking, dispute/refund rules for lead credits, audit trail and buyer feedback moderation. Keep lead-credit revenue distinct from GMV and service-delivery revenue. Do not expose private buyer data without a lawful basis and clear notice.

### Phase 13 — Outcome-Based AI Implementation Marketplace

Structured packages with defined business outcome, baseline, scope, exclusions, deliverables, acceptance criteria, measurable KPIs, timeline, dependencies, data/security prerequisites, human oversight, support and change-control terms. Milestone payments only after legal/payment-provider capability and release gates are verified. Do not guarantee business outcomes or use the word “escrow” without an actual legally valid escrow arrangement.

### Phase 14 — Project delivery, milestones and disputes

Project statements of work, proposals, versioned contracts, milestones, evidence-based acceptance, change requests, acceptance windows, disputes, refunds/chargebacks and audited resolutions. Keep provider execution and fund movement disabled until the ledger and provider state machines cover all supported transitions. Separate objective technical acceptance from subjective business outcome attribution.

### Phase 15 — Trust, safety, legal and compliance

Jurisdiction matrix for consumer protection, privacy, data residency, tax, sanctions, seller/trader traceability, IP takedowns/appeals, accessibility and AI transparency. Category-specific moderation, data retention/export/deletion, consent/cookies, incident notifications and provider liability. Obtain qualified advice for applicable regimes; technical controls do not replace legal review.

### Phase 16 — Durable jobs, events and operational resilience

Outbox/inbox, durable queues, idempotent handlers, bounded retries/backoff, dead-letter queues, safe replay, cancellation, concurrency controls and tracing. Cover artifact scanning/builds, listing revalidation, supplier evidence expiry, lead workflows, project reminders, webhook reconciliation, notifications and reporting. Provide alerting, runbooks, SLOs, backup/restore drills, RTO/RPO and tested rollback.

### Phase 17 — Security engineering and comprehensive verification

Threat-model authentication, RLS, seller review, checkout, webhooks, downloads, automation execution, agent boundaries and project/payment state. SAST/SCA/license/secret scanning, DAST as applicable, SBOM/provenance, artifact integrity, SSRF and egress controls, CSP/session/rate-limit/bot protections, penetration testing, accessibility audits, property-based financial tests, E2E, load/soak, concurrency/failure injection, migration/restore rehearsal. No unresolved critical/high finding without a documented, approved, time-bounded exception.

### Phase 18 — Controlled vertical pilots and product-factory expansion

Pilot core products first; then a small reviewed automation cohort; then a non-transactional supplier directory/qualified-lead cohort; then outcome-based implementation packages only after contracts, milestones, disputes and payment controls are operational. Expand the product inventory in its approved tier order. Each release requires rights, tests, compatibility, security, docs, support owner and immutable artifact evidence.

### Phase 19 — Marketplace intelligence and growth

Search relevance, recommendations, quality/compatibility signals, supplier matching, seller support trends, fraud signals with human review, pricing/retention/attribution experiments and outcome measurement. AI may draft listing metadata, documentation and support responses with evidence checks and human review. Add evaluations, cost/privacy controls, consent, opt-outs and kill switches.

### Phase 20 — Global scale and enterprise operations

Region/currency/payment expansion only after jurisdiction and settlement validation; localization, tax/VAT workflows, supplier geography matching, capacity and measured caching/worker optimization; enterprise audit exports, SLAs, data portability, retention/deprecation policy, business continuity, security/DR exercises and compliance evidence. Scale only when measured load and operational capability justify it.

## Marketplace verticals and shared architecture

- **Template & Script Marketplace:** templates, scripts, launch kits and verified released artifacts.
- **Tech Directory Hub:** tool discovery; directory records are not automatically endorsements.
- **Verified Automation Marketplace:** workflows, integrations, AI agents and reusable automations, with evidence-backed quality and permission disclosures.
- **Verified Specialist Supplier Directory:** evidence-based supplier profiles, capability/geography matching and consent-aware leads.
- **Outcome-Based AI Implementation Marketplace:** scoped packages, measurable acceptance criteria, milestones, disputes and governed delivery.

All verticals reuse identity, catalog, seller profile, verification, search, reviews, audit, notifications and analytics, but maintain separate transaction and liability models. Directory subscriptions/leads are not the same accounting object as product sales or implementation milestone revenue.

## Cross-cutting invariants

- Server-side authorization and database RLS/grants both enforce access.
- No client-controlled role, price, seller identity, rights verification, paid state, entitlement or payout eligibility.
- Immutable snapshots and idempotency for financial operations; ledger reconciliation before financial claims.
- Content-addressed releases, least-privilege artifacts and no secrets in source/logs.
- Evidence-backed verification with expiry, independent review and appeals.
- Accessibility target WCAG 2.2 AA; automated checks do not replace manual assistive-technology review.
- Privacy by design, bounded data collection, retention/deletion, redaction and incident response.
- CI, audit and documentation must refer to the same exact commit SHA.
- Tinlance remains a normal marketplace participant; Web-Temify commercial controls remain authoritative.

## Completion definition

“100% enterprise-grade” means 100% of the agreed requirements for a defined release scope have implementation evidence, passing automated/manual tests, security review, documentation, ownership and operational readiness. It does not mean zero defects or zero risk.

No phase is complete unless: exact-head CI is green; fresh DB migrations and RLS tests pass where applicable; feature-specific positive and negative tests pass; E2E and production build pass; phase forensic audit records files and evidence; docs are reconciled; known limits are explicit; and the phase gate is checked only for the scope actually delivered.
