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

## Catalogue data minimization
- `products` uses column-level `SELECT` grants for anonymous and authenticated API roles; do not restore table-wide `SELECT`.
- Creator account IDs, rights declarations, reviewer IDs/timestamps, rights review state, and artifact digests are not client-readable. Row-level security controls which product rows are visible; UI filters are not authorization.

## RLS helper-function discipline
- When table-wide `SELECT` is intentionally denied, policy subqueries must not depend on callers having that table privilege. Use narrowly scoped `SECURITY DEFINER` boolean predicates only where necessary, with an empty/fixed `search_path`, explicit execute grants, and no returned row data.
- Keep ownership helpers non-disclosing: return only whether the current authenticated principal owns the target object, never whether another principal owns it or any internal metadata.
