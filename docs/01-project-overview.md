> **LEGACY / NON-CANONICAL — reviewed 2026-10-13.** Retained for historical requirements and design context only. Do not treat its framework, database/migration strategy, provider list, security examples, product count, phase status, pricing, testimonials, metrics, or “built/production-ready” claims as current truth. Canonical authority is in `docs/architecture/overview.md`, `docs/architecture/decisions/`, `docs/roadmap/phase-gates.md`, `docs/security/`, `docs/quality/testing-strategy.md`, the tested source and Supabase migrations, and `LloydCoder/web-temify-products/catalog/products.json`. Implement only through the current phase gates and verified evidence.

# WEB-TEMIFY — PROJECT OVERVIEW & BRIEF
## For: Development Team / Builder
## Version: 5.0 | May 2026

---

## WHAT IS WEB-TEMIFY

Web-Temify is a premium digital product marketplace where developers, agencies, and founders buy and sell website templates, PHP scripts, Web3 kits, and launch bundles.

**Think:** ThemeForest + Gumroad + a Tech Directory — built specifically for Africa, with global reach.

**Company:** Web-Temify LTD (RC: 7999659, TIN: 2521759867925) — Nigeria
**Sister company:** Tinlance Limited (RC: 7962164) — AI & cybersecurity engineering studio
**Admin email:** nwachukwuchinaemerem8@gmail.com
**Domain:** web-temify.com
**Positioning:** "From idea to deployable web product in hours"

---

## TECH STACK — FINAL AND LOCKED

```
Frontend:     Next.js 15 (App Router)
Hosting:      Vercel (free tier → Pro when needed)
Database:     Supabase Postgres
Auth:         Supabase Auth
Storage:      Supabase Storage
ORM:          Prisma
Styling:      Tailwind CSS + shadcn/ui
State:        Zustand
Forms:        React Hook Form + Zod
Email:        Resend
AI:           Anthropic Claude API (primary fallback chain)
Repo:         GitHub (auto-deploy to Vercel on push)
```

**DO NOT use:**
- PHP or Laravel (previous build — discarded)
- NextAuth (use Supabase Auth instead)
- MySQL (use Supabase Postgres instead)
- Redux (use Zustand)
- Pages Router (use App Router only)

---

## PAYMENT GATEWAYS — ALL 6 MUST BE IMPLEMENTED

| Gateway | Purpose | Phase |
|---|---|---|
| Paystack | Nigeria + Africa (cards, bank transfer, USSD) | Phase 1 |
| Stripe | International cards + subscriptions | Phase 1 |
| LemonSqueezy | Global digital products + VAT handling | Phase 1 |
| MTN MoMo / Airtel / M-Pesa | Mobile money Africa | Phase 2 |
| Carbon / FairMoney (BNPL) | Buy now pay later Nigeria | Phase 2 |
| NOWPayments (USDT/USDC) | Stablecoins — auto-convert to fiat | Phase 3 |

**NOWPayments rules (CRITICAL):**
- USDT and USDC ONLY — never BTC, ETH, SOL, or volatile coins
- TRC-20 network preferred (cheapest fees)
- Auto-converts to fiat instantly — never hold crypto
- Refunds = platform credits only — no on-chain refunds
- Feature flag: `NEXT_PUBLIC_FEATURE_CRYPTO_PAYMENTS=false` until Phase 3
- IPN webhook verification via HMAC SHA-512

**Rule:** Every checkout page must show ALL enabled gateways as tabs.

---

## DESIGN SYSTEM — NEVER DEVIATE

```css
--bg:      #fffbf4  /* warm cream — NOT white */
--ink:     #0f0d0a  /* near black */
--coral:   #ff5733  /* primary CTA */
--yellow:  #ffd60a  /* badges, highlights */
--mint:    #00c48c  /* success, checkmarks */
--sky:     #4f8ef7  /* info, Web3 elements */
--lilac:   #c084fc  /* AI features */
--surface: #fff8ed  /* card backgrounds */
--muted:   #6b6559  /* secondary text */

Fonts:
  Display/Headings: Cabinet Grotesk (900, 800, 700)
  Italic accents:   Instrument Serif (italic)
  Monospace/labels: DM Mono

Design Rules:
  - 2px solid #0f0d0a borders on ALL cards and buttons
  - 4px 4px 0 #0f0d0a box-shadow on hover (brutalist lift)
  - 6px 6px 0 #0f0d0a for large card hover
  - Warm cream background everywhere — never pure white
  - Coral scrolling marquee strips between major sections
  - Dark ink (#0f0d0a) sections for "How it works" content
  - Yellow for featured/popular/hot badges
  - All buttons have 2px solid border + hover lift effect
  - Dark mode must work on every single page
  - Mobile responsive (375px, 768px, 1200px breakpoints)
  - RTL support for Arabic/Hausa content
```

**Reference:** See `05-homepage-design.html` for exact visual implementation.

---

## AI GATEWAY — MULTI-LLM FALLBACK CHAIN

Never call a single AI provider directly. Always use the gateway service.

```
Task routing:
  Blog posts:           Claude → GPT-4o → Gemini
  Directory listings:   Gemini Flash → Claude → GPT-4o
  Page generator:       Claude → GPT-4o → Grok
  Product descriptions: Claude → GPT-4o → Gemini
  Support replies:      Claude Haiku → GPT-4o-mini → Gemini Flash
  Semantic search:      Gemini Flash → Claude Haiku → GPT-4o-mini
  Web3 content:         Grok → Claude → GPT-4o

Providers:
  1. Claude Sonnet 4 (Anthropic) — primary
  2. Grok-3 (xAI)               — Web3/crypto content
  3. Gemini 2.5 Flash (Google)   — near-free, fast
  4. GPT-4o-mini (OpenAI)        — cheapest fallback
```

---

## BUILD PHASES

### Phase 1 — Launch (Ship First)
Core marketplace, payments, licensing, downloads, admin.
**Do not add Phase 2+ features until Phase 1 is live and making money.**

### Phase 2 — Revenue Foundation
Vendor system, directory hub, services/leads, mobile money, fraud prevention, messaging.

### Phase 3 — Growth
Gamification, AI generator, community forum, courses, crypto payments.

### Phase 4 — Scale
Automation engine, programmatic SEO, mobile app API, affiliate marketplace.

### Phase 5 — Enterprise
SOC 2, white-label, Merchant of Record, GDPR CMP v2, SDK libraries.

---

## COMPANY DETAILS (Use in footer, emails, legal pages)

```
Web-Temify LTD
RC: 7999659
TIN: 2521759867925
Nigeria

Sister company: Tinlance Limited (RC: 7962164)
"Need a custom-built product? That's their lane."
Tinlance URL: https://tinlance.com

Contact email: hello@web-temify.com
Admin email: nwachukwuchinaemerem8@gmail.com
Copyright: © 2026 Web-Temify LTD. All rights reserved.
```

---

## CRITICAL RULES FOR THE BUILDER

1. **Never expose secret keys** — all secret keys server-side only
2. **All DB queries use Prisma** — never raw SQL unless absolutely necessary
3. **All file downloads are signed URLs** — never direct public file links
4. **All payment webhooks verify signatures** — before processing anything
5. **All user input is validated** — Zod schemas on every form and API route
6. **Dark mode works everywhere** — next-themes, class strategy
7. **Mobile responsive everywhere** — test at 375px minimum
8. **TypeScript strict mode** — no `any` types
9. **Row Level Security on all Supabase tables** — never bypass RLS
10. **Feature flags for unbuilt features** — never show broken UI
