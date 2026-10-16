# Phase 5F — support notification outbox (implementation candidate)

**Status: IMPLEMENTED ON BRANCH; CI AND FORENSIC REVIEW PENDING.** This record is not a Phase 5 exit pass or proof that production email delivery is configured.

## Delivered in this candidate

- A database trigger enqueues one requester notification and one operations notification for every support-case event in the same transaction as the append-only event.
- The outbox contains only case/event references, event-time status, recipient kind, worker state, attempt count, lease, and safe error codes. It does not copy descriptions, private notes, payment details, credentials, or arbitrary recipient addresses.
- Service-only claim/finish RPCs use bounded batches, row-lock skipping, a ten-minute lease, a five-attempt ceiling, exponential retry backoff, and a request-ID lease check.
- Delivery failures create an audit event. The worker sends short text-only messages through Resend, resolves requester addresses from Supabase Auth by the stored user ID, and uses deployment configuration for the operations address.
- The internal worker endpoint requires a 32-character-or-longer bearer token, uses a 3-job batch, returns no-store responses, and exposes only generic delivery error codes.
- A GitHub Actions scheduled workflow is configured to invoke the worker every 15 minutes, avoiding the Vercel Hobby plan's cron-frequency limitation. Scheduled workflows run only from the default branch, and the repository secret must be configured before delivery can work. This declaration alone does not prove the production token, sender domain, Resend key, operations mailbox, Supabase service key, cron execution, or alerting are configured.

## Required runtime configuration

- `SUPPORT_NOTIFICATION_WORKER_TOKEN` or `CRON_SECRET` — high-entropy secret, at least 32 characters.
- `RESEND_API_KEY` — restricted transactional-send key.
- `SUPPORT_FROM_EMAIL` — verified sender identity on a controlled domain.
- `SUPPORT_OPERATIONS_EMAIL` — staffed support mailbox.
- `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_SUPABASE_URL`, and `SUPABASE_SECRET_KEY`.

No secrets are committed. The worker fails closed if required configuration is absent.

## Verification still required

- [ ] Exact-head Foundation CI and Security/dependency governance pass.
- [ ] Review the migration, SQL tests, route authorization, retry semantics, and notification privacy.
- [ ] Exercise clean delivery, provider rejection, network timeout, missing requester email, lease expiry, duplicate invocation, exhausted retries, and completion-RPC failure.
- [ ] Configure production secrets and verify the sender domain and operations mailbox.
- [ ] Verify actual scheduled invocations, alerting for retryable/blocked jobs, and a human escalation owner/rota.
- [ ] Approve retention/deletion policy for notification metadata and delivery evidence.
- [ ] Verify production deployment and perform a controlled end-to-end smoke test using an approved test mailbox.

## Delivery semantics and limits

Delivery is at-least-once: a provider may accept an email while the worker loses the response, so a retry can duplicate a notification. The notification deliberately contains no case description or admin note. No automatic SLA deadline is assigned because legal/policy approval and support ownership are not yet evidenced. This worker is not an incident paging service and does not satisfy backup restoration, break-glass, financial dispute/chargeback, payout-hold, or dual-approval gates.

**Phase 5 overall remains incomplete until the remaining code, exact-head CI, production configuration, human operational ownership, and legal/policy gates are independently verified.**
