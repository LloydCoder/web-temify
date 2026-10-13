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

## Known limits

This is not a complete operations centre. Moderation decisions, support cases, financial reconciliation, dispute/chargeback handling, backup restoration, incident-response automation, alert delivery, and break-glass procedures remain separate gates. A dashboard count is operational visibility, not proof of settlement or production readiness.
