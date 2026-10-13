# ADR-0001: Start with a modular monolith

- **Status:** Accepted
- **Date:** 2026-10-13

Start with a strict TypeScript Next.js App Router application in a pnpm/Turborepo workspace, organized into explicit domain modules and shared packages. Extract services only when measured operational, scaling, security, or independent deployment requirements justify the cost. The root application remains the first deployable while apps/_ and packages/_ support expansion. Do not introduce distributed services or Python/Rust without workload-backed reasons.
