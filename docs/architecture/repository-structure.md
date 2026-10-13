# Repository structure

- .github/workflows/: CI and release automation.
- docs/: architecture decisions, governance, product scope, security, quality, roadmap, integrations and operations.
- apps/: future independently deployable applications.
- packages/domain-contracts/: shared Zod schemas and domain types.
- packages/ui/: shared Web-Temify UI components.
- src/app/: Next.js App Router and route groups.
- src/components/: app-specific UI components.
- src/features/: domain modules and application services.
- src/lib/: safe shared utilities, environment validation and Supabase SSR client helpers.
- src/server/: server-only adapters, authorization and integration boundaries.
- src/styles/: design tokens and shared styles.
- supabase/config.toml: local Supabase CLI configuration.
- supabase/migrations/: canonical schema history, created with Supabase CLI.
- supabase/tests/: PostgreSQL/RLS tests.
- tests/unit, integration, contract, security, e2e: layered quality gates.
- pnpm-workspace.yaml and turbo.json: workspace and task orchestration.

The root Next.js app remains the first deployable while apps/* and packages/* are supported. Moving it to apps/web is a separately validated structural migration, not a silent partial move.
