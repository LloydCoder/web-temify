# Phase 4D2 — provider-neutral settlement import contract

## Status

**In progress — contract validation implemented; settlement persistence, reconciliation, journal posting, operator exception handling, and external provider evidence remain incomplete.** Do not enable live-provider processing or claim Phase 4D2 complete.

## Research basis

The contract is intentionally normalized rather than provider-report-specific. Adyen's official settlement-details documentation describes transaction-level settlement records and distinct transaction, fee, correction, and payout entries. Its fee-reconciliation guidance warns that report periods and time zones must align. These facts inform the explicit report period, timezone, row type, references, amounts, and exception fields here:

- [Adyen — Settlement details report](https://docs.adyen.com/reporting/settlement-reconciliation/transaction-level/settlement-details-report/)
- [Adyen — Reconcile fees](https://docs.adyen.com/classic-platforms/reconciliation-use-cases/understand-fees)

This is design research, not evidence that Web-Temify has selected, onboarded, or integrated Adyen or any other provider.

## Implemented in this slice

- SettlementImportSchema pins the contract to version 1.0, currently allowing `paystack`, `polar`, and `sandbox` as settlement-source identifiers; it requires a SHA-256 digest, a source-authentication assertion, an account/report reference, a declared period and timezone, and bounded row count. This import allowlist does not enable an adapter: the existing payment-attempt, webhook, and journal provider constraints still need a separately reviewed migration before any Polar payment or journal-posting flow can exist.
- Migration `20261013037000_phase4d2_settlement_imports.sql` adds server-only report and normalized-row persistence, RLS-deny-by-default tables, immutable evidence triggers, restricted service-role import RPC, report identity/digest uniqueness, and deterministic identical-replay/conflicting-evidence handling. pgTAP covers the initial persistence and privilege boundary.
- Rows have stable identifiers, an explicit row type, optional provider/internal payment references, an offset-aware timestamp, currency, gross/fee/net minor-unit values, and a bounded exception taxonomy.
- Validation rejects unknown keys, duplicate row IDs within a report, currency mismatch, rows outside the declared period, inverted periods, invalid source digests, positive-gross refunds, non-positive-gross payments, and positive-net fee rows.
- Contract tests cover valid reports and the adversarial boundary cases above.

## Critical trust boundary

sourceAuthenticated=true is a trusted-ingress assertion, **not cryptographic verification**. A future server-side import route must authenticate the operator, authenticate the source file or API response, calculate the digest from the exact bytes received, enforce byte/row limits, persist immutable import evidence, and record who/what verified it. Clients must never be allowed to set this assertion and then trigger posting.

Contract validation does not prove that netMinor = grossMinor - feeMinor: settlement semantics vary by row type and provider. It does not perform FX conversion. Version 1 requires one currency per report and per row; multi-currency reports must be split or rejected until an explicit FX-aware contract is reviewed. Values are integer minor units, never floating-point decimal amounts.

## Required next work before Phase 4D2 can pass

1. Authenticate the actual source at trusted ingress, calculate `source_sha256` from the exact received bytes, validate the timezone and report metadata before invoking the service-only RPC, and bind the authenticated operations actor to the request. The database boolean is only an assertion and is not cryptographic proof.
2. Reconcile payment/refund rows against verified journal batches and provider references; quarantine missing, duplicate, cross-currency, out-of-period, amount-mismatched, and unexplained rows. Never auto-resolve an exception.
3. Implement source-specific posting guards for provider settlement and provider fees. Require balanced same-currency entries, evidence linkage, row-level reconciliation, and idempotency; keep money movement and payout execution disabled.
4. Extend pgTAP and application tests for concurrent duplicate imports, partial-import rollback, missing/mismatched references, period/timezone edges, fee-only rows, refunds, unsupported adjustments, journal imbalance, privilege denial, and retry behavior.
5. Build a bounded admin exception queue with immutable decisions and independent approval where required.
6. Run empty-database migration reset, schema lint, full database/RLS tests, foundation/domain tests, typecheck, lint, format, Playwright, production build, security/dependency/license/secret scans, and an exact-head forensic review.
7. Record provider selection, supported jurisdictions/currencies, fees, dispute/refund behavior, settlement report semantics, and onboarding evidence separately. Until those are verified, all live-provider processing remains disabled.

## Acceptance rule

Do not check off the Phase 4D2 gate until implementation, adversarial tests, documentation, exact-head CI, forensic review, and external evidence agree. Passing the schema tests for this contract alone is not a settlement reconciliation approval.
