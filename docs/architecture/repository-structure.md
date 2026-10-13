# Repository structure — canonical map

This is the target structure for the initial modular monolith. A directory in this map does not imply the feature is implemented; add files as the corresponding phase begins.

```text
web-temify/
├── .github/ (workflows, CODEOWNERS, issue templates)
├── docs/ (architecture, governance, product, roadmap, quality, security, operations, integrations)
├── prisma/ (schema, seed, migrations only if Prisma owns migrations)
├── supabase/ (config, migrations/tests only under agreed ownership)
├── public/ (approved icons, images, licensed fonts)
├── scripts/ (validation and maintenance)
├── src/
│   ├── app/
│   │   ├── (marketing)/ (about, pricing, contact, changelog)
│   │   ├── (auth)/ (login, registration, recovery, callback)
│   │   ├── (marketplace)/ (catalogue, categories, product detail, search)
│   │   ├── (checkout)/ (checkout, return/status pages)
│   │   ├── (account)/ (purchases, downloads, licenses, settings)
│   │   ├── (seller)/ (onboarding, submissions, analytics, payouts)
│   │   ├── (admin)/ (moderation, users, products, orders, audit)
│   │   ├── (directory)/ and (content)/ (later-phase surfaces)
│   │   ├── api/ (health and verified provider webhooks)
│   │   └── layout.tsx, page.tsx, error.tsx, not-found.tsx, loading.tsx
│   ├── components/ (ui, layout, marketplace, forms)
│   ├── features/ (identity, catalogue, cart, checkout, orders, payments, entitlements, downloads, licenses, subscriptions, vendors, moderation, notifications, audit, directory, AI, integrations)
│   ├── lib/ (env, flags, logging, observability, security)
│   ├── server/ (auth, db, storage, payments, email, integrations/tinlance)
│   └── styles/
├── tests/ (unit, integration, contract, security, e2e)
└── root config, package manifest, lockfile, README
```

## Rules
Feature modules own schemas, use cases, and tests; routes call use cases instead of embedding business logic. Avoid circular dependencies. Secret-bearing code must not enter client components. Do not create competing schema authorities. Lock the Prisma/Supabase migration model first. Legacy PHP/Laravel prompts are historical references, not canonical implementation instructions.