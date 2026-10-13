# Phase gates and completion criteria

This roadmap is a sequence of evidence gates, not a percentage-complete estimate. A phase is complete only when implementation, automated tests, documentation, forensic review, and CI evidence agree at the same commit SHA. A green CI run over a scaffold does not prove production readiness. Keep every incomplete exit criterion unchecked; never infer completion from a plan or a passing subset of checks.

## Phase 0 — Product and engineering foundation
Scope: confirm product boundaries and launch scope; reconcile existing docs and flag conflicts; define architecture, data ownership, security, integration boundaries, test strategy, delivery gates, and repository map.

Exit criteria:
- [ ] Product scope and initial release scope approved.
- [x] Architecture decisions recorded, including migration ownership.
- [x] Legacy documents in the 2026-10-13 repository snapshot audited and labelled historical/non-canonical; future uploads follow the reconciliation protocol in `docs/governance/legacy-reconciliation.md`.
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
- [x] Legacy/current architecture conflicts are reconciled for the audited repository snapshot; new files must enter the reconciliation register before use.

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

Phase 4A — database invariants (implementation and CI verified; phase-specific audit recorded below):
- [x] Orders and item snapshots are protected by server-only write grants; item insertion revalidates verified rights, released artifact digest, seller, price, currency, version, and release evidence.
- [x] Payment attempts cannot alter order amount/currency and cannot become successful without a verified provider event.
- [x] Orders cannot become paid without a processed verified success event and matching append-only ledger entry.
- [x] The event inbox requires an explicit `signature_verified` assertion, stores only a SHA-256 payload digest (no raw payload), and deduplicates provider event IDs. Provider-specific cryptographic raw-body verification and durable retry processing are Phase 4B requirements, not implemented by this schema migration.
- [x] Ledger rows are append-only balanced debit/credit transfers with unique idempotency references; unsupported chargeback/manual-adjustment sources fail closed.
- [x] Refund amounts are reserved under order locking, cannot exceed the remaining balance, and require verified refund evidence and ledger entries.
- [x] Entitlements require a paid order and matching purchase/release snapshot.
- [x] Download grants contain no storage path or signed URL; access consumption is atomic, bounded, time-limited, and rechecks entitlement/order/release state.
- [x] Customer RLS isolates orders, line items, payment attempts, refunds, and entitlements; financial internals are not client-readable.
- [x] Empty-database migration reset, schema lint, 70 pgTAP assertions, foundation/domain tests, typecheck, lint, Playwright, production build, and service cleanup passed on the reviewed PR head SHA.
- [x] Phase-specific forensic review recorded with exact code, migration, test and CI evidence plus remaining launch risks.

### Phase 4A forensic audit record

- **Disposition:** PASS for the database-invariant scope only; NOT a live commerce or launch-readiness approval.
- **PR/head:** [#10 — feat: establish Phase 4A commerce and secure-delivery invariants](https://github.com/LloydCoder/web-temify/pull/10), reviewed head `281faeb794e1462bd8970f9f58bd76e735937999`.
- **CI evidence:** [Foundation CI run 38425784286](https://github.com/LloydCoder/web-temify/actions/runs/38425784286) completed successfully on that exact head. All 17 substantive and post-job steps succeeded: frozen pnpm install; foundation/domain tests; TypeScript; lint; Supabase CLI; local services; empty-database migration reset; database schema lint; pgTAP/RLS tests; Playwright; production build; and Supabase cleanup.
- **Files reviewed:** `supabase/migrations/20261013020000_phase4_commerce.sql`; `supabase/tests/phase4_commerce.test.sql`; `.github/workflows/ci.yml`; `supabase/migrations/README.md`; `docs/roadmap/phase-gates.md`.
- **Database invariants reviewed:** server-owned order/item snapshots; order subtotal equals item totals; current price/currency and independently verified release evidence are revalidated; payment attempts match order amount/currency and have constrained transitions; event identity and provider references are immutable; event IDs and ledger source postings are idempotently unique; order paid-state requires a processed verified success event and matching ledger transfer; refunds are reserved under an order lock and capped to refundable order value; entitlement creation requires a paid matching order; download grants are short-lived and bounded; consumption atomically rechecks current entitlement, order, and release state; customer policies and column grants restrict financial details.
- **Adversarial test evidence:** 70 pgTAP assertions cover table/RLS setup, client privilege denial, amount mismatches, invalid transitions, missing/false verification assertions, provider/order mismatch, duplicate provider events and ledger posts, premature entitlements, refund/download boundaries, owner/non-owner isolation, atomic download consumption, and append-only restrictions.
- **Residual risks and explicit non-claims:** `signature_verified` is a trusted-ingress assertion, not cryptographic proof by this migration; no raw-body provider signature verifier, checkout/order-creation API, durable webhook worker, provider sandbox integration, signed-URL issuer, seller payout/commission/tax/settlement accounting, chargeback workflow, production Supabase/Vercel configuration, formal penetration test, or full WCAG 2.2 AA audit is delivered here. The ledger is gross payment/refund transfer evidence only. These are later gates and must remain disabled/unclaimed until separately implemented and verified.
- **Gate decision:** Phase 4A may merge after the final CI re-run on the documentation-updated head and repeat review. Phase 4 as a whole remains in progress.

Phase 4B — server-side commerce workflows (implementation in progress):
- [x] Atomic server-only order creation derives price, currency, seller, rights, release version and artifact digest from the canonical database; basket and idempotency replay are validated.
- [x] Checkout and sandbox completion are authenticated, idempotent, non-production only, and fail closed when the provider is disabled or the environment is production.
- [x] Raw-body HMAC verification enforces event identity, timestamp tolerance, constant-time signature comparison, streaming payload limits and strict event contracts.
- [x] Verified webhook events are stored without raw payloads, deduplicated by provider/event ID, conflict-checked by payload digest, and processed with retryable durable state transitions.
- [x] Successful payment processing atomically posts a ledger transfer, marks the order paid, and creates entitlements; refund events require matching refund/attempt/order/amount/currency evidence.
- [x] Customer refund requests are idempotent and explicitly do not imply that money moved; provider execution and approval remain disabled.
- [x] Private downloads issue/reuse bounded grants only for active entitlements on paid or partially refunded orders; consumption locks the order and entitlement, verifies the released artifact digest, and returns a 60-second signed URL with no-store headers. Full refunds revoke entitlements and outstanding grants.
- [x] Unit tests, pgTAP checkout/processor tests, migration reset, schema lint, RLS tests, Playwright, typecheck, lint, production build and phase-specific forensic audit pass on the implementation head SHA.

### Phase 4B forensic audit record

- **Disposition:** PASS for the implemented non-production workflow scope only; NOT a live commerce, payment-provider, seller-payout, or production-launch approval.
- **Implementation head reviewed:** `8c506f3dccd6fec57b72077af1cafefb2b397510`.
- **CI evidence:** [Foundation CI run 38436486905](https://github.com/LloydCoder/web-temify/actions/runs/38436486905) completed successfully on that exact implementation head. Frozen install, foundation/domain tests, TypeScript, lint, empty-database migration reset, Supabase schema lint, pgTAP/RLS tests, Playwright, production build, and service cleanup passed.
- **Files reviewed:** the Phase 4B migration and pgTAP suite; checkout, sandbox-completion, webhook, refund, grant-issuance and download routes; webhook signature/processing modules; bounded-body reader and tests; environment validation; Phase 4B commerce documentation; CI workflow; and phase-gate criteria.
- **Key invariants reviewed:** server-derived prices and immutable order snapshots; authenticated ownership; non-production-only sandbox behavior; raw-body HMAC validation and replay/digest conflict handling; retryable event processing; payment/refund/ledger amount and currency matching; idempotent entitlements; order-locked grant consumption; private-storage delivery with a short-lived URL; and explicit non-claims around real money movement.
- **Audit defect fixed before PASS:** the first implementation checked webhook size only after buffering the full body. The bounded reader now enforces byte limits while streaming and rejects invalid UTF-8. It is used by the webhook endpoint (64 KiB maximum) and checkout, sandbox completion, refund, download-grant and download endpoints (32 KiB maximum). Unit tests cover in-limit, oversized, invalid-length and invalid-UTF-8 inputs.
- **Residual risks:** no live provider adapter or provider-account verification; no tax/VAT calculation; no free checkout; no seller payout/commission/provider-settlement accounting; refund requests do not execute transfers; no chargeback/dispute workflow; partial refunds are order-level rather than item-specific; actual production bucket configuration, secrets, legal/tax review, penetration testing, full WCAG 2.2 AA assessment, and hosting/deployment readiness remain release gates.
- **Gate decision:** Phase 4B workflow primitives are complete for sandbox-only scope. Phase 4 and overall launch readiness remain incomplete until later operational, seller, provider, legal, security and deployment gates pass.

**Phase 4B limitations:** the only adapter is a non-production sandbox; there is no live payment provider, tax calculation, zero-value/free checkout, seller payout, commission accounting, refund execution, or production download enablement. Provider selection must follow jurisdiction/payout eligibility and sandbox verification. Production launch remains blocked until these gaps and the Phase 5–8 gates are completed.

## Phase 5 — Admin and operations

### Phase 5A forensic audit record

- **Disposition:** PASS for the read-only admin-console scope only; this is not a complete operations centre or production-readiness approval.
- **PR:** [#12 — feat: add read-only admin operations console and audit gates](https://github.com/LloydCoder/web-temify/pull/12).
- **Validated implementation head:** `0c83f1601225e1797d555dff82bd2e4ab9260868`.
- **CI evidence:** [Foundation CI run 38441726101](https://github.com/LloydCoder/web-temify/actions/runs/38441726101), run 108, passed on the exact implementation head. Frozen dependency installation, foundation/domain tests, typecheck, lint, empty-database migration reset, Supabase schema lint, pgTAP/RLS tests, Playwright E2E, production build, and cleanup all succeeded.
- **Files reviewed:** `src/app/admin/page.tsx`; `src/server/admin/authorization.ts`; `supabase/migrations/20261013040000_phase5_admin_operations.sql`; `supabase/tests/phase5_admin_operations.test.sql`; `tests/e2e/admin-access.spec.ts`; `docs/operations/admin-console.md`; and `.github/workflows/ci.yml`.
- **Authorization invariants:** server-side Supabase Auth `getUser()` validates the principal; the database-owned role predicate must return true before the privileged client is constructed; missing configuration, auth/role errors, non-admin identities, and audit-persistence failures fail closed; every authorized console view appends an audit record before privileged metrics are queried.
- **Audit integrity:** ordinary client roles cannot read or forge audit rows; update/delete are not granted; the pgTAP suite covers RLS, append-only privileges, role checks and role elevation denial.
- **E2E finding and correction:** the first E2E assertion required HTTP 404, but Next.js may return HTTP 200 when `notFound()` is rendered after streaming starts. The corrected test verifies the rendered not-found UI and confirms no admin heading, catalogue metrics or audit activity is exposed to unauthenticated visitors. This tests the authorization outcome rather than a streaming-sensitive status code.
- **Explicit limits:** the console is read-only. Moderation mutations, support case workflows, provider/settlement reconciliation, disputes and chargebacks, alert delivery, backup restoration drills, incident-response automation, and break-glass governance remain incomplete. Counts are not proof of settlement or financial correctness. Production Supabase/Vercel configuration, legal/tax review, penetration testing, and full WCAG 2.2 AA verification remain separate gates.
- **Gate decision:** Phase 5A passes only for the read-only visibility and audit scope. Phase 5 overall remains in progress.


### Phase 5B — Independent product-rights review (complete for this scope)

- [x] Restricted server-rendered queue lists a bounded set of pending declarations and fails closed on authentication, role, configuration, audit, and database errors.
- [x] Review mutation verifies admin identity before creating the privileged client; enforces same-origin requests, JSON content type, UUIDs, strict Zod fields, bounded notes, and an 8 KiB streaming request-body limit.
- [x] The narrow Postgres RPC is invoker-security, callable only by `service_role`, rechecks the admin role, locks product and attestation rows, rejects self-review and resolved attestations, and updates the attestation, product rights state, and append-only audit event atomically.
- [x] Independent reviewer identity, final-review timestamp, review notes, explicit `under_review` / `verified` / `rejected` transitions, and resolved-state rejection are enforced and tested.
- [x] The 29-assertion pgTAP suite covers grants, successful transitions, reviewer independence, non-admin rejection, resolved-state rejection, audit evidence, and rollback of both rights-state updates when audit persistence is unavailable.
- [x] Playwright verifies that unauthenticated users cannot access the mutation endpoint.
- [x] Foundation CI passed frozen install, foundation/domain tests, typecheck, lint, empty-database migration reset, Supabase schema lint, pgTAP/RLS tests, Playwright E2E, production build, and cleanup on the exact reviewed implementation head.
- [x] Phase-specific forensic audit and known limits are recorded.

#### Phase 5B forensic audit record

- **Disposition:** PASS for the independent rights-review workflow only. This is not product publication approval, artifact security approval, legal certainty, live commerce readiness, or production-launch approval.
- **PR:** [#13 — feat: add audited product rights review workflow](https://github.com/LloydCoder/web-temify/pull/13), merged.
- **Validated implementation head:** `1c849a8732f99c4e265e0c3fc5930c464cc8bba7`.
- **CI evidence:** [Foundation CI run 38449461902](https://github.com/LloydCoder/web-temify/actions/runs/38449461902) succeeded on that exact head. Every substantive check and the final Supabase cleanup succeeded.
- **Merge commit:** `ffbe1b28cf09aef995641d63d9de8f7a85da4ab4`.
- **Files reviewed:** `src/app/admin/reviews/page.tsx`; `src/app/admin/reviews/ReviewActionForm.tsx`; `src/app/api/admin/products/[productId]/rights-review/route.ts`; `src/server/admin/authorization.ts`; `supabase/migrations/20261013050000_phase5b_admin_rights_review.sql`; `supabase/tests/phase5b_admin_rights_review.test.sql`; `tests/e2e/admin-access.spec.ts`; `docs/operations/admin-console.md`; and `.github/workflows/ci.yml`.
- **Security invariants:** untrusted clients cannot call the RPC; authenticated identity and database role are checked before privileged access; creator and reviewer must be distinct; status transitions and rights evidence update in one transaction; resolved evidence cannot be silently reviewed again; audit failure prevents the rights transition; client errors do not disclose raw database details; review success never publishes a product or moves funds.
- **Forensic defects corrected:** the initial endpoint parsed an unbounded JSON request before enforcing field limits. It now uses the shared streaming bounded-body reader, requires JSON, caps the request at 8 KiB, and disables response caching. The database suite was expanded to simulate audit-write denial and prove both attestation and product rights changes roll back. SQL dollar quoting in that regression assertion was corrected before the final green run.
- **Residual risks / explicit non-claims:** product publication remains a separate gate requiring a verified rights attestation and independently released content-addressed artifact. The admin console still lacks full support-case operations, financial settlement reconciliation, dispute/chargeback handling, alert delivery, backup restoration drills, incident response, and break-glass governance. Formal penetration testing, full WCAG 2.2 AA assessment, production provider onboarding, legal/tax review, and deployment verification remain open.
- **Gate decision:** Phase 5B is complete for its stated scope. Phase 5 overall remains in progress; do not treat this subphase as production readiness.


### Phase 5C — Admin audit explorer (complete for this scope)

Scope: restricted audit-stream discovery with exact-match filters, stable cursor pagination, bounded queries, safe fields only, and query-performance indexes. Audit events remain append-only and are never mutated through the explorer.

Exit criteria:
- [x] Authenticated admin authorization and access-audit logging happen before privileged event queries.
- [x] Exact action/entity filters and cursor input are validated; repeated, oversized, unknown, or malformed query parameters fail closed.
- [x] The page queries at most 51 rows per request and displays at most 50; cursor pagination is stable and filter-preserving.
- [x] Only approved audit columns are selected; arbitrary metadata and raw database errors are not exposed.
- [x] Supporting indexes are applied by a reviewed SQL migration; pgTAP confirms indexes and unchanged least-privilege/append-only controls.
- [x] Playwright proves unauthenticated users cannot access the audit explorer or rights-review queue.
- [x] Unit tests, database reset/lint/pgTAP, E2E, typecheck, lint, production build, and cleanup pass on the exact implementation head.
- [x] Phase-specific forensic audit and residual limits are recorded before the next phase begins.


### Phase 5C forensic audit record

- **Disposition:** PASS for the bounded, read-only audit-explorer scope only. This is not a complete operations centre or production-launch approval.
- **PR:** [#16 — feat: add bounded admin audit explorer](https://github.com/LloydCoder/web-temify/pull/16), merged after exact-head CI passed.
- **Validated implementation head:** `62a16f41f5e9689d6ef0f7203f566084af594d3b`.
- **Merge commit:** `50041f25d95aa5f3e16cd22504b7b5c2ee982ad6`.
- **CI evidence:** [Foundation CI run 38461536339](https://github.com/LloydCoder/web-temify/actions/runs/38461536339) completed successfully on the exact PR head. Frozen install, foundation/domain tests, TypeScript, lint, Supabase CLI setup, local services, empty-database migration reset, schema lint, pgTAP/RLS, Playwright, production build, and cleanup all passed.
- **Files reviewed:** `src/app/admin/audit/page.tsx`; `src/server/admin/audit-filters.ts` and tests; `src/server/admin/authorization.ts`; `supabase/migrations/20261013060000_phase5c_admin_audit_explorer.sql`; `supabase/tests/phase5c_admin_audit_explorer.test.sql`; `tests/e2e/admin-access.spec.ts`; `docs/operations/admin-console.md`; and `.github/workflows/ci.yml`.
- **Security invariants:** the shared admin helper validates the Supabase Auth principal and database-owned admin role before constructing the privileged client; access is audit-recorded before the query; only approved audit columns are selected; metadata is not returned; filters are bounded and fail closed; each query fetches at most 51 rows and displays 50; pagination preserves exact filters; audit records remain append-only; anonymous and ordinary authenticated roles cannot read the stream.
- **Forensic defects corrected before PASS:** the pagination href was converted to a typed URL object after TypeScript rejected the prior string; PostgreSQL BIGINT IDs now cross the JavaScript boundary as exact text via a generated `id_text` projection, preventing precision loss above `Number.MAX_SAFE_INTEGER`; a pgTAP assertion verifies that projection; Next.js `typedRoutes` uses the stable top-level config option.
- **Residual risks / explicit non-claims:** cursor pagination is descending ID order, not a tamper-evident audit export; no audit retention/archival policy or external immutable log sink is implemented. Support cases, financial reconciliation, dispute/chargeback handling, alert delivery, backup restoration, incident response, and break-glass governance remain later gates. Full WCAG 2.2 AA, formal penetration testing, production environment configuration, and legal/tax review remain open.
- **Gate decision:** Phase 5C is complete for its stated scope. Phase 5 overall remains in progress. Proceed to the next phase only after the post-merge main workflow passes and the next phase has its own explicit implementation/test gate.


Least-privilege admin controls, moderation queues, support, audit review, financial reconciliation, observability, backup/restore rehearsal, incident response and safe break-glass access.

## Phase 6 — Seller system and product factory
Vendor rights verification, quality gates, payout eligibility, disputes, artifact scanning, isolated builds/previews, product manifests, immutable artifacts, SBOM/provenance, product-specific CI and release evidence. The dedicated source monorepo is [LloydCoder/web-temify-products](https://github.com/LloydCoder/web-temify-products); bootstrap PR #1 was merged after its frozen-install and catalogue-validation CI passed. Its 43-entry inventory is authoritative for planning only; no product-specific source builds or releases are implied. Do not copy independent products into the marketplace app repository without an explicit migration decision.

## Phase 7 — Tinlance integration
Versioned authenticated APIs/events, capability scopes, tenant context, approvals, idempotency, audit, budgets, timeouts, kill switch and isolated execution. Start read-only/sandbox. Web-Temify remains the authority for publication, pricing, payments, refunds, entitlements, licenses and downloads.

## Phase 8 — Launch readiness
Security/performance/accessibility checks, legal and tax review, monitoring, alerting, rollback, customer support, disaster recovery, SLOs, staged launch checklist and verified production deployment. No production launch until each gate has owner, evidence, and explicit disposition.

## Later growth
Directory, AI generation, community, affiliate, automation, mobile API, white-label, and regulated/high-risk categories only after core launch evidence and validated demand. The separate 18 proposed product candidates remain deferred until the core 39 standalone products and 4 launch kits have been implemented and validated in the agreed tier order.
