# Phase 5I forensic audit — verified payment-dispute state machine

**Disposition:** PASS for the database state-machine and exact-head CI scope only. PR [#81](https://github.com/LloydCoder/web-temify/pull/81) merged as `3005da1a7c0f64b2b02af2c58dc3e85781894e19`. This is not a Phase 5 exit pass or production provider approval.

## Implemented boundary

- Private `payment_disputes` records are linked to order, payment attempt, provider dispute ID, amount/currency and evidence deadline/status metadata.
- The service-only RPC requires an existing `payment_webhook_events` record with `signature_verified = true`, matching provider event ID/type, order and payment attempt, and an inbox status of `processing` or `processed`; a merely received/unclaimed event cannot mutate disputes. The payment attempt provider, currency and maximum amount are checked.
- State transitions are constrained to opened, needs evidence, evidence submitted, won/lost and closed; final outcomes cannot be rewritten, while a final won/lost result can be closed with a separate verified event.
- A provider webhook event may be applied only once. Exact replay returns the existing dispute as duplicate; conflicting reuse is rejected.
- Event history is append-only, tables have RLS and no customer grants, and each applied event creates an audit event with payload digest and request trace.
- pgTAP covers authorization, RLS, idempotency, mismatch rejection, financial bounds, lifecycle transitions, terminal behavior and append-only history.

## Explicit non-claims

- The RPC trusts the server's persisted `signature_verified` result; it does not itself verify provider signatures.
- No production provider adapter currently calls this RPC. The existing webhook route is sandbox-only.
- Evidence files are not uploaded, scanned, retained, or submitted to a provider by this migration.
- No deadline scheduler, escalation notification, refund/journal posting, payout-hold enforcement, or production incident workflow is added.
- Provider-specific event mappings and signed sandbox fixtures must be implemented for the selected provider before enabling the workflow.

## Required verification

- [x] Empty-database migration reset and schema lint passed in Foundation CI on exact PR head `4cfc60a05d9c28b1c201937bba9700e1a19991f9` ([run 38979078356](https://github.com/LloydCoder/web-temify/actions/runs/38979078356)).
- [x] Forensic hardening: reject verified but unclaimed webhook inbox events; tests explicitly cover the `received`-state rejection.
- [x] pgTAP/RLS test suite passed in Foundation CI on the exact PR head.
- [x] Typecheck, lint, formatting, E2E, true two-session settlement concurrency test, and production build passed in Foundation CI on the exact PR head.
- [x] Security/dependency governance passed on the exact PR head ([run 38979078315](https://github.com/LloydCoder/web-temify/actions/runs/38979078315)).
- [ ] Provider-specific signature fixtures and sandbox integration tests.
- [ ] Production evidence retention, deadline monitoring, policy and staffing approval.

**Gate decision:** Phase 5I passes for the private database state-machine and CI scope. Provider-specific webhook signature verification/mapping, evidence submission, deadline monitoring, payout enforcement, policy approval, and operational ownership remain open. Phase 5 overall remains incomplete.
