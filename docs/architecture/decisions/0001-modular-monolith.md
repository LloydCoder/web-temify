# ADR-0001: Start with a modular monolith

- **Status:** Proposed
- **Date:** 2026-10-13

## Context
The initial product needs clear boundaries between marketplace, identity, commerce, delivery, vendors, and integrations, but there is no verified traffic or team size justifying distributed services.

## Decision
Use one Next.js TypeScript repository with explicit feature modules and contracts. Extract services only when operational, scaling, security, or independent deployment evidence justifies the cost.

## Consequences
Simpler initial delivery; modules must avoid circular dependencies and cross-domain direct writes. Long-running work can later move to a separate worker without changing domain ownership.