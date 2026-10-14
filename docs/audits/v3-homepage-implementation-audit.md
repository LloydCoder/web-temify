# V3 homepage implementation audit

**Audit date:** 2026-10-14  
**Implementation branch:** `feat/implement-canonical-v3-design`  
**Scope:** Homepage visual restoration and truthful preview behaviour only. This is not an overall roadmap phase-completion claim.

## Canonical source and runtime

- Canonical design source: `docs/web-temify-v3.html` (retained unchanged).
- Served runtime asset: `public/web-temify-v3.html`.
- Homepage entry point: `src/app/page.tsx`, which mounts the runtime asset in a titled, full-viewport iframe.
- Global viewport rules: `src/app/globals.css`.
- Document metadata: `src/app/layout.tsx`.
- Browser coverage: `tests/e2e/homepage.spec.ts`.

The runtime keeps the source composition, layout, typography, colour system, section order and responsive design. It deliberately changes illustrative legacy content that could otherwise be mistaken for live inventory or real customer evidence.

## Corrections applied to runtime content

- Replaced unsupported template/tool/business counts and sales/rating claims.
- Replaced illustrative customer names, quotes and star ratings with explicit preview/roadmap language.
- Removed displayed product, launch-kit and service prices from illustrative cards.
- Clarified that catalogue purchases, seller onboarding, subscriptions, payment providers and secure delivery are not live.
- Routed catalogue discovery actions to the existing `/catalog` route, which fails closed and shows only verified published products.
- Routed named directory tools to their official public sites.
- Routed custom-engineering service requests to Tinlance's public website.
- Replaced unsupported account, vendor, social and content destinations with non-interactive “not live yet” labels instead of dead `#` links.
- Kept the canonical design reference file unchanged so it remains the design baseline.

## Verification requirements

The PR must not merge until the exact head SHA has green results for:

- Frozen dependency install, foundation/domain tests, TypeScript, lint and formatting.
- Supabase empty-database migration reset, schema lint and pgTAP/RLS tests.
- Playwright at mobile and desktop widths, including iframe load, semantic heading, preview disclaimer, absence of placeholder `href="#"` actions, and horizontal overflow.
- Production build and service cleanup.
- Production dependency/license policy and full-history secret scan.

## Explicit limits and non-claims

- The iframe approach is a visual restoration step, not the final native React/component integration.
- The catalogue remains backed by the existing verified-release rules; no real products are assumed to be published.
- Checkout, live payment-provider processing, subscriptions, seller onboarding, automated delivery, directory submission and supplier/implementation transactions remain disabled or not implemented.
- No production launch, legal/tax readiness, full WCAG 2.2 AA compliance, penetration-test completion, or completion of Phases 0–20 is claimed by this homepage work.
- Follow-on work must proceed through the canonical roadmap and phase gates, serially, with exact-head CI and a phase-specific forensic audit.
