# Phase 5E2 forensic audit — listing takedown enforcement and creator appeals

**Disposition:** IMPLEMENTED ON BRANCH; CI AND REVIEW PENDING. Do not treat this slice as accepted until the final PR head passes the full workflow.

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
- Public catalogue visibility continues to depend on product status and existing Phase 3 release-evidence gates. The new takedown transition sets status to `archived`.

## Verification required

- [ ] Full Foundation CI on the exact PR head: frozen install, typecheck, lint, formatting, empty-database migration reset, schema/policy lint, all database/RLS tests, E2E, two-session reconciliation test, and production build.
- [ ] Security/dependency governance passes on the same head.
- [ ] Review SQL function grants, creator ownership filter, case transition preconditions, deadline policy snapshots, and conditional republishing.
- [ ] Verify route behavior for unauthenticated, non-owner, non-admin, invalid body, replay/conflict, and stale state.
- [ ] Record residual legal/operational approval requirements before production rollout.

## Non-claims / release gates

This is not legal advice and does not set statutory appeal deadlines. The internal response target must be approved against a recorded legal review before it assigns due dates. No live payment, provider settlement, payout, or financial action is enabled by this slice. Production alerting, staff rota, retention/deletion approval, penetration testing, formal legal review, full WCAG 2.2 AA, and deployment configuration remain separate release gates.
