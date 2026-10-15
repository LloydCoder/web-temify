# Phase 4D2 scanner-signature freshness — implementation audit

**Disposition:** PASS for the scanner-signature-freshness implementation slice; NOT a Phase 4D2 completion or production activation approval. PR [#57](https://github.com/LloydCoder/web-temify/pull/57) merged as `5e0acdfc84046ee674634ade0173549bfb9f526d`; reviewed implementation head `1842f85f26b11e11ab2227ada38ed90633166fe9` passed Foundation CI run [38732109726](https://github.com/LloydCoder/web-temify/actions/runs/38732109726) and Security/dependency governance run [38732109750](https://github.com/LloydCoder/web-temify/actions/runs/38732109750). The merge commit's post-merge workflow status must be checked separately.

## Scope

- Preserve scanner attestations as immutable audit evidence while recording the timestamp of the scanner's signature database.
- Enforce freshness when private evidence is linked to a settlement import and again at provider-fee journal posting, so a once-fresh link cannot authorize a later posting after its scanner definitions age.
- Fail closed when ClamAV's version response lacks a parseable signature-database timestamp.

## Changes

- Migration `20261015100000_phase4d2_scanner_signature_freshness.sql` adds `signature_updated_at`, updates the service-only attestation RPC, and replaces the evidence-link and financial-journal guards.
- The ClamAV gateway parses the timestamp from `VERSION`, returns it alongside the scan verdict, and rejects missing, invalid, or implausibly future-dated timestamps. Its `/readyz` endpoint also fails closed when signature definitions are older than 48 hours; fresh/stale readiness behavior is covered by gateway tests.
- The upload-side scanner client validates timestamp format and passes it to the service-only database RPC.
- The database retains stale scan attestations but requires the latest digest-matched clean scan to have signature definitions updated within 48 hours; timestamps more than five minutes in the future are not accepted.
- The malware-gate pgTAP suite covers stale-signature denial and fresh-rescan recovery; gateway tests cover parsing and missing-timestamp fail-closed behavior.

## Verification and files reviewed

- Foundation CI exact-head run `38732109726` succeeded through frozen install, foundation/domain tests, typecheck, lint, format, empty-database migration reset, schema lint, database/RLS tests, Playwright E2E, production build, and cleanup.
- Security/dependency governance exact-head run `38732109750` succeeded for production dependency-license policy, high/critical dependency audit, and full-history Gitleaks scan.
- Reviewed implementation files include `supabase/migrations/20261015100000_phase4d2_scanner_signature_freshness.sql`, `supabase/tests/phase4d2_evidence_malware_gate.test.sql`, `services/settlement-scanner/server.mjs`, `services/settlement-scanner/server.test.mjs`, `src/server/commerce/settlement-evidence-scanner.ts`, `src/app/api/admin/settlements/evidence/route.ts`, and the scanner contract/roadmap/commerce documentation.

## Security invariants

1. A recent scan event is not sufficient when the scanner signature database itself is stale.
2. A stale or infected latest attestation cannot authorize a new evidence link or a provider-fee journal posting.
3. A fresh scan can restore eligibility without mutating earlier scan records or the evidence object.
4. Evidence digest equality remains required; the signature timestamp does not establish provider origin.
5. This does not enable live provider ingress, settlement/payout posting, or money movement.

## Remaining gates

- Post-merge `main` CI verification for merge commit `5e0acdfc84046ee674634ade0173549bfb9f526d`.
- Production scanner deployment, HTTPS endpoint and secret provisioning, external freshness monitoring/alerting, and live smoke tests. `/readyz` exposes stale signatures as not-ready but does not itself prove production alert delivery.
- Provider-authenticated ingress, provider settlement/payout posting, concurrent-race integration tests, retention-worker operational verification/alerting, escalation/expiry, external provider onboarding, and legal/jurisdiction approval.

Do not claim Phase 4D2 complete until all code, operational, provider, legal, and exact-head verification gates are satisfied.
