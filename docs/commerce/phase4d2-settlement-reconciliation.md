# Phase 4D2 — provider-neutral settlement import contract

## Status

**In progress — immutable import evidence and a first reconciliation snapshot are implemented in the open draft PR; settlement/fee journal posting, operator exception decisions, trusted-source ingress, and external provider evidence remain incomplete.** Do not enable live-provider processing or claim Phase 4D2 complete.

## Research basis

The contract is intentionally normalized rather than provider-report-specific. Adyen's official settlement-details documentation describes transaction-level settlement records and distinct transaction, fee, correction, and payout entries. Its fee-reconciliation guidance warns that report periods and time zones must align. These facts inform the explicit report period, timezone, row type, references, amounts, and exception fields here:

- [Adyen — Settlement details report](https://docs.adyen.com/reporting/settlement-reconciliation/transaction-level/settlement-details-report/)
- [Adyen — Reconcile fees](https://docs.adyen.com/classic-platforms/reconciliation-use-cases/understand-fees)

This is design research, not evidence that Web-Temify has selected, onboarded, or integrated Adyen or any other provider.

## Implemented in this slice

- SettlementImportSchema pins the contract to version 1.0, currently allowing `paystack`, `polar`, and `sandbox` as settlement-source identifiers; it requires a SHA-256 digest, a source-authentication assertion, an account/report reference, a declared period and timezone, and bounded row count. This import allowlist does not enable an adapter: the existing payment-attempt, webhook, and journal provider constraints still need a separately reviewed migration before any Polar payment or journal-posting flow can exist.
- Migration `20261013037000_phase4d2_settlement_imports.sql` adds server-only report and normalized-row persistence, RLS-deny-by-default tables, immutable evidence triggers, restricted service-role import RPC, report identity/digest uniqueness, and deterministic identical-replay/conflicting-evidence handling. A follow-on slice adds one immutable reconciliation run per import, immutable row-level results, distinct-admin review, idempotent reconciliation retries, and fail-closed matching against already-posted payment/refund journal batches. pgTAP covers persistence, privilege boundaries, replay, and the no-match exception path.
- Rows have stable identifiers, an explicit row type, optional provider/internal payment references, an offset-aware timestamp, currency, gross/fee/net minor-unit values, and a bounded exception taxonomy.
- Validation rejects unknown keys, duplicate row IDs within a report, currency mismatch, rows outside the declared period, inverted periods, invalid source digests, positive-gross refunds, non-positive-gross payments, and positive-net fee rows.
- Contract tests cover valid reports and the adversarial boundary cases above.

## Critical trust boundary

sourceAuthenticated=true is a trusted-ingress assertion, **not cryptographic verification**. A future server-side import route must authenticate the operator, authenticate the source file or API response, calculate the digest from the exact bytes received, enforce byte/row limits, persist immutable import evidence, and record who/what verified it. Clients must never be allowed to set this assertion and then trigger posting.

Contract validation does not prove that netMinor = grossMinor - feeMinor: settlement semantics vary by row type and provider. It does not perform FX conversion. Version 1 requires one currency per report and per row; multi-currency reports must be split or rejected until an explicit FX-aware contract is reviewed. Values are integer minor units, never floating-point decimal amounts.

## Required next work before Phase 4D2 can pass

1. Authenticate the actual source at trusted ingress, calculate `source_sha256` from the exact received bytes, validate the timezone and report metadata before invoking the service-only RPC, and bind the authenticated operations actor to the request. The database boolean is only an assertion and is not cryptographic proof.
2. Extend the initial payment/refund match snapshot with complete verified-journal linkage and adversarial fixtures for matched payments/refunds, duplicate references, cross-currency and amount mismatches, timezone edges, fee-only rows, and unexplained adjustments. Current reconciliation records missing matches and unsupported row types. A separate triage decision can require reimport, request manual review, or record an evidence digest for independent review; it does not resolve the accounting exception, change the reconciliation result, or authorize journal posting. Never auto-resolve an exception.
3. Implement source-specific posting guards for provider settlement and provider fees. Require balanced same-currency entries, evidence linkage, row-level reconciliation, and idempotency; keep money movement and payout execution disabled.
4. Extend pgTAP and application tests for concurrent duplicate imports/reconciliation, partial-import rollback, matched and missing/mismatched references, period/timezone edges, fee-only rows, refunds, unsupported adjustments, journal imbalance, privilege denial, and retry behavior. Current tests cover import replay and the initial missing-match reconciliation path only.
5. Build a bounded admin exception queue/UI over the immutable triage records, evidence access controls, decision history, escalation/expiry policy, and any required second approval. The current database slice persists triage decisions but provides no admin queue UI and does not resolve/post exceptions.
6. Run empty-database migration reset, schema lint, full database/RLS tests, foundation/domain tests, typecheck, lint, format, Playwright, production build, security/dependency/license/secret scans, and an exact-head forensic review.
7. Record provider selection, supported jurisdictions/currencies, fees, dispute/refund behavior, settlement report semantics, and onboarding evidence separately. Until those are verified, all live-provider processing remains disabled.

## Acceptance rule

Do not check off the Phase 4D2 gate until implementation, adversarial tests, documentation, exact-head CI, forensic review, and external evidence agree. Passing the schema tests for this contract alone is not a settlement reconciliation approval.
