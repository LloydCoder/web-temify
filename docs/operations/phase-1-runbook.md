# Phase 1 local and CI runbook

## Prerequisites

Node.js 22 (from `.nvmrc`), Corepack with pnpm 10.18.0, Docker for local Supabase, and Chromium/Playwright system dependencies for browser tests.

## Local validation

Run from a clean checkout:

1. `corepack enable`
2. `corepack pnpm install --frozen-lockfile`
3. `corepack pnpm check:foundation`
4. `corepack pnpm typecheck`
5. `corepack pnpm lint`
6. `corepack pnpm format:check`
7. Install the Supabase CLI at the CI-pinned version (2.107.0) and start local services with `supabase start -x studio,imgproxy,inbucket`.
8. Apply migrations from an empty local database with `supabase db reset`.
9. Lint schema and policies with `supabase db lint --local`.
10. Run database/RLS tests with `supabase test db`.
11. Install browser dependencies with `corepack pnpm exec playwright install --with-deps chromium`.
12. Run browser tests with `corepack pnpm test:e2e`.
13. Run the production build with `corepack pnpm build`.

CI is the authoritative validation path and pins pnpm 10.18.0, Supabase CLI 2.107.0, and GitHub Actions by full commit SHA. It runs the same foundation, type, lint, format, empty-database migration reset, schema lint, pgTAP/RLS, Playwright, and production-build gates. The local environment must have Docker for the database steps; a shell without Docker cannot claim database migration/RLS validation.

Start from `.env.example`; do not copy production secrets locally. Foundation tests and production build must not require payment-provider, AI, or Tinlance credentials. Keep live provider integrations disabled until their independent onboarding and authentication gates pass.

## Reproducibility gate

`pnpm-lock.yaml` is committed. Use `pnpm install --frozen-lockfile` for every clean-checkout validation; never regenerate or update the lockfile implicitly during CI. The lockfile gate is satisfied only when the frozen install succeeds on the exact candidate commit.
