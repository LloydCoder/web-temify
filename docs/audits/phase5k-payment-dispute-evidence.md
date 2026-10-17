# Phase 5K forensic audit — private payment-dispute evidence

**Disposition:** Implementation candidate. Exact-head Foundation CI, Security/dependency governance, and review are required before merge. This slice does not complete Phase 5 or authorize provider evidence submission or live financial actions.

## Implemented in this candidate

- A private payment-dispute-evidence Supabase Storage bucket with a 5 MiB limit and an explicit content-type allowlist.
- Admin-only, same-origin, bounded upload at POST /api/admin/payment-disputes/:disputeId/evidence.
- Database-owned checks that the dispute exists and is still open or needs evidence; terminal disputes reject new uploads.
- Server-computed SHA-256 and a storage path bound to dispute ID, evidence ID, and digest.
- Immutable evidence metadata and immutable scanner attestations, with service-role-only RPCs, RLS enabled, no direct client table grants, and transactional audit events.
- Reuse of the existing private ClamAV scanner client, including digest agreement, HTTPS requirements in production, bounded timeout, scanner version, and signature freshness checks.
- Audited admin access that asks a database RPC to verify the evidence/dispute pair and latest clean, digest-matched, fresh scan before issuing a 60-second signed URL with no-store response headers.
- Fail-closed behavior: scanner unavailable or not configured leaves evidence pending; infected evidence returns a rejected verdict; a digest mismatch or failed scan-attestation persistence returns an error and never reports clean.
- No default retention deadline. retention_until stays null until the approved legal retention policy is recorded.

## Security and correctness limits

- A digest proves byte identity, not source authenticity or provider acceptance.
- This route does not download evidence back to a user, submit it to a provider, change dispute state, issue refunds, post journals, or move funds.
- Provider-specific signature verification/event mapping and signed sandbox fixtures remain required for the selected provider.
- Automated dispute-evidence retention/deletion is not implemented; legal policy and an independently tested worker are required before retention can be operationally claimed.
- Production ClamAV endpoint/token configuration and clean/infected/stale smoke tests remain external deployment gates.

## Verification

- [ ] Exact-head Foundation CI passes, including migration reset, schema lint, pgTAP/RLS, route tests, E2E, typecheck, lint, format, and production build.
- [ ] Exact-head Security/dependency governance passes.
- [ ] Review the migration/RPC grants, storage path/digest invariants, request bounds, same-origin/admin authorization, scanner freshness and failure paths.
- [ ] Verify the preview deployment for the exact PR head; a Vercel rate-limit failure is not a successful preview.

**Gate decision:** This is a private evidence-custody and scanning slice only. Phase 5 remains incomplete until provider integration, evidence submission, payout enforcement, reviewed accounting policy, worker secrets and delivery, legal/retention approval, named operational ownership, incident response, and repository protection are evidenced.
