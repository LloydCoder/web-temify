# Security baseline

This is a minimum engineering baseline, not proof that the application is secure or certified.

## Identity and authorization
- Authenticate and authorize server-side for every protected action; hidden UI/client role flags are not controls.
- Deny by default and check permissions at object level.
- Use PostgreSQL RLS as defense in depth; keep service-role keys server-only and out of ordinary user-request paths.
- Admin actions require least privilege and audit records.

## Input/output
- Validate external input at boundaries.
- Treat uploads, archives, user HTML, AI output, webhooks, and integration events as untrusted.
- Escape output and deploy a restrictive content security policy.
- Never execute uploaded product code in the web process or shared privileged environment.

## Secrets
- Commit placeholders only; use managed secrets in CI/hosting and rotate exposed keys.
- Do not log authorization headers, tokens, signed URLs, secrets, or unnecessary personal/payment data.
- Public env variables must be intentionally public.

## Catalogue publication and release integrity
- Creator rights statements are declarations, not independent verification.
- Only trusted review/release paths may set rights-review state, reviewer metadata, artifact digests, or release state.
- Public catalogue rows require publication, an independently reviewed rights attestation, and a matching released artifact digest.
- Rights evidence, release manifests, and private artifact storage paths are not anonymously selectable.
- Product documentation/demo links are constrained to HTTPS URLs.

## Commerce and delivery
- Verify webhook signatures against the provider-required raw body.
- Enforce idempotency, concurrency control, amount/currency/order matching, and replay resistance.
- Maintain reconcilable financial records and explicit refunds/chargebacks.
- Store paid artifacts privately and issue short-lived URLs after server-side entitlement checks.
- Keep payment methods, seller payouts, subscriptions, and crypto disabled until implementation, security, and legal reviews pass.

## Supply chain and operations
- Commit a lockfile and review dependency advisories.
- Pin GitHub Actions to reviewed immutable SHAs before production hardening.
- Never expose deployment secrets to untrusted PR code.
- Separate development, preview/staging, and production credentials.
- Maintain incident response, key rotation, backup/restore, and vulnerability disclosure procedures before launch.
- Do not claim SOC 2, PCI DSS, GDPR compliance, or certification without evidence-backed assessment.