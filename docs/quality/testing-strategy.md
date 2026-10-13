# Testing strategy

## Test pyramid
1. Static checks: formatting, lint, strict TypeScript, dependency advisories and secret scanning.
2. Unit: domain policy, pricing, state transitions, validation, feature-flag defaults and lifecycle contracts.
3. Integration: PostgreSQL constraints, RLS, auth, storage authorization and provider adapters.
4. Contract: webhook fixtures, API schemas, Tinlance event compatibility and provider sandbox behavior.
5. End-to-end: browse → account → sandbox checkout → verified event → entitlement → authorized download, including denial cases.
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
- Phase 2 migration, identity/RLS tests, homepage E2E and foundation checks passed in CI run 38364828400.
- The lockfile is committed and the web platform CI uses frozen-lockfile installation.
- The dedicated product-source monorepo is being bootstrapped independently; its catalogue validator must not promote planned entries to released products.

## Phase 3 additions
- SQL migration replay from an empty database.
- Rights evidence is private; creators may submit declarations but cannot self-approve.
- Public catalogue query is restricted to published, rights-verified products with artifact SHA-256 evidence.
- Product versions are visible publicly only when released with artifact digest and release timestamp.
- Shared Zod contracts reject invalid lifecycle values, unverified catalogue items and malformed artifact digests.
- Playwright validates the catalogue empty state and prevents unreleased slugs from being presented as live.

## Release evidence
Every phase audit must record the exact commit SHA, CI run and job conclusions, migration result, test counts, E2E results, code/document paths reviewed, security invariants, unresolved risks and explicit exit-gate disposition. If any mandatory check is absent, skipped, inconclusive or run against a different SHA, the phase remains open.
