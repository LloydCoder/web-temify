# Phase 5J forensic audit — payment-dispute deadline alerting

**Disposition:** Implementation candidate. Exact-head Foundation CI, security/dependency governance, and review are required before merge. This is not a Phase 5 exit pass or proof that production alert delivery is configured.

## Delivered in this candidate

- A private, RLS-enabled alert outbox for payment-dispute evidence deadlines.
- A bounded scan that enqueues alerts for open or evidence-needed disputes whose deadlines are within 48 hours, distinguishing due-soon from overdue alerts.
- A unique key on dispute, alert kind, and deadline snapshot so repeated scans do not create duplicate jobs for the same deadline.
- Service-only claim and finish RPCs with a maximum batch size of three, row locking with skip-locked semantics, ten-minute leases, request-ID ownership, bounded attempts, exponential retry, and terminal blocked state.
- A bearer-token-protected Node.js worker that sends a minimal alert to a configured operations mailbox through Resend. It does not include buyer identity, case descriptions, payment credentials, or raw provider payloads.
- A GitHub Actions workflow scheduled every 15 minutes, with manual dispatch for controlled smoke tests.
- SQL tests for table privacy, least privilege, idempotent enqueue, claim/lease ownership, retries, successful completion, and failure audit evidence; route tests cover authorization, configuration, minimal payload, provider failure, and persistence failure.

## Security and correctness boundaries

- The database RPC accepts only the existing dispute record and stored deadline; it does not infer provider deadlines from untrusted client input.
- Alerts do not change dispute state, upload or submit evidence, issue refunds, post journal entries, or release/hold provider funds.
- The worker requires a dedicated repository secret PAYMENT_DISPUTE_ALERT_WORKER_TOKEN (at least 32 characters), NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SECRET_KEY, RESEND_API_KEY, SUPPORT_FROM_EMAIL, DISPUTE_OPERATIONS_EMAIL, and NEXT_PUBLIC_SITE_URL.
- The workflow runs only from the default branch. A merged workflow declaration does not prove the repository secret exists or that the schedule has executed successfully.
- Email delivery is at-least-once. If Resend accepts a message but persistence of the completion fails, the job may retry and duplicate the notification.
- Blocked jobs are durable records, but this workflow does not independently page an operator if the email provider, scheduler, application, or Supabase is unavailable.

## Required verification before merge

- [ ] Exact-head Foundation CI passes, including empty-database migration reset, schema lint, pgTAP/RLS, E2E, typecheck, lint, format, and production build.
- [ ] Exact-head security/dependency governance passes.
- [ ] SQL function signatures, grants, retries, and audit writes are reviewed against the actual migration chain.
- [ ] Route tests pass without external network calls.

## Operational gates still required after merge

- [ ] Configure and validate the dedicated worker secret and production environment variables.
- [ ] Verify the sender identity and operations mailbox, then manually dispatch and inspect a controlled delivery.
- [ ] Confirm scheduled execution and define a separate alert path for failed schedules, blocked jobs, and worker outages.
- [ ] Name a staffed dispute escalation owner and backup; approve evidence-retention and response policies.
- [ ] Integrate provider-specific signature verification, event mapping, evidence upload/submission, and provider sandbox fixtures before enabling any provider.
- [ ] Keep payout execution, journal adjustment posting, and all live money movement disabled until their independent accounting/provider/legal gates pass.

**Gate decision:** This candidate adds a durable notification mechanism for dispute deadlines. It does not complete Phase 5 overall or establish production operational readiness.
