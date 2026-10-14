# Phase 4D1 — refund reversals after proceeds allocation

## Status

**Implementation under review. Not yet a completed phase gate.** Track the change in [PR #27](https://github.com/LloydCoder/web-temify/pull/27). Do not enable live-provider processing or treat the implementation as production financial readiness before exact-head Foundation CI, Security/dependency governance, forensic review and merge.

## Scope

When seller proceeds have already been allocated, a verified refund must not be posted against the unallocated-order liability alone. The workflow creates an independently reviewed reversal of the original item-level allocations before the verified refund outflow can post.

## Database controls

- refund_reversal_requests records the refund, order, amount, currency, reason, evidence digest, requester and decision history.
- refund_reversal_lines links each line to the original order item, seller and fee schedule; gross refund must equal commission reversal plus seller-payable reversal plus tax reversal.
- Request and line evidence is immutable; lines are append-only.
- Approval and rejection are narrowly granted server RPCs. service_role cannot directly update request state.
- A rejected request remains immutable, but a new request can be submitted and audited. At most one active request exists per refund; a posted reversal cannot be repeated.
- The reversal journal must match approved item-level lines and verified provider-event evidence. The refund outflow journal is blocked unless the reversal journal is already posted.
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
- pgTAP tests for role/function grants, independent approval/rejection, line arithmetic, cumulative commission rounding, cumulative over-refund rejection, retry after rejection, verified event matching, balanced journal ordering and duplicate/idempotency behavior.
- Typecheck, lint, format, Playwright and production build.
- High/critical dependency audit, production license policy and full-history secret scan.
- Forensic review of the exact PR diff and workflow evidence before merge.

## Explicit non-claims

This subphase does **not** add a live payment provider, provider settlement reconciliation, seller payout, provider-fee posting, tax/VAT calculation, chargeback/dispute handling, reserve management, manual-adjustment execution or escrow. The provider events in tests are sandbox fixtures. Phase 4 and production launch readiness remain incomplete.
