# Phase 1 local and CI runbook

## Local validation
```bash
node --version
npm --version
npm install
npm run check:foundation
npm run typecheck
npm run lint
npm run build
npm run dev
```

Use Node 22 from `.nvmrc`. Start from `.env.example`; do not copy production secrets locally. The shell should work without payment, AI, database, or Tinlance credentials. Real integrations fail closed when configuration is absent.

A workflow file alone does not prove CI passed. Inspect the actual run and record its URL, commit SHA, and result.

**Known follow-up:** a committed package lockfile is required for reproducible installs. Generate it in a controlled environment, commit it, and switch CI to `npm ci`. Pin third-party GitHub Actions to reviewed immutable SHAs before production hardening.