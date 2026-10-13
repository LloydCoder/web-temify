# ADR-0003: Supabase SQL migrations own schema evolution

- **Status:** Accepted
- **Date:** 2026-10-13

Supabase SQL migrations are the canonical and sole schema history. New migrations are created using the Supabase CLI, reviewed as SQL, tested against local PostgreSQL/Supabase, and applied through controlled environments. Do not add Prisma Migrate or a second competing migration directory. If Prisma is later adopted as a query/client layer, it must not own migrations.

Required controls: every exposed table has RLS and least-privilege grants; policies enforce ownership including USING and WITH CHECK; tests cover anonymous, owner, non-owner, and privileged server paths; review views, functions, triggers, storage policies, grants and extensions; document staging/production application, forward-fix and backup/restore. No production schema changes before local tests and review pass.
