# Phase 5K forensic audit — private payment-dispute evidence

**Disposition:** MERGED in PR [#87](https://github.com/LloydCoder/web-temify/pull/87), merge commit `6c4d32eb4cc114bdd11510e10122f6e281e27d95`. Exact-head Foundation CI [run 39006812908](https://github.com/LloydCoder/web-temify/actions/runs/39006812908) and Security/dependency governance [run 39006812933](https://github.com/LloydCoder/web-temify/actions/runs/39006812933) passed on implementation head `89f5fb6fbd21afe7a98fb7a7887031b14ff9f694`. This slice does not complete Phase 5 or authorize provider evidence submission or live financial actions.

## Implemented in the merged change

- A private payment-dispute-evidence Supabase Storage bucket with a 5 MiB limit and an explicit content-type allowlist.
- Admin-only, same-origin, bounded upload at POST /api/admin/payment-disputes/:disputeId/evidence, with PDF/PNG/JPEG signatures checked and text/plain required to be valid UTF-8 without NUL bytes.
- Database-owned checks that the dispute exists and is still open or needs evidence; terminal disputes reject new uploads.
- Server-computed SHA-256 and a storage path bound to dispute ID, evidence ID, and digest.
- Immutable evidence metadata and immutable scanner attestations, with service-role-only RPCs, RLS enabled, no direct client table grants, and transactional audit events.
- Reuse of the existing private ClamAV scanner client, including digest agreement, HTTPS requirements in production, bounded timeout, scanner version, and signature freshness checks.
- Audited admin access that asks a database RPC to verify the evidence/dispute pair and latest clean, digest-matched, fresh scan before issuing a 60-second signed URL with no-store response headers; signed URLs force attachment download.
- Fail-closed behavior: scanner unavailable or not configured leaves evidence pending; infected evidence returns a rejected verdict; a digest mismatch or failed scan-attestation persistence returns an error and never reports clean.
- No default retention deadline. retention_until stays null until the approved legal retention policy is recorded.

## Security and correctness limits

- A digest proves byte identity, not source authenticity or provider acceptance.
- The upload endpoint does not submit evidence to a provider, change dispute state, issue refunds, post journals, or move funds. The separate access endpoint returns a 60-second signed URL only after the database verifies admin authorization and a current clean scan.
- Provider-specific signature verification/event mapping and signed sandbox fixtures remain required for the selected provider.
- Automated dispute-evidence retention/deletion is not implemented; legal policy and an independently tested worker are required before retention can be operationally claimed.
- Production ClamAV endpoint/token configuration and clean/infected/stale smoke tests remain external deployment gates.

## Verification

- [x] Add route tests for upload authorization, same-origin checks, terminal-dispute denial, digest mismatch, scanner unavailability/infection, upload cleanup, audited access, signed-URL expiry, and storage failure.
- [x] Add pgTAP assertions for private bucket configuration, RLS, direct-table denial, service-only RPC grants, malformed digests, and admin-role enforcement.
- [x] Exact-head Foundation CI passes, including migration reset, schema lint, pgTAP/RLS, route tests, E2E, typecheck, lint, format, and production build (run 39006812908 on the exact PR head).
- [x] Exact-head Security/dependency governance passes (run 39006812933 on the exact PR head).
- [x] Review the migration/RPC grants, storage path/digest invariants, request bounds, same-origin/admin authorization, scanner freshness and failure paths.
- [x] Verify the Vercel preview for exact PR head `5169c54e790cc398321da1c562a20d819956f811`: homepage and `/web-temify-v3.html` returned HTTP 200; unauthenticated evidence access returned 404 with `Cache-Control: no-store`.
- [ ] Verify production deployment and configure required production environment variables; Vercel's environment list is empty, and the latest production deployment is `ERROR`.

**Gate decision:** MERGED and CI-verified for private evidence custody and scanning only. Phase 5 remains incomplete until provider integration, evidence submission, payout enforcement, reviewed accounting policy, worker secrets and delivery, legal/retention approval, named operational ownership, incident response, and repository protection are evidenced.
