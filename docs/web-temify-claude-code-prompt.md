> **LEGACY BUILD PROMPT — reviewed 2026-10-13.** This long-form prompt is historical requirements input, not an executable source of truth. It contains mixed framework, provider, payment, schema, and feature assumptions that may conflict with accepted ADRs and the current phase gates. Do not execute wholesale. Use current source, Supabase migrations, tests, `docs/roadmap/phase-gates.md`, and the canonical product manifest instead.

# WEB-TEMIFY — CLAUDE CODE MASTER BUILD PROMPT

## Complete PHP Platform Build Brief

### Version 3.0 | May 2026 | Pure PHP/MySQL

---

## HOW TO USE THIS PROMPT

Paste this entire document into Claude Code (or Claude Projects).
Build phase by phase. Each phase is self-contained and deployable.
Never skip the phase order — each phase depends on the previous.

---

## PROJECT OVERVIEW

**Product:** Web-Temify — A premium website template marketplace
**Company:** Web-Temify LTD (RC: 7999659) — Nigeria
**Sister company:** Tinlance Limited (RC: 7962164) — AI & cybersecurity engineering studio
**Domain:** web-temify.com
**Hosting:** Contabo VPS (Ubuntu, Apache, PHP 8.2+, MySQL 8.0+)
**Stack:** Pure PHP/MySQL — no framework, no Node.js, no Next.js
**CDN/Storage:** Supabase Storage (images, videos, screenshots, avatars)
**Positioning:** "From idea to deployable web product in hours"

---

## DESIGN SYSTEM (NEVER DEVIATE FROM THIS)

```
Background:     #fffbf4  (warm cream)
Ink/Text:       #0f0d0a  (near black)
Coral/Primary:  #ff5733  (main CTA colour)
Yellow/Accent:  #ffd60a  (badges, highlights)
Mint/Success:   #00c48c  (success states, checkmarks)
Sky/Info:       #4f8ef7  (info, Web3 elements)
Lilac/AI:       #c084fc  (AI features)
Surface:        #fff8ed  (card backgrounds)
Muted text:     #6b6559
Border:         2px solid #0f0d0a
Border radius:  2px–8px (brutalist, sharp)
Shadow hover:   4px 4px 0 #0f0d0a
Shadow large:   6px 6px 0 #0f0d0a

Fonts:
  Display/Headings: Cabinet Grotesk (900, 800, 700 weights)
  Italic accents:   Instrument Serif (italic)
  Monospace/labels: DM Mono

Design style:
  Brutalist editorial marketplace
  2px solid black borders on all cards and buttons
  Box-shadow hover lift effect on all interactive elements
  Warm cream background — NOT white, NOT dark
  Coral scrolling marquee strips between sections
  Dark ink (#0f0d0a) sections for "How it works" type content
  Yellow (#ffd60a) for featured/popular badges
  All buttons: border 2px solid ink, hover lifts with shadow

Reference design: web-temify-v3.html (already built homepage)
```

---

## URL STRUCTURE (.htaccess)

All .php extensions hidden. Clean URLs throughout.

```
/ → index.php
/templates → public/templates.php
/templates/[category] → public/templates.php?cat=[category]
/preview/[slug] → public/preview.php?slug=[slug]
/launch-kits → public/launch-kits.php
/web3 → public/web3.php
/directory → public/directory.php
/directory/[category] → public/directory-category.php?cat=[category]
/directory/tool/[slug] → public/directory-listing.php?slug=[slug]
/services → public/services.php
/blog → public/blog.php
/blog/[slug] → public/blog-post.php?slug=[slug]
/pricing → public/pricing.php
/login → public/login.php
/register → public/register.php
/dashboard → public/dashboard.php
/vendor → public/vendor-dashboard.php
/vendor/register → public/vendor-register.php
/admin → admin/index.php
/api/v1 → api/v1.php
/niche/[slug] → public/niche/[slug].php
```

---

## DATABASE SCHEMA (70 Tables)

### CORE TABLES

```sql
-- Users
users (id, email, password_hash, name, username, avatar, bio, role,
       plan, plan_expires_at, trial_ends_at, trial_charged, status,
       google_id, github_id, twitter_id, two_factor_secret,
       two_factor_enabled, login_attempts, locked_until,
       profile_score, points, dark_mode, language, timezone,
       currency, referral_code, referred_by, device_fingerprint,
       fraud_score, ip_address, terms_accepted_at, age_verified,
       created_at, updated_at)

-- Sessions
sessions (id, user_id, token, ip_address, user_agent, created_at, expires_at)

-- Templates / Products
products (id, vendor_id, name, slug, description, short_desc,
          category_id, type, tech_stack, page_count, difficulty,
          demo_url, download_file, file_version, file_hash,
          price, original_price, license_type, compatibility,
          color_scheme, industry_tags, status, featured,
          exclusive, quality_score, virus_scan_status,
          virus_scan_date, downloads, views, purchases,
          rating_avg, rating_count, created_at, updated_at)

-- Categories
categories (id, name, slug, description, icon, color, count, sort_order)

-- Orders
orders (id, user_id, vendor_id, product_id, plan_id, amount,
        currency, gateway, gateway_ref, gateway_status,
        license_key_id, coupon_id, fraud_score, ip_address,
        device_fingerprint, status, created_at)

-- Subscriptions
subscriptions (id, user_id, plan_id, gateway, gateway_sub_id,
               status, paused, pause_reason, current_period_start,
               current_period_end, cancel_at_period_end,
               grace_period_until, trial_end, created_at)

-- Plans
plans (id, name, slug, price_monthly, price_annual, features_json,
       template_limit, download_limit, api_access, team_seats,
       white_label, volume_licensing, sort_order, active)

-- Payments
payments (id, order_id, user_id, amount, currency, gateway,
          gateway_ref, gateway_response, status,
          idempotency_key, created_at)

-- Downloads
downloads (id, user_id, product_id, order_id, token, token_expires_at,
           downloaded_at, ip_address, count)

-- Reviews
reviews (id, user_id, product_id, order_id, rating, title, body,
         status, helpful_count, created_at)
```

### VENDOR TABLES

```sql
-- Vendors
vendors (id, user_id, business_name, slug, bio, avatar, banner,
         website, social_links_json, speciality_tags, verified,
         verified_at, id_document, tier, commission_rate,
         total_earnings, pending_earnings, response_time_avg,
         chargeback_rate, quality_score_avg, status, created_at)

-- Vendor Products (links vendors to products)
vendor_products (id, vendor_id, product_id, revenue_share,
                 exclusive, created_at)

-- Vendor Payouts
vendor_payouts (id, vendor_id, amount, currency, gateway,
                gateway_ref, status, requested_at, processed_at)

-- Vendor Analytics (daily snapshots)
vendor_analytics (id, vendor_id, product_id, date, views,
                  previews, purchases, revenue, conversion_rate)
```

### LICENSE TABLES

```sql
-- License Keys
license_keys (id, order_id, product_id, user_id, key_hash,
              license_type, activation_limit, activation_count,
              domains_json, expires_at, revoked, revoked_at,
              revoked_reason, created_at)

-- License Activations
license_activations (id, license_key_id, domain, ip_address,
                     user_agent, activated_at, deactivated_at,
                     active)
```

### DIRECTORY TABLES

```sql
-- Directory Listings
directory_listings (id, name, slug, tagline, description, url,
                    logo, category, pricing_tier, region,
                    affiliate_url, featured, featured_until,
                    sponsored, rating_avg, rating_count,
                    click_count, status, submitted_by,
                    approved_at, created_at)

-- Directory Categories
directory_categories (id, name, slug, icon, description, count)

-- Directory Reviews
directory_reviews (id, user_id, listing_id, rating, body,
                   status, created_at)
```

### COMMUNITY TABLES

```sql
-- Forum Categories
forum_categories (id, name, slug, description, icon, sort_order)

-- Forum Threads
forum_threads (id, user_id, category_id, title, slug, body,
               views, reply_count, pinned, locked,
               last_reply_at, created_at)

-- Forum Replies
forum_replies (id, thread_id, user_id, body, parent_id,
               helpful_count, created_at)

-- Showcase
showcase_entries (id, user_id, product_id, title, description,
                  screenshot_url, site_url, status,
                  likes, created_at)

-- Leaderboard
leaderboard_snapshots (id, user_id, vendor_id, period,
                       score, rank, category, created_at)
```

### GAMIFICATION TABLES

```sql
-- Points
user_points (id, user_id, points, action, reference_id,
             description, created_at)

-- Badges
badges (id, name, slug, description, icon, condition_type,
        condition_value, rarity)

-- User Badges
user_badges (id, user_id, badge_id, earned_at)

-- Challenges
challenges (id, title, description, reward_points,
            reward_credits, start_date, end_date,
            condition_type, condition_value, active)

-- Challenge Participants
challenge_participants (id, challenge_id, user_id,
                        progress, completed, completed_at)
```

### MESSAGING & SUPPORT TABLES

```sql
-- Messages (buyer-vendor)
messages (id, thread_id, sender_id, body, read_at, created_at)

-- Message Threads
message_threads (id, buyer_id, vendor_id, product_id,
                 order_id, last_message_at, created_at)

-- Support Tickets
support_tickets (id, user_id, vendor_id, order_id, product_id,
                 subject, status, priority, sla_due_at,
                 resolved_at, created_at)

-- Support Replies
support_replies (id, ticket_id, user_id, body, is_ai_generated,
                 created_at)
```

### COURSES TABLES

```sql
-- Courses
courses (id, vendor_id, product_id, title, description,
         thumbnail, price, free_with_purchase,
         lesson_count, duration_mins, status, created_at)

-- Lessons
course_lessons (id, course_id, title, body, video_url,
                duration_secs, sort_order, prerequisite_lesson_id)

-- Course Progress
course_progress (id, user_id, course_id, lesson_id,
                 completed, completed_at)

-- Quizzes
course_quizzes (id, lesson_id, questions_json, pass_score)

-- Quiz Attempts
quiz_attempts (id, user_id, quiz_id, answers_json,
               score, passed, attempted_at)

-- Certificates
certificates (id, user_id, course_id, issued_at, cert_uuid)
```

### SERVICES & LEADS TABLES

```sql
-- Service Requests
service_requests (id, user_id, product_id, category,
                  budget_range, timeline, description,
                  attachments_json, status, admin_notes,
                  contacted_at, converted_at, created_at)
```

### REMAINING TABLES

```sql
affiliate_links, affiliate_commissions, affiliate_tiers,
coupons, gift_cards, credits, wishlist, collections,
collection_items, notifications, activity_log,
email_campaigns, email_campaign_recipients, drip_sequences,
drip_steps, abandoned_checkouts, nps_responses,
announcement_banners, faqs, testimonials, roadmap_items,
changelog_entries, niche_pages, press_mentions,
ad_zones, outgoing_webhooks, vendor_webhooks,
api_keys, api_usage_log, fraud_flags, chargebacks,
search_log, zero_result_searches, page_views,
revenue_attribution, cohort_data, mobile_money_transactions,
bnpl_transactions, crypto_payments,
template_requests, showcase_likes, follow_vendors,
user_follows, product_comparisons, recently_viewed,
launch_kit_items, bundle_purchases
```

---

## COMPLETE FILE STRUCTURE

```
web-temify/
├── .htaccess
├── index.php
├── robots.txt
├── sitemap.xml
├── sitemap-html.php
├── manifest.json
├── sw.js
├── offline.html
│
├── /assets/
│   ├── /css/
│   │   ├── main.css
│   │   ├── dark.css
│   │   └── rtl.css
│   ├── /js/
│   │   ├── main.js
│   │   ├── checkout.js
│   │   ├── search.js
│   │   ├── compare.js
│   │   ├── sandbox.js
│   │   ├── ai-generator.js
│   │   └── analytics.js
│   └── /images/icons/
│
├── /includes/
│   ├── db.php
│   ├── auth.php
│   ├── functions.php
│   ├── security.php
│   ├── payments.php
│   ├── paystack.php
│   ├── stripe.php
│   ├── lemonsqueezy.php
│   ├── mobilemoney.php
│   ├── bnpl.php
│   ├── nowpayments.php
│   ├── email.php
│   ├── upload.php
│   ├── supabase.php
│   ├── seo.php
│   ├── ppp.php
│   ├── vat.php
│   ├── i18n.php
│   ├── search.php
│   ├── recommendations.php
│   ├── gamification.php
│   ├── affiliate.php
│   ├── notifications.php
│   ├── activity.php
│   ├── license.php
│   ├── fraud.php
│   └── header.php / footer.php
│
├── /public/
│   ├── templates.php
│   ├── preview.php
│   ├── compare.php
│   ├── collections.php
│   ├── wishlist.php
│   ├── search-results.php
│   ├── free.php
│   ├── new-arrivals.php
│   ├── trending.php
│   ├── sandbox.php
│   ├── launch-kits.php
│   ├── kit-detail.php
│   ├── web3.php
│   ├── web3-category.php
│   ├── directory.php
│   ├── directory-category.php
│   ├── directory-listing.php
│   ├── directory-compare.php
│   ├── directory-submit.php
│   ├── services.php
│   ├── service-request.php
│   ├── service-confirmation.php
│   ├── ai-generator.php
│   ├── pricing.php
│   ├── checkout.php
│   ├── checkout-guest.php
│   ├── order-summary.php
│   ├── order-bump.php
│   ├── payment-success.php
│   ├── payment-failed.php
│   ├── invoice.php
│   ├── gift-card.php
│   ├── coupon.php
│   ├── download.php
│   ├── login.php
│   ├── register.php
│   ├── logout.php
│   ├── forgot-password.php
│   ├── reset-password.php
│   ├── verify-email.php
│   ├── 2fa-setup.php
│   ├── 2fa-verify.php
│   ├── social-login.php
│   ├── oauth-callback.php
│   ├── dashboard.php
│   ├── my-downloads.php
│   ├── my-purchases.php
│   ├── my-collections.php
│   ├── my-wishlist.php
│   ├── my-subscription.php
│   ├── my-invoices.php
│   ├── refund-request.php
│   ├── profile.php
│   ├── profile-edit.php
│   ├── account-settings.php
│   ├── notifications.php
│   ├── points-rewards.php
│   ├── badges.php
│   ├── referrals.php
│   ├── data-export.php
│   ├── delete-account.php
│   ├── onboarding.php
│   ├── vendor-register.php
│   ├── vendor-dashboard.php
│   ├── vendor-products.php
│   ├── vendor-upload.php
│   ├── vendor-edit-product.php
│   ├── vendor-analytics.php
│   ├── vendor-payouts.php
│   ├── vendor-profile.php
│   ├── vendor-import.php
│   ├── vendor-webhooks.php
│   ├── vendor-api-usage.php
│   ├── become-designer.php
│   ├── affiliate.php
│   ├── affiliate-dashboard.php
│   ├── affiliate-leaderboard.php
│   ├── blog.php
│   ├── blog-post.php
│   ├── blog-category.php
│   ├── forum.php
│   ├── forum-category.php
│   ├── forum-thread.php
│   ├── forum-new-thread.php
│   ├── showcase.php
│   ├── showcase-submit.php
│   ├── leaderboard.php
│   ├── developer-hub.php
│   ├── api-docs.php
│   ├── code-snippets.php
│   ├── component-library.php
│   ├── advertise.php
│   ├── /niche/ (auto-generated SEO pages)
│   ├── about.php
│   ├── roadmap.php
│   ├── changelog.php
│   ├── status.php
│   ├── press.php
│   ├── contact.php
│   ├── privacy.php
│   ├── terms.php
│   ├── cookie-policy.php
│   ├── cookie-preferences.php
│   ├── dmca.php
│   ├── licenses.php
│   ├── refund-policy.php
│   ├── unsubscribe.php
│   ├── nps.php
│   └── 404.php
│
├── /admin/
│   ├── index.php
│   ├── templates.php / template-add.php / template-edit.php
│   ├── template-versions.php / template-scan.php
│   ├── users.php / user-detail.php / user-impersonate.php
│   ├── user-import.php
│   ├── vendors.php / vendor-detail.php
│   ├── vendor-payouts.php / vendor-disputes.php
│   ├── directory.php / directory-add.php / directory-edit.php
│   ├── directory-submissions.php / directory-featured.php
│   ├── orders.php / order-detail.php
│   ├── subscriptions.php / refunds.php
│   ├── coupons.php / gift-cards.php / credits.php
│   ├── abandoned-checkouts.php / revenue-attribution.php
│   ├── service-requests.php / service-request-detail.php
│   ├── analytics.php / analytics-geo.php
│   ├── analytics-templates.php / analytics-search.php
│   ├── analytics-attribution.php / analytics-cohort.php
│   ├── email-campaigns.php / email-campaign-new.php
│   ├── email-templates.php / email-drip.php
│   ├── email-bounces.php / mailchimp-sync.php
│   ├── blog.php / blog-new.php / blog-edit.php
│   ├── blog-categories.php
│   ├── forum-moderation.php / showcase-moderation.php
│   ├── reviews-moderation.php
│   ├── points.php / badges.php / challenges.php
│   ├── leaderboard.php
│   ├── affiliates.php / affiliate-commissions.php
│   ├── announcements.php / faqs.php / testimonials.php
│   ├── roadmap-admin.php / changelog-admin.php
│   ├── niche-pages.php
│   ├── settings.php / integrations.php / ad-zones.php
│   ├── webhooks-outgoing.php / activity-log.php
│   ├── error-log.php / export-reports.php
│   ├── image-optimiser.php / update-checker.php
│   ├── roles.php / admin-2fa.php
│   └── fraud-dashboard.php / chargeback-manager.php
│
├── /api/
│   ├── v1.php
│   ├── webhooks-paystack.php
│   ├── webhooks-stripe.php
│   ├── webhooks-lemonsqueezy.php
│   ├── webhooks-mobilemoney.php
│   ├── webhooks-nowpayments.php
│   ├── ai-generate.php
│   ├── ai-search.php
│   ├── ai-recommendations.php
│   ├── validate-license.php
│   ├── publish-post.php
│   ├── publish-directory.php
│   ├── social-share.php
│   └── /oauth/google.php / github.php / twitter.php
│
├── /cron/
│   ├── expiry-reminders.php
│   ├── auto-downgrade.php
│   ├── abandoned-checkout.php
│   ├── drip-emails.php
│   ├── weekly-reset.php
│   ├── token-cleanup.php
│   ├── profile-scores.php
│   ├── mrr-calculation.php
│   ├── free-trial-charge.php
│   ├── dunning.php
│   ├── bounce-handler.php
│   ├── directory-autofill.php
│   ├── blog-autogenerate.php
│   ├── nps-trigger.php
│   ├── points-expiry.php
│   ├── weekly-newsletter.php
│   ├── win-back-campaign.php
│   ├── license-expiry-reminders.php
│   ├── flash-sale-expiry.php
│   └── sponsored-placement-reset.php
│
├── /automation/
│   ├── content_engine.py
│   ├── blog_generator.py
│   ├── directory_populator.py
│   ├── requirements.txt
│   └── config.example.env
│
├── /languages/
│   ├── en.php / fr.php / es.php / pt.php
│
├── /email-templates/
│   (25 HTML email templates — see email section below)
│
├── /uploads/
│   ├── /templates/
│   ├── /previews/ → Supabase
│   ├── /screenshots/ → Supabase
│   ├── /videos/ → Supabase
│   ├── /avatars/ → Supabase
│   ├── /vendor-docs/ (encrypted)
│   └── /press/
│
├── /database/
│   ├── schema.sql
│   ├── seed.sql
│   └── /migrations/
│       ├── 001_initial.sql
│       ├── 002_vendor_system.sql
│       ├── 003_directory.sql
│       ├── 004_gamification.sql
│       ├── 005_community.sql
│       ├── 006_mobile_money.sql
│       ├── 007_services_leads.sql
│       ├── 008_ai_features.sql
│       ├── 009_license_keys.sql
│       ├── 010_fraud_prevention.sql
│       ├── 011_messaging_support.sql
│       ├── 012_courses.sql
│       └── 013_crypto_payments.sql
│
├── /config/
│   ├── config.php
│   ├── config.example.php
│   └── .env.example
│
└── /docs/
    ├── API.md
    ├── DEPLOYMENT.md
    ├── CRON-SETUP.md
    └── SUPABASE-SETUP.md
```

---

## CONFIG VARIABLES (config.php)

```php
<?php
// Database
define('DB_HOST', getenv('DB_HOST') ?: 'localhost');
define('DB_NAME', getenv('DB_NAME') ?: 'webtemify');
define('DB_USER', getenv('DB_USER') ?: 'root');
define('DB_PASS', getenv('DB_PASS') ?: '');

// Site
define('SITE_URL', getenv('SITE_URL') ?: 'https://web-temify.com');
define('SITE_NAME', 'Web-Temify');
define('SITE_EMAIL', 'hello@web-temify.com');
define('ADMIN_EMAIL', 'nwachukwuchinaemerem8@gmail.com');
define('ENVIRONMENT', getenv('ENVIRONMENT') ?: 'production');

// Payments — Paystack
define('PAYSTACK_PUBLIC_KEY', getenv('PAYSTACK_PUBLIC_KEY'));
define('PAYSTACK_SECRET_KEY', getenv('PAYSTACK_SECRET_KEY'));
define('PAYSTACK_WEBHOOK_SECRET', getenv('PAYSTACK_WEBHOOK_SECRET'));

// Payments — Stripe
define('STRIPE_PUBLIC_KEY', getenv('STRIPE_PUBLIC_KEY'));
define('STRIPE_SECRET_KEY', getenv('STRIPE_SECRET_KEY'));
define('STRIPE_WEBHOOK_SECRET', getenv('STRIPE_WEBHOOK_SECRET'));

// Payments — LemonSqueezy
define('LEMONSQUEEZY_API_KEY', getenv('LEMONSQUEEZY_API_KEY'));
define('LEMONSQUEEZY_STORE_ID', getenv('LEMONSQUEEZY_STORE_ID'));
define('LEMONSQUEEZY_WEBHOOK_SECRET', getenv('LEMONSQUEEZY_WEBHOOK_SECRET'));

// Payments — NOWPayments (USDT/USDC)
define('NOWPAYMENTS_API_KEY', getenv('NOWPAYMENTS_API_KEY'));
define('NOWPAYMENTS_IPN_SECRET', getenv('NOWPAYMENTS_IPN_SECRET'));

// Payments — Mobile Money
define('MOMO_API_KEY', getenv('MOMO_API_KEY'));
define('MOMO_SUBSCRIPTION_KEY', getenv('MOMO_SUBSCRIPTION_KEY'));

// Storage — Supabase
define('SUPABASE_URL', getenv('SUPABASE_URL'));
define('SUPABASE_ANON_KEY', getenv('SUPABASE_ANON_KEY'));
define('SUPABASE_SERVICE_KEY', getenv('SUPABASE_SERVICE_KEY'));
define('SUPABASE_BUCKET_PREVIEWS', 'template-previews');
define('SUPABASE_BUCKET_VIDEOS', 'template-videos');
define('SUPABASE_BUCKET_AVATARS', 'user-avatars');

// Email — PHPMailer / SMTP
define('SMTP_HOST', getenv('SMTP_HOST'));
define('SMTP_USER', getenv('SMTP_USER'));
define('SMTP_PASS', getenv('SMTP_PASS'));
define('SMTP_PORT', getenv('SMTP_PORT') ?: 587);
define('SMTP_FROM_NAME', 'Web-Temify');
define('SMTP_FROM_EMAIL', 'hello@web-temify.com');

// Claude API (AI features)
define('ANTHROPIC_API_KEY', getenv('ANTHROPIC_API_KEY'));
define('CLAUDE_MODEL', 'claude-sonnet-4-20250514');

// OAuth
define('GOOGLE_CLIENT_ID', getenv('GOOGLE_CLIENT_ID'));
define('GOOGLE_CLIENT_SECRET', getenv('GOOGLE_CLIENT_SECRET'));
define('GITHUB_CLIENT_ID', getenv('GITHUB_CLIENT_ID'));
define('GITHUB_CLIENT_SECRET', getenv('GITHUB_CLIENT_SECRET'));
define('TWITTER_CLIENT_ID', getenv('TWITTER_CLIENT_ID'));
define('TWITTER_CLIENT_SECRET', getenv('TWITTER_CLIENT_SECRET'));

// Security
define('CSRF_SECRET', getenv('CSRF_SECRET'));
define('JWT_SECRET', getenv('JWT_SECRET'));
define('ENCRYPTION_KEY', getenv('ENCRYPTION_KEY'));
define('ADMIN_IP_WHITELIST', explode(',', getenv('ADMIN_IP_WHITELIST') ?: ''));
define('HIGH_VALUE_CHECKOUT_THRESHOLD', 200); // USD

// VirusTotal
define('VIRUSTOTAL_API_KEY', getenv('VIRUSTOTAL_API_KEY'));

// Integrations
define('GTM_ID', getenv('GTM_ID') ?: 'GTM-XXXXXXX');
define('CLARITY_ID', getenv('CLARITY_ID'));
define('MAILCHIMP_API_KEY', getenv('MAILCHIMP_API_KEY'));
define('MAILCHIMP_LIST_ID', getenv('MAILCHIMP_LIST_ID'));
define('TAWK_PROPERTY_ID', getenv('TAWK_PROPERTY_ID'));

// Feature flags
define('FEATURE_CRYPTO_PAYMENTS', false); // Enable in Phase 3
define('FEATURE_MOBILE_MONEY', false);    // Enable in Phase 2
define('FEATURE_COURSES', false);         // Enable in Phase 3
define('FEATURE_FORUM', false);           // Enable in Phase 3
define('FEATURE_AI_GENERATOR', false);    // Enable in Phase 3
```

---

## PAYMENT GATEWAYS — COMPLETE SPEC

### Rule: ALL payment flows must offer ALL enabled gateways

**Phase 1 (Live now):** Paystack + Stripe + LemonSqueezy
**Phase 2 (Add):** MTN MoMo + Airtel Money + M-Pesa + Carbon BNPL + FairMoney BNPL
**Phase 3 (Add):** USDT/USDC via NOWPayments (auto-convert, no volatile crypto)

### Checkout Flow (applies to ALL payment flows)

```
1. Order summary displayed (items, subtotal, tax, discount, total)
2. Coupon code field (AJAX validation)
3. Gift card redemption field
4. For purchases > $200: require 2FA confirmation
5. Payment method tabs: [Paystack] [Stripe] [LemonSqueezy] [Crypto*] [Mobile Money*] [Pay Later*]
   (* = only shown when feature flag enabled)
6. On success: generate license key (if script/plugin), send receipt email,
   trigger download token, log to activity log, award points
7. On failure: log fraud flag, show retry options
```

### Paystack Integration

```php
// Always verify webhook HMAC:
$hash = hash_hmac('sha512', $payload, PAYSTACK_WEBHOOK_SECRET);
if ($hash !== $_SERVER['HTTP_X_PAYSTACK_SIGNATURE']) { die('Invalid'); }

// Events to handle:
// charge.success → complete order
// subscription.create → activate subscription
// subscription.disable → cancel subscription
// charge.dispute.create → open chargeback record
// transfer.success → vendor payout confirmed
```

### Stripe Integration

```php
// Verify webhook:
$event = \Stripe\Webhook::constructEvent($payload, $sig, STRIPE_WEBHOOK_SECRET);

// Events to handle:
// payment_intent.succeeded → complete order
// customer.subscription.created → activate
// customer.subscription.deleted → cancel
// charge.dispute.created → open chargeback
// payout.paid → vendor payout confirmed
```

### LemonSqueezy Integration

```php
// Verify webhook HMAC:
$hash = hash_hmac('sha256', $payload, LEMONSQUEEZY_WEBHOOK_SECRET);

// Events to handle:
// order_created → complete order
// subscription_created → activate
// subscription_cancelled → cancel
// subscription_payment_failed → dunning
```

### NOWPayments (Crypto — Phase 3)

```php
// Auto-convert USDT/USDC to fiat
// IPN verification:
$sig = hash_hmac('sha512', $sorted_payload, NOWPAYMENTS_IPN_SECRET);

// Flow:
// 1. Create payment → get payment address + QR code
// 2. Show to buyer with 30-minute countdown
// 3. On IPN confirmed → complete order (same as card)
// 4. No refunds on-chain — platform credits only
// Accepted: USDT (TRC-20), USDC (TRC-20, ERC-20)
// No BTC, ETH, SOL, or volatile coins
```

---

## SECURITY REQUIREMENTS

Apply to EVERY file:

```php
// 1. Session security (in auth.php)
session_start();
session_regenerate_id(true);
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.cookie_samesite', 'Strict');

// 2. CSRF on every form
function generate_csrf(): string {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}
function verify_csrf(string $token): bool {
    return hash_equals($_SESSION['csrf_token'] ?? '', $token);
}

// 3. All DB queries — PDO prepared statements ONLY
// Never: "SELECT * FROM users WHERE id = " . $_GET['id']
// Always: $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");

// 4. Rate limiting (in security.php)
// Login: 5 attempts / 15 minutes
// Register: 3 attempts / hour
// Checkout: 10 attempts / hour
// API: 100 requests / hour
// Download: 20 per day per user

// 5. Input sanitization
function clean(string $input): string {
    return htmlspecialchars(strip_tags(trim($input)), ENT_QUOTES, 'UTF-8');
}

// 6. Output encoding — always htmlspecialchars() on display
// 7. File uploads — validate MIME type + extension + size + VirusTotal scan
// 8. Admin panel — check IP whitelist + require 2FA
// 9. Download tokens — expire after 24h, single-use
// 10. Honeypot field on all public forms
```

---

## EMAIL TEMPLATES REQUIRED (25 total)

All emails use Cabinet Grotesk font, coral brand colour.
All emails include unsubscribe link and List-Unsubscribe header.

1. welcome.html — After registration
2. verify-email.html — Email verification
3. password-reset.html — Password reset
4. purchase-receipt.html — After purchase (includes license key if applicable)
5. subscription-receipt.html — New subscription
6. expiry-reminder.html — 3 days before plan expires
7. download-ready.html — Download is ready
8. product-updated.html — Buyer notified of new version
9. vendor-approved.html — Vendor product approved
10. vendor-sale.html — Vendor makes a sale
11. vendor-payout.html — Vendor payout processed
12. affiliate-commission.html — Affiliate earns commission
13. abandoned-checkout.html — Abandoned checkout recovery
14. drip-1.html / drip-3.html / drip-7.html / drip-14.html — Drip sequence
15. dunning-1.html / dunning-2.html / dunning-3.html / dunning-final.html — Failed payment
16. suspicious-login.html — Suspicious login alert
17. service-request-confirm.html — Service request received (to buyer)
18. service-request-admin.html — New lead notification (to admin)
19. newsletter-weekly.html — Weekly newsletter
20. nps-survey.html — NPS survey
21. win-back.html — 60-day inactive user re-engagement
22. license-expiry.html — License expiring in 30 days
23. annual-recap.html — Year in review (January)
24. vendor-rejection.html — Product rejected with feedback
25. 2fa-code.html — 2FA verification code email

---

## CRON JOB SCHEDULE

```
* * * * *   php /var/www/web-temify/cron/token-cleanup.php
0 */6 * * * php /var/www/web-temify/cron/expiry-reminders.php
0 2 * * *   php /var/www/web-temify/cron/auto-downgrade.php
0 3 * * *   php /var/www/web-temify/cron/abandoned-checkout.php
0 4 * * *   php /var/www/web-temify/cron/drip-emails.php
0 5 * * *   php /var/www/web-temify/cron/dunning.php
0 6 * * *   php /var/www/web-temify/cron/bounce-handler.php
0 7 * * *   php /var/www/web-temify/cron/nps-trigger.php
0 8 * * *   php /var/www/web-temify/cron/win-back-campaign.php
0 9 * * *   php /var/www/web-temify/cron/license-expiry-reminders.php
0 10 * * *  php /var/www/web-temify/cron/flash-sale-expiry.php
0 0 * * *   php /var/www/web-temify/cron/mrr-calculation.php
0 0 * * *   php /var/www/web-temify/cron/profile-scores.php
0 0 * * *   php /var/www/web-temify/cron/points-expiry.php
0 1 * * 1   php /var/www/web-temify/cron/weekly-reset.php
0 6 * * 1   php /var/www/web-temify/cron/weekly-newsletter.php
0 7 * * 1   php /var/www/web-temify/cron/sponsored-placement-reset.php
0 2 1 * *   php /var/www/web-temify/cron/free-trial-charge.php
0 */4 * * * python3 /var/www/web-temify/automation/directory_populator.py
0 3 * * *   python3 /var/www/web-temify/automation/blog_generator.py
```

---

## AI INTEGRATION (Claude API)

Use for these features:

```php
// 1. AI page generator (api/ai-generate.php)
// Input: business description + niche
// Output: complete HTML landing page
// Model: claude-sonnet-4-20250514
// Max tokens: 4000

// 2. Semantic search (api/ai-search.php)
// Input: user query string
// Output: search intent + expanded keywords
// Model: claude-sonnet-4-20250514

// 3. AI recommendations (api/ai-recommendations.php)
// Input: user browsing history + plan + past purchases
// Output: ranked product IDs with reasoning

// 4. AI support auto-responder (support_replies)
// Input: ticket body + product FAQ + product description
// Output: draft response for vendor to review

// 5. AI product description (vendor-upload.php)
// Input: product name + category + tags
// Output: draft description + SEO meta

// 6. Directory auto-populate (automation/directory_populator.py)
// Input: tool name + website URL
// Output: structured listing data

// 7. Blog auto-generate (automation/blog_generator.py)
// Input: target keyword + category
// Output: 1500-word SEO blog post (saved as draft)
```

---

## PYTHON AUTOMATION ENGINE

```python
# automation/content_engine.py

import anthropic
import requests
import os
from datetime import datetime

client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))

SITE_API_URL = os.getenv('SITE_URL') + '/api'
SITE_API_KEY = os.getenv('INTERNAL_API_KEY')

def generate_blog_post(keyword: str, category: str) -> dict:
    """Generate SEO blog post and publish as draft."""
    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4000,
        messages=[{
            "role": "user",
            "content": f"""Write a 1500-word SEO blog post for web-temify.com.

Topic: {keyword}
Category: {category}
Brand voice: Professional, helpful, developer-focused. Africa-first perspective.
Target audience: Developers, agencies, founders in Africa and globally.

Requirements:
- Target keyword: {keyword}
- Include H2 subheadings
- Include internal link suggestions to [TEMPLATE_LINK]
- Include meta title (60 chars max) and meta description (160 chars max)
- End with CTA to browse Web-Temify templates

Return as JSON:
{{
  "title": "...",
  "meta_title": "...",
  "meta_description": "...",
  "body": "HTML content...",
  "tags": ["tag1", "tag2"],
  "category_slug": "..."
}}"""
        }]
    )
    return json.loads(message.content[0].text)

def populate_directory_listing(tool_name: str, url: str) -> dict:
    """Generate directory listing for a tool."""
    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        messages=[{
            "role": "user",
            "content": f"""Create a directory listing for web-temify.com's tech directory.

Tool: {tool_name}
URL: {url}

Return as JSON:
{{
  "name": "...",
  "tagline": "...(max 80 chars)",
  "description": "...(150-200 words)",
  "category": "ai|webdev|web3|design|nocode|hosting|plugins|blockchain|freelancer|learning",
  "pricing_tier": "free|freemium|paid",
  "tags": ["tag1", "tag2", "tag3"]
}}"""
        }]
    )
    return json.loads(message.content[0].text)

def publish_post_to_site(post_data: dict) -> bool:
    """Publish blog post as draft via internal API."""
    response = requests.post(
        f"{SITE_API_URL}/publish-post.php",
        json=post_data,
        headers={"Authorization": f"Bearer {SITE_API_KEY}"}
    )
    return response.status_code == 200

def publish_listing_to_site(listing_data: dict) -> bool:
    """Publish directory listing as draft."""
    response = requests.post(
        f"{SITE_API_URL}/publish-directory.php",
        json=listing_data,
        headers={"Authorization": f"Bearer {SITE_API_KEY}"}
    )
    return response.status_code == 200
```

---

## .htaccess — COMPLETE

```apache
Options -Indexes
ServerSignature Off

# Security headers
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://www.googletagmanager.com https://js.stripe.com https://widget.tawk.to; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https://*.supabase.co https://www.gravatar.com; connect-src 'self' https://api.anthropic.com https://*.supabase.co https://api.paystack.co; frame-src https://js.stripe.com https://hooks.stripe.com;"

# Force HTTPS
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Remove trailing slash
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)/$ /$1 [L,R=301]

# Remove .php extension
RewriteCond %{REQUEST_FILENAME} !-d
RewriteCond %{REQUEST_FILENAME}\.php -f
RewriteRule ^([^\.]+)$ $1.php [NC,L]

# Public pages
RewriteRule ^templates/?$ /public/templates.php [L]
RewriteRule ^templates/([a-z0-9-]+)/?$ /public/templates.php?cat=$1 [L,QSA]
RewriteRule ^preview/([a-z0-9-]+)/?$ /public/preview.php?slug=$1 [L]
RewriteRule ^launch-kits/?$ /public/launch-kits.php [L]
RewriteRule ^launch-kits/([a-z0-9-]+)/?$ /public/kit-detail.php?slug=$1 [L]
RewriteRule ^web3/?$ /public/web3.php [L]
RewriteRule ^web3/([a-z0-9-]+)/?$ /public/web3-category.php?cat=$1 [L]
RewriteRule ^directory/?$ /public/directory.php [L]
RewriteRule ^directory/([a-z0-9-]+)/?$ /public/directory-category.php?cat=$1 [L]
RewriteRule ^directory/tool/([a-z0-9-]+)/?$ /public/directory-listing.php?slug=$1 [L]
RewriteRule ^services/?$ /public/services.php [L]
RewriteRule ^blog/?$ /public/blog.php [L]
RewriteRule ^blog/([a-z0-9-]+)/?$ /public/blog-post.php?slug=$1 [L]
RewriteRule ^blog/category/([a-z0-9-]+)/?$ /public/blog-category.php?cat=$1 [L]
RewriteRule ^pricing/?$ /public/pricing.php [L]
RewriteRule ^login/?$ /public/login.php [L]
RewriteRule ^register/?$ /public/register.php [L]
RewriteRule ^logout/?$ /public/logout.php [L]
RewriteRule ^dashboard/?$ /public/dashboard.php [L]
RewriteRule ^vendor/?$ /public/vendor-dashboard.php [L]
RewriteRule ^vendor/register/?$ /public/vendor-register.php [L]
RewriteRule ^vendor/([a-z0-9-]+)/?$ /public/vendor-profile.php?slug=$1 [L]
RewriteRule ^profile/([a-z0-9-]+)/?$ /public/profile.php?username=$1 [L]
RewriteRule ^affiliate/?$ /public/affiliate.php [L]
RewriteRule ^forum/?$ /public/forum.php [L]
RewriteRule ^forum/([a-z0-9-]+)/?$ /public/forum-category.php?cat=$1 [L]
RewriteRule ^forum/thread/([a-z0-9-]+)/?$ /public/forum-thread.php?slug=$1 [L]
RewriteRule ^showcase/?$ /public/showcase.php [L]
RewriteRule ^leaderboard/?$ /public/leaderboard.php [L]
RewriteRule ^niche/([a-z0-9-]+)/?$ /public/niche/$1.php [L]
RewriteRule ^about/?$ /public/about.php [L]
RewriteRule ^roadmap/?$ /public/roadmap.php [L]
RewriteRule ^changelog/?$ /public/changelog.php [L]
RewriteRule ^status/?$ /public/status.php [L]
RewriteRule ^press/?$ /public/press.php [L]
RewriteRule ^contact/?$ /public/contact.php [L]
RewriteRule ^privacy/?$ /public/privacy.php [L]
RewriteRule ^terms/?$ /public/terms.php [L]
RewriteRule ^dmca/?$ /public/dmca.php [L]
RewriteRule ^licenses/?$ /public/licenses.php [L]
RewriteRule ^developer-hub/?$ /public/developer-hub.php [L]
RewriteRule ^api-docs/?$ /public/api-docs.php [L]

# API
RewriteRule ^api/v1/?$ /api/v1.php [L]
RewriteRule ^api/validate-license/?$ /api/validate-license.php [L]

# Block direct access to sensitive dirs
RewriteRule ^(includes|config|cron|automation|database|email-templates|uploads/vendor-docs)/ - [F,L]

# Block access to .env and config files
<FilesMatch "\.(env|sql|log|sh|py)$">
    Order allow,deny
    Deny from all
</FilesMatch>

# PHP settings
php_flag display_errors Off
php_value upload_max_filesize 50M
php_value post_max_size 55M
php_value max_execution_time 120
php_value memory_limit 256M
```

---

## BUILD PHASES — DETAILED

### PHASE 1 — DEPLOY & GO LIVE (Week 1–2)

**Goal:** Platform live at web-temify.com with clean URLs and all 3 gateways working.

Files to create/verify:

1. `.htaccess` — complete URL rewriting (above)
2. `config/config.php` — all environment variables
3. `config/.env.example` — template for production
4. `includes/db.php` — PDO connection with error handling
5. `includes/supabase.php` — storage helper class
6. `index.php` — homepage using v3 design
7. `database/schema.sql` — complete 70-table schema
8. `database/seed.sql` — plans, categories, languages, drip sequences
9. Verify all 3 payment gateways: Paystack + Stripe + LemonSqueezy
10. Verify all 9 existing cron jobs work on VPS
11. Update homepage hero copy: "From idea to deployable web product in hours"
12. `docs/DEPLOYMENT.md` — deployment checklist

**Success criteria:** Site loads at web-temify.com, /templates works,
/pricing works, checkout works end-to-end on all 3 gateways.

---

### PHASE 2 — REVENUE FOUNDATION (Month 1–2)

Priority order:

1. Vendor system (vendor-register, vendor-dashboard, vendor-upload,
   admin/vendors, revenue split, payouts via all 3 gateways)
2. License key system (license.php, validate-license API endpoint,
   buyer dashboard integration, admin revocation)
3. Directory hub (directory.php, 10 category pages, admin CRUD,
   featured listing payments via all 3 gateways)
4. Services/leads system (service-request.php, admin/service-requests,
   email notifications to admin and buyer)
5. Fraud prevention basics (fraud.php, risk scoring on registration
   and checkout, fraud-dashboard in admin)
6. Mobile Money integration (mobilemoney.php, MTN MoMo API,
   Airtel Money, M-Pesa — enable FEATURE_MOBILE_MONEY flag)
7. Chargeback protection (chargeback table, evidence packet
   auto-generation, payout hold logic)
8. Buyer-vendor messaging (messages, message_threads tables,
   messaging UI in dashboard)

---

### PHASE 3 — GROWTH ENGINE (Month 2–4)

Priority order:

1. Gamification (points, badges, challenges, leaderboard tables + UI)
2. Social login (Google + GitHub OAuth via oauth/ handlers)
3. AI page generator (api/ai-generate.php + public/ai-generator.php)
4. Community forum (forum tables + forum.php + moderation)
5. Courses (courses tables + mini course builder for vendors)
6. Launch kits section (launch-kits.php + kit-detail.php)
7. Advanced analytics (geo heatmap, attribution, cohort)
8. Win-back + upgrade nudge campaigns (cron/win-back-campaign.php)
9. Exit survey on cancellation
10. Crypto payments (USDT/USDC via NOWPayments — enable FEATURE_CRYPTO_PAYMENTS)

---

### PHASE 4 — SCALE & AUTOMATE (Month 4–8)

1. Python automation engine (automation/ directory, blog + directory generators)
2. Programmatic SEO pages (public/niche/ auto-generation from admin)
3. ProductHunt-style launch system
4. Mobile app API endpoints (prepare REST API for React Native app)
5. Reseller programme
6. Annual recap email (cron — January)
7. Referral contest system
8. Usage-based pricing for API tools
9. Dynamic pricing / flash sales with countdown timers

---

### PHASE 5 — ENTERPRISE & GLOBAL (Month 8–12)

1. SOC 2 readiness checklist in admin
2. White-label platform option (multi-tenant)
3. Merchant of Record setup (global tax handling)
4. GDPR CMP v2 (IAB TCF 2.2 compliant)
5. Staging environment for Business/Agency users
6. API key management for buyers
7. Full SOC 2 documentation
8. iOS + Android React Native apps

---

## KEY RULES FOR CLAUDE CODE

1. **Never write code before tests** — write the function spec first
2. **All DB queries use PDO prepared statements** — no exceptions
3. **All user input is sanitised** — htmlspecialchars on output
4. **All payment webhooks verify HMAC signature** — before processing
5. **All file uploads are validated** — MIME + extension + size + VirusTotal
6. **All admin pages check 2FA + IP whitelist** — before rendering
7. **All download tokens expire** — 24h, single-use
8. **All forms have CSRF tokens** — hidden input + server verify
9. **All emails have unsubscribe link** — List-Unsubscribe header
10. **All 3 payment gateways appear on every payment page** — always
11. **Dark mode works on every page** — CSS class on body, JS toggle
12. **Mobile responsive on every page** — test at 375px, 768px, 1200px
13. **RTL support on every page** — dir="rtl" class works
14. **Never store raw passwords** — bcrypt only (password_hash)
15. **Log all security events** — activity_log table

---

## DESIGN COMPONENT EXAMPLES

### Standard Button

```html
<a href="#" class="btn btn-fill">Browse Templates →</a>
<a href="#" class="btn btn-ghost">See how it works</a>
<a href="#" class="btn btn-yellow">Get Kit →</a>
<a href="#" class="btn btn-dark">Start Selling →</a>
```

### Template Card

```html
<div class="tpl-card">
  <div class="tpl-preview" style="background:#fff5f0">
    <span class="tpl-badge badge-hot">🔥 Hot</span>
    🏦
  </div>
  <div class="tpl-body">
    <div class="tpl-name">NeoBank Pro Template</div>
    <div class="tpl-type">HTML5 + React · 12 pages</div>
    <div class="tpl-footer">
      <span class="tpl-price">$149</span>
      <span class="tpl-stats">★ 4.9 · 847 sales</span>
    </div>
  </div>
</div>
```

### Section Header

```html
<div class="section-head">
  <div>
    <p class="eyebrow">Browse by Category</p>
    <h2 class="section-title">
      Whatever your<br />
      <span class="serif">business needs</span>
    </h2>
  </div>
  <a href="#" class="btn btn-ghost">View All →</a>
</div>
```

### Coral Marquee Strip

```html
<div class="strip">
  <div class="strip-inner">
    Templates <span>✦</span> Scripts <span>✦</span> Web3 Kits
    <span>✦</span> Launch Today <span>✦</span>
    <!-- duplicate for seamless loop -->
    Templates <span>✦</span> Scripts <span>✦</span> Web3 Kits
    <span>✦</span> Launch Today <span>✦</span>
  </div>
</div>
```

---

## START HERE — PHASE 1 FIRST FILE

When you receive this prompt, start with Phase 1.
Build files in this exact order:

1. `config/config.example.php` — environment template
2. `config/.env.example` — env variables template
3. `.htaccess` — complete URL rewriting
4. `database/schema.sql` — all 70 tables
5. `database/seed.sql` — plans, categories, languages, drip sequences
6. `includes/db.php` — PDO connection
7. `includes/functions.php` — global helpers
8. `includes/security.php` — CSRF, rate limiting, honeypot
9. `includes/auth.php` — session management, login checks
10. `includes/seo.php` — meta tags, OG, JSON-LD builder
11. `includes/supabase.php` — storage helper
12. `includes/email.php` — PHPMailer wrapper
13. `assets/css/main.css` — complete design system
14. `assets/css/dark.css` — dark mode
15. `assets/js/main.js` — global JS
16. `includes/header.php` — shared nav header
17. `includes/footer.php` — shared footer
18. `index.php` — homepage (match web-temify-v3.html design)
19. All Phase 1 public pages
20. Then proceed to Phase 2

---

## COMPANY INFO (for footer, legal pages, emails)

```
Web-Temify LTD
RC: 7999659
TIN: 2521759867925
Nigeria

Sister company: Tinlance Limited
RC: 7962164
TIN: 2521714521054

Admin email: nwachukwuchinaemerem8@gmail.com
Site email: hello@web-temify.com
Copyright: © 2026 Web-Temify LTD. All rights reserved.
```

---

## WHAT TO BUILD AFTER THIS PROMPT

After Claude Code completes Phase 1, paste this same prompt
with the instruction: "Now build Phase 2."

All context is contained in this document.
No need to re-explain anything between phases.

---

_Web-Temify Master Build Prompt v3.0 — May 2026_
_215 features · 26 feature groups · 5 build phases_
_PHP/MySQL · Supabase Storage · Contabo VPS_
