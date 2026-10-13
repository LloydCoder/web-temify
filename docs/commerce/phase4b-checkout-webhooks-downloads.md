# Phase 4B — checkout, verified events, refunds, and secure downloads

## Scope and status

This phase adds server-side workflow primitives on top of the Phase 4A database invariants. It is not a live payment launch. The only implemented payment adapter is a deliberately restricted sandbox and it returns HTTP 503 in production. PAYMENT_PROVIDER defaults to disabled.

## Local environment

Copy .env.example to an untracked .env.local. For local development only, set PAYMENT_PROVIDER=sandbox and PAYMENT_WEBHOOK_SECRET to a random value of at least 32 characters. Configure the local Supabase URL, publishable key, server-only SUPABASE_SECRET_KEY, and WEB_TEMIFY_ARTIFACT_BUCKET=products-private for a private bucket provisioned separately.

Never put server-only keys in a NEXT_PUBLIC variable, browser bundle, Git commit, log, or issue. The example file contains no usable secret.

## Endpoints

### POST /api/checkout

Requires an authenticated customer. Accepts a list of productVersionId/quantity pairs and an idempotencyKey. The database RPC locks the customer/idempotency pair, derives prices and release snapshots from canonical rows, rejects mixed currencies, unavailable or unverified releases, duplicate version IDs, and zero-value checkout, and creates the order plus item snapshots atomically. The route creates or reuses a sandbox payment attempt. The returned completeEndpoint is a development-only test harness, not a checkout page or real payment method.

### POST /api/checkout/sandbox/complete

Requires the authenticated owner of the order and a sandbox payment attempt. It creates a deterministic signed sandbox success event and runs the same durable event processor as the webhook route. It is disabled in production.

### POST /api/webhooks/payments

Accepts only the sandbox protocol while non-production PAYMENT_PROVIDER=sandbox. It reads the raw request body through a streaming byte-limited reader (64 KiB maximum) before parsing, and verifies the event ID, Unix timestamp within 300 seconds, and v1 HMAC-SHA256 signature over eventId.timestamp.rawBody. The checkout, sandbox-completion, refund, download-grant and download JSON endpoints also use a 32 KiB streaming request-body limit; body size is checked while reading rather than after unbounded buffering. The event ID must match the payload ID. Strict schemas reject unsupported fields. The inbox stores only a SHA-256 payload digest, never the raw payload. Identical replays are idempotent; reusing an event ID with a different digest returns 409. Failed processing returns 503 so the sender can retry.

Production provider adapters must implement that provider's official signature scheme against the unmodified raw body. This sandbox protocol is not compatible with Paystack, Stripe, or other providers.

### POST /api/refunds

Requires the authenticated owner of a paid or partially refunded order. Creates an idempotent refund request only. A 202 response with moneyMoved=false does not mean a refund was approved or settled. Provider execution, privileged approval, chargeback handling, and financial reconciliation remain disabled until later phases.

### POST /api/downloads/grants

Requires an authenticated customer and an entitlement ID. The authenticated RLS read establishes ownership; the service-only `issue_download_grant` RPC rechecks the paid or partially refunded order, active entitlement, verified product rights, released artifact digest, and storage path under row locks. It reuses a still-valid grant or issues a grant expiring within 14 minutes with a maximum of three consumptions. No storage path or signed URL is returned.

### POST /api/downloads

Requires an authenticated customer and a grant ID. It checks grant ownership and the current released artifact digest; creates a 60-second signed URL in the configured private bucket; then atomically consumes the grant through the authenticated RPC, which locks the order before the entitlement/grant and rechecks the current state. The URL is returned only after successful consumption with no-store and no-referrer headers. URLs are bearer credentials and remain valid until expiry; keep TTL short and do not log or cache them. Partial refunds preserve access to active entitlements because refunds are not yet mapped to individual order items. A full refund revokes the order's entitlements and outstanding grants.

## Database invariants

Migration 20261013030000_phase4b_checkout_webhooks.sql provides:

- create_order_for_checkout: service-role-only atomic order/item creation with server-derived price and idempotency validation.
- Financial webhook columns to validate event amount, currency, and provider reference.
- process_payment_webhook_event: service-role-only, row-locked, idempotent state processor. It checks event/attempt/order/refund/amount/currency evidence, posts a unique ledger transfer, transitions the order, and creates entitlements within one transaction. Failed processing leaves a retryable failed inbox row; raw provider payloads are not retained.
- Trigger-level checks that a processed event has matching attempt/refund and ledger evidence.

## Explicit launch blockers

- No live provider adapter is enabled or selected.
- No tax/VAT calculation is implemented; order tax is currently zero and must not be represented as a tax quote.
- Free/zero-value checkout is unsupported.
- No seller payout, commission, provider settlement, refund execution, chargeback, or manual financial adjustment flow is enabled. Partial refunds are order-level goodwill refunds, not item-specific refunds; full refunds revoke all order entitlements.
- The private bucket must be provisioned as private in the actual Supabase project; local schema CI does not prove production bucket configuration.
- Supabase signed URLs cannot be revoked immediately once issued; the implemented TTL is 60 seconds, but it remains a bearer URL until expiry.
- Production secrets, live provider eligibility, end-to-end provider sandbox account verification, formal security review, penetration testing, and legal/tax review remain release gates.

## Verification

The phase gate is only complete when new unit and pgTAP assertions pass along with frozen install, typecheck, lint, empty-database migration reset, Supabase schema lint, database/RLS tests, Playwright, and production build on one commit SHA, followed by a documented forensic audit. A green test run does not approve a production payment integration.
