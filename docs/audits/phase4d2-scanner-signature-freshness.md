# Phase 4D2 scanner-signature freshness — implementation audit

**Disposition:** Implementation candidate; exact-head CI and production scanner operations must be verified before merge/activation. This slice does not close Phase 4D2.

## Scope

- Preserve scanner attestations as immutable audit evidence while recording the timestamp of the scanner's signature database.
- Enforce freshness when private evidence is linked to a settlement import and again at provider-fee journal posting, so a once-fresh link cannot authorize a later posting after its scanner definitions age.
- Fail closed when ClamAV's version response lacks a parseable signature-database timestamp.

## Changes

- Migration `20261015100000_phase4d2_scanner_signature_freshness.sql` adds `signature_updated_at`, updates the service-only attestation RPC, and replaces the evidence-link and financial-journal guards.
- The ClamAV gateway parses the timestamp from `VERSION`, returns it alongside the scan verdict, and rejects missing, invalid, or implausibly future-dated timestamps.
- The upload-side scanner client validates timestamp format and passes it to the service-only database RPC.
- The database retains stale scan attestations but requires the latest digest-matched clean scan to have signature definitions updated within 48 hours; timestamps more than five minutes in the future are not accepted.
- The malware-gate pgTAP suite covers stale-signature denial and fresh-rescan recovery; gateway tests cover parsing and missing-timestamp fail-closed behavior.

## Security invariants

1. A recent scan event is not sufficient when the scanner signature database itself is stale.
2. A stale or infected latest attestation cannot authorize a new evidence link or a provider-fee journal posting.
3. A fresh scan can restore eligibility without mutating earlier scan records or the evidence object.
4. Evidence digest equality remains required; the signature timestamp does not establish provider origin.
5. This does not enable live provider ingress, settlement/payout posting, or money movement.

## Remaining gates

- Exact-head Foundation CI and Security/dependency governance.
- Production scanner deployment, HTTPS endpoint and secret provisioning, signature freshness monitoring/alerting, and live smoke tests.
- Provider-authenticated ingress, provider settlement/payout posting, concurrent-race integration tests, retention-worker operational verification/alerting, escalation/expiry, external provider onboarding, and legal/jurisdiction approval.

Do not claim Phase 4D2 complete until all code, operational, provider, legal, and exact-head verification gates are satisfied.
