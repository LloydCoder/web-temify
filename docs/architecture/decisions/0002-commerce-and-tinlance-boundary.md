# ADR-0002: Web-Temify retains commerce authority; Tinlance is a governed executor

- **Status:** Accepted
- **Date:** 2026-10-13

Web-Temify remains authoritative for catalogue, orders, payments, refunds, licenses, entitlements, customer permissions, vendor and payout state. Tinlance retains agent identity, policy, approvals, runtime, tools, budgets, and execution evidence. Communication uses authenticated, versioned APIs/events.

Integration stays disabled by default. Require idempotency, correlation IDs, scoped capabilities, audit records, kill switches, and sandbox-first rollout. No direct agent database access or autonomous financial actions.
