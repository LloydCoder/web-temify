> **LEGACY / NON-CANONICAL — reviewed 2026-10-13.** Retained for historical requirements and design context only. Do not treat its framework, database/migration strategy, provider list, security examples, product count, phase status, pricing, testimonials, metrics, or “built/production-ready” claims as current truth. Canonical authority is in `docs/architecture/overview.md`, `docs/architecture/decisions/`, `docs/roadmap/phase-gates.md`, `docs/security/`, `docs/quality/testing-strategy.md`, the tested source and Supabase migrations, and `LloydCoder/web-temify-products/catalog/products.json`. Implement only through the current phase gates and verified evidence.

# WEB-TEMIFY — COMPLETE FEATURE MASTER LIST
## 332 Total Features | 219 To Build | 34 Groups
## Version 5.0 | May 2026

---

## ALREADY BUILT (113 checks — existing PHP build)
These exist in the old PHP build and must be rebuilt in Next.js:
Auth, marketplace listing, template preview, Paystack/Stripe/LemonSqueezy
payments, webhooks, admin panel, blog, affiliate, 2FA, dark mode, RTL,
4 languages, GDPR export, SEO, PWA, 9 cron jobs, 25+ public pages.

---

## PHASE 1 — LAUNCH (Build These First)

### Core Marketplace
- [ ] Homepage matching web-temify-v3.html design exactly
- [ ] Template listing page with category + filter sidebar
- [ ] Template preview page (desktop/tablet/mobile device switcher)
- [ ] Side-by-side template comparison
- [ ] Search with autocomplete (fulltext via Supabase)
- [ ] 12 category grid on homepage
- [ ] Free templates section (no card required)
- [ ] New arrivals page
- [ ] Trending templates page
- [ ] Recently viewed (persistent, stored in DB)
- [ ] Wishlist (add/remove from heart icon)
- [ ] Template collections (user-curated bundles)
- [ ] Purchase counter on every card ("847 purchases")
- [ ] Live purchase notification toast ("Someone in Lagos just bought...")
- [ ] Hot / New / Web3 / Pro badges on template cards

### Auth
- [ ] Email + password registration (Supabase Auth)
- [ ] Email verification flow
- [ ] Login page
- [ ] Forgot password + reset password
- [ ] Google OAuth (Supabase Socialite)
- [ ] GitHub OAuth
- [ ] Twitter/X OAuth
- [ ] 2FA setup (TOTP — Google Authenticator)
- [ ] 2FA verify on login
- [ ] Suspicious login alert email
- [ ] Session management + logout
- [ ] Honeypot on register form

### Checkout & Payments
- [ ] Checkout page with ALL enabled gateway tabs
- [ ] Paystack payment initiation + callback
- [ ] Stripe payment intent + confirmation
- [ ] LemonSqueezy checkout redirect
- [ ] Paystack webhook (HMAC verify + idempotency)
- [ ] Stripe webhook (HMAC verify + idempotency)
- [ ] LemonSqueezy webhook (HMAC verify + idempotency)
- [ ] Coupon code AJAX validation
- [ ] Gift card redemption at checkout
- [ ] Order bump / upsell at checkout
- [ ] Guest checkout flow
- [ ] Two-click checkout for returning buyers (saved method)
- [ ] Order summary page
- [ ] Payment success page
- [ ] Payment failed page
- [ ] PDF invoice generator (DomPDF)
- [ ] Multi-currency invoicing (NGN/KES/GHS/USD/EUR)
- [ ] PPP pricing by country
- [ ] VAT/tax calculation
- [ ] 2FA required for purchases above $200

### License System
- [ ] License key auto-generated on purchase
- [ ] License key shown in user dashboard
- [ ] License validation API endpoint (/api/v1/validate-license)
- [ ] License activation tracking (domain + IP)
- [ ] License deactivation from dashboard
- [ ] Admin license revocation (on chargeback/fraud)
- [ ] License expiry + 30-day reminder email
- [ ] License upgrade path (single → multi → agency)
- [ ] Bulk license purchases

### Downloads
- [ ] Secure token-based download (expires 24h, max 5 uses)
- [ ] Signed Supabase Storage URL (expires 5 minutes)
- [ ] Re-download from dashboard without support
- [ ] Product update notifications to existing buyers

### User Dashboard
- [ ] Dashboard home (stats, recent downloads, subscription status)
- [ ] My downloads history
- [ ] My purchases library
- [ ] My subscription (with self-service pause/resume)
- [ ] My invoices (list + download PDF)
- [ ] My licenses (view, deactivate domains)
- [ ] My collections
- [ ] My wishlist
- [ ] Profile page (public)
- [ ] Edit profile (name, avatar, bio, social links)
- [ ] Account settings (email, password, 2FA, notifications)
- [ ] GDPR data export
- [ ] GDPR account deletion
- [ ] Onboarding checklist (PLG — step-by-step for new users)
- [ ] Referral links + earnings

### Admin Panel
- [ ] Admin dashboard (revenue chart, MRR, ARR, LTV, churn)
- [ ] User list + search + segments
- [ ] User detail + suspension + impersonation
- [ ] Product list + bulk approve/reject
- [ ] Add/edit products (form + Supabase Storage upload)
- [ ] Template version history + changelog
- [ ] VirusTotal malware scan trigger
- [ ] Order list + detail
- [ ] Subscription list + detail
- [ ] Refund queue management
- [ ] Coupon CRUD
- [ ] Gift card CRUD
- [ ] Abandoned checkout tracker
- [ ] Revenue attribution dashboard
- [ ] Email campaign composer (with A/B testing)
- [ ] Drip sequence management
- [ ] Transactional email template editor
- [ ] Blog post CRUD (TinyMCE/rich text)
- [ ] Announcement banner (scheduled, with colour picker)
- [ ] FAQ CRUD
- [ ] Testimonial management
- [ ] Roadmap item management
- [ ] Changelog entry management
- [ ] Activity log (searchable, paginated, exportable)
- [ ] Error log viewer
- [ ] CSV export (users, orders, revenue, subscriptions)
- [ ] Admin 2FA enforcement
- [ ] IP allowlist for admin panel
- [ ] RBAC roles (admin, vendor, user)
- [ ] Global admin search

### SEO & Performance
- [ ] Dynamic sitemap.ts (all pages, products, blog posts)
- [ ] Dynamic robots.ts
- [ ] Open Graph meta on every page
- [ ] JSON-LD Product schema on template pages
- [ ] JSON-LD SoftwareApplication schema on script pages
- [ ] Twitter Card meta
- [ ] hreflang for multi-language
- [ ] Canonical URLs
- [ ] Core Web Vitals optimisation (WebP auto-conversion)
- [ ] Image lazy loading
- [ ] Critical CSS inline
- [ ] Cloudflare CDN for static assets

### PWA
- [ ] manifest.json
- [ ] Service worker (offline fallback)
- [ ] Push notification opt-in (new products in watched categories)
- [ ] offline.html fallback page

### Emails (25 templates — Resend)
- [ ] Welcome
- [ ] Verify email
- [ ] Password reset
- [ ] Purchase receipt (with license key + download link)
- [ ] Subscription receipt
- [ ] Expiry reminder (3 days before)
- [ ] Download ready
- [ ] Product updated (new version to buyers)
- [ ] Vendor approved
- [ ] Vendor sale notification
- [ ] Vendor payout processed
- [ ] Vendor rejection (with feedback)
- [ ] Affiliate commission earned
- [ ] Abandoned checkout recovery
- [ ] Drip day 1 / 3 / 7 / 14
- [ ] Dunning touch 1 / 2 / 3 / final
- [ ] Suspicious login alert
- [ ] Service request confirmation (buyer)
- [ ] Service request admin notification
- [ ] Weekly newsletter
- [ ] NPS survey
- [ ] Win-back (60-day inactive)
- [ ] License expiry reminder
- [ ] Annual recap (January)
- [ ] 2FA code

---

## PHASE 2 — REVENUE FOUNDATION

### Vendor System
- [ ] Vendor registration + step-by-step onboarding wizard
- [ ] Vendor dashboard (earnings, products, analytics)
- [ ] Product submission flow (upload, price, description, demo, screenshots)
- [ ] Admin product approval queue (approve/reject/revise)
- [ ] Revenue split system (platform 20-30%, vendor rest)
- [ ] Payout request system (Paystack + Stripe + LemonSqueezy)
- [ ] Vendor analytics dashboard (views, conversions, revenue)
- [ ] Vendor earnings forecast
- [ ] Conversion funnel per product (views → preview → purchase)
- [ ] Public vendor storefront (/vendor/[slug])
- [ ] "Follow a Seller" feature
- [ ] Seller Q&A on product pages
- [ ] Dispute resolution system
- [ ] Bulk product import (CSV/JSON)
- [ ] Seller webhook events (new purchase, review, payout)
- [ ] Seller API rate limit dashboard
- [ ] Vendor tier badges (Verified, Pro Seller, Top Contributor)
- [ ] Exclusive listing programme (85% revenue share)
- [ ] Listing quality score (0-100)
- [ ] Automated listing feedback on rejection
- [ ] Vendor earnings forecast at upload
- [ ] Vendor SLA dashboard
- [ ] Vendor academy (guides + videos)
- [ ] Verified Seller Badge (ID verification)
- [ ] CAC/business registry verification (Nigerian vendors)
- [ ] Vendor response time badge
- [ ] Canned responses for vendor support

### Vendor Financial Services
- [ ] Vendor earnings wallet
- [ ] Instant payouts (Paystack transfer on sale confirmed)
- [ ] Revenue advance for top vendors
- [ ] Tax reserve sub-wallet (auto-set aside %)
- [ ] Vendor earnings interest/yield (3-5% APY)

### Directory Hub
- [ ] Directory homepage (all 10 categories)
- [ ] 10 category pages (AI, Web Dev, Web3, Design, No-Code, Hosting, Plugins, Blockchain, Freelancer, Learning)
- [ ] Individual tool listing page (SEO indexed)
- [ ] Directory search + filter system
- [ ] Featured listing payment flow (all 3 gateways)
- [ ] Sponsored banner slots
- [ ] Affiliate link tracking per listing
- [ ] User ratings + reviews on listings
- [ ] "Submit a Tool" form + admin approval
- [ ] Compare Tools side-by-side
- [ ] Weekly "Top Tools" digest
- [ ] Internal linking (directory → related templates)

### Services & Leads (→ Tinlance)
- [ ] Services page (listing Tinlance capabilities)
- [ ] 6 service category selection
- [ ] Project brief form (budget, timeline, description, attachments)
- [ ] Service request confirmation email to buyer
- [ ] Service request admin notification
- [ ] Lead management in admin (view, respond, track status)
- [ ] CTA hook on every template page ("Need this customised?")
- [ ] Upsell hook at checkout ("Want us to install this?")

### Fraud Prevention
- [ ] Fraud risk scoring on registration + purchase
- [ ] Chargeback protection (track ratio, auto-hold payouts)
- [ ] Device fingerprinting on registration
- [ ] Velocity checks (flag abnormal download speed)
- [ ] Stolen card detection (IP vs billing address)
- [ ] Vendor fraud detection (plagiarised content)
- [ ] Content ID system (file hash comparison)
- [ ] Fraud dashboard in admin

### Messaging & Support
- [ ] Buyer-vendor direct messaging (post-purchase threads)
- [ ] Support ticket system (per purchase, SLA tracking)
- [ ] AI support auto-responder (Claude API first response)
- [ ] Canned responses for vendors

### Mobile Money (Phase 2 feature flag)
- [ ] MTN MoMo integration
- [ ] Airtel Money integration
- [ ] M-Pesa integration
- [ ] USSD payment option (*737# etc.)

### BNPL (Phase 2 feature flag)
- [ ] Carbon instalments integration
- [ ] FairMoney instalments integration
- [ ] 3-month instalment display at checkout

---

## PHASE 3 — GROWTH ENGINE

### Gamification
- [ ] Points system (earn for purchases, reviews, referrals, logins)
- [ ] Badges + achievements system
- [ ] Monthly leaderboard (buyers, sellers, reviewers)
- [ ] Seasonal challenges + contests
- [ ] Referral contest (top 3 monthly winners)
- [ ] Usage milestone celebrations ("10th download!")
- [ ] Annual recap email (January, Year in Review)
- [ ] Win-back campaign (60-day inactive users)
- [ ] Upgrade nudge (Free users viewing 5+ premium templates)
- [ ] Exit survey on subscription cancellation
- [ ] Review incentive programme (50 points for review)

### AI Features
- [ ] AI page generator ("generate landing page in 60 seconds")
- [ ] Editable in-browser template sandbox
- [ ] AI product description generator (vendor upload assist)
- [ ] AI pricing recommendation for vendors
- [ ] AI review summariser (10+ reviews → 2-sentence summary)
- [ ] AI chargeback predictor (pre-transaction risk score)
- [ ] AI semantic search (intent-based not just keywords)
- [ ] AI-powered homepage recommendations
- [ ] AI support auto-responder
- [ ] Multi-LLM fallback chain (Claude → Grok → Gemini → GPT-4o)

### Community
- [ ] Forum (categories, threads, replies, moderation)
- [ ] Forum Q&A sections (Show Your Builds, Web3 Dev Chat, etc.)
- [ ] Template showcase gallery ("Built with Web-Temify")
- [ ] Showcase submission form
- [ ] Platform-wide leaderboard page
- [ ] Template request system (buyers post requests, sellers bid)

### Courses (Phase 3 feature flag)
- [ ] Mini course builder for vendors
- [ ] Video lesson hosting (Supabase Storage player)
- [ ] Course progress tracking per user
- [ ] Prerequisite gating (lesson 2 before lesson 3)
- [ ] Quiz/assessment builder
- [ ] Certificate PDF auto-generation

### Crypto Payments (Phase 3 feature flag)
- [ ] NOWPayments USDT/USDC integration
- [ ] QR code + wallet address display at checkout
- [ ] 30-minute payment countdown timer
- [ ] Auto-convert to fiat on receipt
- [ ] Crypto refund = platform credits only policy

### Discovery Enhancements
- [ ] Visual/screenshot-based search
- [ ] "Collections by Use Case" curated pages
- [ ] "Complete the Kit" cross-sell engine
- [ ] Advanced filter system (tech stack, colour, page count, industry)
- [ ] Preview with real content (buyer types company name → live in preview)
- [ ] Tutorial video per template (60s walkthrough)

---

## PHASE 4 — SCALE & AUTOMATE

### Content Automation
- [ ] Python automation engine (Claude API → SEO blog drafts)
- [ ] Blog auto-generator (1500w SEO posts → admin draft)
- [ ] Directory auto-populator (Product Hunt + GitHub + RSS → draft listings)
- [ ] Programmatic SEO niche pages (auto-generated from DB keywords)

### Marketing & Analytics
- [ ] Affiliate marketplace (public page for affiliates to find products)
- [ ] Affiliate performance tiers (Starter → Silver → Gold → Platinum)
- [ ] Co-marketing system (vendor + platform joint promotions)
- [ ] A/B testing framework (pricing, copy, CTAs)
- [ ] Buyer LTV segmentation (Low/Medium/High/VIP)
- [ ] Product performance score (weekly automated)
- [ ] Revenue forecasting dashboard (ML-based MRR prediction)
- [ ] Traffic source heatmap (world map of buyers)
- [ ] ProductHunt-style launch system for vendor products
- [ ] Google Shopping product feed
- [ ] Seasonal promotion calendar

### B2B Features
- [ ] Agency client management portal
- [ ] Team collaboration on vendor accounts (roles)
- [ ] B2B bulk order system (quote request)
- [ ] Purchase Order (PO) support + NET15/NET30 terms
- [ ] Client onboarding checklist for agency users
- [ ] Volume licensing (single purchase → 10 client sites)
- [ ] Reseller programme (40% discount, white-label invoice)

### Platform Operations
- [ ] API key management for buyers (create/rotate/revoke)
- [ ] Staging environment for Business/Agency plan users
- [ ] Webhook testing tool in admin (send test payloads)
- [ ] Postman collection for API
- [ ] API versioning (/api/v1, /api/v2)
- [ ] SDK libraries (TypeScript + PHP)
- [ ] Uptime monitoring + status page (web-temify.com/status)
- [ ] Database health dashboard (slow queries, table sizes)
- [ ] Audit log export (CSV/JSON)
- [ ] Staged deployment checklist in admin

### Africa-Specific
- [ ] Diaspora payment support (GBP/CAD/AUD via Stripe → local currency)
- [ ] Africa timezone smart scheduling (WAT/EAT optimal send times)
- [ ] Naira pricing psychology (₦14,999 not ₦15,000)
- [ ] Multilingual support (Yoruba, Igbo, Hausa ticket routing)
- [ ] Low-bandwidth mode (simplified cards, text-only)
- [ ] WhatsApp Business integration (support chat)
- [ ] WhatsApp order notifications (download link on purchase)

---

## PHASE 5 — ENTERPRISE & GLOBAL

- [ ] SOC 2 readiness checklist in admin
- [ ] White-label platform option (multi-tenancy)
- [ ] Merchant of Record setup (global VAT handling)
- [ ] GDPR CMP v2 (IAB TCF 2.2 compliant)
- [ ] Revenue advance for top vendors
- [ ] Vendor yield on wallet balance (3-5% APY)
- [ ] iOS app (React Native)
- [ ] Android app (React Native)
- [ ] WCAG 2.2 Level AA full audit
- [ ] Screen reader optimisation (ARIA labels)
- [ ] Keyboard navigation complete
- [ ] High contrast mode
- [ ] Dyslexia-friendly font mode
- [ ] Redis caching for high-traffic queries
- [ ] Core Web Vitals dashboard (Google Search Console API)
- [ ] WebP auto-conversion on all uploads
- [ ] Critical CSS inlining
- [ ] Automated backup system

---

## PRODUCTS TO BUILD (44 total — separate build)

### Tier 1 — Build First (6)
- [ ] Courier & Logistics Template ($79–$199)
- [ ] Loan & Lending Template ($99–$249)
- [ ] NeoBank & Digital Banking Template ($99–$299)
- [ ] Digital Agency Pro Template ($49–$99)
- [ ] SaaS & Startup Landing Page ($49–$99)
- [ ] Portfolio & Freelancer Template ($29–$79)

### Tier 2 — Medium Term (12)
- [ ] P2P Crypto Trading Script ($299–$799)
- [ ] Online Banking Lite Script ($199–$499)
- [ ] Loan Management System Script ($199–$499)
- [ ] NFT Marketplace Template ($99–$249)
- [ ] Real Estate Listing Template ($79–$199)
- [ ] Invoice & Billing System Script ($149–$399)
- [ ] E-commerce Store Template ($79–$199)
- [ ] Restaurant & Food Delivery Template ($79–$199)
- [ ] Hospital & Clinic Template ($79–$199)
- [ ] School & Education Template ($79–$199)
- [ ] SaaS Admin Dashboard Template ($99–$249)
- [ ] POS System Script ($149–$399)

### Tier 3 — Later (16)
- [ ] CEX Lite Exchange Script ($499–$999)
- [ ] DeFi Dashboard Template ($199–$499)
- [ ] Fleet Management Script ($199–$499)
- [ ] Crowdfunding Platform Script ($199–$499)
- [ ] Crypto Trading Dashboard ($99–$249)
- [ ] Web3 dApp Landing Page ($79–$199)
- [ ] Blockchain Agency Template ($79–$199)
- [ ] Token Launch / ICO Script ($149–$399)
- [ ] Event Management & Ticketing ($99–$249)
- [ ] Multi-Vendor Marketplace Script ($299–$799)
- [ ] DAO Governance Template ($99–$249)
- [ ] LMS Lite Script ($149–$399)
- [ ] Pharmacy & Health Store Template ($79–$179)
- [ ] Construction & Architecture Template ($59–$149)
- [ ] Travel & Tour Agency Template ($59–$149)
- [ ] Ajo / Esusu Savings Script ($149–$399)

### Tier 4 — Launch Kits (4)
- [ ] SaaS Starter Kit ($299)
- [ ] Web3 DApp Starter Kit ($399)
- [ ] Fintech Launch Kit ($349)
- [ ] Agency Starter Kit ($249)

### Tier 5 — Africa Niche (6)
- [ ] Islamic Finance / Halal Banking Template ($99–$249)
- [ ] Agritech & Farm Marketplace Template ($79–$179)
- [ ] ISP & Telecom Company Template ($79–$179)
- [ ] Solar Energy & Power Company Template ($79–$179)
- [ ] Okada / Ride-Hailing App Landing ($59–$149)
- [ ] Ajo / Esusu Script — Africa Exclusive ($149–$399)

---

## DESIGN RULES — BUILDER CHECKLIST

For every page built, verify:
- [ ] Background is #fffbf4 (warm cream) — never pure white
- [ ] All cards have 2px solid #0f0d0a border
- [ ] All buttons have 2px solid border
- [ ] Hover lifts with 4px 4px 0 #0f0d0a box-shadow
- [ ] Dark mode works correctly
- [ ] Mobile responsive at 375px minimum
- [ ] RTL direction works
- [ ] Font is Cabinet Grotesk (not system font)
- [ ] Italic accents use Instrument Serif
- [ ] Coral (#ff5733) for primary CTAs only
- [ ] Yellow (#ffd60a) for badges and highlights
- [ ] Mint (#00c48c) for success states
- [ ] Loading skeleton shown while data fetches
- [ ] Error state shown when fetch fails
- [ ] Empty state shown when no results

---

## SECURITY CHECKLIST — BUILDER MUST FOLLOW

For every API route and server action:
- [ ] Verify user is authenticated (Supabase getUser)
- [ ] Validate all input with Zod schema
- [ ] Use Prisma for all DB queries (never raw SQL)
- [ ] Never expose service_role_key to client
- [ ] All webhook routes verify HMAC signature
- [ ] All download routes verify token ownership
- [ ] All admin routes check role = ADMIN/SUPER_ADMIN
- [ ] All vendor routes check vendor.status = ACTIVE
- [ ] All cron routes verify CRON_SECRET header
- [ ] Rate limit all public API endpoints
- [ ] Log security events to activity_log table
- [ ] Never log or expose API keys anywhere
