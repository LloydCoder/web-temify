# Admin operations console (Phase 5A)

## Scope

The initial operations console is deliberately read-only. It presents counts for catalogue records, pending product review, orders, paid orders, failed payment-webhook events and refund records, plus the latest 20 audit events. It does not publish products, alter orders, execute refunds, change roles, issue downloads, or call the Tinlance Agent System.

## Authorization boundary

- The page is a server component and is force-dynamic.
- The shared server-only authorization helper calls Supabase Auth `getUser()`, then the database-owned `current_user_has_role('admin')` function using the authenticated session.
- A privileged Supabase client is constructed only after the role check succeeds.
- Missing configuration, unauthenticated requests, role lookup failures, and non-admin users fail closed with a not-found response.
- Administrative console access is appended to `audit_events` before the privileged view is served. If that audit insert fails, the console is denied.
- The dashboard selects only action/entity/request identifiers and timestamps from audit events; it does not render arbitrary metadata or raw database errors.

## Audit integrity

The canonical Phase 2 migration restricts audit-event insertion to the trusted service role and does not grant update/delete privileges. The Phase 5A pgTAP suite asserts those privileges, RLS, and the role-check function behavior for customer and administrator identities.

## Independent product-rights review (Phase 5B)

The restricted `/admin/reviews` queue lists up to 50 pending rights attestations. It is available only after the same server-side identity and admin-role check as the operations console. Review decisions are submitted to a server route with strict input validation and same-origin protection, then executed by a narrow database function in one transaction.

- The creator who submitted an attestation cannot review it.
- Review decisions require a bounded reviewer note; the route accepts JSON only and enforces an 8 KiB streaming request-body limit before parsing.
- `under_review`, `verified`, and `rejected` are explicit transitions; a resolved attestation cannot be silently re-reviewed.
- Product rights state and reviewer evidence update atomically with an append-only audit event. If the audit insert fails, the transaction rolls back.
- Rights verification does not publish a product, approve its artifact, grant customer entitlements, or imply legal certainty. Publication still requires a verified release and immutable artifact evidence.

## Audit explorer (Phase 5C)

The restricted `/admin/audit` page provides cursor-based pagination and exact-match filters for action and entity type. It queries at most 51 rows to display 50 and determine whether a next page exists. The cursor is a bounded positive integer string; action/entity filters are trimmed, length-limited, and restricted to a safe token alphabet before they are passed to parameterized Supabase query filters.

- The shared server-only admin authorization helper authenticates the principal, verifies the database-owned admin role, and appends an access-audit event before the page queries privileged data.
- The view selects only event ID, action, entity type, entity ID, request ID, and timestamp. It never selects or renders the JSON metadata column.
- Query errors return a generic unavailable state; invalid filters fail closed rather than silently broadening the query.
- Supporting indexes cover exact action and entity-type filters. RLS and grants remain unchanged: anonymous and ordinary authenticated clients cannot read audit events, and history remains append-only.
- Pagination and filters are operational visibility only; this page cannot alter or delete events, execute refunds, publish products, or trigger provider actions.

## Support case workflow (Phase 5D, complete for tested workflow scope; operations remain incomplete)

The authenticated `/support` page submits cases through a bounded same-origin API. Customer case history is filtered by the authenticated user ID on the server; ordinary client roles have no direct table grants. Case creation uses a database RPC with per-requester idempotency locking and rejects reuse of a key with conflicting content.

The restricted `/admin/support` queue requires the shared audited admin context. Admin actions use a narrow database RPC that rechecks the database-owned admin role, locks the case row, enforces explicit state transitions, and atomically appends both a case event and an audit event. Assignment is limited to administrators. Case event history is append-only; terminal timestamps are set and cleared consistently on resolve, close, and reopen.

This slice does not send customer email, run scheduled SLA/escalation jobs, staff an on-call rota, or replace a formal incident-response system. The migration, pgTAP, E2E, and exact-head CI gates passed on implementation head `989969d18d95eb54d2d003800ecb33619b804012` ([Foundation CI](https://github.com/LloydCoder/web-temify/actions/runs/38574294521), [Security and dependency governance](https://github.com/LloydCoder/web-temify/actions/runs/38574294451)). Remaining operational controls are separate release gates; Phase 5 overall is still incomplete.

## Known limits

This is not a complete operations centre. Product-publication moderation beyond rights review, financial reconciliation, dispute/chargeback handling, backup restoration, incident-response automation, alert delivery, and break-glass procedures remain separate gates. A dashboard count is operational visibility, not proof of settlement or production readiness.

## Support notification outbox (Phase 5F candidate; verification pending)

Support-case event creation now has a candidate transactional outbox and a token-protected internal worker using Resend. The outbox intentionally excludes case descriptions and private notes. Delivery uses bounded batches, leases, a five-attempt ceiling, retry backoff, and audited failures. The worker resolves customer addresses from Supabase Auth by the stored requester ID; operations recipients come from server configuration.

This branch is not yet CI-verified or merged. Production delivery requires `SUPPORT_NOTIFICATION_WORKER_TOKEN` or `CRON_SECRET`, `RESEND_API_KEY`, a verified `SUPPORT_FROM_EMAIL`, a staffed `SUPPORT_OPERATIONS_EMAIL`, Supabase service credentials, a valid site URL, a verified scheduled invocation, and alerting for retryable/blocked jobs. Delivery is at-least-once and may duplicate an email if the provider accepts it but the worker loses the response. No legal SLA deadline is inferred, and an email outbox is not an incident paging service.
