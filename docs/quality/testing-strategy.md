# Testing strategy

## Test pyramid

1. Static checks: formatting, lint, strict TypeScript, dependency advisories and secret scanning.
2. Unit: domain policy, pricing, state transitions, validation, feature-flag defaults and lifecycle contracts.
3. Integration: PostgreSQL constraints, RLS, auth, storage authorization and provider adapters.
4. Contract: webhook fixtures, API schemas, Tinlance event compatibility and provider sandbox behavior.
5. End-to-end: browse â†’ account â†’ sandbox checkout â†’ verified event â†’ entitlement â†’ authorized download, including denial cases.
6. Security: IDOR, role escalation, replay, amount/currency mismatch, races, revoked entitlements, prompt injection and malicious uploads.
7. Operational: migration rehearsal, backup/restore, rollback/forward-fix, rate limits, alerting and incident runbook.

## Required principles

- Test both allowed and denied outcomes.
- Keep tests deterministic; no real payments/AI calls except explicitly approved sandbox jobs.
- Use synthetic fixtures, not production personal data.
- Unit tests do not establish RLS/provider/deployment/production readiness.
- Preserve CI output, test reports, commit SHA, environment and reviewer decisions.
- Fail closed on critical missing configuration; health endpoints must not leak secrets.
- CI green means all configured gates passed for that commit; it does not imply an independent security certification or production approval.

## Existing evidence

- Phase 2 migration, ident¶»§q«^