# Testing strategy

## Test pyramid
1. Static checks: formatting, lint, strict TypeScript, dependency/secret scanning.
2. Unit: domain policy, pricing, state transitions, validation, feature-flag defaults.
3. Integration: PostgreSQL constraints, RLS, auth, storage authorization, provider adapters.
4. Contract: webhook fixtures, API schemas, Tinlance event compatibility, provider sandbox.
5. End-to-end: browse → account → sandbox checkout → verified event → entitlement → authorized download, including denial cases.
6. Security: IDOR, role escalation, replay, amount/currency mismatch, races, revoked entitlements, prompt injection, malicious uploads.
7. Operational: migration rehearsal, backup/restore, rollback/forward-fix, rate limits, alerting, incident runbook.

## Required principles
- Test both allowed and denied outcomes.
- Keep tests deterministic; no real payments/AI calls except explicitly approved sandbox jobs.
- Use synthetic fixtures, not production personal data.
- Unit tests do not establish RLS/provider/deployment/production readiness.
- Preserve CI output, test reports, commit SHA, environment, and reviewer decisions.
- Fail closed on critical missing configuration; health endpoints must not leak secrets.

## Phase 1 baseline
Foundation structure validator and Node built-in tests. Next: generate and commit a lockfile in a controlled environment, run lint/typecheck/build, and wire results into required PR checks.