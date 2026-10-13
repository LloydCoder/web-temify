# Supabase project structure

Supabase PostgreSQL is the application database and Supabase SQL migrations are the canonical schema history. Prisma is not the schema authority and must not generate competing migrations.

- config.toml: local Supabase CLI configuration.
- migrations/: ordered SQL migration history; create new files with supabase migration new <name>.
- tests/: database/RLS tests run against local Supabase.
- Keep RLS enabled on exposed tables and test positive and negative access paths.
- Never expose secret/service-role keys to client bundles.
- Use private Storage buckets for paid artifacts; issue short-lived download URLs only after server-side entitlement checks.
- Do not run schema changes against a linked production project during foundation setup.
