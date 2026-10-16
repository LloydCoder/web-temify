# Phase 5E1 forensic audit — listing moderation case intake

**Disposition:** IN PROGRESS — bounded report intake, admin queue, and audited case-transition slice. This is not a Phase 5 exit pass.

## Implementation added on this branch

- `supabase/migrations/20261016110000_phase5e_listing_moderation_cases.sql`: private case/event tables; RLS and least-privilege grants; service-only idempotent report creation; database-owned admin-role enforcement for triage, action-required, dismissal, and closure; append-only event history; same-transaction audit events.
- `supabase/tests/phase5e_listing_moderation_cases.test.sql`: pgTAP checks for table/RLS/grant/function boundaries, idempotent report creation, conflicting key rejection, legal state transitions, admin denial, invalid transition rejection, append-only history, audit records, and non-implicit publication changes.
- `src/app/api/moderation/reports/route.ts`: authenticated report intake, same-origin and JSON checks, 8 KiB streaming request cap, strict Zod validation, server-derived reporter identity, request correlation, no-store response, and bounded error mapping.
- `src/app/catalog/ReportListingForm.tsx` and `src/app/catalog/[slug]/page.tsx`: user-facing report form on the published product detail page with bounded fields, idempotency key reuse for retries, accessible status feedback, and an explicit warning that reports do not automatically remove listings.
- `src/app/api/admin/moderation-cases/[caseId]/transition/route.ts` and `src/app/admin/moderation/ModerationCaseActionForm.tsx`: audited admin context, same-origin and JSON checks, bounded body, strict action/resolution validation, and visible admin action controls.
- `src/app/admin/moderation/page.tsx`: audited, server-rendered, oldest-first queue capped at 50 records; explicit statement that this case queue does not itself unpublish listings.

## Invariants and limitations

- Client roles cannot read or write moderation records directly; service-role table mutation is not granted. Writes use narrowly scoped RPCs.
- Report identity is derived from the authenticated Supabase principal, not request JSON.
- Repeated identical reports with the same reporter/idempotency key return the original case; conflicting reuse is rejected.
- Moderator identity and legal transitions are checked again inside the database function. Event and audit writes share the state-change transaction.
- The current slice **does not** suppress public listing visibility, perform a takedown, or implement an appeal/counter-notice process. It must not be marketed as a complete moderation system. Those enforcement and appeal workflows remain the next required Phase 5 slices.
- Production staffing, support notification delivery, alerting/escalation, retention policy approval, financial dispute/chargeback controls, backup/restore drills, incident response, safe break-glass, provider onboarding, legal review, penetration testing and full WCAG 2.2 AA remain unverified.
- Keep payment providers and all live money movement disabled.

## Verification

On implementation head `4afd50d29609b1f43c21d97b0369f6dbb6b5e738`, [Foundation CI run 38888892585](https://github.com/LloydCoder/web-temify/actions/runs/38888892585) and [Security/dependency governance run 38888892674](https://github.com/LloydCoder/web-temify/actions/runs/38888892674) passed. Foundation CI covered typecheck, lint, formatting, empty-database migration reset, schema/policy lint, database/RLS tests including the Phase 5E1 assertions, E2E, two-session settlement reconciliation concurrency, production build, and service cleanup.

This evidence applies only to that exact head. Re-run all required checks after any subsequent code or documentation commit and before merge. Phase 5E1 remains a bounded slice, not a Phase 5 exit pass.
