# Phase 4D2 Settlement Exception Queue — Slice Audit

**Disposition: PARTIAL — not a Phase 4D2 completion record.**

This audit covers the bounded administrative exception queue and immutable triage-action surface. It does not certify settlement reconciliation, financial posting, provider integration, or production readiness.

## Security and accounting invariants

- The queue RPC is executable only by `service_role`; it independently checks the supplied principal against the database-owned admin role before returning exception data.
- Queue reads are bounded to 1–51 rows. Cursor parameters must be complete, row identifiers are length-bounded, and the exclusive descending `(created_at, run_id, row_id)` cursor prevents repeating the page boundary.
- Gross, fee, and net minor units are returned as decimal text, avoiding unsafe JavaScript integer conversion.
- The server-rendered page calls `getAdminContext`, which validates the authenticated principal and admin role and fails closed if the access audit cannot be persisted.
- The decision endpoint requires same-origin JSON, caps the request body, validates the run UUID and strict decision schema, and only permits an evidence digest for `accepted_with_evidence`.
- A pre-mutation audit event records the requested triage action. The database decision RPC enforces the independent-admin rule and immutable decision history. A triage decision does not alter the reconciliation result or authorize financial posting.
- Unauthenticated browser coverage verifies that the admin queue and decision mutation endpoint do not disclose protected operations.

## Files in scope

- `supabase/migrations/20261014020000_phase4d2_exception_queue.sql`
- `supabase/tests/phase4d2_settlement_imports.test.sql`
- `src/app/admin/settlements/page.tsx`
- `src/app/admin/settlements/SettlementExceptionDecisionForm.tsx`
- `src/app/api/admin/settlements/[runId]/decision/route.ts`
- `src/server/commerce/settlement-exception-decision.ts` and its unit tests
- `tests/e2e/admin-access.spec.ts`
- `docs/commerce/phase4d2-settlement-reconciliation.md`
- `docs/roadmap/phase-gates.md`

## Explicitly open blockers

1. Cryptographic authentication of actual settlement-source files or authenticated provider downloads. The existing source-authentication field is not cryptographic proof.
2. Actual evidence storage, controlled evidence retrieval, retention/deletion policy, and evidence access audit.
3. Refund matching and broader adversarial reconciliation fixtures, including duplicate posted references, amount mismatches, timezone edges, fee-only rows, unexplained adjustments, concurrent retries, and partial-import rollback.
4. Source-specific settlement/fee posting guards and accounting-policy approval. No settlement/fee journal posting, payout execution, or exception auto-resolution is enabled by this slice.
5. Escalation/expiry policy, operational ownership, provider selection/onboarding evidence, and supported-jurisdiction review.
6. Final exact-head CI, security-scan, diff, and forensic review for the PR that carries this audit. Results from earlier SHAs must not be treated as validation of a later head.

**Exit rule:** keep Phase 4D2 unchecked until the code, database invariants, adversarial tests, external provider evidence, operational controls, and exact-head CI all agree.
