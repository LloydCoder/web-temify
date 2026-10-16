# Phase 5G — financial control requests and payout holds

**Status: FOUNDATION CI AND SECURITY PASSED ON IMPLEMENTATION HEAD `8c096e0950e00c27eb0e1cf4b6cab1dbaa7cf784`; MERGE AND OPERATIONAL VERIFICATION PENDING.** Foundation CI [run 38971016846](https://github.com/LloydCoder/web-temify/actions/runs/38971016846) and Security/dependency governance [run 38971016857](https://github.com/LloydCoder/web-temify/actions/runs/38971016857) passed on the exact implementation head. This is a database workflow candidate, not an authorization to move money or enable payouts.

## Delivered in this candidate

- Server-only requests for manual adjustment review, negative-balance review, payout-hold placement, and payout-hold release.
- Maker-checker approvals: the requester cannot approve their own request, two distinct database-authorized administrators must approve, and approval evidence is append-only.
- A payout hold becomes active only after two approvals. Release requires a new request matching the active hold's seller, amount, and currency, followed by two distinct approvals.
- Negative-balance review requests must match the current posted seller-payable deficit at creation and at each approval; order-linked requests must reference an order containing an item for that seller and currency.
- Private tables, RLS, no public/authenticated table grants, service-only RPCs, immutable request identity/evidence, append-only event history, and audit events.
- Idempotent request creation is serialized by an advisory transaction lock.
- Requests may be cancelled by their maker only before review begins.

## Deliberate safety boundary

This migration does **not** post a financial journal batch, debit/credit a ledger, call a provider, execute a payout, or create a real provider chargeback. A manual adjustment that reaches `approved` is an approved request only; journal execution is not implemented here. Payout holds are internal control records, not escrow and not proof that a payout processor enforces them. Evidence digests are recorded, but private evidence-object storage, content verification, and provider-authenticated dispute ingress are separate gates.

## Verification required

- [ ] Foundation CI: migration reset, schema lint, pgTAP/RLS, E2E, formatting, typecheck, lint, and production build on exact PR head.
- [ ] Security/dependency governance on the exact PR head.
- [ ] Adversarial tests for concurrent idempotent creates, duplicate approvers, rejection after one approval, repeated hold-release attempts, incorrect seller/order links, negative-balance drift, and audit rollback.
- [ ] Add a restricted admin API/UI and operational evidence display before exposing these workflows to staff.
- [ ] Keep live payout execution disabled until the payout service enforces active holds and checks available seller payable against the journal.
- [ ] Implement the separate provider-authenticated chargeback/dispute lifecycle and evidence intake.
- [ ] Approve financial adjustment policy, retention, approval thresholds, staffing, and incident response.

**Phase 5 remains incomplete.** This candidate covers part of the maker-checker/payout-hold gate only.
