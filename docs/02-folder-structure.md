# WEB-TEMIFY — COMPLETE NEXT.JS FOLDER STRUCTURE
## Next.js 15 App Router + Supabase + Prisma
### Version 5.0 | May 2026

---

```
web-temify/
│
├── .env.local                              # Environment variables (never commit)
├── .env.example                            # Template (safe to commit)
├── .gitignore
├── next.config.ts                          # Next.js config
├── tailwind.config.ts                      # Design system tokens
├── tsconfig.json                           # TypeScript strict mode
├── prisma/
│   ├── schema.prisma                       # All 85 table definitions
│   ├── seed.ts                             # Seed plans, categories, badges
│   └── migrations/                         # Auto-generated migration files
│
├── supabase/
│   ├── config.toml                         # Supabase local config
│   ├── seed.sql                            # SQL seed data
│   └── migrations/                         # Supabase migration files
│       ├── 001_rls_policies.sql            # Row Level Security policies
│       ├── 002_functions.sql               # Postgres functions
│       └── 003_triggers.sql                # DB triggers (points, counters)
│
├── public/
│   ├── robots.txt
│   ├── sitemap.xml                         # Auto-generated
│   ├── manifest.json                       # PWA
│   ├── sw.js                               # Service worker
│   ├── offline.html                        # PWA fallback
│   └── fonts/                              # Self-hosted font fallbacks
│
└── src/
    │
    ├── app/                                # Next.js App Router
    │   │
    │   ├── layout.tsx                      # Root layout (fonts, themes, providers)
    │   ├── page.tsx                        # Homepage (/)
    │   ├── not-found.tsx                   # Custom 404
    │   ├── error.tsx                       # Error boundary
    │   ├── loading.tsx                     # Global loading skeleton
    │   ├── sitemap.ts                      # Dynamic sitemap generator
    │   ├── robots.ts                       # Dynamic robots.txt
    │   │
    │   ├── (marketing)/                    # Public marketing pages group
    │   │   ├── layout.tsx                  # Marketing layout (nav + footer)
    │   │   ├── about/page.tsx
    │   │   ├── pricing/page.tsx
    │   │   ├── changelog/page.tsx
    │   │   ├── roadmap/page.tsx
    │   │   ├── press/page.tsx
    │   │   ├── contact/page.tsx
    │   │   ├── status/page.tsx
    │   │   ├── advertise/page.tsx
    │   │   └── developer-hub/page.tsx
    │   │
    │   ├── (legal)/                        # Legal pages group
    │   │   ├── privacy/page.tsx
    │   │   ├── terms/page.tsx
    │   │   ├── cookie-policy/page.tsx
    │   │   ├── dmca/page.tsx
    │   │   ├── licenses/page.tsx
    │   │   └── refund-policy/page.tsx
    │   │
    │   ├── (auth)/                         # Auth pages group
    │   │   ├── layout.tsx                  # Auth layout (centered card)
    │   │   ├── login/page.tsx
    │   │   ├── register/page.tsx
    │   │   ├── forgot-password/page.tsx
    │   │   ├── reset-password/page.tsx
    │   │   ├── verify-email/page.tsx
    │   │   ├── 2fa-setup/page.tsx
    │   │   └── auth/callback/route.ts      # Supabase OAuth callback
    │   │
    │   ├── (marketplace)/                  # Public marketplace pages
    │   │   ├── layout.tsx                  # Marketplace layout
    │   │   ├── templates/
    │   │   │   ├── page.tsx                # /templates — listing + filters
    │   │   │   └── [category]/page.tsx     # /templates/fintech etc.
    │   │   ├── preview/
    │   │   │   └── [slug]/page.tsx         # /preview/neobank-pro
    │   │   ├── compare/page.tsx            # Side-by-side comparison
    │   │   ├── sandbox/page.tsx            # Editable preview sandbox
    │   │   ├── free/page.tsx               # Free templates
    │   │   ├── new-arrivals/page.tsx
    │   │   ├── trending/page.tsx
    │   │   ├── launch-kits/
    │   │   │   ├── page.tsx
    │   │   │   └── [slug]/page.tsx
    │   │   ├── web3/
    │   │   │   ├── page.tsx
    │   │   │   └── [category]/page.tsx
    │   │   ├── search/page.tsx
    │   │   └── niche/
    │   │       └── [slug]/page.tsx         # Programmatic SEO pages
    │   │
    │   ├── (directory)/                    # Tech directory
    │   │   ├── directory/
    │   │   │   ├── page.tsx                # Directory hub
    │   │   │   ├── [category]/page.tsx     # /directory/ai-tools
    │   │   │   ├── tool/
    │   │   │   │   └── [slug]/page.tsx     # Individual tool page
    │   │   │   ├── compare/page.tsx
    │   │   │   └── submit/page.tsx
    │   │
    │   ├── (blog)/                         # Blog
    │   │   ├── blog/
    │   │   │   ├── page.tsx
    │   │   │   ├── [slug]/page.tsx
    │   │   │   └── category/
    │   │   │       └── [cat]/page.tsx
    │   │
    │   ├── (community)/                    # Community
    │   │   ├── forum/
    │   │   │   ├── page.tsx
    │   │   │   ├── [category]/page.tsx
    │   │   │   ├── thread/
    │   │   │   │   └── [slug]/page.tsx
    │   │   │   └── new/page.tsx
    │   │   ├── showcase/
    │   │   │   ├── page.tsx
    │   │   │   └── submit/page.tsx
    │   │   └── leaderboard/page.tsx
    │   │
    │   ├── checkout/                       # Checkout flow
    │   │   ├── page.tsx                    # Main checkout
    │   │   ├── success/page.tsx
    │   │   └── failed/page.tsx
    │   │
    │   ├── pricing/page.tsx
    │   ├── services/
    │   │   ├── page.tsx
    │   │   └── request/page.tsx
    │   │
    │   ├── ai-generator/page.tsx           # AI page generator
    │   ├── affiliate/
    │   │   ├── page.tsx
    │   │   └── dashboard/page.tsx
    │   │
    │   ├── (dashboard)/                    # Protected user dashboard
    │   │   ├── layout.tsx                  # Dashboard layout (sidebar)
    │   │   ├── dashboard/page.tsx
    │   │   ├── my-downloads/page.tsx
    │   │   ├── my-purchases/page.tsx
    │   │   ├── my-collections/page.tsx
    │   │   ├── my-wishlist/page.tsx
    │   │   ├── my-subscription/page.tsx
    │   │   ├── my-invoices/page.tsx
    │   │   ├── my-licenses/page.tsx
    │   │   ├── points-rewards/page.tsx
    │   │   ├── badges/page.tsx
    │   │   ├── referrals/page.tsx
    │   │   ├── notifications/page.tsx
    │   │   ├── profile/
    │   │   │   ├── page.tsx
    │   │   │   └── edit/page.tsx
    │   │   ├── account-settings/page.tsx
    │   │   ├── data-export/page.tsx
    │   │   └── delete-account/page.tsx
    │   │
    │   ├── (vendor)/                       # Vendor portal
    │   │   ├── layout.tsx                  # Vendor layout (sidebar)
    │   │   ├── vendor/
    │   │   │   ├── register/page.tsx
    │   │   │   ├── dashboard/page.tsx
    │   │   │   ├── products/
    │   │   │   │   ├── page.tsx
    │   │   │   │   ├── new/page.tsx
    │   │   │   │   └── [id]/
    │   │   │   │       └── edit/page.tsx
    │   │   │   ├── analytics/page.tsx
    │   │   │   ├── payouts/page.tsx
    │   │   │   ├── wallet/page.tsx
    │   │   │   ├── messages/page.tsx
    │   │   │   ├── courses/
    │   │   │   │   ├── page.tsx
    │   │   │   │   └── new/page.tsx
    │   │   │   └── [slug]/page.tsx         # Public vendor storefront
    │   │
    │   ├── (admin)/                        # Admin panel
    │   │   ├── layout.tsx                  # Admin layout (sidebar)
    │   │   ├── admin/
    │   │   │   ├── page.tsx                # Dashboard (revenue, MRR, charts)
    │   │   │   ├── users/
    │   │   │   │   ├── page.tsx
    │   │   │   │   └── [id]/page.tsx
    │   │   │   ├── products/
    │   │   │   │   ├── page.tsx
    │   │   │   │   ├── new/page.tsx
    │   │   │   │   └── [id]/
    │   │   │   │       └── edit/page.tsx
    │   │   │   ├── vendors/
    │   │   │   │   ├── page.tsx
    │   │   │   │   └── [id]/page.tsx
    │   │   │   ├── directory/
    │   │   │   │   ├── page.tsx
    │   │   │   │   ├── new/page.tsx
    │   │   │   │   ├── [id]/edit/page.tsx
    │   │   │   │   └── submissions/page.tsx
    │   │   │   ├── orders/
    │   │   │   │   ├── page.tsx
    │   │   │   │   └── [id]/page.tsx
    │   │   │   ├── subscriptions/page.tsx
    │   │   │   ├── analytics/
    │   │   │   │   ├── page.tsx
    │   │   │   │   ├── geo/page.tsx
    │   │   │   │   ├── attribution/page.tsx
    │   │   │   │   └── cohort/page.tsx
    │   │   │   ├── email-campaigns/
    │   │   │   │   ├── page.tsx
    │   │   │   │   └── new/page.tsx
    │   │   │   ├── blog/
    │   │   │   │   ├── page.tsx
    │   │   │   │   ├── new/page.tsx
    │   │   │   │   └── [id]/edit/page.tsx
    │   │   │   ├── forum-moderation/page.tsx
    │   │   │   ├── reviews-moderation/page.tsx
    │   │   │   ├── showcase-moderation/page.tsx
    │   │   │   ├── gamification/
    │   │   │   │   ├── points/page.tsx
    │   │   │   │   ├── badges/page.tsx
    │   │   │   │   └── challenges/page.tsx
    │   │   │   ├── affiliates/page.tsx
    │   │   │   ├── fraud/page.tsx
    │   │   │   ├── chargebacks/page.tsx
    │   │   │   ├── service-requests/
    │   │   │   │   ├── page.tsx
    │   │   │   │   └── [id]/page.tsx
    │   │   │   ├── niche-pages/page.tsx
    │   │   │   ├── coupons/page.tsx
    │   │   │   ├── gift-cards/page.tsx
    │   │   │   ├── announcements/page.tsx
    │   │   │   ├── faqs/page.tsx
    │   │   │   ├── testimonials/page.tsx
    │   │   │   ├── roadmap/page.tsx
    │   │   │   ├── changelog/page.tsx
    │   │   │   ├── activity-log/page.tsx
    │   │   │   ├── export-reports/page.tsx
    │   │   │   └── settings/page.tsx
    │   │
    │   └── api/                            # API routes
    │       ├── auth/
    │       │   └── callback/route.ts       # Supabase auth callback
    │       ├── webhooks/
    │       │   ├── paystack/route.ts       # Paystack webhook
    │       │   ├── stripe/route.ts         # Stripe webhook
    │       │   ├── lemonsqueezy/route.ts   # LemonSqueezy webhook
    │       │   └── nowpayments/route.ts    # NOWPayments IPN (Phase 3)
    │       ├── v1/
    │       │   ├── templates/route.ts
    │       │   ├── categories/route.ts
    │       │   ├── me/route.ts
    │       │   ├── validate-license/route.ts
    │       │   ├── ai/
    │       │   │   ├── generate/route.ts   # AI page generator
    │       │   │   ├── search/route.ts     # Semantic search
    │       │   │   └── recommend/route.ts  # Recommendations
    │       │   └── social-share/route.ts
    │       ├── checkout/
    │       │   ├── paystack/route.ts
    │       │   ├── stripe/route.ts
    │       │   └── lemonsqueezy/route.ts
    │       ├── download/
    │       │   └── [token]/route.ts        # Secure file download
    │       ├── upload/route.ts             # File upload to Supabase Storage
    │       └── cron/                       # Vercel cron jobs
    │           ├── expiry-reminders/route.ts
    │           ├── auto-downgrade/route.ts
    │           ├── abandoned-checkout/route.ts
    │           ├── drip-emails/route.ts
    │           ├── dunning/route.ts
    │           ├── mrr-calculation/route.ts
    │           ├── win-back/route.ts
    │           ├── weekly-newsletter/route.ts
    │           ├── blog-autogenerate/route.ts
    │           ├── directory-autofill/route.ts
    │           ├── license-expiry/route.ts
    │           ├── flash-sale-expiry/route.ts
    │           ├── points-expiry/route.ts
    │           └── sponsored-reset/route.ts
    │
    ├── components/
    │   ├── ui/                             # shadcn/ui components
    │   │   ├── button.tsx
    │   │   ├── card.tsx
    │   │   ├── dialog.tsx
    │   │   ├── dropdown-menu.tsx
    │   │   ├── input.tsx
    │   │   ├── label.tsx
    │   │   ├── select.tsx
    │   │   ├── table.tsx
    │   │   ├── tabs.tsx
    │   │   ├── toast.tsx
    │   │   ├── badge.tsx
    │   │   ├── avatar.tsx
    │   │   ├── progress.tsx
    │   │   └── skeleton.tsx
    │   │
    │   ├── layout/
    │   │   ├── Navbar.tsx                  # Main navigation
    │   │   ├── Footer.tsx                  # Main footer
    │   │   ├── Sidebar.tsx                 # Dashboard sidebar
    │   │   ├── AdminSidebar.tsx            # Admin sidebar
    │   │   ├── VendorSidebar.tsx           # Vendor sidebar
    │   │   ├── Marquee.tsx                 # Coral scrolling strip
    │   │   ├── AnnouncementBanner.tsx      # Sitewide banner
    │   │   ├── CookieBanner.tsx            # GDPR cookie consent
    │   │   └── DarkModeToggle.tsx
    │   │
    │   ├── marketplace/
    │   │   ├── TemplateCard.tsx            # Product card with hover lift
    │   │   ├── TemplateGrid.tsx            # Grid with filters
    │   │   ├── FilterSidebar.tsx           # Advanced filters
    │   │   ├── SearchBar.tsx               # Autocomplete search
    │   │   ├── CategoryGrid.tsx            # 12 category cards
    │   │   ├── PreviewDevice.tsx           # Desktop/tablet/mobile switcher
    │   │   ├── CompareTable.tsx            # Side-by-side comparison
    │   │   ├── KitCard.tsx                 # Launch kit card
    │   │   ├── ReviewCard.tsx              # Product review
    │   │   ├── RatingStars.tsx
    │   │   ├── BadgeLabel.tsx              # Hot/New/Web3/Pro badges
    │   │   ├── PurchaseCounter.tsx         # "847 purchases" social proof
    │   │   ├── LivePurchaseToast.tsx       # "Someone just bought..."
    │   │   └── VideoPreview.tsx            # 60s demo video player
    │   │
    │   ├── checkout/
    │   │   ├── CheckoutForm.tsx            # Main checkout form
    │   │   ├── PaymentTabs.tsx             # All gateway tabs
    │   │   ├── PaystackButton.tsx
    │   │   ├── StripeButton.tsx
    │   │   ├── LemonSqueezyButton.tsx
    │   │   ├── CryptoPaymentBox.tsx        # NOWPayments QR (Phase 3)
    │   │   ├── CouponInput.tsx             # AJAX coupon validation
    │   │   ├── GiftCardInput.tsx
    │   │   ├── OrderSummary.tsx
    │   │   └── OrderBump.tsx               # Upsell at checkout
    │   │
    │   ├── directory/
    │   │   ├── DirectoryCard.tsx           # Tool listing card
    │   │   ├── DirectoryGrid.tsx
    │   │   ├── DirectoryTabs.tsx           # 10 category tabs
    │   │   ├── DirectorySearch.tsx
    │   │   └── DirectoryCompare.tsx
    │   │
    │   ├── vendor/
    │   │   ├── VendorCard.tsx              # Vendor storefront card
    │   │   ├── VendorSteps.tsx             # Onboarding wizard steps
    │   │   ├── ProductUploadForm.tsx       # Upload new template
    │   │   ├── EarningsChart.tsx           # Revenue chart
    │   │   ├── PayoutRequest.tsx
    │   │   ├── WalletBalance.tsx           # Earnings wallet
    │   │   └── QualityScore.tsx            # Listing quality 0-100
    │   │
    │   ├── dashboard/
    │   │   ├── StatsCard.tsx               # MRR, downloads, etc.
    │   │   ├── DownloadItem.tsx
    │   │   ├── InvoiceRow.tsx
    │   │   ├── LicenseCard.tsx
    │   │   ├── PointsBalance.tsx
    │   │   ├── BadgeGrid.tsx
    │   │   └── OnboardingChecklist.tsx     # PLG onboarding
    │   │
    │   ├── admin/
    │   │   ├── RevenueChart.tsx            # MRR/ARR Chart.js
    │   │   ├── UserTable.tsx
    │   │   ├── ProductTable.tsx
    │   │   ├── OrderTable.tsx
    │   │   ├── FraudDashboard.tsx
    │   │   ├── GeoHeatmap.tsx              # Sales by country
    │   │   └── ActivityLog.tsx
    │   │
    │   ├── community/
    │   │   ├── ForumThread.tsx
    │   │   ├── ForumReply.tsx
    │   │   ├── ShowcaseCard.tsx
    │   │   └── LeaderboardTable.tsx
    │   │
    │   ├── ai/
    │   │   ├── AiGeneratorBox.tsx          # 60-second page generator
    │   │   ├── AiChipSuggestions.tsx       # Example prompts
    │   │   └── GeneratedPagePreview.tsx
    │   │
    │   └── common/
    │       ├── SocialProofToast.tsx
    │       ├── PricingCard.tsx
    │       ├── TestimonialCard.tsx
    │       ├── StatBar.tsx                 # Hero stats
    │       ├── TrustBadges.tsx
    │       ├── MoneyBackBadge.tsx
    │       ├── PressBar.tsx                # "As seen in" logos
    │       └── CountUpNumber.tsx           # Animated counters
    │
    ├── lib/
    │   ├── supabase/
    │   │   ├── client.ts                   # Browser Supabase client
    │   │   ├── server.ts                   # Server Supabase client
    │   │   └── middleware.ts               # Auth middleware
    │   ├── prisma.ts                       # Prisma client singleton
    │   ├── stripe.ts                       # Stripe client
    │   ├── paystack.ts                     # Paystack helpers
    │   ├── lemonsqueezy.ts                 # LemonSqueezy helpers
    │   ├── nowpayments.ts                  # NOWPayments helpers (Phase 3)
    │   ├── ai-gateway.ts                   # Multi-LLM fallback service
    │   ├── claude.ts                       # Anthropic Claude client
    │   ├── grok.ts                         # xAI Grok client
    │   ├── gemini.ts                       # Google Gemini client
    │   ├── openai.ts                       # OpenAI client
    │   ├── resend.ts                       # Email service
    │   ├── license.ts                      # License key generation/validation
    │   ├── fraud.ts                        # Fraud risk scoring
    │   ├── gamification.ts                 # Points + badges logic
    │   ├── affiliate.ts                    # Affiliate tracking
    │   ├── storage.ts                      # Supabase Storage helpers
    │   ├── ppp.ts                          # PPP pricing by country
    │   ├── vat.ts                          # VAT/tax calculation
    │   ├── seo.ts                          # Meta tags + JSON-LD builder
    │   └── utils.ts                        # General utilities
    │
    ├── hooks/
    │   ├── useUser.ts                      # Current user state
    │   ├── useVendor.ts                    # Vendor state
    │   ├── useCart.ts                      # Cart state (Zustand)
    │   ├── useTheme.ts                     # Dark mode
    │   ├── useSearch.ts                    # Search with debounce
    │   ├── useWishlist.ts
    │   ├── useNotifications.ts             # Real-time bell notifications
    │   ├── usePoints.ts                    # Gamification
    │   └── useFeatureFlag.ts               # Feature flag checks
    │
    ├── stores/                             # Zustand stores
    │   ├── cart.store.ts
    │   ├── compare.store.ts                # Template comparison
    │   ├── notifications.store.ts
    │   └── ui.store.ts                     # Modals, sidebars, toasts
    │
    ├── types/
    │   ├── database.types.ts               # Auto-generated from Supabase
    │   ├── product.types.ts
    │   ├── user.types.ts
    │   ├── vendor.types.ts
    │   ├── order.types.ts
    │   ├── payment.types.ts
    │   └── api.types.ts
    │
    ├── actions/                            # Next.js Server Actions
    │   ├── auth.actions.ts                 # Login, register, logout
    │   ├── product.actions.ts              # CRUD products
    │   ├── checkout.actions.ts             # Process checkout
    │   ├── download.actions.ts             # Generate download token
    │   ├── vendor.actions.ts               # Vendor management
    │   ├── review.actions.ts               # Submit review
    │   ├── wishlist.actions.ts
    │   ├── gamification.actions.ts         # Award points
    │   └── admin.actions.ts               # Admin CRUD
    │
    ├── middleware.ts                       # Next.js middleware (auth guard)
    │
    └── styles/
        ├── globals.css                     # Tailwind + CSS variables
        ├── dark.css                        # Dark mode overrides
        └── rtl.css                         # RTL support
```

---

## VERCEL CRON JOBS (vercel.json)

```json
{
  "crons": [
    { "path": "/api/cron/expiry-reminders", "schedule": "0 */6 * * *" },
    { "path": "/api/cron/auto-downgrade", "schedule": "0 2 * * *" },
    { "path": "/api/cron/abandoned-checkout", "schedule": "0 3 * * *" },
    { "path": "/api/cron/drip-emails", "schedule": "0 4 * * *" },
    { "path": "/api/cron/dunning", "schedule": "0 5 * * *" },
    { "path": "/api/cron/win-back", "schedule": "0 8 * * *" },
    { "path": "/api/cron/mrr-calculation", "schedule": "0 0 * * *" },
    { "path": "/api/cron/license-expiry", "schedule": "0 9 * * *" },
    { "path": "/api/cron/flash-sale-expiry", "schedule": "0 10 * * *" },
    { "path": "/api/cron/points-expiry", "schedule": "0 1 * * *" },
    { "path": "/api/cron/weekly-newsletter", "schedule": "0 6 * * 1" },
    { "path": "/api/cron/sponsored-reset", "schedule": "0 7 * * 1" },
    { "path": "/api/cron/blog-autogenerate", "schedule": "0 3 * * *" },
    { "path": "/api/cron/directory-autofill", "schedule": "0 */4 * * *" }
  ]
}
```

---

## KEY PACKAGE LIST (package.json)

```json
{
  "dependencies": {
    "next": "15.x",
    "react": "19.x",
    "react-dom": "19.x",
    "typescript": "5.x",
    "@supabase/supabase-js": "^2.x",
    "@supabase/ssr": "^0.x",
    "@prisma/client": "^5.x",
    "prisma": "^5.x",
    "stripe": "^14.x",
    "@lemonsqueezy/lemonsqueezy-js": "^3.x",
    "anthropic": "^0.x",
    "zustand": "^4.x",
    "@tanstack/react-query": "^5.x",
    "react-hook-form": "^7.x",
    "zod": "^3.x",
    "@hookform/resolvers": "^3.x",
    "resend": "^3.x",
    "lucide-react": "^0.x",
    "next-themes": "^0.x",
    "sharp": "^0.x",
    "tailwindcss": "^3.x",
    "@tailwindcss/forms": "^0.x",
    "@tailwindcss/typography": "^0.x",
    "class-variance-authority": "^0.x",
    "clsx": "^2.x",
    "tailwind-merge": "^2.x",
    "date-fns": "^3.x",
    "recharts": "^2.x",
    "react-hot-toast": "^2.x",
    "framer-motion": "^11.x",
    "@radix-ui/react-dialog": "^1.x",
    "@radix-ui/react-dropdown-menu": "^2.x",
    "@radix-ui/react-tabs": "^1.x",
    "@radix-ui/react-select": "^2.x",
    "@radix-ui/react-toast": "^1.x"
  }
}
```
