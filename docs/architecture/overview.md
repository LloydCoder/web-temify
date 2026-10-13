# Architecture overview

Web-Temify uses strict TypeScript, Next.js App Router, Tailwind CSS, shadcn/ui, the Web-Temify design system, pnpm workspaces, Turborepo, Zod, and shared domain contracts. Supabase PostgreSQL is the database; Supabase Auth owns authentication; application authorization is enforced server-side and in row-level security. Supabase SQL migrations are the only canonical schema history. Paid assets use private object storage and server-authorized expiring downloads.

GitHub Actions validates changes. Vercel is the default deployment target where runtime requirements fit. Payment providers are adapters selected only after business eligibility, payout availability, fees, refunds, webhook security and sandbox behavior are verified. Add durable workers when real asynchronous workload requires them. Python and Rust are optional and require a workload-based justification.

Tinlance Agent System is a governed external executor, not the commerce authority. Integration is disabled by default and cannot independently authorize refunds, payouts, entitlements, roles, or publication.
