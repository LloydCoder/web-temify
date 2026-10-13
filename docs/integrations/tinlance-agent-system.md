# Tinlance Agent System integration contract — draft

**State: disabled/design-only.** This document does not imply a working connection, credentials, or runtime capability.

## Potential initial use cases
Read-only engineering analysis; artifact scan/build preparation in isolated sandbox; draft listings held for human review; internal support summaries with data minimization.

## Prohibited without separate approval and proof
Direct database mutation; payment/refund/payout changes; license or role changes; unreviewed publication; autonomous customer contact; production deployment/config changes; broad secret access.

## Contract requirements
Versioned HTTPS API or signed event envelope; authenticated service identity and scoped capabilities; tenant/actor context; request/correlation IDs; idempotency key; timestamps/expiry; explicit action and schemas; payload limits; policy/approval decision; immutable execution evidence; timeouts/retries/rate limits/budgets/cancellation/kill switch; replay protection; signature rotation; redaction; tests for allowed and denied actions.

## Rollout
Design and threat-model; stub adapter and contract tests; read-only sandbox; approved low-risk tasks; write-capable actions only after separate review and explicit authorization.