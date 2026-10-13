# WEB-TEMIFY — COMPLETE LARAVEL FOLDER STRUCTURE
## Laravel 11 + MySQL + Redis + Supabase Storage
### Version 4.0 | May 2026

---

```
web-temify/                                    # Laravel 11 root
│
├── app/
│   ├── Console/
│   │   ├── Kernel.php                         # Laravel Scheduler (replaces raw cron)
│   │   └── Commands/
│   │       ├── GenerateBlogPostsCommand.php   # Trigger AI blog generation
│   │       ├── PopulateDirectoryCommand.php   # Trigger directory auto-populate
│   │       ├── SendWeeklyNewsletterCommand.php
│   │       └── ProcessVendorPayoutsCommand.php
│   │
│   ├── Events/
│   │   ├── OrderCompleted.php
│   │   ├── SubscriptionCreated.php
│   │   ├── SubscriptionCancelled.php
│   │   ├── VendorProductApproved.php
│   │   ├── LicenseKeyGenerated.php
│   │   ├── FraudDetected.php
│   │   └── ChargebackOpened.php
│   │
│   ├── Exceptions/
│   │   └── Handler.php                        # Custom error handling + logging
│   │
│   ├── Http/
│   │   ├── Controllers/
│   │   │
│   │   │   # ── AUTH ──
│   │   │   ├── Auth/
│   │   │   │   ├── LoginController.php
│   │   │   │   ├── RegisterController.php
│   │   │   │   ├── TwoFactorController.php    # 2FA setup + verify
│   │   │   │   ├── SocialLoginController.php  # Google + GitHub + Twitter
│   │   │   │   ├── PasswordResetController.php
│   │   │   │   └── EmailVerificationController.php
│   │   │   │
│   │   │   # ── MARKETPLACE ──
│   │   │   ├── Marketplace/
│   │   │   │   ├── HomeController.php
│   │   │   │   ├── TemplateController.php     # Listing + filters + search
│   │   │   │   ├── PreviewController.php      # Template detail + device switcher
│   │   │   │   ├── CompareController.php      # Side-by-side comparison
│   │   │   │   ├── SearchController.php       # Semantic + fulltext search
│   │   │   │   ├── SandboxController.php      # In-browser editable preview
│   │   │   │   ├── KitController.php          # Launch kits
│   │   │   │   └── Web3Controller.php         # Web3 hub
│   │   │   │
│   │   │   # ── CHECKOUT & PAYMENTS ──
│   │   │   ├── Checkout/
│   │   │   │   ├── CheckoutController.php     # Main checkout flow
│   │   │   │   ├── PaystackController.php     # Paystack initiate + callback
│   │   │   │   ├── StripeController.php       # Stripe payment intent
│   │   │   │   ├── LemonSqueezyController.php # LemonSqueezy checkout
│   │   │   │   ├── NowPaymentsController.php  # USDT/USDC (Phase 3)
│   │   │   │   ├── MobileMoneyController.php  # MTN MoMo + M-Pesa (Phase 2)
│   │   │   │   ├── BnplController.php         # Carbon/FairMoney BNPL (Phase 2)
│   │   │   │   ├── DownloadController.php     # Secure token-based download
│   │   │   │   ├── CouponController.php       # AJAX coupon validation
│   │   │   │   ├── GiftCardController.php     # Gift card redemption
│   │   │   │   └── InvoiceController.php      # PDF invoice generation
│   │   │   │
│   │   │   # ── USER DASHBOARD ──
│   │   │   ├── Dashboard/
│   │   │   │   ├── UserDashboardController.php
│   │   │   │   ├── SubscriptionController.php  # Self-service pause/resume
│   │   │   │   ├── WishlistController.php
│   │   │   │   ├── CollectionController.php
│   │   │   │   ├── ProfileController.php
│   │   │   │   ├── AccountSettingsController.php
│   │   │   │   ├── NotificationController.php
│   │   │   │   ├── GamificationController.php  # Points + badges
│   │   │   │   ├── ReferralController.php
│   │   │   │   ├── GdprController.php          # Export + delete account
│   │   │   │   └── LicenseController.php       # User license management
│   │   │   │
│   │   │   # ── VENDOR ──
│   │   │   ├── Vendor/
│   │   │   │   ├── VendorController.php        # Register + dashboard
│   │   │   │   ├── VendorProductController.php # CRUD products
│   │   │   │   ├── VendorAnalyticsController.php
│   │   │   │   ├── VendorPayoutController.php
│   │   │   │   ├── VendorWalletController.php  # Earnings wallet (Phase 3)
│   │   │   │   ├── VendorMessagingController.php
│   │   │   │   ├── VendorCoursesController.php # Course builder (Phase 3)
│   │   │   │   └── VendorWebhookController.php # Vendor webhook config
│   │   │   │
│   │   │   # ── DIRECTORY ──
│   │   │   ├── Directory/
│   │   │   │   ├── DirectoryController.php     # Hub + 10 categories
│   │   │   │   ├── DirectoryListingController.php
│   │   │   │   ├── DirectoryCompareController.php
│   │   │   │   └── DirectorySubmitController.php
│   │   │   │
│   │   │   # ── SERVICES ──
│   │   │   ├── Services/
│   │   │   │   └── ServiceRequestController.php # → Tinlance leads
│   │   │   │
│   │   │   # ── COMMUNITY ──
│   │   │   ├── Community/
│   │   │   │   ├── ForumController.php
│   │   │   │   ├── ForumThreadController.php
│   │   │   │   ├── ShowcaseController.php
│   │   │   │   └── LeaderboardController.php
│   │   │   │
│   │   │   # ── BLOG ──
│   │   │   ├── Blog/
│   │   │   │   └── BlogController.php
│   │   │   │
│   │   │   # ── AFFILIATE ──
│   │   │   ├── Affiliate/
│   │   │   │   ├── AffiliateController.php
│   │   │   │   └── AffiliateDashboardController.php
│   │   │   │
│   │   │   # ── AI FEATURES ──
│   │   │   ├── AI/
│   │   │   │   ├── AiGeneratorController.php   # 60-second page generator
│   │   │   │   ├── AiSearchController.php      # Semantic search
│   │   │   │   └── AiRecommendationsController.php
│   │   │   │
│   │   │   # ── PAGES ──
│   │   │   ├── Pages/
│   │   │   │   └── PageController.php          # About, roadmap, changelog, etc.
│   │   │   │
│   │   │   # ── ADMIN ──
│   │   │   ├── Admin/
│   │   │   │   ├── AdminDashboardController.php # Revenue, MRR, charts
│   │   │   │   ├── AdminUserController.php
│   │   │   │   ├── AdminProductController.php
│   │   │   │   ├── AdminVendorController.php
│   │   │   │   ├── AdminDirectoryController.php
│   │   │   │   ├── AdminOrderController.php
│   │   │   │   ├── AdminSubscriptionController.php
│   │   │   │   ├── AdminAnalyticsController.php  # MRR/LTV/Churn/Geo
│   │   │   │   ├── AdminEmailController.php       # Campaigns + templates
│   │   │   │   ├── AdminBlogController.php
│   │   │   │   ├── AdminGamificationController.php
│   │   │   │   ├── AdminAffiliateController.php
│   │   │   │   ├── AdminFraudController.php
│   │   │   │   ├── AdminChargebackController.php
│   │   │   │   ├── AdminServiceRequestController.php
│   │   │   │   ├── AdminNichePageController.php   # Programmatic SEO
│   │   │   │   ├── AdminReportController.php      # CSV exports
│   │   │   │   └── AdminSettingsController.php
│   │   │   │
│   │   │   # ── API ──
│   │   │   ├── API/
│   │   │   │   ├── ApiV1Controller.php
│   │   │   │   ├── LicenseValidationController.php
│   │   │   │   ├── AiGeneratorApiController.php
│   │   │   │   └── SocialShareController.php
│   │   │   │
│   │   │   # ── WEBHOOKS ──
│   │   │   └── Webhooks/
│   │   │       ├── PaystackWebhookController.php
│   │   │       ├── StripeWebhookController.php
│   │   │       ├── LemonSqueezyWebhookController.php
│   │   │       └── NowPaymentsWebhookController.php
│   │   │
│   │   ├── Middleware/
│   │   │   ├── TwoFactorMiddleware.php         # Enforce 2FA for admin
│   │   │   ├── IpWhitelistMiddleware.php        # Admin IP restriction
│   │   │   ├── VendorMiddleware.php             # Check vendor status
│   │   │   ├── WebhookVerifyMiddleware.php      # HMAC signature verify
│   │   │   ├── FraudCheckMiddleware.php         # Score suspicious requests
│   │   │   ├── FeatureFlagMiddleware.php        # Check feature flags
│   │   │   ├── TrackPageViewMiddleware.php      # Analytics tracking
│   │   │   ├── LocalizationMiddleware.php       # Set locale + currency
│   │   │   └── LowBandwidthMiddleware.php       # Lite mode for slow connections
│   │   │
│   │   └── Requests/                            # Form Request validation classes
│   │       ├── Auth/
│   │       │   ├── LoginRequest.php
│   │       │   └── RegisterRequest.php
│   │       ├── Checkout/
│   │       │   └── ProcessCheckoutRequest.php
│   │       ├── Vendor/
│   │       │   ├── StoreVendorRequest.php
│   │       │   └── StoreProductRequest.php
│   │       ├── Service/
│   │       │   └── StoreServiceRequestRequest.php
│   │       └── Directory/
│   │           └── StoreDirectorySubmissionRequest.php
│   │
│   ├── Jobs/                                    # Queued jobs
│   │   ├── Mail/
│   │   │   ├── SendWelcomeEmailJob.php
│   │   │   ├── SendVerificationEmailJob.php
│   │   │   ├── SendPurchaseReceiptJob.php
│   │   │   ├── SendSubscriptionReceiptJob.php
│   │   │   ├── SendExpiryReminderJob.php
│   │   │   ├── SendProductUpdateNotificationJob.php
│   │   │   ├── SendVendorApprovedJob.php
│   │   │   ├── SendVendorSaleJob.php
│   │   │   ├── SendVendorPayoutJob.php
│   │   │   ├── SendAffiliateCommissionJob.php
│   │   │   ├── SendAbandonedCheckoutJob.php
│   │   │   ├── SendDripEmailJob.php
│   │   │   ├── SendDunningEmailJob.php
│   │   │   ├── SendSuspiciousLoginJob.php
│   │   │   ├── SendServiceRequestConfirmJob.php
│   │   │   ├── SendServiceRequestAdminJob.php
│   │   │   ├── SendWeeklyNewsletterJob.php
│   │   │   ├── SendNpsSurveyJob.php
│   │   │   ├── SendWinBackEmailJob.php
│   │   │   ├── SendLicenseExpiryReminderJob.php
│   │   │   ├── SendAnnualRecapJob.php
│   │   │   ├── SendVendorRejectionJob.php
│   │   │   └── Send2FACodeJob.php
│   │   ├── Processing/
│   │   │   ├── ProcessVirusTotalScanJob.php
│   │   │   ├── ProcessImageOptimizationJob.php
│   │   │   ├── ProcessWebPConversionJob.php
│   │   │   ├── GenerateLicenseKeyJob.php
│   │   │   ├── ProcessVendorPayoutJob.php
│   │   │   ├── CheckChargebackRatioJob.php
│   │   │   └── DetectFraudSignalsJob.php
│   │   └── Analytics/
│   │       ├── CalculateMRRJob.php
│   │       ├── UpdateProfileScoreJob.php
│   │       ├── UpdateVendorAnalyticsJob.php
│   │       ├── UpdateProductPerformanceScoreJob.php
│   │       ├── UpdateLeaderboardJob.php
│   │       └── GenerateRevenueAttributionJob.php
│   │
│   ├── Listeners/
│   │   ├── OrderCompletedListener.php          # Generate license, send receipt, award points
│   │   ├── SubscriptionCreatedListener.php     # Send welcome, update plan
│   │   ├── VendorProductApprovedListener.php   # Notify vendor, update counters
│   │   ├── FraudDetectedListener.php           # Alert admin, flag account
│   │   └── ChargebackOpenedListener.php        # Hold payout, generate evidence
│   │
│   ├── Mail/                                   # Mailable classes
│   │   ├── WelcomeEmail.php
│   │   ├── PurchaseReceiptMail.php
│   │   ├── VendorSaleMail.php
│   │   ├── WeeklyNewsletterMail.php
│   │   └── (25 Mail classes total)
│   │
│   ├── Models/
│   │   ├── User.php
│   │   ├── Product.php
│   │   ├── Category.php
│   │   ├── Order.php
│   │   ├── Plan.php
│   │   ├── Subscription.php
│   │   ├── Payment.php
│   │   ├── Download.php
│   │   ├── LicenseKey.php
│   │   ├── LicenseActivation.php
│   │   ├── Vendor.php
│   │   ├── VendorPayout.php
│   │   ├── VendorAnalytic.php
│   │   ├── VendorWalletTransaction.php
│   │   ├── DirectoryListing.php
│   │   ├── DirectoryCategory.php
│   │   ├── DirectoryReview.php
│   │   ├── Review.php
│   │   ├── ProductVersion.php
│   │   ├── Collection.php
│   │   ├── CollectionItem.php
│   │   ├── Wishlist.php
│   │   ├── Coupon.php
│   │   ├── GiftCard.php
│   │   ├── Credit.php
│   │   ├── AffiliateLink.php
│   │   ├── AffiliateCommission.php
│   │   ├── AffiliateTier.php
│   │   ├── Badge.php
│   │   ├── UserBadge.php
│   │   ├── UserPoint.php
│   │   ├── Challenge.php
│   │   ├── ChallengeParticipant.php
│   │   ├── Notification.php
│   │   ├── ActivityLog.php
│   │   ├── EmailCampaign.php
│   │   ├── DripSequence.php
│   │   ├── DripStep.php
│   │   ├── AbandonedCheckout.php
│   │   ├── NpsResponse.php
│   │   ├── AnnouncementBanner.php
│   │   ├── Faq.php
│   │   ├── Testimonial.php
│   │   ├── RoadmapItem.php
│   │   ├── ChangelogEntry.php
│   │   ├── NichePage.php
│   │   ├── AdZone.php
│   │   ├── OutgoingWebhook.php
│   │   ├── VendorWebhook.php
│   │   ├── ApiKey.php
│   │   ├── ApiUsageLog.php
│   │   ├── FraudFlag.php
│   │   ├── Chargeback.php
│   │   ├── SearchLog.php
│   │   ├── ZeroResultSearch.php
│   │   ├── PageView.php
│   │   ├── RevenueAttribution.php
│   │   ├── CohortData.php
│   │   ├── MobileMoneyTransaction.php
│   │   ├── BnplTransaction.php
│   │   ├── CryptoPayment.php
│   │   ├── TemplateRequest.php
│   │   ├── ServiceRequest.php
│   │   ├── Message.php
│   │   ├── MessageThread.php
│   │   ├── SupportTicket.php
│   │   ├── SupportReply.php
│   │   ├── Course.php
│   │   ├── CourseLesson.php
│   │   ├── CourseProgress.php
│   │   ├── CourseQuiz.php
│   │   ├── QuizAttempt.php
│   │   ├── Certificate.php
│   │   ├── ForumCategory.php
│   │   ├── ForumThread.php
│   │   ├── ForumReply.php
│   │   ├── ShowcaseEntry.php
│   │   ├── LeaderboardSnapshot.php
│   │   ├── FollowVendor.php
│   │   ├── ProductComparison.php
│   │   ├── RecentlyViewed.php
│   │   ├── LaunchKit.php
│   │   ├── LaunchKitItem.php
│   │   ├── BlogPost.php
│   │   ├── BlogCategory.php
│   │   ├── PressEntry.php
│   │   ├── AiUsageLog.php
│   │   └── PressMention.php
│   │
│   ├── Notifications/                          # Laravel notifications
│   │   ├── NewPurchaseNotification.php
│   │   ├── NewReviewNotification.php
│   │   ├── VendorPayoutProcessedNotification.php
│   │   └── FraudAlertNotification.php
│   │
│   ├── Observers/                              # Model observers
│   │   ├── OrderObserver.php                   # On create: generate license, award points
│   │   ├── ProductObserver.php                 # On approve: notify vendor followers
│   │   └── UserObserver.php                    # On create: set referral code
│   │
│   ├── Policies/                               # Authorization policies
│   │   ├── ProductPolicy.php
│   │   ├── VendorPolicy.php
│   │   └── OrderPolicy.php
│   │
│   ├── Providers/
│   │   ├── AppServiceProvider.php
│   │   ├── AuthServiceProvider.php
│   │   └── EventServiceProvider.php
│   │
│   └── Services/                               # Business logic services
│       ├── PaymentService.php                  # Unified payment router
│       ├── PaystackService.php                 # Paystack API wrapper
│       ├── StripeService.php                   # Stripe API wrapper
│       ├── LemonSqueezyService.php             # LemonSqueezy wrapper
│       ├── NowPaymentsService.php              # USDT/USDC (Phase 3)
│       ├── MobileMoneyService.php              # MTN MoMo + M-Pesa (Phase 2)
│       ├── BnplService.php                     # Carbon/FairMoney (Phase 2)
│       ├── LicenseService.php                  # License key CRUD
│       ├── FraudService.php                    # Risk scoring + detection
│       ├── AIGatewayService.php                # Multi-LLM fallback chain
│       ├── ClaudeService.php                   # Anthropic Claude API
│       ├── GrokService.php                     # xAI Grok API
│       ├── GeminiService.php                   # Google Gemini API
│       ├── OpenAIService.php                   # OpenAI API
│       ├── SupabaseService.php                 # Storage helper
│       ├── VirusTotalService.php               # Malware scanning
│       ├── GamificationService.php             # Points + badges
│       ├── DirectoryService.php                # Directory + auto-populate
│       ├── AffiliateService.php                # Commissions + tracking
│       ├── SearchService.php                   # Fulltext + semantic search
│       ├── NotificationService.php             # Bell + push + email
│       ├── AnalyticsService.php                # MRR, LTV, cohort calc
│       ├── EmailCampaignService.php            # Campaign sender
│       ├── DripService.php                     # Drip sequence processor
│       ├── PppPricingService.php               # PPP by country
│       ├── VatService.php                      # VAT/tax calculation
│       ├── SeoService.php                      # Meta + JSON-LD builder
│       ├── VendorWalletService.php             # Wallet + instant payouts
│       └── CourseService.php                   # Course + certificate (Phase 3)
│
├── bootstrap/
│   ├── app.php                                 # Middleware + service providers
│   └── cache/
│
├── config/
│   ├── app.php
│   ├── auth.php
│   ├── cache.php
│   ├── database.php
│   ├── filesystems.php
│   ├── mail.php
│   ├── queue.php
│   ├── services.php                            # OAuth + external service keys
│   ├── paystack.php                            # Paystack config
│   ├── stripe.php                              # Stripe config
│   ├── lemonsqueezy.php                        # LemonSqueezy config
│   ├── nowpayments.php                         # NOWPayments config
│   ├── supabase.php                            # Supabase config
│   ├── features.php                            # Feature flags
│   ├── ai.php                                  # AI provider config
│   └── webtemify.php                           # Platform-wide settings
│
├── database/
│   ├── migrations/
│   │   ├── 2026_01_01_000001_create_users_table.php
│   │   ├── 2026_01_01_000002_create_categories_table.php
│   │   ├── 2026_01_01_000003_create_plans_table.php
│   │   ├── 2026_01_01_000004_create_vendors_table.php
│   │   ├── 2026_01_01_000005_create_products_table.php
│   │   ├── 2026_01_01_000006_create_product_versions_table.php
│   │   ├── 2026_01_01_000007_create_orders_table.php
│   │   ├── 2026_01_01_000008_create_payments_table.php
│   │   ├── 2026_01_01_000009_create_subscriptions_table.php
│   │   ├── 2026_01_01_000010_create_license_keys_table.php
│   │   ├── 2026_01_01_000011_create_license_activations_table.php
│   │   ├── 2026_01_01_000012_create_downloads_table.php
│   │   ├── 2026_01_01_000013_create_reviews_table.php
│   │   ├── 2026_01_01_000014_create_wishlists_table.php
│   │   ├── 2026_01_01_000015_create_collections_table.php
│   │   ├── 2026_01_01_000016_create_collection_items_table.php
│   │   ├── 2026_01_01_000017_create_coupons_table.php
│   │   ├── 2026_01_01_000018_create_gift_cards_table.php
│   │   ├── 2026_01_01_000019_create_credits_table.php
│   │   ├── 2026_01_01_000020_create_directory_listings_table.php
│   │   ├── 2026_01_01_000021_create_directory_reviews_table.php
│   │   ├── 2026_01_01_000022_create_affiliate_links_table.php
│   │   ├── 2026_01_01_000023_create_affiliate_commissions_table.php
│   │   ├── 2026_01_01_000024_create_affiliate_tiers_table.php
│   │   ├── 2026_01_01_000025_create_badges_table.php
│   │   ├── 2026_01_01_000026_create_user_badges_table.php
│   │   ├── 2026_01_01_000027_create_user_points_table.php
│   │   ├── 2026_01_01_000028_create_challenges_table.php
│   │   ├── 2026_01_01_000029_create_challenge_participants_table.php
│   │   ├── 2026_01_01_000030_create_notifications_table.php
│   │   ├── 2026_01_01_000031_create_activity_log_table.php
│   │   ├── 2026_01_01_000032_create_email_campaigns_table.php
│   │   ├── 2026_01_01_000033_create_drip_sequences_table.php
│   │   ├── 2026_01_01_000034_create_drip_steps_table.php
│   │   ├── 2026_01_01_000035_create_abandoned_checkouts_table.php
│   │   ├── 2026_01_01_000036_create_nps_responses_table.php
│   │   ├── 2026_01_01_000037_create_announcement_banners_table.php
│   │   ├── 2026_01_01_000038_create_faqs_table.php
│   │   ├── 2026_01_01_000039_create_testimonials_table.php
│   │   ├── 2026_01_01_000040_create_roadmap_items_table.php
│   │   ├── 2026_01_01_000041_create_changelog_entries_table.php
│   │   ├── 2026_01_01_000042_create_niche_pages_table.php
│   │   ├── 2026_01_01_000043_create_ad_zones_table.php
│   │   ├── 2026_01_01_000044_create_outgoing_webhooks_table.php
│   │   ├── 2026_01_01_000045_create_vendor_webhooks_table.php
│   │   ├── 2026_01_01_000046_create_api_keys_table.php
│   │   ├── 2026_01_01_000047_create_api_usage_log_table.php
│   │   ├── 2026_01_01_000048_create_fraud_flags_table.php
│   │   ├── 2026_01_01_000049_create_chargebacks_table.php
│   │   ├── 2026_01_01_000050_create_search_log_table.php
│   │   ├── 2026_01_01_000051_create_zero_result_searches_table.php
│   │   ├── 2026_01_01_000052_create_page_views_table.php
│   │   ├── 2026_01_01_000053_create_revenue_attribution_table.php
│   │   ├── 2026_01_01_000054_create_cohort_data_table.php
│   │   ├── 2026_01_01_000055_create_mobile_money_transactions_table.php
│   │   ├── 2026_01_01_000056_create_bnpl_transactions_table.php
│   │   ├── 2026_01_01_000057_create_crypto_payments_table.php
│   │   ├── 2026_01_01_000058_create_template_requests_table.php
│   │   ├── 2026_01_01_000059_create_service_requests_table.php
│   │   ├── 2026_01_01_000060_create_message_threads_table.php
│   │   ├── 2026_01_01_000061_create_messages_table.php
│   │   ├── 2026_01_01_000062_create_support_tickets_table.php
│   │   ├── 2026_01_01_000063_create_support_replies_table.php
│   │   ├── 2026_01_01_000064_create_courses_table.php
│   │   ├── 2026_01_01_000065_create_course_lessons_table.php
│   │   ├── 2026_01_01_000066_create_course_progress_table.php
│   │   ├── 2026_01_01_000067_create_course_quizzes_table.php
│   │   ├── 2026_01_01_000068_create_quiz_attempts_table.php
│   │   ├── 2026_01_01_000069_create_certificates_table.php
│   │   ├── 2026_01_01_000070_create_forum_categories_table.php
│   │   ├── 2026_01_01_000071_create_forum_threads_table.php
│   │   ├── 2026_01_01_000072_create_forum_replies_table.php
│   │   ├── 2026_01_01_000073_create_showcase_entries_table.php
│   │   ├── 2026_01_01_000074_create_leaderboard_snapshots_table.php
│   │   ├── 2026_01_01_000075_create_follow_vendors_table.php
│   │   ├── 2026_01_01_000076_create_recently_viewed_table.php
│   │   ├── 2026_01_01_000077_create_launch_kits_table.php
│   │   ├── 2026_01_01_000078_create_launch_kit_items_table.php
│   │   ├── 2026_01_01_000079_create_blog_posts_table.php
│   │   ├── 2026_01_01_000080_create_blog_categories_table.php
│   │   ├── 2026_01_01_000081_create_vendor_payout_table.php
│   │   ├── 2026_01_01_000082_create_vendor_wallet_transactions_table.php
│   │   ├── 2026_01_01_000083_create_ai_usage_log_table.php
│   │   ├── 2026_01_01_000084_create_press_mentions_table.php
│   │   └── 2026_01_01_000085_create_permissions_tables.php  # Spatie
│   │
│   ├── seeders/
│   │   ├── DatabaseSeeder.php                  # Master seeder
│   │   ├── PlansSeeder.php                     # Free, Pro, Business, Agency plans
│   │   ├── CategoriesSeeder.php                # 12 marketplace categories
│   │   ├── DirectoryCategoriesSeeder.php       # 10 directory categories
│   │   ├── LanguagesSeeder.php                 # en, fr, es, pt
│   │   ├── DripSequencesSeeder.php             # 4-touch drip emails
│   │   ├── BadgesSeeder.php                    # Achievement badges
│   │   ├── RolesAndPermissionsSeeder.php       # Spatie roles
│   │   ├── AffiliateTiersSeeder.php            # Starter/Silver/Gold/Platinum
│   │   └── ProductionSeeder.php                # Safe for production
│   │
│   └── factories/
│       ├── UserFactory.php
│       ├── ProductFactory.php
│       ├── OrderFactory.php
│       └── VendorFactory.php
│
├── public/
│   ├── index.php
│   ├── .htaccess                               # Laravel default
│   ├── robots.txt
│   ├── sitemap.xml                             # Auto-generated
│   ├── manifest.json                           # PWA
│   ├── sw.js                                   # Service worker
│   ├── offline.html                            # PWA fallback
│   └── build/                                  # Vite compiled assets
│
├── resources/
│   ├── css/
│   │   ├── app.css                             # Tailwind + custom design system
│   │   ├── dark.css                            # Dark mode overrides
│   │   └── rtl.css                             # RTL support
│   │
│   ├── js/
│   │   ├── app.js                              # Alpine.js + global JS
│   │   ├── checkout.js                         # Payment flow
│   │   ├── search.js                           # Autocomplete + semantic
│   │   ├── compare.js                          # Template comparison
│   │   ├── sandbox.js                          # Editable preview
│   │   ├── ai-generator.js                     # AI page generator
│   │   └── analytics.js                        # GTM + GA4 + pixels
│   │
│   ├── views/
│   │   ├── layouts/
│   │   │   ├── app.blade.php
│   │   │   ├── admin.blade.php
│   │   │   ├── auth.blade.php
│   │   │   └── vendor.blade.php
│   │   │
│   │   ├── components/
│   │   │   ├── template-card.blade.php
│   │   │   ├── kit-card.blade.php
│   │   │   ├── directory-card.blade.php
│   │   │   ├── pricing-card.blade.php
│   │   │   ├── vendor-card.blade.php
│   │   │   ├── review-card.blade.php
│   │   │   ├── nav.blade.php
│   │   │   ├── footer.blade.php
│   │   │   ├── marquee.blade.php
│   │   │   ├── social-proof-toast.blade.php
│   │   │   ├── announcement-banner.blade.php
│   │   │   ├── cookie-banner.blade.php
│   │   │   ├── dark-mode-toggle.blade.php
│   │   │   ├── payment-tabs.blade.php
│   │   │   ├── onboarding-checklist.blade.php
│   │   │   └── ai-generator-box.blade.php
│   │   │
│   │   ├── home/
│   │   │   └── index.blade.php                # Matches web-temify-v3.html
│   │   │
│   │   ├── marketplace/
│   │   │   ├── index.blade.php
│   │   │   ├── preview.blade.php
│   │   │   ├── compare.blade.php
│   │   │   ├── search.blade.php
│   │   │   └── sandbox.blade.php
│   │   │
│   │   ├── kits/
│   │   │   ├── index.blade.php
│   │   │   └── show.blade.php
│   │   │
│   │   ├── web3/
│   │   │   └── index.blade.php
│   │   │
│   │   ├── directory/
│   │   │   ├── index.blade.php
│   │   │   ├── category.blade.php
│   │   │   ├── show.blade.php
│   │   │   └── submit.blade.php
│   │   │
│   │   ├── checkout/
│   │   │   ├── index.blade.php
│   │   │   ├── success.blade.php
│   │   │   └── failed.blade.php
│   │   │
│   │   ├── dashboard/
│   │   │   ├── index.blade.php
│   │   │   ├── downloads.blade.php
│   │   │   ├── purchases.blade.php
│   │   │   ├── subscription.blade.php
│   │   │   ├── points.blade.php
│   │   │   ├── badges.blade.php
│   │   │   └── licenses.blade.php
│   │   │
│   │   ├── vendor/
│   │   │   ├── register.blade.php
│   │   │   ├── dashboard.blade.php
│   │   │   ├── products/
│   │   │   │   ├── index.blade.php
│   │   │   │   ├── create.blade.php
│   │   │   │   └── edit.blade.php
│   │   │   ├── analytics.blade.php
│   │   │   ├── payouts.blade.php
│   │   │   └── wallet.blade.php
│   │   │
│   │   ├── admin/
│   │   │   ├── dashboard.blade.php
│   │   │   ├── users/
│   │   │   ├── products/
│   │   │   ├── vendors/
│   │   │   ├── directory/
│   │   │   ├── orders/
│   │   │   ├── analytics/
│   │   │   ├── blog/
│   │   │   ├── fraud.blade.php
│   │   │   ├── chargebacks.blade.php
│   │   │   ├── service-requests.blade.php
│   │   │   └── settings.blade.php
│   │   │
│   │   ├── community/
│   │   │   ├── forum/
│   │   │   │   ├── index.blade.php
│   │   │   │   ├── category.blade.php
│   │   │   │   ├── thread.blade.php
│   │   │   │   └── create.blade.php
│   │   │   ├── showcase.blade.php
│   │   │   └── leaderboard.blade.php
│   │   │
│   │   ├── blog/
│   │   │   ├── index.blade.php
│   │   │   └── show.blade.php
│   │   │
│   │   ├── services/
│   │   │   ├── index.blade.php
│   │   │   └── request.blade.php
│   │   │
│   │   ├── ai/
│   │   │   └── generator.blade.php
│   │   │
│   │   ├── pages/
│   │   │   ├── about.blade.php
│   │   │   ├── roadmap.blade.php
│   │   │   ├── changelog.blade.php
│   │   │   ├── pricing.blade.php
│   │   │   ├── licenses.blade.php
│   │   │   ├── developer-hub.blade.php
│   │   │   ├── api-docs.blade.php
│   │   │   ├── privacy.blade.php
│   │   │   ├── terms.blade.php
│   │   │   ├── cookie-policy.blade.php
│   │   │   ├── dmca.blade.php
│   │   │   ├── refund-policy.blade.php
│   │   │   ├── press.blade.php
│   │   │   ├── status.blade.php
│   │   │   ├── contact.blade.php
│   │   │   ├── advertise.blade.php
│   │   │   └── 404.blade.php
│   │   │
│   │   └── emails/                            # 25 email templates
│   │       ├── welcome.blade.php
│   │       ├── verify-email.blade.php
│   │       ├── password-reset.blade.php
│   │       ├── purchase-receipt.blade.php
│   │       ├── subscription-receipt.blade.php
│   │       ├── expiry-reminder.blade.php
│   │       ├── download-ready.blade.php
│   │       ├── product-updated.blade.php
│   │       ├── vendor-approved.blade.php
│   │       ├── vendor-sale.blade.php
│   │       ├── vendor-payout.blade.php
│   │       ├── vendor-rejection.blade.php
│   │       ├── affiliate-commission.blade.php
│   │       ├── abandoned-checkout.blade.php
│   │       ├── drip-1.blade.php
│   │       ├── drip-3.blade.php
│   │       ├── drip-7.blade.php
│   │       ├── drip-14.blade.php
│   │       ├── dunning-1.blade.php
│   │       ├── dunning-2.blade.php
│   │       ├── dunning-3.blade.php
│   │       ├── dunning-final.blade.php
│   │       ├── suspicious-login.blade.php
│   │       ├── service-request-confirm.blade.php
│   │       ├── service-request-admin.blade.php
│   │       ├── newsletter-weekly.blade.php
│   │       ├── nps-survey.blade.php
│   │       ├── win-back.blade.php
│   │       ├── license-expiry.blade.php
│   │       ├── annual-recap.blade.php
│   │       └── 2fa-code.blade.php
│   │
│   └── lang/
│       ├── en/
│       ├── fr/
│       ├── es/
│       └── pt/
│
├── routes/
│   ├── web.php                                # All web routes
│   ├── api.php                                # API v1 routes
│   ├── auth.php                               # Breeze auth routes
│   ├── admin.php                              # Admin routes (separate file)
│   ├── vendor.php                             # Vendor routes
│   └── webhooks.php                           # Webhook routes (no CSRF)
│
├── storage/
│   ├── app/
│   │   ├── private/
│   │   │   └── downloads/                     # Secure template files
│   │   └── public/                            # Publicly accessible
│   ├── framework/
│   └── logs/
│
├── tests/
│   ├── Feature/
│   │   ├── Auth/
│   │   │   ├── LoginTest.php
│   │   │   ├── RegisterTest.php
│   │   │   └── TwoFactorTest.php
│   │   ├── Checkout/
│   │   │   ├── CheckoutTest.php
│   │   │   ├── PaystackWebhookTest.php
│   │   │   ├── StripeWebhookTest.php
│   │   │   └── LicenseKeyTest.php
│   │   ├── Vendor/
│   │   │   ├── VendorRegistrationTest.php
│   │   │   └── ProductSubmissionTest.php
│   │   ├── Security/
│   │   │   ├── FraudDetectionTest.php
│   │   │   ├── RateLimitingTest.php
│   │   │   └── WebhookVerificationTest.php
│   │   └── API/
│   │       └── ApiV1Test.php
│   └── Unit/
│       ├── LicenseServiceTest.php
│       ├── FraudServiceTest.php
│       ├── AIGatewayServiceTest.php
│       └── GamificationServiceTest.php
│
├── automation/                                # Python AI automation engine
│   ├── content_engine.py                      # Main orchestrator
│   ├── blog_generator.py                      # SEO blog post generator
│   ├── directory_populator.py                 # Directory listing auto-populate
│   ├── requirements.txt                       # anthropic, requests, python-dotenv
│   └── config.example.env
│
├── .env                                       # Environment variables
├── .env.example                               # Template (safe to commit)
├── .gitignore
├── artisan
├── composer.json
├── composer.lock
├── package.json
├── package-lock.json
├── tailwind.config.js                         # Tailwind + design system tokens
├── vite.config.js                             # Asset bundling
└── phpunit.xml                                # Test configuration
```

---

## KEY PACKAGE LIST (composer.json)

```json
{
    "require": {
        "php": "^8.2",
        "laravel/framework": "^11.0",
        "laravel/breeze": "^2.0",
        "laravel/socialite": "^5.0",
        "laravel/sanctum": "^4.0",
        "laravel/scout": "^10.0",
        "laravel/reverb": "^1.0",
        "laravel/telescope": "^5.0",
        "spatie/laravel-permission": "^6.0",
        "spatie/laravel-activitylog": "^4.0",
        "stripe/stripe-php": "^13.0",
        "unicodeveloper/laravel-paystack": "^1.2",
        "barryvdh/laravel-dompdf": "^2.0",
        "simplesoftwareio/simple-qrcode": "^4.2",
        "pragmarx/google2fa-laravel": "^2.0",
        "intervention/image": "^3.0",
        "guzzlehttp/guzzle": "^7.0",
        "predis/predis": "^2.0",
        "league/flysystem-aws-s3-v3": "^3.0"
    },
    "require-dev": {
        "laravel/dusk": "^8.0",
        "fakerphp/faker": "^1.9",
        "mockery/mockery": "^1.6",
        "nunomaduro/collision": "^8.0",
        "phpunit/phpunit": "^11.0"
    }
}
```

---

## TAILWIND CONFIG (tailwind.config.js)

```js
module.exports = {
  content: ['./resources/**/*.blade.php', './resources/**/*.js'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        bg:      '#fffbf4',
        ink:     '#0f0d0a',
        coral:   '#ff5733',
        yellow:  '#ffd60a',
        mint:    '#00c48c',
        sky:     '#4f8ef7',
        lilac:   '#c084fc',
        surface: '#fff8ed',
        muted:   '#6b6559',
      },
      fontFamily: {
        display: ['Cabinet Grotesk', 'sans-serif'],
        serif:   ['Instrument Serif', 'serif'],
        mono:    ['DM Mono', 'monospace'],
      },
      boxShadow: {
        'brutal':    '4px 4px 0 #0f0d0a',
        'brutal-lg': '6px 6px 0 #0f0d0a',
        'brutal-sm': '2px 2px 0 #0f0d0a',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
```

---

## DEPLOYMENT CHECKLIST (Contabo VPS)

```bash
# Server requirements
PHP 8.2+ with extensions: mbstring, xml, curl, zip, gd, redis, mysql
MySQL 8.0+
Redis 7.0+
Node.js 20+
Composer 2.x
Nginx or Apache

# Nginx config for Laravel
server {
    listen 80;
    server_name web-temify.com www.web-temify.com;
    root /var/www/web-temify/public;
    index index.php index.html;
    location / { try_files $uri $uri/ /index.php?$query_string; }
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    }
    # Block direct access to sensitive files
    location ~ /\.(env|git) { deny all; }
    location ~ /storage/app/private { deny all; }
}

# Queue worker (Supervisor)
[program:webtemify-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/web-temify/artisan queue:work redis --queue=high,default,low --sleep=3 --tries=3 --timeout=120
autostart=true
autorestart=true
numprocs=2
user=www-data

# Crontab (single line for Laravel Scheduler)
* * * * * cd /var/www/web-temify && php artisan schedule:run >> /dev/null 2>&1

# Production commands
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
composer install --optimize-autoloader --no-dev
npm run build
php artisan migrate --force
php artisan db:seed --class=ProductionSeeder
php artisan storage:link
```

---

*Web-Temify Laravel Folder Structure v4.0 — May 2026*
*Laravel 11 · MySQL 8 · Redis · Supabase Storage*
*332 features · 85 migrations · 80+ models · 34 service classes*
