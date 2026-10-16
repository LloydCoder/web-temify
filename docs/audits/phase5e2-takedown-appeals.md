# Phase 5E2 forensic audit — listing takedown enforcement and creator appeals

**Disposition:** PASS for the Phase 5E2 code and CI scope. PR #72 is merged as `c7e587585fad5b26b573fa2c9469ce8915097960`. This is not Phase 5 completion or production moderation readiness.

## Scope implemented

- `supabase/migrations/20261016120000_phase5e2_takedown_appeals.sql` adds private enforcement, creator appeal, appeal-policy, and append-only appeal-event records.
- A guarded database RPC applies a takedown only to a published listing whose moderation case has reached an approved `action_required` resolution. It archives the product, closes the case, and writes case-event and audit evidence in the same transaction.
- Creator appeal intake verifies the authenticated creator owns the product associated with an active enforcement, uses a transaction-scoped idempotency lock, and rejects conflicting key reuse or a second appeal for the same enforcement.
- Appeal decisions are database-owned and admin-role checked. Reversing a takedown restores publication only if independent rights verification and a released artifact still validate; otherwise the listing stays archived and the enforcement records that publication was not restored.
- The creator appeal center only queries the signed-in creator's own archived products and appeals. Admin appeal queue actions and policy configuration are protected by the existing audited admin context.
- The internal response target has no due date until an admin records an approved policy version, internal target, approval note, and legal-review reference. The target is an operational SLA, not a claim about statutory deadlines. Existing appeals retain the deadline/policy version captured at submission.

## Security and correctness invariants

- No anonymous or authenticated direct table reads/writes are granted for internal enforcement, appeal, policy, or appeal-event tables; server reads are filtered by creator identity or restricted to the admin queue.
- Only a moderator/admin database role can apply a takedown, decide an appeal, or configure the internal response target. RPCs re-check role and state inside the database.
- A takedown cannot be applied to a non-published listing, an open/under-review/dismissed case, or a case without an action-required resolution.
- Appeal reversal never blindly republishes a product: publication requires the existing Phase 3 independent-rights and released-artifact checks.
- Case and appeal histories are append-only; all state transitions and policy approval write audit evidence transactionally.
- Public catalogue and detail pages filter to `published` products. Takedown changes the product status to `archived`, and the Phase 5E2 migration now locks/checks that product row when consuming an already-issued download grant so a stale grant cannot bypass the takedown.

## Verification record

- [x] Exact PR-head Foundation CI passed on `ef4611f6e3d57edb97352124661286c2d30efbbf`: [run 38898002442](https://github.com/LloydCoder/web-temify/actions/runs/38898002442). This included frozen install, typecheck, lint, formatting, empty-database migrations, schema/policy lint, database/RLS tests, E2E, two-session settlement reconciliation, and production build.
- [x] Exact PR-head Security/dependency governance passed on the same SHA: [run 38898002455](https://github.com/LloydCoder/web-temify/actions/runs/38898002455).
- [x] Reviewed SQL grants, moderator/admin role checks, creator ownership filtering, case/enforcement/appeal transitions, idempotency locking, policy snapshots, append-only events, and conditional republishing. The download-consumption override preserves Phase 4B's order → entitlement → grant lock order, then share-locks the product so takedown and consumption serialize.
- [x] pgTAP covers direct-table privileges, database role enforcement, eligible/ineligible case states, creator ownership, replay/conflict behavior, appeal decisions, audit history, and conditional restoration. E2E covers unauthenticated creator/admin access and mutation denial.
- [x] Added authenticated HTTP-handler tests in PR #74 for creator appeal intake and admin takedown, appeal-transition, and policy routes. They verify same-origin/authentication gates, server-derived actor identity, strict body validation, bounded requests, safe RPC error mapping, and no privileged mutation on invalid input. Foundation CI passed on exact route-test head `46bc029ba02f38307a97b254d33e12d378ebcdaa` in [run 38957559684](https://github.com/LloydCoder/web-temify/actions/runs/38957559684); Security/dependency governance passed in [run 38957559726](https://github.com/LloydCoder/web-temify/actions/runs/38957559726).
- [ ] Production Vercel preview for the exact final PR head was not verified: the deployment check hit the account's daily API deployment limit. The preceding app-code deployment was READY at `d380e86604314c46106de0cec697ccd71f005ab0`; the final PR commit changed only the E2E request host. Production environment configuration and moderation staffing remain separate gates.
- [ ] Operational/legal policy approval and notification/escalation arrangements remain unverified. Do not assign appeal deadlines until the recorded legal review and internal policy approval are real and authorized.

**Post-merge verification:** Foundation CI passed on merge commit `c7e587585fad5b26b573fa2c9469ce8915097960` in run [38954515697](https://github.com/LloydCoder/web-temify/actions/runs/38954515697). Security/dependency governance also passed on that merge commit in run [38954515716](https://github.com/LloydCoder/web-temify/actions/runs/38954515716).

## Non-claims / release gates

This is not legal advice and does not set statutory appeal deadlines. The internal response target must be approved against a recorded legal review before it assigns due dates. No live payment, provider settlement, payout, or financial action is enabled by this slice. Production alerting, staff rota, retention/deletion approval, penetration testing, formal legal review, full WCAG 2.2 AA, and deployment configuration remain separate release gates.
