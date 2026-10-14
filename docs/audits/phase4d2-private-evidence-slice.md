# Phase 4D2 Private Settlement Evidence — Slice Audit

**Disposition: IMPLEMENTED ON BRANCH; awaiting exact-head CI and review. Not a Phase 4D2 completion record.**

## Scope delivered

- Private Supabase Storage bucket `settlement-evidence`, capped at 5 MiB and restricted to a small allowlist of report media types.
- Server-only, admin-authorized upload route with same-origin check, streamed byte cap (including chunked bodies without a declared length), server-computed SHA-256, sanitized filename, immutable object path, and pre-mutation audit event.
- Immutable database metadata with RLS enabled, no authenticated-client access, and no service-role update/delete grants.
- Admin-only download route that audits access, fetches from private storage, verifies byte count and SHA-256 against immutable metadata, fails closed on integrity mismatch, and serves only as an attachment with `application/octet-stream`, `nosniff`, and `no-store`.
- Unit tests for bounded byte reads and pgTAP checks for bucket privacy, size limit, RLS, grants, and metadata immutability.

## Security properties and non-claims

- The SHA-256 digest identifies the uploaded bytes; it does not prove the provider created the file or that the report is authentic.
- Uploading is restricted to an already authenticated marketplace admin; no public upload endpoint or signed upload URL is created.
- The file is not parsed or executed by the app and is returned as an attachment. Malware scanning and semantic report validation are not implemented in this slice.
- The `retention_until` value is a policy target only. No scheduled deletion or retention enforcement is implemented; metadata is intentionally immutable until a separately reviewed retention workflow exists.
- Evidence metadata is not yet bound to a settlement import/reconciliation run by this route. That association must be an explicit, audited operation and must not be inferred from a filename or client-supplied digest.
- Provider-specific API signature validation, authenticated report download, settlement/fee journal posting, payouts, and exception auto-resolution remain disabled.

## Exact verification required

- [ ] Empty-database `supabase db reset` passes with this migration.
- [ ] `supabase db lint --local` passes.
- [ ] Full pgTAP/RLS suite passes, including `phase4d2_private_settlement_evidence.test.sql`.
- [ ] Foundation tests, typecheck, lint, format, Playwright, and production build pass on the same PR head.
- [ ] Security/dependency/license/secret scans pass on the same PR head.
- [ ] Review upload cleanup behavior, audit failure paths, storage quotas, rate limiting, and operational retention policy.

## Residual Phase 4D2 blockers

1. Provider-authenticated ingress and source-specific cryptographic verification.
2. Evidence-to-import/reconciliation linkage and explicit operator workflow.
3. Automated retention/deletion, malware scanning, and evidence access/retention governance.
4. Refund matching and broader adversarial reconciliation tests.
5. Balanced, idempotent, source-specific settlement and fee journal posting.
6. Escalation/expiry, ownership, provider onboarding, supported-jurisdiction evidence, and final external financial-policy approval.

**Exit rule:** keep Phase 4D2 unchecked until these residual requirements, exact-head CI, and independent forensic review are complete. No live provider processing or money movement is enabled by this slice.
