# Web-Temify

**From idea to deployable web product in hours.**

Web-Temify is a planned global-first digital-product marketplace and product factory.

> **Foundation in progress.** Documented features are not proof of implementation. Production commerce, payment processing, vendor payouts, license enforcement, and live Tinlance Agent System execution are not yet demonstrated.

## Canonical docs
- [Phase gates](docs/roadmap/phase-gates.md)
- [Architecture overview](docs/architecture/overview.md)
- [Repository structure](docs/architecture/repository-structure.md)
- [Domain boundaries](docs/architecture/domain-boundaries.md)
- [Security baseline](docs/security/security-baseline.md)
- [Threat model](docs/security/threat-model.md)
- [Testing strategy](docs/quality/testing-strategy.md)
- [Legacy reconciliation](docs/governance/legacy-reconciliation.md)

## Stack direction
Next.js App Router, React, strict TypeScript, Supabase PostgreSQL/Auth/Storage, Prisma, Tailwind CSS, Zod, and Vercel are the intended baseline. Compatible versions, migration ownership, lockfile, and CI execution must be verified before the stack is considered reproducible.

## Local setup
1. Install Node.js from `.nvmrc`.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and add only required credentials.
4. Run `npm run check:foundation`.
5. Run `npm run dev`.

Never commit secrets. Work on a branch, run checks, record evidence, and open a PR. Do not mark a phase complete without its exit criteria.