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

## Phase 1 — Reproducible engineering foundation and application skeleton

Scope: branch-based delivery, root configuration, accessible App Router shell, strict TypeScript, lint/test/foundation commands, safe environment boundaries, CI checks.

Exit criteria:

- [x] Clean checkout installs reproducibly with committed pnpm-lock.yaml and CI enforces --frozen-lockfile.
- [x] Lint, typecheck, foundation tests, and production build passed in CI on the Phase 2 baseline commit.
- [x] No secrets or local env files are present in the tracked tree.
- [x] Formatting check (`pnpm format:check`), high/critical dependency audit with verified local-patch exception handling, license policy scan, and full-history secret scanning pass on the exact candidate head. Evidence: PR #21 head `5e505bb7bdf926c1a3f34b9b4b23217ba2bc9ebc`; Foundation CI run 38472660193 and Security/dependency governance run 38472660132 passed.
- [x] The patched Next.js/React dependency graph has no unresolved high/critical advisories in the CI audit.
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

Scope: server-owned orders and item snapshots, provider-neutral payment attempts, verified-event inbox, idempotent financial ledger, refunds, paid-order entitlements, private-download authorization, and the Phase 4C evidence-backed journal/allocation primitives. Provider integrations remain disabled until business eligibility, jurisdiction coverage, fees, webhook semantics, tax treatment and payout settlement are verified. Settlement, chargeback, reserve and manual-adjustment posting sources remain blocked until dedicated evidence-backed state machines and accounting policy are implemented. The journal supports independently approved seller fee schedules and proceeds allocation, but Phase 4 remains incomplete.

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
- **Gate decision:** Phase 4A is merged and passes for its database-invariant scope only. Phase 4 as a whole remains in progress because the provider-neutral/live-provider boundary, durable event guarantees, and end-to-end delivery readiness must be verified against the canonical Phase 4 gate; this record is not launch approval.

### Phase 4B — server-side commerce workflows (complete for sandbox-only scope)

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

### Phase 4C — immutable financial journal and proceeds allocation (complete for tested sandbox-ledger scope)

- [x] Immutable financial journal batches and append-only entries enforce same-currency debit/credit balancing before posting.
- [x] Payment/refund journal posting must reconcile to the immutable ledger transaction and verified provider event, including provider reference and payload digest; arbitrary balanced postings are rejected.
- [x] Seller fee schedules require a database-owned admin role, independent approval/revocation actors, immutable terms, and effective/expiry controls.
- [x] Idempotent per-order-item proceeds allocation reconciles gross, seller payable, platform commission and any tax amount already present on the order snapshot.
- [x] Unsupported posting sources (settlement, provider fees, chargebacks, reserves, manual adjustments) fail closed; post-allocation refund outflow requires an approved reversal journal first.
- [x] 169 pgTAP assertions, empty-database migration reset, schema lint, typecheck, lint, format check, Playwright, production build and cleanup passed on the exact reviewed head.

### Phase 4C forensic audit record

- **Disposition:** PASS for immutable journal and proceeds-allocation primitives only; NOT live commerce or production financial readiness.
- **PR/head/merge:** [PR #24](https://github.com/LloydCoder/web-temify/pull/24), reviewed head `3e5e438af23ef6dadb0e54443609507ab14b35dd`, merged commit `ed9f1d461c3f7fab2d47f5624cbbee4483c3baa7`.
- **CI evidence:** [Foundation CI run 38515752985](https://github.com/LloydCoder/web-temify/actions/runs/38515752985) and [Security/dependency governance run 38515753014](https://github.com/LloydCoder/web-temify/actions/runs/38515753014) both passed on the exact reviewed head.
- **Files reviewed:** `supabase/migrations/20261013035000_phase4c_financial_journal.sql`, `supabase/tests/phase4_commerce.test.sql`, Phase 4B commerce documentation, migration README, master roadmap and phase-gate register.
- **Residual gate:** settlement, provider fee posting, payouts, chargebacks, manual adjustments and reserves remain disabled. Phase 4D1 now implements a sandbox/test-only reversal-before-refund workflow; settlement, provider fees, payouts, chargebacks, reserves, manual adjustments and production readiness remain blocked. No live provider, tax calculation, escrow, or production readiness is claimed.

### Phase 4D — settlement, refund reversals, chargebacks, reserves and financial adjustments (in progress)

#### Phase 4D1 — refund reversals after proceeds allocation (complete for tested sandbox-only scope)

- [x] Exact-head empty-database migration reset, schema lint, pgTAP/RLS tests, Playwright, production build and cleanup pass.
- [x] Exact-head dependency/license/secret governance passes.
- [x] Forensic review verifies immutable reversal requests/lines, distinct-admin approval/rejection, verified webhook evidence, balanced reversal-before-refund posting, cumulative item/fee/tax caps, idempotency and rejected-request retry.
- [x] Commission reversal arithmetic uses cumulative rounding, including minor-unit carry across partial refunds.
- [x] Service-role table grants do not allow direct state-transition updates; approval/rejection uses narrowly granted server RPCs.
- [x] Roadmap, migration README, Phase 4C commerce documentation and this gate register agree with the reviewed Phase 4D1 implementation and its tested sandbox-only boundary.
- [x] Explicit non-claims remain: no live provider, settlement reconciliation, provider-fee posting, payout, tax calculator, chargeback, reserve, manual-adjustment execution or escrow.

**Phase 4D1 forensic audit record — PASS (sandbox/test scope only)**

- **Disposition:** PASS for the implemented database reversal workflow and its tested accounting invariants. This is not live-commerce, provider settlement, payout, tax, escrow, or production-launch approval.
- **PR:** [#27 — feat(commerce): add approved refund reversal workflow](https://github.com/LloydCoder/web-temify/pull/27), merged as `0202c0154828a9dfd0c822fff265120b98514521`.
- **Validated implementation head:** `1aa58cfe7801d03191f8ba15646702c625cb964d`.
- **Foundation CI:** [run 38523309374](https://github.com/LloydCoder/web-temify/actions/runs/38523309374) — passed on the exact implementation head, including frozen install, foundation tests, typecheck, lint, formatting, empty-database migration reset, schema lint, pgTAP/RLS tests, Playwright E2E, production build and cleanup.
- **Security/dependency governance:** [run 38523309382](https://github.com/LloydCoder/web-temify/actions/runs/38523309382) — passed on the exact implementation head, including dependency, production-license and full-history secret checks.
- **Files reviewed:** `supabase/migrations/20261013036000_phase4d1_refund_reversals.sql`, `supabase/tests/phase4_commerce.test.sql`, `docs/commerce/phase4d1-refund-reversals.md`, `docs/commerce/phase4c-financial-journal.md`, `supabase/migrations/README.md`, the master roadmap, and this gate register.
- **Security/accounting invariants:** restricted server-only approval/rejection RPCs; distinct database-owned admin decision-maker; immutable request/line evidence; verified provider-event matching; balanced reversal journal posted before refund outflow; per-seller attribution; cumulative gross/fee/seller-net/tax caps; cumulative commission rounding; rejected-request retry; and no direct service-role table updates to request state.
- **Test-fixture defects corrected before PASS:** all new refund records begin in the required `requested` state; the overflow fixture requests the remaining order balance but attempts an oversized item reversal; and the failed fixture is transitioned to `failed` to release its reserved order balance. The pgTAP plan and assertion count were updated together to 215.
- **Residual risk:** no live provider, settlement reconciliation, provider-fee posting, payout, tax/VAT calculator, chargeback/dispute workflow, reserve management, manual-adjustment execution, escrow, production environment verification, formal penetration test, legal/tax review, or full WCAG 2.2 AA assessment is implied by these passing checks.
- **Gate decision:** Phase 4D1 is complete for its stated sandbox/test scope. Phase 4D and launch readiness remain incomplete. The next serial gate is Phase 4D2, provider settlement reconciliation; provider selection, jurisdiction eligibility, settlement evidence and external onboarding remain prerequisites.

#### Phase 4D2 — provider settlement reconciliation (in progress; implementation partial, external provider gate open)

- [x] Reconcile the previously accepted provider-role strategy and record evidence boundaries in [`docs/commerce/provider-strategy.md`](../commerce/provider-strategy.md). The record distinguishes Polar (MoR candidate), Paystack (Nigeria/local direct-payment candidate), Sellra (unverified candidate), and Grey (treasury/FX only); older exploratory providers are not automatically approved for integration.
- [ ] Select the first-launch route from the accepted roles only after Web-Temify account/KYB approval, marketplace contractual permission, supported buyer/seller jurisdictions, currencies, fees, refunds/disputes, settlement evidence and operational support are confirmed. Public provider documentation alone is insufficient.
- [ ] Define a versioned provider-neutral settlement import contract with signed/source-authenticated evidence, content digest, report period, currency, gross, fees, net, provider references and row-level exceptions.
- [ ] Reconcile settlement rows idempotently to verified payment/refund journal batches; reject duplicate, missing, mismatched, out-of-period, cross-currency and unexplained amounts.
- [x] Post sandbox-only provider-fee rows through source-specific balanced same-currency journal guards after digest-linked private evidence and an admin reviewer distinct from the importer, uploader, and evidence linker. This is accounting-only and does not move funds.
- [ ] Implement source-specific provider-settlement/payout journal posting only after provider-authenticated ingress and external settlement evidence; keep live processing and money movement disabled.
- [ ] Add adversarial pgTAP tests, reconciliation fixtures, failure/replay tests, operator exception queues, documentation and exact-head CI/forensic audit.
- [ ] Record external onboarding and settlement evidence; until then keep live provider processing disabled.

#### Phase 4D2 implementation checkpoint — partial, not a gate pass

- **Disposition:** IN PROGRESS. The settlement import/reconciliation foundation was merged in [PR #30](https://github.com/LloydCoder/web-temify/pull/30) at `2aca37e5388cf0607fb7dc26581a55fc1f4e6c08`. Foundation CI [38532428797](https://github.com/LloydCoder/web-temify/actions/runs/38532428797) and Security/dependency governance [38532428794](https://github.com/LloydCoder/web-temify/actions/runs/38532428794) passed on exact PR head `27a4aed8084264c63a656545be15365e1d3c733e`. PR #31 merged explicit cross-currency mismatch classification and matching fixtures at `7203a783c27b0536cc67bc97a6ac2433be1276c7`.
- **Merged evidence custody:** [PR #38](https://github.com/LloydCoder/web-temify/pull/38) merged private settlement evidence storage, bounded admin upload, server-computed SHA-256, immutable metadata, audited integrity-checked download, and least-privilege storage controls at `bc348d66cc7553f48f55ff9d400df44c0181ddab`. Foundation CI [38546441406](https://github.com/LloydCoder/web-temify/actions/runs/38546441406) and Security/dependency governance [38546442263](https://github.com/LloydCoder/web-temify/actions/runs/38546442263) passed on the exact reviewed PR head. A digest proves byte identity, not provider origin.
- **Merged adversarial import tests:** [PR #39](https://github.com/LloydCoder/web-temify/pull/39) expanded the Phase 4D2 settlement-import suite; the current SQL test plan is 127 pgTAP assertions (`select plan(127)`), covering unknown timezones, local-date/UTC boundaries, out-of-period rows, atomic rollback, unmatched refunds, fee-only rows, and explicit adjustment exceptions. It merged at `eeedd56bb37dfe54c7f16b3fc524afaf82281ef7`; Foundation CI [38547154433](https://github.com/LloydCoder/web-temify/actions/runs/38547154433) and Security/dependency governance [38547154460](https://github.com/LloydCoder/web-temify/actions/runs/38547154460) passed on exact PR head `19328f08f44ae153213b4b7791e58f6a34333858`.
- **Merged evidence-to-import linkage:** [PR #40](https://github.com/LloydCoder/web-temify/pull/40) merged at `2590bea1cc6e73f64ad279bb4bfa6d400101b1af`. It adds an append-only evidence-to-import link, exact digest matching, an independent admin distinct from both uploader and importer, atomic audit persistence, and a forward migration that removes direct service-role evidence-metadata inserts. Foundation CI [38549266378](https://github.com/LloydCoder/web-temify/actions/runs/38549266378) and Security/dependency governance [38549266372](https://github.com/LloydCoder/web-temify/actions/runs/38549266372) passed on exact implementation head `c32113784e8fb939ef48a9419c2c0c978603334c`. This remains a bounded implementation slice, not Phase 4D2 completion.
- **Implementation boundary:** Phase 4D2 remains incomplete. Reconciliation covers payment/refund matching to already-posted journal batches and classifies missing, duplicate, amount, currency, and unsupported-row cases. PR [#42](https://github.com/LloydCoder/web-temify/pull/42) merged the global journal-match uniqueness invariant and deterministic advisory-lock ordering at `7054460874d9e9c505e5e34c2125d44b0a0406a2`; reviewed head `b551bc7dd242d71eb91c52538b6cafa95f727c79` passed [Foundation CI](https://github.com/LloydCoder/web-temify/actions/runs/38553648423) and [Security/dependency governance](https://github.com/LloydCoder/web-temify/actions/runs/38553648430). PR [#43](https://github.com/LloydCoder/web-temify/pull/43) added verified partial-refund-to-journal matching coverage at `93a9f5222b94e0c4c8894676cd26d076eb3414c9`; reviewed head `00ed1a608d1a84008d50d02f2829b73957742a6a` passed [Foundation CI](https://github.com/LloydCoder/web-temify/actions/runs/38555233489) and [Security/dependency governance](https://github.com/LloydCoder/web-temify/actions/runs/38555233495). PR [#44](https://github.com/LloydCoder/web-temify/pull/44) added passing refund amount-mismatch, currency-mismatch, and duplicate-replay cases at `f1e82caadf2c47e1929c7a35e32b1a21cf506c61`; reviewed head `bbf3ccaf6aeb24614b8cb343f1b385cba506d8b1` passed [Foundation CI](https://github.com/LloydCoder/web-temify/actions/runs/38556186662) and [Security/dependency governance](https://github.com/LloydCoder/web-temify/actions/runs/38556186684). The Phase 4D2 pgTAP suite includes 34 sandbox-fee posting assertions and 31 scanner-gate assertions. Treat individual suite results at the exact reviewed commit as the acceptance evidence; aggregate assertion totals are informational and must be recalculated whenever suites change. The fee path is deliberately limited to sandbox fixtures with linked evidence and independent review. A new database gate requires the latest digest-matched scanner attestation to be clean before linkage or fee posting. A token-protected ClamAV gateway, application client, and upload-route integration are implemented in code. **Persistent production deployment, HTTPS endpoint configuration, secret provisioning, signature-freshness monitoring/alerting, and live scanner smoke tests are deferred until settlement-evidence processing is explicitly in the production launch scope; they are not blockers for unrelated marketplace phases.** Until then, keep the database gate fail-closed and settlement posting disabled. Other Phase 4D2 blockers remain true concurrent-race tests, source-specific provider-settlement/payout posting, provider-authenticated source ingress, production retention scheduling/alerting, escalation/expiry, and external provider onboarding/settlement evidence. The source-authentication field remains a trusted-ingress assertion, not cryptographic proof.
- **Cross-import replay regression (PR #62):** merged as `58144e21f6a1d083bed7f12132d43389de0ca3db`. The added settlement-import test verifies that a second USD report referencing a payment journal already matched by a prior import is recorded as `duplicate_reference` with no journal-batch link. The new fixture uses a unique source digest so it cannot collide with the existing amount-mismatch evidence fixture. PR-head [Foundation CI run 38778385931](https://github.com/LloydCoder/web-temify/actions/runs/38778385931) and [Security/dependency governance run 38778385646](https://github.com/LloydCoder/web-temify/actions/runs/38778385646) passed on exact head `9760477017c84b714f4f8778ffa8f5ee93bf7142`. The merge commit `58144e21f6a1d083bed7f12132d43389de0ca3db` then passed [Foundation CI run 38779048118](https://github.com/LloydCoder/web-temify/actions/runs/38779048118) and [Security/dependency governance run 38779047967](https://github.com/LloydCoder/web-temify/actions/runs/38779047967). The subsequent documentation-only main head `48f247fc1abe8b90db22e4e4b71f6b878c01c272` also passed [Foundation CI run 38779961266](https://github.com/LloydCoder/web-temify/actions/runs/38779961266) and [Security/dependency governance run 38779961294](https://github.com/LloydCoder/web-temify/actions/runs/38779961294), including the four reported checks: Foundation checks, full-history secret scan, production dependency license policy, and high/critical dependency audit. This verifies the current main head at audit time; it does not prove true multi-session concurrent-race handling, which remains open.

- **Sandbox fee-posting sub-gate:** the new forward migration `20261014130000_phase4d2_sandbox_fee_journal_posting.sql` adds a source-specific `provider_fee` journal only for `sandbox_fixture` imports. It requires an exact fee-row arithmetic contract, a private evidence link with matching SHA-256, a reviewer distinct from importer/uploader/linker, a balanced debit to `provider_fee_expense`, a matching credit to `provider_clearing`, immutable posting linkage, idempotency, and an audit event in the same transaction. The dedicated pgTAP suite covers successful posting, missing-evidence rollback/retry, actor separation, immutable evidence, and malformed fee arithmetic. This sub-gate does not enable live providers, settlement cash movement, or payouts.
- **Evidence-retention sub-gate (implementation partial; operations unverified):** migration `20261014150000_phase4d2_evidence_retention_worker.sql` adds a service-only queue and bounded claim/finish RPCs. Only expired, unlinked evidence bytes are eligible; linked financial evidence is preserved pending an approved retention policy. The protected `/api/internal/settlements/evidence-retention` endpoint requires a 32+ character bearer secret, processes at most 25 objects per run, uses 15-minute leases and a five-attempt ceiling, preserves immutable metadata/audit history, and blocks new links after expiry. The pgTAP suite and application route tests cover retention exclusions, tombstones, retries, authorization and failure handling. `vercel.json` declares a daily 03:15 UTC Vercel Cron invocation; production deployment and `CRON_SECRET`/dedicated token configuration, smoke test, alerting, and manual review for blocked jobs remain open. Do not claim the worker is operational until those controls are verified.
- **Evidence malware-gate sub-gate:** migration `20261014140000_phase4d2_evidence_malware_gate.sql` adds immutable scan attestations and makes evidence linking and fee posting fail closed unless the latest scan result is clean for the exact stored digest. The token-protected ClamAV gateway in `services/settlement-scanner/` uses INSTREAM, verifies the digest independently, and does not expose the clamd port outside its private Docker network. The admin upload route records clean/infected/error results only after a validated scanner response; missing configuration, timeout, digest mismatch, or service failure leaves evidence pending. Production deployment, HTTPS endpoint configuration, secret provisioning, signature freshness/alerting, and a live smoke test remain unverified. The dedicated pgTAP suite adds 31 assertions for digest binding, pending/infected denial, immutable scan history, audit events, stale-signature denial, and fresh-rescan recovery. The separate retention worker implementation audit is recorded in `docs/audits/phase4d2-evidence-retention-worker.md`.
- **Scanner signature freshness sub-gate — merged, code scope passed:** PR [#57](https://github.com/LloydCoder/web-temify/pull/57) merged at `5e0acdfc84046ee674634ade0173549bfb9f526d`; reviewed implementation head `1842f85f26b11e11ab2227ada38ed90633166fe9` passed Foundation CI [38732109726](https://github.com/LloydCoder/web-temify/actions/runs/38732109726) and Security/dependency governance [38732109750](https://github.com/LloydCoder/web-temify/actions/runs/38732109750). Migration `20261015100000_phase4d2_scanner_signature_freshness.sql` stores the scanner-reported signature-database update time. The ClamAV gateway parses the timestamp from `VERSION` and fails closed if it is missing or invalid. Evidence linkage and provider-fee posting require a latest digest-matched clean scan with signature definitions no older than 48 hours; timestamps more than five minutes in the future are rejected. Stale attestations remain immutable audit evidence but cannot authorize linkage or posting. Database and gateway tests cover stale-signature denial and fresh-rescan recovery. **Post-merge verification:** the merge commit `5e0acdfc84046ee674634ade0173549bfb9f526d` passed Foundation CI [run 38733674367](https://github.com/LloydCoder/web-temify/actions/runs/38733674367) and Security/dependency governance [run 38733674369](https://github.com/LloydCoder/web-temify/actions/runs/38733674369). The current `main` head at audit time, `982cc75f480e0ea2fd39801ee988e0799018b5ce`, also passed Foundation CI [run 38739977107](https://github.com/LloydCoder/web-temify/actions/runs/38739977107) and Security/dependency governance [run 38739977256](https://github.com/LloydCoder/web-temify/actions/runs/38739977256). **Deferred until production settlement-evidence launch:** scanner deployment, HTTPS endpoint/secret configuration, signature-freshness monitoring/alerting, and live scanner smoke tests. Keep the gate fail-closed and settlement posting disabled until that deferred checklist is completed. **Still open for Phase 4D2:** provider-authenticated ingress, provider settlement/payout posting, true concurrent-race tests, retention-worker operational verification, escalation/expiry, and provider/legal onboarding evidence. Repository settings are also a release-control blocker: the `main` branch API reports `protected: false`, with required status checks unenforced; configure branch protection/rulesets and required checks before treating CI as an enforced merge gate. This sub-gate does not close Phase 4D2.
- **Acceptance status:** keep the overall Phase 4D2 exit criterion unchecked until the complete workflow, adversarial database tests, security review, exact-head CI, and external evidence have passed together. Do not enable live provider processing.

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

### Phase 5C — Admin audit explorer (complete for its reviewed scope)

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

Least-privilege admin controls, moderation queues, support, audit review, financial reconciliation, observability, backup/restore rehearsal, incident response and safe break-glass access.

#### Phase 5C forensic audit record

- **Disposition:** PASS for the bounded, read-only audit-explorer scope only; this is not overall operations-centre or production-readiness approval.
- **PR:** [#16 — feat: add bounded admin audit explorer](https://github.com/LloydCoder/web-temify/pull/16), merged.
- **Reviewed implementation head:** `62a16f41f5e9689d6ef0f7203f566084af594d3b`.
- **Merge commit:** `50041f25d95aa5f3e16cd22504b7b5c2ee982ad6`.
- **CI evidence:** [Foundation CI run 38461536339](https://github.com/LloydCoder/web-temify/actions/runs/38461536339) completed successfully on the exact reviewed head. Frozen install, foundation/domain tests, TypeScript, lint, local Supabase startup, empty-database migration reset, schema lint, pgTAP/RLS tests, Playwright, production build, and cleanup all succeeded.
- **Files reviewed:** `src/app/admin/audit/page.tsx`; `src/server/admin/audit-filters.ts` and its tests; `supabase/migrations/20261013060000_phase5c_admin_audit_explorer.sql`; `supabase/tests/phase5c_admin_audit_explorer.test.sql`; `next.config.ts`; admin operations documentation; and CI workflow.
- **Controls:** authentication and database-owned admin authorization precede privileged reads; the access event is written before querying; action/entity filters are exact-match and bounded; cursor parameters are validated; queries fetch at most 51 rows and render at most 50; only approved audit columns are selected; arbitrary metadata and raw errors are excluded; audit IDs cross the PostgreSQL/JavaScript boundary as exact text to avoid BIGINT precision loss; pagination preserves active filters; SQL tests cover supporting indexes, exact cursor projection, and unchanged least-privilege/append-only controls.
- **Residual limits:** this is an administrative visibility surface, not a complete support, incident-response, finance-reconciliation, moderation, backup/restore, alerting, or break-glass system. Passing CI does not prove production secrets, provider configuration, legal/tax readiness, penetration-test completion, or full WCAG 2.2 AA conformance.
- **Gate decision:** Phase 5C passes its bounded implementation and CI gate. Phase 5 overall remains incomplete. The canonical sequence must be followed: complete the remaining Phase 4 implementation gates that are direct dependencies of Phase 5. Production provider onboarding, scanner deployment, settlement-evidence retention/monitoring, and live money-movement controls remain mandatory launch gates, but do not block independent Phase 5 admin, moderation, support, and trust implementation while all financial actions remain fail-closed. Complete the Phase 5 operational gates before advancing to Phase 6.

### Phase 5 overall exit gates (not satisfied by the read-only console or audit explorer alone)

- [ ] Moderation, takedown, appeal and support-case workflows have scoped authorization, evidence retention, reason codes and audit events.
- [ ] Financial reconciliation distinguishes gross orders, refunds, provider settlement, platform fees, seller payable, reserves and tax liabilities.
- [ ] Disputes, chargebacks, payout holds, negative balances and manual adjustments have reviewed state machines and dual approval for high-risk actions.
- [ ] Incident alerts, escalation ownership, safe break-glass access, backup/restore exercises and incident response procedures are operationally tested.
- [ ] Support communications and data access are tenant-scoped, logged, retention-aware and protected against disclosure of secrets or payment data.

### Phase 5D — Audited support-case workflow (complete for tested workflow scope; operations remain incomplete)

- [x] Migration and pgTAP tests pass from an empty database on the exact reviewed head.
- [x] Authenticated customer intake and ownership-scoped case history are verified; customer history is filtered by the validated authenticated user ID.
- [x] Admin queue and state transitions enforce server-side role checks, same-origin requests, bounded bodies, explicit transitions, admin-only assignment, append-only events, and transactional audit evidence.
- [x] E2E verifies unauthenticated admin access denial and customer history authentication.
- [x] Phase-specific forensic audit records exact-head CI evidence and remaining operational limits.

#### Phase 5D forensic audit record

- **Disposition:** PASS for the audited support-case workflow and CI scope only. Phase 5 overall remains incomplete; this does not certify a staffed support operation or production readiness.
- **PR:** [#48 — Feat/phase5 support case workflow](https://github.com/LloydCoder/web-temify/pull/48).
- **Reviewed implementation head before this audit-record commit:** `989969d18d95eb54d2d003800ecb33619b804012`.
- **Exact-head CI evidence:** [Foundation CI run 38574294521](https://github.com/LloydCoder/web-temify/actions/runs/38574294521) and [Security and dependency governance run 38574294451](https://github.com/LloydCoder/web-temify/actions/runs/38574294451) both succeeded on that head. Foundation checks include frozen install, validation/tests, TypeScript, lint, format, empty-database migration reset, schema lint, pgTAP/RLS, Playwright E2E, production build, and Supabase cleanup; security checks include high/critical dependency audit, production license policy, and full-history secret scanning.
- **Files reviewed:** `src/app/admin/support/page.tsx`; `src/app/admin/support/SupportCaseActionForm.tsx`; `src/app/api/admin/support-cases/[caseId]/transition/route.ts`; `src/app/api/support-cases/route.ts`; `src/app/support/page.tsx`; `src/app/support/SupportCaseCreateForm.tsx`; `supabase/migrations/20261014110000_phase5_support_cases.sql`; `supabase/tests/phase5d_support_cases.test.sql`; `tests/e2e/admin-access.spec.ts`; `playwright.config.ts`; and admin/support/migration/test documentation.
- **Authorization and data controls:** customer routes validate the Supabase principal with `auth.getUser()`; history queries are constrained to that user ID; privileged case creation and transitions use narrow service-role-only database RPCs; the transition RPC independently checks the database-owned admin role, locks the case row, enforces legal state transitions, and verifies admin assignment. Request bodies are bounded and schema-validated; mutations require same-origin requests; responses avoid raw database errors. Direct client table writes are revoked, RLS is enabled, case events reject update/delete, and creation/state changes append audit evidence in the same transaction.
- **Concurrency/idempotency:** creation serializes requester/idempotency-key use with a transaction-scoped advisory lock, returns the original case for identical replay, and rejects conflicting reuse. State transitions lock the target case row before evaluating status.
- **Test evidence:** the 40-assertion pgTAP suite covers RLS/grants, RPC permissions, create/replay/conflicting-key behavior, role enforcement, assignment, state transitions, terminal timestamps, append-only events, and audit-event counts. Playwright covers unauthenticated admin routes/mutations and unauthenticated customer history.
- **Residual limits:** the workflow does not deliver outbound support notifications, automated SLA/escalation jobs, or staff an on-call rota. It does not implement the broader takedown/appeal workflow, financial reconciliation, disputes/chargebacks, backup restoration, incident-response automation, alert delivery, or break-glass controls. Retention/deletion policy and a staffed support communications process still require explicit operational/legal decisions. The service-role customer-history query relies on server-side ownership filtering and therefore warrants continued regression coverage; direct database access remains denied. No production provider, legal/tax, penetration-test, full WCAG 2.2 AA, or deployment-readiness claim is made.
- **Gate decision:** Phase 5D passes for its implemented workflow scope after the exact-head green CI runs above. Phase 5 overall remains in progress and cannot advance to Phase 6 until its own exit gates and the remaining Phase 4 implementation gates that are direct dependencies are satisfied. Production provider onboarding, scanner deployment, settlement-evidence retention/monitoring, and live money-movement controls remain mandatory launch gates but do not block independent admin, moderation, support, and trust implementation while financial actions remain fail-closed.

### Phase 5E1 — Listing moderation case intake (implementation pending CI)

**Status: IN PROGRESS.** This is the first bounded slice for moderation operations, not a full takedown/appeal workflow.

- [ ] Apply the new moderation case/event migration from an empty database and pass schema lint and pgTAP.
- [ ] Pass exact-head Foundation CI, E2E, production build, formatting and security/dependency governance.
- [ ] Review the product-detail report form, admin queue/action controls, authenticated report intake/idempotency, database-owned transitions, append-only event history, and transactional audit evidence.
- [ ] Add enforcement that suppresses public visibility when a reviewed takedown is required; verify every public read path and RLS policy.
- [ ] Implement creator appeal/counter-notice intake, independent review, evidence retention, deadlines, and audited outcomes before treating moderation as complete.

Forensic record: `docs/audits/phase5e-moderation-cases.md`. The current case queue does not itself unpublish a product or implement appeals. Phase 5 remains incomplete; live payment/provider processing stays disabled.

## Phase 6 — Seller system and product factory

**Status: NOT COMPLETE.** This phase builds the trusted supply side and a repeatable, evidence-backed product release pipeline. The dedicated source monorepo is [LloydCoder/web-temify-products](https://github.com/LloydCoder/web-temify-products); its inventory is planning input, not evidence that products have been built or released. Keep product source code, manifests, build/test contracts and immutable release evidence in that repository; keep commercial listing state and marketplace transactions in this repository.

Exit gates (all required):

- [ ] Seller onboarding captures legal/business identity, beneficial ownership where required, payout jurisdiction, tax status, support/contact and policy acceptance without presenting unverified claims as verified.
- [ ] Verification is evidence-based, independently reviewable, timestamped, revocable and appealable; creator self-review is prohibited; badges/ranking reflect current evidence and never imply a government endorsement.
- [ ] Seller status, listing publication, product rights, artifact release and payout eligibility are distinct state machines with server/database enforcement.
- [ ] Product manifests are schema-validated and versioned; builds run in isolated least-privilege environments with resource/time limits, network egress controls, secret isolation and cleanup.
- [ ] Released artifacts are immutable/content-addressed; digest, source revision, toolchain, build logs, test evidence, license/rights evidence and SBOM/provenance are linked to a release.
- [ ] Malware/secrets/dependency/license scans fail closed on policy violations; scan exceptions require a documented, time-bounded approval and audit evidence.
- [ ] Product-specific CI validates lint, typecheck, unit/integration tests, security checks, reproducible manifest shape and build output before a release is eligible for listing.
- [ ] Seller contracts, prohibited-content rules, IP takedown, refunds, dispute handling, payout holds, reserves and audit obligations have reviewed operational/legal policies before real sellers or money are enabled.
- [ ] Admin actions are permission-scoped, reason-coded, auditable, idempotent and protected against self-approval.
- [ ] Automated tests cover seller tenancy isolation, privilege escalation, artifact substitution, malicious build scripts, replay, stale/revoked evidence, payout eligibility and moderation races.
- [ ] Exact-head CI, migration reset/lint/pgTAP, browser E2E, production build and a phase-specific forensic review pass before merging.

Deferred until explicitly gated: live seller payouts, escrow claims, tax calculation, regulated/high-risk categories and arbitrary third-party executable code. Never label funds as escrow unless the legal and payment architecture genuinely supports that service.

### Phase 6 marketplace vertical requirements

- **Verified Automation Marketplace:** list workflows, AI agents, integrations and reusable digital solutions only with supported compatibility claims, setup documentation, versioned artifacts, test/security evidence and clear permission/data requirements.
- **Verified Specialist Supplier Marketplace:** represent firms and specialists using evidence-backed capabilities, service regions, certifications, references and measured performance. Use status labels that distinguish identity verification from skill certification, reference checks and outcome history.
- **Outcome-Based AI Implementation Marketplace:** each offer defines scope, exclusions, customer prerequisites, baseline methodology, measurable outcome metrics, acceptance criteria, milestones, change control, dispute process and responsibility boundaries. Do not promise outcomes or use escrow terminology without enforceable terms and operational capability.
- Tinlance Limited may be a seller under the same eligibility, verification, ranking and dispute rules as other vendors. No privileged placement, self-verification or hidden policy exceptions.

### Product factory and inventory gates (also required for Phase 18 expansion)

- [ ] Reconcile the canonical product inventory against source repositories; assign each entry a unique ID, owner, tier, target buyer, differentiation evidence and acceptance criteria.
- [ ] Resolve duplicate/ambiguous catalogue entries before product implementation; generate counts from canonical data rather than copying them into docs.
- [ ] Establish lifecycle states: proposed → validated → specified → building → security review → released → listed → maintained/retired.
- [ ] Each product has a versioned manifest, rights/license evidence, threat model, tests, deployment instructions, support policy, changelog and immutable release record.
- [ ] Build/publish through CI with signed provenance/SBOM where supported, dependency/license/security scans and reproducible artifact checks.
- [ ] Planned, unbuilt, unverified products are never represented as available for purchase.

## Phase 7 — Governed Tinlance Agent System integration

**Status: NOT COMPLETE.** Begin with read-only/sandbox assistance. Web-Temify remains the authority for listings, pricing, checkout, payment state, refunds, entitlements, licenses, downloads, moderation and seller payouts.

- [ ] Define versioned integration contracts, tenant context, capability scopes, authenticated APIs/events, schema compatibility and deprecation rules.
- [ ] Enforce explicit human approvals for publishing, changing prices, issuing refunds, modifying entitlements, seller verification, payout actions and external communications.
- [ ] Apply least privilege, per-task budgets, timeouts, idempotency, rate limits, kill switch, trace IDs, audit evidence, secret isolation and isolated execution.
- [ ] Treat all user/product/vendor content and tool outputs as untrusted; test prompt injection, data exfiltration, cross-tenant access and confused-deputy paths.
- [ ] Prohibit agents from treating untrusted instructions as policy or from directly mutating commercial truth outside narrow server-enforced workflows.
- [ ] Test retries, duplicate events, partial failures, cancellation, approvals, policy denials and rollback/compensation behavior.
- [ ] Demonstrate integration against staging fixtures and a documented threat model before any production scope is enabled.

## Phase 8 — Production readiness and controlled launch

**Status: NOT COMPLETE.** No public production launch until every release gate has named ownership and auditable evidence.

- [ ] Provider eligibility and sandbox verification; live payments, refunds, seller payouts, taxes and settlement reconciliation validated for the target jurisdictions.
- [ ] Independent security review and penetration test; dependency/supply-chain controls; secret rotation; vulnerability disclosure and incident response.
- [ ] Full WCAG 2.2 AA assessment, keyboard/screen-reader checks, responsive QA and localization/currency/date handling.
- [ ] SLOs, error budgets, service dashboards, actionable alerts, structured logs, trace correlation, privacy-safe analytics and abuse monitoring.
- [ ] Backup/restore rehearsal with measured RPO/RTO; tested disaster recovery, migration rollback and deployment rollback.
- [ ] Legal review for consumer rights, seller terms, privacy/data protection, IP/takedown, tax/VAT, payment services, sanctions and marketplace obligations in launch jurisdictions.
- [ ] Support operations, escalation rota, refund/dispute procedures, data-subject request process and status communications are staffed and rehearsed.
- [ ] Staged rollout with explicit go/no-go owner, rollback trigger, canary monitoring and customer-impact review.
- [ ] Production environment evidence, smoke tests and deployment provenance are attached to the release; no claim of production readiness from CI alone.

## Phase 9 — Automation Marketplace domain and quality model

**Status: NOT COMPLETE.** Add automation/workflow/AI-agent/integration listings on shared identity, catalogue, seller, rights and commerce primitives. Directory metadata does not prove that an automation is safe or executable.

- [ ] Model automation listings with inputs/outputs, supported systems and versions, prerequisites, required scopes, data categories, execution location, external side effects, cost bounds, rollback behavior and maintainer identity.
- [ ] Require setup, permission, security, compatibility, maintenance and support documentation with immutable version references.
- [ ] Distinguish static downloadable artifacts from hosted execution and managed automation; pricing, SLAs and security claims must match the delivered service.
- [ ] Require deterministic contract tests or representative fixtures where feasible, permission review and explicit buyer consent for sensitive scopes.
- [ ] Enforce version pinning, revocation, dependency updates, vulnerability advisories and buyer notification for material changes.
- [ ] Keep Tinlance products/providers under the same publication, verification, ranking and dispute rules as every other seller.

## Phase 10 — Automation sandbox, verification and delivery

**Status: NOT COMPLETE.** Submitted automations must be validated outside the marketplace control plane before any hosted execution is enabled.

- [ ] Build isolated, resource-bounded validation environments with timeouts, quotas, filesystem/network controls, cleanup and auditable execution evidence.
- [ ] Scan dependencies, secrets, licenses and artifacts; produce content-addressed packages and signed release evidence where supported.
- [ ] Validate permission manifests, compatibility, test fixtures, setup/rollback behavior and declared external side effects.
- [ ] Reject packages requiring uncontrolled credentials, unrestricted egress, unsafe privilege or undeclared sensitive-data access.
- [ ] Define version pinning, revocation, rollback, vulnerability disclosure and customer notification for compromised or materially changed packages.
- [ ] Make execution an explicit customer-side or separately governed runtime action; never execute untrusted submissions inside the marketplace control plane.
- [ ] Test prompt injection, malicious packages, SSRF/egress abuse, secret exfiltration, resource exhaustion and cross-tenant isolation.

## Phase 11 — Specialist Supplier Directory

- [ ] Define supplier profiles, service taxonomies, service regions, capacity, evidence expiry, insurance/licensing where relevant and accessible dispute/contact workflows.
- [ ] Separate identity checks, business registration checks, certification validation, references, skills assessments and observed delivery outcomes.
- [ ] Record evidence source, reviewer, timestamp, expiry and revocation; support correction/appeal and audit history.
- [ ] Ranking is transparent, relevance-based and protected against paid-placement conflicts, review manipulation, retaliation and self-preferencing.
- [ ] Collect only necessary personal data, define retention/access controls and complete privacy/legal review before external onboarding.

## Phase 12 — Lead qualification and supplier trust operations

**Status: NOT COMPLETE.** Start with consent-aware discovery and qualified leads; lead monetization must remain distinct from product GMV and implementation revenue.

- [ ] Collect explicit buyer requirements and lawful/transparent consent before sharing contact or business data with suppliers.
- [ ] Define lead ownership, attribution, deduplication, qualification evidence, expiry, dispute/refund rules for lead credits and auditable delivery records.
- [ ] Add fraud, spam, resale and duplicate-lead controls plus supplier response-SLA tracking and buyer feedback moderation.
- [ ] Restrict access to buyer data by purpose, tenant and retention policy; log access and support deletion/objection workflows where applicable.
- [ ] Disclose paid placement and lead-credit commercial terms; payment or subscription must never imply supplier verification.
- [ ] Test unauthorized disclosure, repeated lead delivery, fraudulent leads, supplier conflicts and refund/dispute outcomes.

## Phase 13 — Outcome-Based AI Implementation Marketplace

- [ ] Require scoped statements of work with baseline, measurement method, success metric, exclusions, dependencies, acceptance window, deliverables and change-control rules.
- [ ] Define outcome attribution and dispute review before payment milestones; protect both parties from metrics that either side can unilaterally manipulate.
- [ ] Use staged milestones and evidence-backed acceptance; no outcome guarantee without substantiation and enforceable contractual terms.
- [ ] Keep funds flow, refunds, chargebacks, seller payout and tax accounting within reviewed provider/legal constraints; do not market an escrow service unless licensed and actually implemented.
- [ ] Test scope changes, failed acceptance, partial delivery, buyer/supplier disputes, cancellation and data access termination.

## Phase 14 — Project delivery, milestones and disputes

**Status: NOT COMPLETE.** This phase requires structured contracts and auditable delivery/acceptance before enabling any milestone fund movement.

- [ ] Model proposals, versioned statements of work, deliverables, milestones, acceptance windows, dependencies, customer prerequisites and change requests.
- [ ] Define measurable acceptance criteria, baseline/measurement method, evidence requirements, exclusions, service boundaries and support obligations per package.
- [ ] Implement milestone submission, buyer acceptance/rejection, reminders, partial delivery, cancellation, change control and escalation with immutable audit evidence.
- [ ] Separate objective technical acceptance from subjective business-outcome attribution; no party may unilaterally rewrite the agreed measurement.
- [ ] Define dispute intake, evidence access, independent review, reason-coded decisions, appeals and refund/chargeback coordination.
- [ ] Keep provider execution and fund movement disabled until payment, ledger, refunds, chargebacks and seller eligibility cover every supported transition.
- [ ] Test acceptance timeout, scope changes, failed delivery, partial completion, disputes, cancellation, replay and concurrent decisions.

## Phase 15 — Trust, safety, legal and compliance

- [ ] Maintain policy taxonomy, prohibited/restricted categories, content moderation, abuse reporting, sanctions/fraud controls where applicable and documented escalation.
- [ ] Operationalize IP complaints/takedowns, counter-notices where applicable, evidence preservation and repeat-infringer handling with legal review.
- [ ] Maintain data inventory, processing purposes, retention/deletion, access requests, incident notification and vendor/subprocessor registers.
- [ ] Review obligations per launch jurisdiction before marketing availability; avoid claims of certification or compliance without independent evidence.
- [ ] Track policy exceptions with owner, reason, expiry, compensating controls and an auditable renewal/revocation path.

## Phase 16 — Durable jobs, events and operational resilience

- [ ] Define environments, network boundaries, identity, secret management, least-privilege deployment roles and immutable release promotion.
- [ ] Establish SLOs/SLIs, trace propagation, privacy-safe telemetry, alert ownership, on-call escalation and service runbooks.
- [ ] Test queue backpressure, retry limits, dead-letter handling, replay safety, graceful degradation and dependency outages.
- [ ] Validate capacity, database indexes, connection pooling, caching invalidation, CDN behavior and cost ceilings under representative load.
- [ ] Complete backup restoration, disaster recovery, regional outage, key rotation and compromised credential drills with evidence.

### Durable workflow requirements

- [ ] Implement transactional outbox/inbox patterns where cross-system delivery must not be lost between database commit and event publication.
- [ ] Use durable queues and idempotent handlers with bounded retries/backoff, dead-letter queues, safe replay, cancellation and concurrency controls.
- [ ] Cover artifact scanning/builds, listing revalidation, supplier evidence expiry, lead workflows, project reminders, webhook reconciliation, notifications and reporting.
- [ ] Test delayed/duplicate events, worker crashes, queue backpressure, poison messages, partial outages and replay without duplicate financial effects.

- [ ] Exercise incident, payment-provider outage, delayed webhook, duplicate event and financial reconciliation playbooks.

## Phase 17 — Security engineering and comprehensive verification

- [ ] Establish a risk-based test pyramid with unit, contract, integration, database/RLS, browser E2E, accessibility, load, chaos and security regression tests.
- [ ] Add property/invariant tests for order totals, ledger balancing, entitlement transitions, artifact integrity, seller isolation and idempotency.
- [ ] Run concurrency/race tests and failure injection for checkout, webhook processing, refunds, downloads, moderation and payout state.
- [ ] Maintain coverage by critical business invariant and risk; code-coverage percentages alone are not acceptance evidence.
- [ ] Verify test isolation, deterministic fixtures, migration-from-empty behavior and rollback compatibility on every relevant change.

### Security baseline requirements

- [ ] Map application security controls to a pinned, reviewed version of OWASP ASVS (stable v5.0.0 at roadmap publication) and the applicable OWASP Top 10 edition; record scope and exceptions.
- [ ] Run SAST, software-composition/dependency, license and secret scans; add DAST/container checks where applicable and produce SBOM/provenance for release artifacts.
- [ ] Harden CI supply chain: least-privilege workflow permissions, protected environments, and third-party Actions pinned to verified full commit SHAs or an approved immutable dependency-lock mechanism.
- [ ] Test SSRF and egress controls, CSP/security headers, session/cookie hardening, rate limits/bot abuse, log redaction, artifact integrity and tenant isolation.
- [ ] Complete independent penetration testing and vulnerability-disclosure handling before launch; no unresolved critical/high finding without an approved, time-bounded exception.
- [ ] Complete manual keyboard/screen-reader accessibility review against WCAG 2.2 AA; automated accessibility scans alone are insufficient.

## Phase 18 — Controlled vertical pilots and product-factory expansion

- [ ] Validate demand and willingness to pay separately for digital products, automations, specialist suppliers and outcome-based implementation.
- [ ] Launch by controlled cohort and jurisdiction; define activation, conversion, refund, dispute, reliability and support guardrails before ramping.
- [ ] Confirm supply quality, buyer trust, catalogue depth and support capacity before opening each vertical.
- [ ] Record experiment hypotheses, cohorts, metrics, stop conditions and decision outcomes; do not infer product-market fit from traffic alone.
- [ ] Maintain rollback, customer communication and data export/deletion procedures during staged launch.

### Staged pilot and release gates

- [ ] Pilot the core product marketplace first, then a small reviewed automation cohort, then a non-transactional supplier/qualified-lead cohort, then outcome-based implementation packages only after milestone/dispute/payment controls pass.
- [ ] For each cohort define jurisdiction, target segment, activation/conversion/refund/dispute/reliability/support guardrails, stop conditions, owner and rollback plan.
- [ ] Expand the canonical product inventory only in the approved tier order and only when each release has rights, tests, compatibility, security evidence, documentation, support ownership and an immutable artifact.
- [ ] Record hypotheses, cohort metrics and decisions; do not infer product-market fit from traffic or waitlist counts alone.

## Phase 19 — Marketplace intelligence and growth

- [ ] Prioritize product additions using evidence of demand, competitive alternatives, implementation/support cost, gross margin and strategic differentiation.
- [ ] Maintain search relevance, structured metadata, compatibility facets, version/deprecation state, recommendation explanations and abuse resistance.
- [ ] Build catalogue analytics with privacy-safe aggregation and seller/buyer access boundaries.
- [ ] Expand only when product release gates and maintenance ownership are sustainable; avoid quantity targets that dilute quality.
- [ ] Reassess low-performing, vulnerable, unsupported or legally risky products for remediation, delisting or retirement.

### Growth, ecosystem and API requirements

- [ ] Build consent-based lifecycle messaging, referral/affiliate attribution, partner onboarding and seller enablement with fraud controls.
- [ ] Ensure paid placements and affiliate relationships are clearly disclosed and do not override trust/safety or evidence requirements.
- [ ] Provide versioned APIs/webhooks with scoped tokens, rate limits, replay protection, audit logs and compatibility commitments.
- [ ] Enable white-label/mobile/community extensions only after tenant isolation, support, privacy and upgrade paths are proven.
- [ ] Track sustainable unit economics, retention, quality and customer outcomes—not vanity metrics alone.

### Intelligence safeguards

- [ ] Use privacy-safe aggregation and enforce seller/buyer access boundaries for catalogue analytics and recommendations.
- [ ] Explain material ranking/recommendation signals, protect against abuse and manipulation, and keep paid placements/affiliate relationships clearly disclosed.
- [ ] AI-assisted metadata, documentation and support drafts require source evidence checks, human review, evaluation, cost/privacy controls, consent/opt-outs and kill switches.

## Phase 20 — Global scale and enterprise operations

- [ ] Validate multi-currency pricing, locale/timezone behavior, regional tax/payment support, data residency and localization before each market launch.
- [ ] Establish enterprise tenant controls, SSO/SCIM where justified, delegated administration, audit export, retention policies and contractual SLAs.
- [ ] Prove horizontal scale, disaster recovery, regional failover, migration safety, performance and cost governance against explicit targets.
- [ ] Maintain independent security/compliance evidence, supplier risk management, incident communications and annual control reviews.
- [ ] Operate a formal product lifecycle review for launch, expansion, suspension and retirement in each jurisdiction.

## Cross-phase serial execution protocol

1. Work only on the earliest phase whose dependencies are satisfied; later-phase work remains blocked until the current phase is audited and merged.
2. For each phase: inspect current code and schema; research relevant standards and vendor docs; define acceptance criteria; implement the smallest complete vertical slice; add adversarial tests; run exact-head CI; inspect the diff and test evidence; update the phase audit record.
3. A phase is complete only when all required checks pass on the exact commit, its security/business invariants are tested, docs agree with code, and known limits are explicit.
4. A green workflow is necessary but not sufficient for production readiness. Production, legal, provider, security and human operational gates require their own evidence.
5. If a blocker cannot be fixed safely within the available permissions or environment, record the exact blocker and stop at that gate; never fabricate a green result or silently skip phases.
6. Security assurance should use a pinned, stable verification baseline (for example, OWASP ASVS 5.0.0); accessibility targets WCAG 2.2 AA; artifact build provenance should follow an appropriate SLSA provenance format where applicable; Supabase exposed tables require explicit grants, RLS policies, and positive/negative database tests. Revalidate standards versions at implementation time.
