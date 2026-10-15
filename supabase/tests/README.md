Database tests must run against local Supabase/PostgreSQL and cover anonymous access, authenticated owner, non-owner, privileged server operations, and storage policy behavior. No schema/RLS tests are considered passed until executable SQL tests are present and run.

Phase 4D2 settlement tests:

- `phase4d2_settlement_imports.test.sql` — 127 assertions (current test plan: `select plan(127)`) covering import idempotency, exact payment matching, currency/amount/duplicate-reference exceptions, explicit exception preservation, timezone boundaries, atomic rollback, unmatched refunds, fee-only rows, and adjustment exceptions.
- `phase4d2_private_settlement_evidence.test.sql` — private bucket, 5 MiB cap, RLS, grants, and immutable evidence metadata.
- `phase4d2_evidence_import_linkage.test.sql` — guarded RPC privileges, digest equality, idempotent replay, independent reviewer requirements, immutable linkage, and atomic audit persistence.

These tests verify only the sandbox/provider-neutral data and control-plane behavior. They do not establish provider-authenticated ingress, matched-refund correctness, production retention/deletion, malware scanning, or approval for live financial posting.

Phase 5D support-case workflow:

- `phase5d_support_cases.test.sql` — support-case grants/RLS, idempotent create/replay, conflicting idempotency-key rejection, administrator-only state transitions, assignment, terminal timestamps, append-only event history, and audit evidence.

Outbound notifications, automated SLA escalation, and a staffed on-call rota are not implemented by this workflow and remain operational gates.
