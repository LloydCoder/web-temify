# Phase 4D2 evidence-retention worker — forensic slice audit

**Disposition:** Implementation candidate only; exact-head CI and production operations are not yet verified. This slice does not close Phase 4D2.

## Scope inspected

- Existing immutable evidence metadata and private Storage bucket in `20261014040000_phase4d2_private_settlement_evidence.sql`.
- Evidence-to-import binding and independent-review constraints in `20261014050000_phase4d2_evidence_import_linkage.sql`.
- Latest malware attestation/link gate in `20261014140000_phase4d2_evidence_malware_gate.sql`.
- Admin evidence upload/download routes and service-side scanner integration.
- Existing migration, roadmap, and acceptance-gate documentation.

## Implementation

- `20261014150000_phase4d2_evidence_retention_worker.sql` adds a service-only retention work queue and claim/finish RPCs.
- `src/app/api/internal/settlements/evidence-retention/route.ts` implements a bearer-token-protected, maximum-25-item worker invocation using the server-only Supabase secret key.
- `src/app/api/admin/settlements/evidence/[evidenceId]/route.ts` rejects download after a deletion tombstone, during active deletion, or when the job is blocked.
- `supabase/tests/phase4d2_evidence_retention.test.sql` adds pgTAP coverage for privilege boundaries, eligibility, audit, tombstones, retry ceilings, and blocked work.
- `src/app/api/internal/settlements/evidence-retention/route.test.ts` tests authentication, bounded processing, deletion success/failure, already-absent object recovery, database failure, malformed claim data, and completion persistence failure.
- `.env.example`, migration documentation, the settlement contract, phase gate, and master roadmap record the operating boundary.

## Invariants enforced

1. Only objects past `retention_until` with no evidence-to-import link are eligible for deletion.
2. Linked financial evidence is preserved until an approved legal/accounting retention policy explicitly governs it.
3. A metadata row lock and `SKIP LOCKED` prevent competing workers from claiming the same object. A 15-minute lease permits recovery after a crashed worker.
4. A retention claim and an evidence-link attempt serialize on the immutable metadata row. New links are rejected after expiry or after a retention claim; the existing clean-scan and independent-admin checks remain in force.
5. The worker deletes private object bytes only. It preserves immutable evidence metadata, scan attestations, evidence links, and audit history.
6. Completion is bound to the latest claim request ID so a stale worker cannot overwrite a newer worker's outcome.
7. Removal errors trigger a storage-list check so an already-absent object can be finalized idempotently. Other failures retry up to five attempts; exhausted or crashed leases are blocked for operator review.
8. The download endpoint returns a tombstone-aware response rather than attempting to read deleted bytes.

## Deliberate exclusions and remaining gates

- No linked settlement evidence is automatically deleted; legal/accounting policy and any required holds have not been approved.
- `vercel.json` declares a daily 03:15 UTC Vercel Cron schedule, but the production deployment does not provision `CRON_SECRET` or `SETTLEMENT_EVIDENCE_RETENTION_TOKEN` from this repository. The worker is not operational until the deployment, secret, least-privilege runtime configuration, smoke test, and alerting are verified.
- Blocked jobs require an operational queue/runbook and a human disposition; this slice records the blocked state but does not send alerts.
- Provider-authenticated ingress, provider settlement/payout posting, true concurrent integration tests, operational escalation/expiry, scanner signature freshness monitoring, external provider onboarding, and jurisdiction approval remain open.
- No live-provider processing, payout, escrow, or money movement is enabled.

## Verification required before merge

- Exact-head Foundation CI: fresh database reset, schema lint, all pgTAP/RLS tests, unit/foundation tests, typecheck, lint/format, Playwright and production build.
- Exact-head Security/dependency governance: dependency audit, production license policy, full-history secret scan.
- Review the migration and route diff against the current main head and reconcile any changed upstream functions before merge.
