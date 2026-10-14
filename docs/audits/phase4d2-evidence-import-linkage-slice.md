# Phase 4D2 Evidence-to-Import Linkage — Slice Audit

**Disposition: IMPLEMENTED ON BRANCH; exact-head CI and independent review pending. Not a Phase 4D2 completion record.**

## Scope delivered

- Append-only `settlement_evidence_links` table with RLS enabled and no direct client/service-role table privileges.
- Service-only `link_settlement_evidence` RPC and same-origin admin route.
- Link creation requires a database-owned admin who is distinct from both the evidence uploader and the import actor.
- The evidence SHA-256 must exactly match the imported report's source SHA-256. A mismatch fails closed.
- One evidence object can be linked to at most one import. Identical replay returns the existing link id; conflicting linkage is rejected.
- Link metadata and its completion audit event are written in one database transaction.
- pgTAP coverage checks privilege boundaries, matching digest, idempotent replay, digest mismatch, independent reviewer requirements, immutable links, and atomic audit persistence.
- Playwright coverage denies unauthenticated requests to the linking endpoint.

## Security properties and non-claims

- Digest equality binds the stored object to the import's declared source digest; it does not prove provider origin or cryptographic authenticity.
- This operation does not alter immutable evidence metadata or settlement rows, resolve reconciliation exceptions, post journals, or move funds.
- No direct table insert is granted to the service role; link creation must use the guarded RPC.
- The reviewer must be distinct from both uploader and importer, even if the same person performed both operations.
- Retention/deletion enforcement, malware scanning, provider-specific source verification, and evidence retrieval/access-retention governance remain open.

## Exact verification required

- [ ] Empty-database `supabase db reset` passes with this migration.
- [ ] `supabase db lint --local` passes.
- [ ] Full pgTAP/RLS suite passes, including `phase4d2_evidence_import_linkage.test.sql`.
- [ ] Foundation tests, typecheck, lint, format, Playwright, and production build pass on the same PR head.
- [ ] Security/dependency/license/secret scans pass on the same PR head.
- [ ] Review concurrency, replay, authorization, and audit failure paths.

## Residual Phase 4D2 blockers

1. Provider-authenticated ingress and source-specific cryptographic verification.
2. Automated retention/deletion, malware scanning, and evidence access/retention governance.
3. Matched refund reconciliation and duplicate posted journal-reference fixtures.
4. Concurrency tests for import/reconciliation replay and a review of partial-import rollback under concurrent retries.
5. Balanced, idempotent, source-specific settlement and fee journal posting.
6. Escalation/expiry, operational ownership, provider onboarding, supported-jurisdiction evidence, and external financial-policy approval.

**Exit rule:** keep Phase 4D2 unchecked until these residual requirements, exact-head CI, and independent forensic review are complete. No live provider processing or money movement is enabled by this slice.
