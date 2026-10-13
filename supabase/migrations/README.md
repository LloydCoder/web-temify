# Canonical SQL migration history

Supabase SQL migrations are the sole authoritative schema history for Web-Temify. The ordered migrations in this directory are applied by the local Supabase stack and CI from an empty database; they must remain replayable and deterministic.

## Rules
- Create new migrations with `supabase migration new descriptive_name`.
- Never introduce Prisma Migrate or a second hand-maintained schema history.
- Review SQL for least privilege, explicit grants, RLS, safe `search_path` on privileged functions, and migration reversibility/forward-fix strategy.
- Add pgTAP coverage for schema constraints, grants, RLS, allowed actions, denied actions, and concurrency-sensitive invariants.
- Validate with `supabase db reset` and `supabase test db` before merge; CI repeats both against an empty local database.
- Never use production credentials or production personal data in migration tests.

## Current migration set
- `20261013000000_phase2_identity_catalogue.sql` — identity, role baseline, catalogue primitives, and RLS.
- `20261013010000_phase3_catalogue_quality.sql` — product compatibility, independent rights attestations, content-addressed release evidence, and evidence-gated public visibility.
- `20261013015000_phase3_creator_policy_privileges.sql` — security-definer ownership predicates so creator RLS policies work with intentionally restricted column-level product grants.

The catalogue currently contains no approved production releases. A passing migration suite proves schema/test behavior only; it does not establish live checkout, payment processing, vendor payouts, entitlements, signed downloads, or production readiness.
