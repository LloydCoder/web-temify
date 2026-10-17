# Phase 5F — support notification outbox

**Status: MERGED; implementation and exact-head CI passed; operational delivery remains unverified.** PR [#77](https://github.com/LloydCoder/web-temify/pull/77) merged as `04e4cb86841bba5e51fae3746649d4583351243f`. Foundation CI [passed](https://github.com/LloydCoder/web-temify/actions/runs/38968988453) and Security/dependency governance [passed](https://github.com/LloydCoder/web-temify/actions/runs/38968988465) on exact PR head `4d35488bd93780adf7bc22b4b9455ca968e57bb7`. The Vercel preview status failed because of the team's deployment/build rate limit, not a test failure. The scheduled delivery workflow later failed before dispatch because `SUPPORT_NOTIFICATION_WORKER_TOKEN` was absent ([run 39000635593](https://github.com/LloydCoder/web-temify/actions/runs/39000635593)). This is not a Phase 5 exit pass or proof that production email delivery is configured.

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

- [x] Exact-head Foundation CI and Security/dependency governance passed on PR #77.
- [x] Review the migration, SQL tests, route authorization, retry semantics, and notification privacy.
- [ ] Exercise clean delivery, provider rejection, network timeout, missing requester email, lease expiry, duplicate invocation, exhausted retries, and completion-RPC failure.
- [ ] Configure production secrets and verify the sender domain and operations mailbox.
- [ ] Verify actual scheduled invocations, alerting for retryable/blocked jobs, and a human escalation owner/rota.
- [ ] Approve retention/deletion policy for notification metadata and delivery evidence.
- [ ] Verify production deployment and perform a controlled end-to-end smoke test using an approved test mailbox.

## Delivery semantics and limits

Delivery is at-least-once: a provider may accept an email while the worker loses the response, so a retry can duplicate a notification. The notification deliberately contains no case description or admin note. No automatic SLA deadline is assigned because legal/policy approval and support ownership are not yet evidenced. This worker is not an incident paging service and does not satisfy backup restoration, break-glass, financial dispute/chargeback, payout-hold, or dual-approval gates.

**Phase 5 overall remains incomplete until the remaining code, exact-head CI, production configuration, human operational ownership, and legal/policy gates are independently verified.**
