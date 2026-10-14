# Phase 4C — immutable financial journal and proceeds allocation

## Scope and disposition

**Disposition: PASS for the accounting-journal and seller-proceeds-allocation primitives only.** This is not a live-payment, payout, settlement, tax, escrow, or production-launch approval.

Implementation is in migration `supabase/migrations/20261013035000_phase4c_financial_journal.sql`, with pgTAP coverage integrated into `supabase/tests/phase4_commerce.test.sql`.

## Implemented invariants

- A server-only financial journal stores immutable batches and append-only entries. Batches can transition only from draft to posted; posting requires at least two same-currency entries with equal debit and credit totals.
- Payment and refund journal batches must match an existing immutable ledger transaction, the corresponding signed/verified event assertion, provider, provider reference, amount, currency, and SHA-256 payload digest. Arbitrary balanced payment/refund postings are rejected.
- The only currently enabled posting sources are verified payment, verified refund before proceeds allocation, and proceeds allocation. Settlement, provider fees, chargebacks, reserves and manual adjustments remain explicitly blocked until dedicated workflows are implemented.
- Verified payments debit provider clearing and credit unallocated-order liability. Verified refunds reverse that unallocated liability and credit provider clearing. Refund posting still fails closed after proceeds have been allocated until Phase 4D1 is reviewed, CI-verified and merged; PR #27 is implementing the reversal workflow, but it does not enable live-provider money movement.
- Seller fee schedules start pending. Activation requires a database-owned admin role and an approver different from the seller. Revocation requires a separate admin actor and preserves the original approval evidence. Commercial terms are immutable after creation.
- Proceeds allocation is idempotent by order, idempotency key and evidence digest. Every order item must have a current independently approved seller fee schedule. Integer basis-point arithmetic determines the platform fee and seller net.
- Allocation posting reconciles gross item totals to the immutable order subtotal and records seller payable, platform commission and any already-recorded order tax liability in a balanced batch. This does not calculate tax; the current order tax remains zero unless a future reviewed tax implementation supplies it.
- RLS is enabled and public/anonymous/authenticated roles have no table privileges. The allocation function is executable only by the trusted server role. Append-only triggers prevent editing or deleting posted journal evidence.

## Verification evidence

- **PR:** [#24 — feat(commerce): add immutable financial journal and proceeds allocation](https://github.com/LloydCoder/web-temify/pull/24)
- **Reviewed implementation head:** `3e5e438af23ef6dadb0e54443609507ab14b35dd`
- **Merged commit:** `ed9f1d461c3f7fab2d47f5624cbbee4483c3baa7`
- **Foundation CI:** [run 38515752985](https://github.com/LloydCoder/web-temify/actions/runs/38515752985) — passed on the exact reviewed head. This includes frozen install, foundation tests, typecheck, lint, format check, empty-database migration reset, schema lint, pgTAP/RLS tests, Playwright, production build and cleanup.
- **Security/dependency governance:** [run 38515753014](https://github.com/LloydCoder/web-temify/actions/runs/38515753014) — passed on the exact reviewed head, including high/critical dependency audit, production license policy and full-history secret scanning.
- **Database tests:** 169 pgTAP assertions in the commerce test file pass, including verified payment/refund journal evidence, balanced entries, allocation arithmetic, idempotency, role checks, immutable history, and rejection of unverified or unsupported financial posting sources.

## Explicit residual gates

- No live provider adapter, provider-account eligibility check, settlement reconciliation, provider fee posting, seller payout, chargeback handling, manual-adjustment workflow or reserve workflow. Phase 4D1 reversal code remains under review until exact-head CI and forensic gates pass.
- No tax/VAT calculator; the journal can record an order tax liability already present in the immutable order snapshot but does not calculate or quote tax.
- No production Supabase/Vercel configuration, real provider settlement proof, legal/tax review, formal penetration test, or full WCAG 2.2 AA assessment is implied by these passing tests.
- The sandbox adapter remains non-production only. Do not advertise escrow, live payouts, tax calculation, or production financial readiness.

## Next serial gate

Phase 4D1 is currently under review for evidence-backed refund reversals after proceeds allocation. Subsequent sub-gates must implement settlement reconciliation, chargeback/dispute, reserve and dual-approval financial-adjustment state machines while keeping unsupported money movement fail-closed. Phase 4 remains in progress until all Phase 4 exit criteria and external provider/business gates are evidenced.
