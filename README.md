# Web-Temify

**From idea to deployable web product in hours.**

Web-Temify is a planned global-first digital-product marketplace and product factory.

> Foundation in progress. Documented features are not proof of implementation. Production commerce, payment processing, vendor payouts, license enforcement, and live Tinlance Agent System execution are not yet demonstrated.

## Canonical documentation

- Canonical 20-phase enterprise roadmap: [docs/roadmap/master-enterprise-roadmap.md](docs/roadmap/master-enterprise-roadmap.md)
- Phase evidence register: [docs/roadmap/phase-gates.md](docs/roadmap/phase-gates.md)
- Payment/MoR/treasury provider strategy and activation gates: [docs/commerce/provider-strategy.md](docs/commerce/provider-strategy.md)
- Architecture overview: [docs/architecture/overview.md](docs/architecture/overview.md)
- Repository structure: [docs/architecture/repository-structure.md](docs/architecture/repository-structure.md)
- Domain boundaries: [docs/architecture/domain-boundaries.md](docs/architecture/domain-boundaries.md)
- Security baseline: [docs/security/security-baseline.md](docs/security/security-baseline.md)
- Threat model: [docs/security/threat-model.md](docs/security/threat-model.md)
- Testing strategy: [docs/quality/testing-strategy.md](docs/quality/testing-strategy.md)
- Legacy reconciliation: [docs/governance/legacy-reconciliation.md](docs/governance/legacy-reconciliation.md)
- Product source monorepo and canonical planned inventory: [LloydCoder/web-temify-products](https://github.com/LloydCoder/web-temify-products)

## Public ecosystem map

The homepage presents nine agreed platform areas with explicit capability status and destination routes:

1. Template & Script Marketplace — existing /catalog route; only verified published releases are eligible to appear.
2. Web Hosting & Deployment — /hosting (planned; provisioning and billing are not operational).
3. AI Site Builder — /ai-site-builder (planned; generation is disabled).
4. Tech Directory Hub — /directory (homepage preview only; submissions and paid placements are not live).
5. Verified Automation Marketplace — /automations (planned; transactions disabled).
6. Specialist Supplier Directory — /specialists (planned; onboarding not available).
7. Outcome-Based AI Implementation Marketplace — /implementation (planned; contracts and milestone payments disabled).
8. Shared Enterprise Platform — /platform (cross-cutting foundation, not a standalone storefront).
9. Tech Hub & Advertising Engine — /tech-hub (planned; publishing and monetization workflows not enabled).

The canonical visual/design reference is docs/web-temify-v3.html. The homepage is implemented as native Next.js/React markup; the public HTML copy is retained as a design/legacy reference, not embedded by the homepage. These UI disclosures are not proof of production readiness. Phase 4D2/Phase 5 provider, financial, legal, security, staffing and operational gates remain independent launch requirements.

## Canonical technology stack

- TypeScript strict mode, Next.js App Router, React.
- Tailwind CSS, shadcn/ui conventions, Web-Temify design tokens.
- pnpm workspaces and Turborepo.
- Zod and shared domain contracts.
- Supabase PostgreSQL, Supabase Auth, private Supabase Storage.
- Supabase SQL migrations as the only canonical schema history.
- Vitest, Playwright, PostgreSQL/RLS tests, GitHub Actions.
- Vercel for suitable web workloads; provider adapters only after eligibility checks.
- Durable worker/job system only when asynchronous workload requires it; Python and Rust remain optional.

## Local setup

1. Install Node.js 22 and enable Corepack.
2. Run `pnpm install --frozen-lockfile`.
3. Copy `.env.example` to `.env.local` and add only required local credentials.
4. Run `pnpm check:foundation`, `pnpm typecheck`, `pnpm lint`, and `pnpm build`.
5. Run `pnpm exec playwright install chromium` before `pnpm test:e2e`.
6. Run `pnpm exec supabase start` to test database work locally.

The product-source repository owns product source workspaces, manifests, build/test contracts and immutable release evidence. This marketplace repository owns public listing state, accounts, checkout, orders, payments, refunds, licenses, entitlements, downloads and seller operations. Planned inventory entries must not appear as available products until an approved release artifact and rights evidence are available.
