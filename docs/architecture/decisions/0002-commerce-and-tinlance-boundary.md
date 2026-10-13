# ADR-0002: Web-Temify retains commerce authority; Tinlance is a governed executor

- **Status:** Proposed
- **Date:** 2026-10-13

## Context
Web-Temify plans to use Tinlance Agent System and other Tinlance tools for engineering and operations. Mixing agent runtime authority with marketplace commerce creates privilege and audit risks.

## Decision
Web-Temify remains authoritative for catalogue, orders, payments, refunds, licenses, entitlements, customer permissions, vendor/payout state. Tinlance retains agent identity, policy, approvals, runtime, tools, budgets, and execution evidence. Communication uses authenticated, versioned APIs/events.

## Consequences
Require stable contracts, idempotency, correlation IDs, scoped capabilities, audit records, kill switches, and a sandbox-first rollout. Integration stays disabled by default.