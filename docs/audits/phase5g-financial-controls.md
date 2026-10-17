# Phase 5G — financial control requests and payout holds

**Status: MERGED; database/API/UI code and CI passed; operational and accounting gates remain open.** PR [#78](https://github.com/LloydCoder/web-temify/pull/78) merged as `aee85f43e64676666b509d70bb12c523f7a0b093`; Foundation CI [passed](https://github.com/LloydCoder/web-temify/actions/runs/38971016846) and Security/dependency governance [passed](https://github.com/LloydCoder/web-temify/actions/runs/38971016857) on its exact implementation head. PR [#79](https://github.com/LloydCoder/web-temify/pull/79) added the restricted financial-controls API/UI and merged as `da12595799edc7d003f0dc90bed5ec29c68eb80b`; Foundation CI [passed](https://github.com/LloydCoder/web-temify/actions/runs/38973476047) and Security/dependency governance [passed](https://github.com/LloydCoder/web-temify/actions/runs/38973476065) on exact head `0f65229c27252e78cc1bb72f3da05c4f65081028`. The Vercel preview was not verified because of the team's deployment/build rate limit. These controls are not authorization to move money or enable payouts.

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

- [x] Foundation CI: migration reset, schema lint, pgTAP/RLS, E2E, formatting, typecheck, lint, and production build passed on exact PR head `89633d471eb7003f579cf732544b1231c1c1fe11`.
- [x] Security/dependency governance passed on the same exact PR head.
- [ ] Adversarial tests for concurrent idempotent creates, duplicate approvers, rejection after one approval, repeated hold-release attempts, incorrect seller/order links, negative-balance drift, and audit rollback.
- [x] Add the restricted financial-controls API/UI for request and approval workflows in PR #79. Private evidence-object storage/content verification and a complete operational evidence display remain open.
- [ ] Keep live payout execution disabled until the payout service enforces active holds and checks available seller payable against the journal.
- [ ] Implement the separate provider-authenticated chargeback/dispute lifecycle and evidence intake.
- [ ] Approve financial adjustment policy, retention, approval thresholds, staffing, and incident response.

**Phase 5 remains incomplete.** The maker-checker request workflow and restricted UI are merged, but approved manual adjustments do not post journal entries, no payout service enforces active holds, private evidence storage/verification is absent, and provider-authenticated chargeback/dispute handling and operational/legal approvals remain open.
