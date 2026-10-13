**Status:** Proposed baseline; approval and runtime verification remain required.

## Product shape
Web-Temify is a global-first digital-product marketplace and product factory. Templates, scripts, launch kits, developer tools, directory, subscriptions, APIs, AI generation, and engineering referrals are distinct capability domains, not a promise that all are in launch scope.

## Initial application shape
Start with a TypeScript modular monolith. Keep module boundaries explicit; do not introduce distributed services without measured justification.
- Web: Next.js App Router; server components by default.
- Domain/application: use-case services, input schemas, authorization, domain policies.
- Persistence: PostgreSQL through Supabase; Prisma for typed data access, pending a migration-authority decision.
- Identity: Supabase Auth with server-side session verification.
- Files: private storage for paid artifacts; short-lived signed URLs after entitlement checks.
- Payments: provider adapters; webhook events and redirects never independently grant entitlements.
- Email: Resend adapter with retry-safe delivery.
- AI: provider gateway with budgets, timeouts, safety controls, provenance, disabled-by-default rollout.
- Agents: Tinlance integration through governed APIs/events; no direct commerce database authority.
- Hosting/CI: GitHub Actions and Vercel with environment separation and least privilege.

## Trust boundaries
Browser input is untrusted. Server authorization and database RLS are defense in depth. Payment providers are asynchronous sources; webhook handling must be authenticated and idempotent. Download URLs are bearer capabilities and must be short-lived and excluded from logs. Uploaded artifacts are untrusted and must be scanned and isolated. AI output is untrusted. Tinlance agents are delegated workers, not the source of truth for commerce.

## Source of truth
Web-Temify owns catalogue, product versions, orders, payment records, refunds, licenses, entitlements, download authorization, vendor agreements/payout state, and moderation. Supabase Auth owns authentication identity; the app maps it to profile/roles. Tinlance owns agent runtime, identity, policy, approvals, tools, budgets, and execution evidence. Provider-side records reconcile against the Web-Temify ledger.

## Constraints
No client-side secrets; no broad service-role key for ordinary requests; no entitlement from unverified webhook/redirect; no arbitrary uploaded-code execution in the web process; no direct agent mutation of commerce tables; no external side effect without authorization, idempotency, audit, and approval where required.