# V3 homepage implementation audit

**Audit date:** 2026-10-17  
**Implementation branch:** `feat/native-v3-nextjs-homepage`  
**Scope:** Native V3 homepage integration and user-facing preview accuracy. This audit does not claim completion of the wider enterprise roadmap or production launch.

## Canonical design and implementation

- Canonical design reference: `docs/web-temify-v3.html`, reconciled with the legacy visual reference and extended with the nine-area ecosystem section, status disclosures, and destination links.
- Legacy public runtime copy: `public/web-temify-v3.html`; it is not embedded by the homepage and is being kept aligned with truthful preview messaging.
- Native homepage entry point: `src/app/page.tsx`, with V3 markup rendered as React/JSX rather than an iframe.
- Scoped V3 stylesheet: `src/app/v3-home.css`; selectors are scoped under `.v3-app` to avoid leaking into catalogue, account, checkout, and admin routes.
- Shared application metadata: `src/app/layout.tsx`.
- Destination route template: `src/app/ecosystem-destination.tsx` and `src/app/ecosystem-destination.css`.
- Dedicated destination routes: `/hosting`, `/ai-site-builder`, `/directory`, `/automations`, `/specialists`, `/implementation`, `/platform`, and `/tech-hub`; the marketplace card links to the existing `/catalog` route.
- Browser coverage: `tests/e2e/homepage.spec.ts` and `tests/e2e/ecosystem-routes.spec.ts`.

The native implementation preserves the V3 visual language: warm cream background, near-black typography and borders, coral/yellow/mint accents, Cabinet Grotesk and Instrument Serif, editorial section composition, offset shadows, and responsive layouts. The global CSS and other route styles are not replaced by the homepage stylesheet.

## Frontend behaviour and accessibility

- Adds a keyboard-accessible skip link and responsive mobile navigation with `aria-expanded` state.
- Keeps internal catalogue navigation on Next.js links.
- Makes directory category tabs filter the visible external-tool cards and expose selection through `aria-pressed`.
- Makes AI prompt suggestions keyboard-operable and fills the input as a prototype interaction.
- Respects `prefers-reduced-motion` and provides visible focus styling.
- Keeps the AI Site Builder generation control disabled and labels the capability as planned/not live.
- Removes invented category inventory counts and unsupported payment/download claims from the user-facing preview.
- Uses explicit preview language for illustrative content, rather than implying real sales, customers, published inventory, or active checkout.
- Adds an ecosystem overview covering all nine agreed areas, with dedicated destination routes and status labels; shared enterprise platform is framed as a cross-cutting layer rather than a storefront.
- Avoids placeholder `href="#" ` links and checks same-page fragment targets.

## Verification required before merge

The integration must not be merged until the exact head SHA has green results for:

- Frozen dependency installation, foundation/domain tests, TypeScript, ESLint, and Prettier.
- Supabase empty-database migration reset, schema lint, pgTAP/RLS tests, and the existing concurrent reconciliation test.
- Playwright checks for native rendering without an iframe, all nine ecosystem cards and route destinations, route-level availability notices, semantic content, no unresolved anchors, mobile/desktop overflow, mobile navigation, directory filtering, and AI-preview behaviour.
- Production build and service cleanup.
- Production dependency/license policy and full-history secret scan.
- Preview deployment and visual comparison where Vercel deployment quota permits.

At the time this audit file is updated, CI/formatting and browser verification are still being iterated on; this document is not evidence that those gates have passed.

## Explicit limits and non-claims

- This is a native rendering integration, not a claim that the marketplace is fully implemented.
- The catalogue must continue to show only products backed by verified release and rights evidence.
- AI generation, hosting provisioning, checkout, live payment-provider processing, subscriptions, seller onboarding, automated delivery, directory submissions, and supplier/implementation transactions must not be presented as live unless their implementation and release evidence are verified.
- Payment processing, payout execution, settlement posting, and live money movement remain subject to the separate Phase 4D2/Phase 5 operational, provider, legal, accounting, security, and staffing gates.
- No production launch, legal/tax readiness, full WCAG 2.2 AA conformance, penetration-test completion, or completion of Phases 0–20 is claimed by this frontend work.
