# Phase 4D1 — refund reversals after proceeds allocation

## Status

**Complete for tested sandbox-only scope; not production financial readiness.** PR [#27](https://github.com/LloydCoder/web-temify/pull/27), implementation head `a5182c8f6258e525059a5e960a472f00e419a943`, passed [Foundation CI run 38522581791](https://github.com/LloydCoder/web-temify/actions/runs/38522581791) and [Security/dependency governance run 38522581805](https://github.com/LloydCoder/web-temify/actions/runs/38522581805). The forensic audit and residual gates are recorded in `docs/roadmap/phase-gates.md`. Do not enable live-provider processing.

## Scope

When seller proceeds have already been allocated, a verified refund must not be posted against the unallocated-order liability alone. The workflow creates an independently reviewed reversal of the original item-level allocations before the verified refund outflow can post.

## Database controls

- refund_reversal_requests records the refund, order, amount, currency, reason, evidence digest, requester and decision history.
- refund_reversal_lines links each line to the original order item, seller and fee schedule; gross refund must equal commission reversal plus seller-payable reversal plus tax reversal.
- Request and line evidence is immutable; lines are append-only.
- Approval and rejection are narrowly granted server RPCs. service_role cannot directly update request state.
- A rejected request remains immutable, but a new request can be submitted and audited. At most one active request exists per refund; a posted reversal cannot be repeated.
- The reversal journal must match approved item-level lines and verified provider-event evidence; seller-payable debits must match each original seller, not merely the aggregate amount. The same guard hardens proceeds-allocation journals with per-seller checks. The refund outflow journal is blocked unless the reversal journal is already posted.
- Cumulative gross, commission, seller-payable and order-tax reversal caps are checked against original allocations. Commission reversal uses cumulative rounding so splitting a refund cannot silently under-reverse commission minor units.

## State and accounting order

1. Record a pending refund and an immutable reversal request with item-level lines.
2. A distinct database-owned admin approves or rejects the request.
3. On a cryptographically verified refund-success event, the processor validates matching refund/order/attempt/amount/currency/provider evidence.
4. The system posts a balanced reversal journal that debits seller payable, platform revenue and recorded tax liability as applicable, and credits unallocated order liability.
5. Only after that reversal is posted can the verified refund outflow journal debit unallocated order liability and credit provider clearing.
6. The processor then advances refund/order state and records processed event evidence. Duplicate event handling remains governed by the Phase 4B idempotent processor.

## Verification expectations

- Fresh-database migration reset and schema lint.
- pgTAP tests for role/function grants, independent approval/rejection, line arithmetic, cumulative commission rounding, cumulative over-refund rejection, retry after rejection, verified event matching, balanced journal ordering, wrong-seller attribution rejection and duplicate/idempotency behavior.
- Typecheck, lint, format, Playwright and production build.
- High/critical dependency audit, production license policy and full-history secret scan.
- Forensic review of the exact PR diff and workflow evidence: PASS on implementation head `a5182c8f6258e525059a5e960a472f00e419a943`; Foundation CI and Security/dependency governance passed on that exact head.

## Explicit non-claims

This subphase does **not** add a live payment provider, provider settlement reconciliation, seller payout, provider-fee posting, tax/VAT calculation, chargeback/dispute handling, reserve management, manual-adjustment execution or escrow. The provider events in tests are sandbox fixtures. Phase 4 and production launch readiness remain incomplete.


## Forensic audit result

- **Disposition:** PASS for the sandbox/test database workflow only.
- **Implementation head:** `a5182c8f6258e525059a5e960a472f00e419a943`.
- **Foundation CI:** [38522581791](https://github.com/LloydCoder/web-temify/actions/runs/38522581791) passed migration reset, schema lint, 215 pgTAP assertions, Playwright E2E, production build and cleanup.
- **Security/dependency governance:** [38522581805](https://github.com/LloydCoder/web-temify/actions/runs/38522581805) passed on the same head.
- **Corrections found during CI:** refund fixtures now begin in `requested`; the over-allocation fixture respects the remaining order balance while testing an excessive item-level reversal; its failed state releases the reserved balance; the pgTAP plan is 215 and matches the assertions.
- **Residual boundary:** no live provider, settlement reconciliation, payouts, tax/VAT calculation, chargebacks, reserves, manual adjustments, escrow or production-launch approval.
