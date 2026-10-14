# Phase 1 local and CI runbook

## Prerequisites

Node.js 22, Corepack/pnpm 10, Docker for local Supabase, and browser dependencies for Playwright.

## Local validation

1. corepack enable
2. pnpm install
3. pnpm check:foundation
4. pnpm typecheck
5. pnpm lint
6. pnpm build
7. pnpm exec playwright install --with-deps chromium
8. pnpm test:e2e
9. pnpm exec supabase start
10. pnpm exec supabase db lint --local

Start from .env.example; do not copy production secrets locally. The shell should work without payment, AI, database, or Tinlance credentials.

Lockfile gate: commit pnpm-lock.yaml after running pnpm install with the pinned package manager. CI must use pnpm install --frozen-lockfile once the lockfile exists. Do not declare the foundation reproducible before then.
