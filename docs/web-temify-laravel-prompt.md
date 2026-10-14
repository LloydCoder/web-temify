> **DEPRECATED LEGACY BUILD PROMPT — reviewed 2026-10-13.** This Laravel/PHP/MySQL build prompt is historical only and conflicts with the accepted Next.js App Router, strict TypeScript, pnpm/Turborepo, and Supabase SQL-migration architecture. Do not execute it wholesale or treat its payment, security, product, or readiness claims as current. See `docs/architecture/overview.md`, accepted ADRs, and `docs/roadmap/phase-gates.md`.

# WEB-TEMIFY — LARAVEL MASTER BUILD PROMPT

## Complete Laravel 11 Platform Build Brief

### Version 4.0 | May 2026 | Laravel 11 + MySQL + Supabase Storage

---

## HOW TO USE THIS PROMPT

Paste this entire document into Claude Code.
Build phase by phase. Each phase is self-contained and deployable.
Never skip the phase order — each phase depends on the previous.
After each phase is complete and tested, paste this same prompt
with: "Phase X is complete. Now build Phase X+1."

---

## PROJECT OVERVIEW

**Product:** Web-Temify — Premium website template marketplace
**Company:** Web-Temify LTD (RC: 7999659, TIN: 2521759867925) — Nigeria
**Sister company:** Tinlance Limited (RC: 7962164) — AI & cybersecurity studio
**Domain:** web-temify.com
**Hosting:** Contabo VPS (Ubuntu 22.04, Apache/Nginx, PHP 8.2+, MySQL 8.0+)
**Framework:** Laravel 11 (latest stable)
**Frontend:** Blade templates + Alpine.js + Tailwind CSS
**Storage:** Supabase Storage (images, videos, screenshots, avatars)
**Queue:** Laravel Queues with Redis (emails, notifications, cron jobs)
**Cache:** Redis (query caching, session storage)
**Search:** Laravel Scout + MySQL fulltext (upgrade to Meilisearch later)
**Positioning:** "From idea to deployable web product in hours"

---

## TECH STACK — COMPLETE

```
Backend:        Laravel 11
PHP:            8.2+
Database:       MySQL 8.0+
Cache/Queue:    Redis
Frontend:       Blade + Alpine.js + Tailwind CSS 3
Storage:        Supabase Storage (media) + local (secure downloads)
Auth:           Laravel Breeze (extended) + Socialite (OAuth)
Payments:       Paystack + Stripe + LemonSqueezy + NOWPayments
Email:          Laravel Mail + SMTP (Mailgun/SES)
AI:             Anthropic Claude API (primary) + Grok + Gemini + OpenAI
Search:         Laravel Scout + MySQL fulltext
PDF:            DomPDF (invoices, certificates)
QR Codes:       Simple QrCode package
2FA:            pragmarx/google2fa-laravel
VirusTotal:     HTTP client API calls
Scheduler:      Laravel Scheduler (replaces raw cron)
Jobs/Queues:    Laravel Queues with Redis
WebSockets:     Laravel Reverb (real-time notifications)
Testing:        PHPUnit + Laravel Dusk
```

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
Border:         2px solid #0f0d0a (brutalist)
Shadow hover:   4px 4px 0 #0f0d0a
Shadow large:   6px 6px 0 #0f0d0a

Fonts:
  Display/Headings: Cabinet Grotesk (900,800,700)
  Italic accents:   Instrument Serif (italic)
  Monospace/labels: DM Mono

Design style:
  Brutalist editorial marketplace
  2px solid black borders on all cards and buttons
  Box-shadow hover lift on all interactive elements
  Warm cream background — NOT white, NOT dark
  Coral scrolling marquee strips between sections
  Dark ink sections for "How it works" content
  Yellow for featured/popular badges
  All buttons: border 2px solid ink, hover lifts with shadow

Reference design: web-temify-v3.html (already built homepage)
```

---

## LARAVEL PROJECT SETUP

```bash
# Create new Laravel 11 project
composer create-project laravel/laravel web-temify "11.*"
cd web-temify

# Core packages
composer require laravel/breeze
composer require laravel/socialite
composer require spatie/laravel-permission
composer require laravel/scout
composer require stripe/stripe-php
composer require unicodeveloper/laravel-paystack
composer require barryvdh/laravel-dompdf
composer require simplesoftwareio/simple-qrcode
composer require pragmarx/google2fa-laravel
composer require intervention/image
composer require guzzlehttp/guzzle
composer require laravel/reverb
composer require predis/predis

# Dev packages
composer require --dev laravel/telescope
composer require --dev laravel/dusk

# Frontend
npm install
npm install -D tailwindcss @tailwindcss/forms @tailwindcss/typography
npm install alpinejs
npm install @alpinejs/collapse @alpinejs/persist

# Breeze with Blade
php artisan breeze:install blade

# Spatie permissions
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider"

# Google 2FA
php artisan vendor:publish --provider="PragmaRX\Google2FALaravel\ServiceProvider"
```

---

## ENVIRONMENT VARIABLES (.env)

```env
APP_NAME="Web-Temify"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://web-temify.com
APP_TIMEZONE=Africa/Lagos

# Database
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=webtemify
DB_USERNAME=webtemify_user
DB_PASSWORD=

# Cache & Queue
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
BROADCAST_DRIVER=reverb

# Redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# Mail
MAIL_MAILER=smtp
MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=hello@web-temify.com
MAIL_FROM_NAME="Web-Temify"

# Paystack
PAYSTACK_PUBLIC_KEY=
PAYSTACK_SECRET_KEY=
PAYSTACK_WEBHOOK_SECRET=

# Stripe
STRIPE_PUBLIC_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=

# LemonSqueezy
LEMONSQUEEZY_API_KEY=
LEMONSQUEEZY_STORE_ID=
LEMONSQUEEZY_WEBHOOK_SECRET=

# NOWPayments (USDT/USDC - Phase 3)
NOWPAYMENTS_API_KEY=
NOWPAYMENTS_IPN_SECRET=
NOWPAYMENTS_ENABLED=false

# Mobile Money (Phase 2)
MOMO_API_KEY=
MOMO_SUBSCRIPTION_KEY=
MOBILE_MONEY_ENABLED=false

# BNPL (Phase 2)
CARBON_API_KEY=
BNPL_ENABLED=false

# Supabase Storage
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
SUPABASE_BUCKET_PREVIEWS=template-previews
SUPABASE_BUCKET_VIDEOS=template-videos
SUPABASE_BUCKET_AVATARS=user-avatars
SUPABASE_BUCKET_SCREENSHOTS=template-screenshots

# AI APIs
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-20250514
GROK_API_KEY=
GROK_MODEL=grok-3
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini
AI_PRIMARY_PROVIDER=claude

# OAuth
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
TWITTER_CLIENT_ID=
TWITTER_CLIENT_SECRET=

# VirusTotal
VIRUSTOTAL_API_KEY=

# Integrations
GTM_ID=
CLARITY_ID=
MAILCHIMP_API_KEY=
MAILCHIMP_LIST_ID=
TAWK_PROPERTY_ID=

# Security
ADMIN_IP_WHITELIST=
HIGH_VALUE_CHECKOUT_THRESHOLD=200

# Feature Flags
FEATURE_CRYPTO_PAYMENTS=false
FEATURE_MOBILE_MONEY=false
FEATURE_BNPL=false
FEATURE_COURSES=false
FEATURE_FORUM=false
FEATURE_AI_GENERATOR=false
FEATURE_VENDOR_WALLET=false
FEATURE_INSTANT_PAYOUTS=false

# Company
COMPANY_NAME="Web-Temify LTD"
COMPANY_RC=7999659
ADMIN_EMAIL=nwachukwuchinaemerem8@gmail.com
TINLANCE_URL=https://tinlance.com
```

---

## DATABASE MIGRATIONS (Laravel Migration Files)

### Core Tables

```php
// 2026_01_01_000001_create_users_table.php
Schema::create('users', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('email')->unique();
    $table->string('username')->unique()->nullable();
    $table->timestamp('email_verified_at')->nullable();
    $table->string('password');
    $table->string('avatar')->nullable();
    $table->text('bio')->nullable();
    $table->enum('plan', ['free','pro','business','agency'])->default('free');
    $table->timestamp('plan_expires_at')->nullable();
    $table->timestamp('trial_ends_at')->nullable();
    $table->boolean('trial_charged')->default(false);
    $table->enum('status', ['active','suspended','banned'])->default('active');
    $table->string('google_id')->nullable();
    $table->string('github_id')->nullable();
    $table->string('twitter_id')->nullable();
    $table->string('two_factor_secret')->nullable();
    $table->boolean('two_factor_enabled')->default(false);
    $table->integer('login_attempts')->default(0);
    $table->timestamp('locked_until')->nullable();
    $table->integer('profile_score')->default(0);
    $table->integer('points')->default(0);
    $table->boolean('dark_mode')->default(false);
    $table->string('language', 5)->default('en');
    $table->string('timezone')->default('Africa/Lagos');
    $table->string('currency', 3)->default('USD');
    $table->string('referral_code', 10)->unique()->nullable();
    $table->foreignId('referred_by')->nullable()->constrained('users');
    $table->string('device_fingerprint')->nullable();
    $table->integer('fraud_score')->default(0);
    $table->string('ip_address')->nullable();
    $table->timestamp('terms_accepted_at')->nullable();
    $table->boolean('age_verified')->default(false);
    $table->rememberToken();
    $table->timestamps();
    $table->softDeletes();
});

// 2026_01_01_000002_create_products_table.php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->foreignId('vendor_id')->constrained('vendors');
    $table->string('name');
    $table->string('slug')->unique();
    $table->text('description');
    $table->string('short_desc', 200)->nullable();
    $table->foreignId('category_id')->constrained('categories');
    $table->enum('type', ['template','script','kit','component','course']);
    $table->string('tech_stack')->nullable();
    $table->integer('page_count')->nullable();
    $table->enum('difficulty', ['beginner','intermediate','advanced'])->default('beginner');
    $table->string('demo_url')->nullable();
    $table->string('download_file')->nullable();
    $table->string('file_version', 20)->default('1.0.0');
    $table->string('file_hash')->nullable();
    $table->decimal('price', 10, 2)->default(0);
    $table->decimal('original_price', 10, 2)->nullable();
    $table->decimal('rental_price', 10, 2)->nullable();
    $table->enum('license_type', ['regular','extended','white_label'])->default('regular');
    $table->string('compatibility')->nullable();
    $table->string('color_scheme')->nullable();
    $table->json('industry_tags')->nullable();
    $table->enum('status', ['draft','pending','approved','rejected','suspended'])->default('draft');
    $table->boolean('featured')->default(false);
    $table->boolean('exclusive')->default(false);
    $table->integer('quality_score')->default(0);
    $table->enum('virus_scan_status', ['pending','clean','infected','skipped'])->default('pending');
    $table->timestamp('virus_scan_date')->nullable();
    $table->integer('downloads')->default(0);
    $table->integer('views')->default(0);
    $table->integer('purchases')->default(0);
    $table->decimal('rating_avg', 3, 2)->default(0);
    $table->integer('rating_count')->default(0);
    $table->boolean('has_dark_mode')->default(false);
    $table->boolean('has_rtl')->default(false);
    $table->boolean('mobile_responsive')->default(true);
    $table->string('preview_image')->nullable();
    $table->json('screenshots')->nullable();
    $table->string('demo_video')->nullable();
    $table->timestamps();
    $table->softDeletes();
});

// 2026_01_01_000003_create_orders_table.php
Schema::create('orders', function (Blueprint $table) {
    $table->id();
    $table->string('order_number')->unique();
    $table->foreignId('user_id')->constrained();
    $table->foreignId('product_id')->nullable()->constrained();
    $table->foreignId('plan_id')->nullable()->constrained('plans');
    $table->foreignId('vendor_id')->nullable()->constrained('vendors');
    $table->decimal('amount', 10, 2);
    $table->string('currency', 3)->default('USD');
    $table->enum('gateway', ['paystack','stripe','lemonsqueezy','nowpayments','mobilemoney','bnpl']);
    $table->string('gateway_ref')->nullable();
    $table->string('gateway_status')->nullable();
    $table->foreignId('license_key_id')->nullable()->constrained('license_keys');
    $table->foreignId('coupon_id')->nullable()->constrained('coupons');
    $table->integer('fraud_score')->default(0);
    $table->string('ip_address')->nullable();
    $table->string('device_fingerprint')->nullable();
    $table->enum('status', ['pending','completed','failed','refunded','disputed'])->default('pending');
    $table->string('idempotency_key')->unique()->nullable();
    $table->timestamps();
});

// 2026_01_01_000004_create_subscriptions_table.php
Schema::create('subscriptions', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained();
    $table->foreignId('plan_id')->constrained('plans');
    $table->enum('gateway', ['paystack','stripe','lemonsqueezy']);
    $table->string('gateway_sub_id')->nullable();
    $table->enum('status', ['active','cancelled','expired','paused','past_due'])->default('active');
    $table->boolean('paused')->default(false);
    $table->string('pause_reason')->nullable();
    $table->timestamp('current_period_start')->nullable();
    $table->timestamp('current_period_end')->nullable();
    $table->boolean('cancel_at_period_end')->default(false);
    $table->timestamp('grace_period_until')->nullable();
    $table->timestamp('trial_end')->nullable();
    $table->timestamps();
});

// 2026_01_01_000005_create_license_keys_table.php
Schema::create('license_keys', function (Blueprint $table) {
    $table->id();
    $table->foreignId('order_id')->constrained();
    $table->foreignId('product_id')->constrained();
    $table->foreignId('user_id')->constrained();
    $table->string('key_hash')->unique();
    $table->string('key_display', 40);
    $table->enum('license_type', ['single','multi','agency','white_label']);
    $table->integer('activation_limit')->default(1);
    $table->integer('activation_count')->default(0);
    $table->json('domains')->nullable();
    $table->timestamp('expires_at')->nullable();
    $table->boolean('revoked')->default(false);
    $table->timestamp('revoked_at')->nullable();
    $table->string('revoked_reason')->nullable();
    $table->timestamps();
});

// 2026_01_01_000006_create_vendors_table.php
Schema::create('vendors', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->unique();
    $table->string('business_name');
    $table->string('slug')->unique();
    $table->text('bio')->nullable();
    $table->string('avatar')->nullable();
    $table->string('banner')->nullable();
    $table->string('website')->nullable();
    $table->json('social_links')->nullable();
    $table->json('speciality_tags')->nullable();
    $table->boolean('verified')->default(false);
    $table->timestamp('verified_at')->nullable();
    $table->string('id_document')->nullable();
    $table->enum('tier', ['starter','pro','top','exclusive'])->default('starter');
    $table->decimal('commission_rate', 5, 2)->default(20.00);
    $table->decimal('total_earnings', 12, 2)->default(0);
    $table->decimal('pending_earnings', 12, 2)->default(0);
    $table->decimal('wallet_balance', 12, 2)->default(0);
    $table->decimal('tax_reserve', 12, 2)->default(0);
    $table->decimal('tax_reserve_percent', 5, 2)->default(10.00);
    $table->integer('response_time_avg')->nullable();
    $table->decimal('chargeback_rate', 5, 4)->default(0);
    $table->decimal('quality_score_avg', 5, 2)->default(0);
    $table->string('cac_number')->nullable();
    $table->boolean('cac_verified')->default(false);
    $table->enum('status', ['pending','active','suspended'])->default('pending');
    $table->timestamps();
});

// 2026_01_01_000007_create_directory_listings_table.php
Schema::create('directory_listings', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('slug')->unique();
    $table->string('tagline', 120)->nullable();
    $table->text('description');
    $table->string('url');
    $table->string('logo')->nullable();
    $table->enum('category', [
        'ai_ml','webdev','web3','design','nocode',
        'hosting','plugins','blockchain','freelancer','learning'
    ]);
    $table->enum('pricing_tier', ['free','freemium','paid'])->default('freemium');
    $table->string('region')->nullable();
    $table->string('affiliate_url')->nullable();
    $table->boolean('featured')->default(false);
    $table->timestamp('featured_until')->nullable();
    $table->boolean('sponsored')->default(false);
    $table->decimal('rating_avg', 3, 2)->default(0);
    $table->integer('rating_count')->default(0);
    $table->integer('click_count')->default(0);
    $table->enum('status', ['draft','approved','rejected'])->default('draft');
    $table->foreignId('submitted_by')->nullable()->constrained('users');
    $table->timestamp('approved_at')->nullable();
    $table->json('tags')->nullable();
    $table->timestamps();
});
```

---

## MODELS (app/Models/)

```php
// Key relationships to implement in each model:

// User.php
class User extends Authenticatable {
    use HasRoles, HasFactory, Notifiable, SoftDeletes;

    public function vendor() { return $this->hasOne(Vendor::class); }
    public function orders() { return $this->hasMany(Order::class); }
    public function subscription() { return $this->hasOne(Subscription::class)->latest(); }
    public function downloads() { return $this->hasMany(Download::class); }
    public function reviews() { return $this->hasMany(Review::class); }
    public function points() { return $this->hasMany(UserPoint::class); }
    public function badges() { return $this->belongsToMany(Badge::class, 'user_badges')->withTimestamps(); }
    public function wishlist() { return $this->belongsToMany(Product::class, 'wishlists'); }
    public function collections() { return $this->hasMany(Collection::class); }
    public function licenseKeys() { return $this->hasMany(LicenseKey::class); }
    public function serviceRequests() { return $this->hasMany(ServiceRequest::class); }
    public function isVendor(): bool { return $this->vendor()->exists(); }
    public function hasActivePlan(): bool { return $this->plan !== 'free' && $this->plan_expires_at > now(); }
    public function getAvatarUrlAttribute(): string {
        return $this->avatar
            ? config('supabase.url') . '/storage/v1/object/public/user-avatars/' . $this->avatar
            : 'https://www.gravatar.com/avatar/' . md5($this->email);
    }
}

// Product.php
class Product extends Model {
    use HasFactory, SoftDeletes;

    protected $casts = [
        'industry_tags' => 'array',
        'screenshots' => 'array',
    ];

    public function vendor() { return $this->belongsTo(Vendor::class); }
    public function category() { return $this->belongsTo(Category::class); }
    public function orders() { return $this->hasMany(Order::class); }
    public function reviews() { return $this->hasMany(Review::class)->where('status', 'approved'); }
    public function licenseKeys() { return $this->hasMany(LicenseKey::class); }
    public function versions() { return $this->hasMany(ProductVersion::class); }
    public function wishlists() { return $this->belongsToMany(User::class, 'wishlists'); }
    public function getPreviewImageUrlAttribute(): string {
        return $this->preview_image
            ? config('supabase.url') . '/storage/v1/object/public/template-previews/' . $this->preview_image
            : asset('images/placeholder.jpg');
    }
    public function scopeApproved($query) { return $query->where('status', 'approved'); }
    public function scopeFeatured($query) { return $query->where('featured', true); }
}

// Vendor.php
class Vendor extends Model {
    public function user() { return $this->belongsTo(User::class); }
    public function products() { return $this->hasMany(Product::class); }
    public function payouts() { return $this->hasMany(VendorPayout::class); }
    public function analytics() { return $this->hasMany(VendorAnalytic::class); }
    public function getCommissionRateAttribute(): float {
        return $this->exclusive ? 15.00 : $this->attributes['commission_rate'];
    }
    public function getRevenueShareAttribute(): float {
        return 100 - $this->commission_rate;
    }
}
```

---

## CONTROLLERS (app/Http/Controllers/)

### Controller Structure

```
Controllers/
├── Auth/
│   ├── LoginController.php
│   ├── RegisterController.php
│   ├── TwoFactorController.php
│   └── SocialLoginController.php
├── Marketplace/
│   ├── TemplateController.php
│   ├── PreviewController.php
│   ├── CompareController.php
│   ├── SearchController.php
│   └── SandboxController.php
├── Checkout/
│   ├── CheckoutController.php
│   ├── PaystackController.php
│   ├── StripeController.php
│   ├── LemonSqueezyController.php
│   ├── NowPaymentsController.php
│   └── DownloadController.php
├── Dashboard/
│   ├── UserDashboardController.php
│   ├── SubscriptionController.php
│   ├── WishlistController.php
│   └── CollectionController.php
├── Vendor/
│   ├── VendorController.php
│   ├── VendorProductController.php
│   ├── VendorAnalyticsController.php
│   └── VendorPayoutController.php
├── Directory/
│   ├── DirectoryController.php
│   ├── DirectoryListingController.php
│   └── DirectorySubmitController.php
├── Services/
│   └── ServiceRequestController.php
├── Community/
│   ├── ForumController.php
│   ├── ShowcaseController.php
│   └── LeaderboardController.php
├── Admin/
│   ├── AdminDashboardController.php
│   ├── AdminUserController.php
│   ├── AdminProductController.php
│   ├── AdminVendorController.php
│   ├── AdminDirectoryController.php
│   ├── AdminOrderController.php
│   ├── AdminAnalyticsController.php
│   ├── AdminEmailController.php
│   ├── AdminBlogController.php
│   ├── AdminGamificationController.php
│   ├── AdminFraudController.php
│   └── AdminSettingsController.php
├── API/
│   ├── ApiV1Controller.php
│   ├── LicenseController.php
│   ├── AiGeneratorController.php
│   └── AiSearchController.php
└── Webhooks/
    ├── PaystackWebhookController.php
    ├── StripeWebhookController.php
    ├── LemonSqueezyWebhookController.php
    └── NowPaymentsWebhookController.php
```

---

## ROUTES (routes/)

```php
// routes/web.php

// Public routes
Route::get('/', [HomeController::class, 'index'])->name('home');
Route::get('/templates', [TemplateController::class, 'index'])->name('templates');
Route::get('/templates/{category}', [TemplateController::class, 'category'])->name('templates.category');
Route::get('/preview/{slug}', [PreviewController::class, 'show'])->name('preview');
Route::get('/compare', [CompareController::class, 'index'])->name('compare');
Route::get('/launch-kits', [KitController::class, 'index'])->name('kits');
Route::get('/launch-kits/{slug}', [KitController::class, 'show'])->name('kits.show');
Route::get('/web3', [Web3Controller::class, 'index'])->name('web3');
Route::get('/directory', [DirectoryController::class, 'index'])->name('directory');
Route::get('/directory/{category}', [DirectoryController::class, 'category'])->name('directory.category');
Route::get('/directory/tool/{slug}', [DirectoryListingController::class, 'show'])->name('directory.listing');
Route::get('/services', [ServiceController::class, 'index'])->name('services');
Route::get('/pricing', [PricingController::class, 'index'])->name('pricing');
Route::get('/blog', [BlogController::class, 'index'])->name('blog');
Route::get('/blog/{slug}', [BlogController::class, 'show'])->name('blog.show');
Route::get('/about', [PageController::class, 'about'])->name('about');
Route::get('/roadmap', [PageController::class, 'roadmap'])->name('roadmap');
Route::get('/changelog', [PageController::class, 'changelog'])->name('changelog');

// Auth routes (Breeze)
require __DIR__.'/auth.php';

// OAuth
Route::get('/auth/{provider}', [SocialLoginController::class, 'redirect'])->name('social.redirect');
Route::get('/auth/{provider}/callback', [SocialLoginController::class, 'callback'])->name('social.callback');

// Authenticated routes
Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('/dashboard', [UserDashboardController::class, 'index'])->name('dashboard');
    Route::get('/my-downloads', [UserDashboardController::class, 'downloads'])->name('downloads');
    Route::get('/my-purchases', [UserDashboardController::class, 'purchases'])->name('purchases');
    Route::get('/my-subscription', [SubscriptionController::class, 'index'])->name('subscription');
    Route::post('/subscription/pause', [SubscriptionController::class, 'pause'])->name('subscription.pause');
    Route::post('/subscription/resume', [SubscriptionController::class, 'resume'])->name('subscription.resume');
    Route::get('/checkout/{product?}', [CheckoutController::class, 'index'])->name('checkout');
    Route::post('/checkout/process', [CheckoutController::class, 'process'])->name('checkout.process');
    Route::get('/download/{token}', [DownloadController::class, 'download'])->name('download');
    Route::get('/vendor/register', [VendorController::class, 'register'])->name('vendor.register');
    Route::post('/vendor/register', [VendorController::class, 'store'])->name('vendor.store');
    Route::middleware(['vendor'])->prefix('vendor')->name('vendor.')->group(function () {
        Route::get('/', [VendorController::class, 'dashboard'])->name('dashboard');
        Route::resource('products', VendorProductController::class);
        Route::get('/analytics', [VendorAnalyticsController::class, 'index'])->name('analytics');
        Route::get('/payouts', [VendorPayoutController::class, 'index'])->name('payouts');
        Route::post('/payouts/request', [VendorPayoutController::class, 'request'])->name('payouts.request');
        Route::get('/wallet', [VendorWalletController::class, 'index'])->name('wallet');
    });
    Route::get('/service-request', [ServiceRequestController::class, 'create'])->name('service.create');
    Route::post('/service-request', [ServiceRequestController::class, 'store'])->name('service.store');
    Route::get('/2fa/setup', [TwoFactorController::class, 'setup'])->name('2fa.setup');
    Route::post('/2fa/enable', [TwoFactorController::class, 'enable'])->name('2fa.enable');
    Route::get('/points-rewards', [GamificationController::class, 'index'])->name('points');
    Route::get('/profile/{username}', [ProfileController::class, 'show'])->name('profile');
});

// Admin routes
Route::middleware(['auth', '2fa', 'role:admin', 'ip_whitelist'])
    ->prefix('admin')
    ->name('admin.')
    ->group(function () {
        Route::get('/', [AdminDashboardController::class, 'index'])->name('dashboard');
        Route::resource('users', AdminUserController::class);
        Route::resource('products', AdminProductController::class);
        Route::resource('vendors', AdminVendorController::class);
        Route::resource('directory', AdminDirectoryController::class);
        Route::resource('orders', AdminOrderController::class);
        Route::get('/analytics', [AdminAnalyticsController::class, 'index'])->name('analytics');
        Route::get('/analytics/geo', [AdminAnalyticsController::class, 'geo'])->name('analytics.geo');
        Route::get('/analytics/attribution', [AdminAnalyticsController::class, 'attribution'])->name('analytics.attribution');
        Route::resource('blog', AdminBlogController::class);
        Route::resource('email-campaigns', AdminEmailController::class);
        Route::get('/fraud', [AdminFraudController::class, 'index'])->name('fraud');
        Route::get('/chargebacks', [AdminFraudController::class, 'chargebacks'])->name('chargebacks');
        Route::get('/service-requests', [AdminServiceController::class, 'index'])->name('service-requests');
        Route::get('/settings', [AdminSettingsController::class, 'index'])->name('settings');
        Route::post('/settings', [AdminSettingsController::class, 'update'])->name('settings.update');
    });

// API routes
Route::prefix('api/v1')
    ->name('api.v1.')
    ->middleware(['api', 'throttle:100,1'])
    ->group(function () {
        Route::get('/templates', [ApiV1Controller::class, 'templates']);
        Route::get('/categories', [ApiV1Controller::class, 'categories']);
        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/me', [ApiV1Controller::class, 'me']);
            Route::get('/my-templates', [ApiV1Controller::class, 'myTemplates']);
        });
        Route::post('/validate-license', [LicenseController::class, 'validate']);
        Route::post('/ai/generate', [AiGeneratorController::class, 'generate'])->middleware('auth:sanctum');
        Route::post('/ai/search', [AiSearchController::class, 'search']);
    });

// Webhook routes (no CSRF)
Route::prefix('webhooks')->middleware('webhook.verify')->group(function () {
    Route::post('/paystack', [PaystackWebhookController::class, 'handle'])->name('webhooks.paystack');
    Route::post('/stripe', [StripeWebhookController::class, 'handle'])->name('webhooks.stripe');
    Route::post('/lemonsqueezy', [LemonSqueezyWebhookController::class, 'handle'])->name('webhooks.lemonsqueezy');
    Route::post('/nowpayments', [NowPaymentsWebhookController::class, 'handle'])->name('webhooks.nowpayments');
});
```

---

## SERVICES (app/Services/)

```php
// app/Services/PaymentService.php
class PaymentService {
    public function initiate(array $data, string $gateway): array {}
    public function verify(string $reference, string $gateway): bool {}
    public function refund(Order $order): bool {}
    public function createSubscription(User $user, Plan $plan, string $gateway): array {}
    public function cancelSubscription(Subscription $sub): bool {}
    public function pauseSubscription(Subscription $sub): bool {}
}

// app/Services/LicenseService.php
class LicenseService {
    public function generate(Order $order): LicenseKey {}
    public function validate(string $key, string $domain): array {}
    public function activate(LicenseKey $key, string $domain): bool {}
    public function deactivate(LicenseKey $key, string $domain): bool {}
    public function revoke(LicenseKey $key, string $reason): bool {}
}

// app/Services/FraudService.php
class FraudService {
    public function scoreRegistration(Request $request): int {}
    public function scoreTransaction(array $data): int {}
    public function detectVelocity(User $user): bool {}
    public function detectStolenCard(array $payment): bool {}
    public function fingerprintMatch(string $fingerprint): ?User {}
}

// app/Services/AIGatewayService.php
class AIGatewayService {
    private array $providers = ['claude', 'grok', 'gemini', 'openai'];
    private array $taskRouting = [
        'blog_post'          => ['claude', 'openai', 'gemini'],
        'directory_listing'  => ['gemini', 'claude', 'openai'],
        'page_generator'     => ['claude', 'openai', 'grok'],
        'product_description'=> ['claude', 'openai', 'gemini'],
        'support_reply'      => ['claude', 'gemini', 'openai'],
        'semantic_search'    => ['gemini', 'claude', 'openai'],
        'web3_content'       => ['grok', 'claude', 'openai'],
        'pricing_advice'     => ['claude', 'openai', 'gemini'],
        'review_summary'     => ['claude', 'gemini', 'openai'],
    ];

    public function complete(string $prompt, string $task = 'general', int $maxTokens = 1000): string {
        $ordered = $this->taskRouting[$task] ?? $this->providers;
        foreach ($ordered as $provider) {
            try {
                $result = $this->callProvider($provider, $prompt, $maxTokens);
                $this->logUsage($provider, $task, $result);
                return $result;
            } catch (\Exception $e) {
                $this->logFailure($provider, $task, $e->getMessage());
                continue;
            }
        }
        return $this->getFallbackResponse($task);
    }

    private function callProvider(string $provider, string $prompt, int $maxTokens): string {
        return match($provider) {
            'claude'  => $this->callClaude($prompt, $maxTokens),
            'grok'    => $this->callGrok($prompt, $maxTokens),
            'gemini'  => $this->callGemini($prompt, $maxTokens),
            'openai'  => $this->callOpenAI($prompt, $maxTokens),
            default   => throw new \Exception("Unknown provider: $provider"),
        };
    }
}

// app/Services/SupabaseService.php
class SupabaseService {
    public function upload(string $file, string $bucket, string $path): string {}
    public function delete(string $path, string $bucket): bool {}
    public function getUrl(string $path, string $bucket): string {}
    public function getSignedUrl(string $path, string $bucket, int $expiresIn = 3600): string {}
    public function transformImage(string $path, array $transforms): string {}
}

// app/Services/GamificationService.php
class GamificationService {
    public function awardPoints(User $user, string $action, int $amount, ?int $referenceId = null): void {}
    public function checkBadges(User $user): void {}
    public function updateLeaderboard(): void {}
    public function redeemPoints(User $user, int $points): float {}
}

// app/Services/DirectoryService.php
class DirectoryService {
    public function autoPopulate(): void {}
    public function fetchFromProductHunt(): array {}
    public function fetchFromGitHubTrending(): array {}
    public function generateListingData(string $name, string $url): array {}
    public function trackClick(DirectoryListing $listing, Request $request): void {}
}
```

---

## JOBS & QUEUES (app/Jobs/)

```php
// All jobs extend Job and implement ShouldQueue

SendWelcomeEmail::class
SendVerificationEmail::class
SendPasswordResetEmail::class
SendPurchaseReceiptEmail::class
SendSubscriptionReceiptEmail::class
SendExpiryReminderEmail::class
SendDownloadReadyEmail::class
SendProductUpdateNotificationEmail::class
SendVendorApprovedEmail::class
SendVendorSaleEmail::class
SendVendorPayoutEmail::class
SendAffiliateCommissionEmail::class
SendAbandonedCheckoutEmail::class
SendDripEmailJob::class
SendDunningEmailJob::class
SendSuspiciousLoginEmail::class
SendServiceRequestConfirmEmail::class
SendServiceRequestAdminEmail::class
SendWeeklyNewsletterJob::class
SendNpsSurveyEmail::class
SendWinBackEmailJob::class
SendLicenseExpiryReminderEmail::class
SendAnnualRecapEmailJob::class
SendVendorRejectionEmail::class
Send2FACodeEmail::class

ProcessVirusTotalScan::class
ProcessImageOptimization::class
ProcessWebPConversion::class
GenerateLicenseKey::class
CalculateMRR::class
UpdateProfileScore::class
UpdateVendorAnalytics::class
UpdateProductPerformanceScore::class
ProcessVendorPayout::class
CheckChargebackRatio::class
DetectFraudSignals::class
PopulateDirectoryListing::class
GenerateBlogPost::class
GenerateNichePage::class
ProcessCryptoPayment::class
```

---

## LARAVEL SCHEDULER (app/Console/Kernel.php)

```php
protected function schedule(Schedule $schedule): void
{
    // Every minute
    $schedule->job(new CleanExpiredTokensJob)->everyMinute();

    // Every 6 hours
    $schedule->job(new SendExpiryRemindersJob)->everySixHours();

    // Daily jobs
    $schedule->job(new AutoDowngradeExpiredSubscriptionsJob)->dailyAt('02:00');
    $schedule->job(new SendAbandonedCheckoutEmailsJob)->dailyAt('03:00');
    $schedule->job(new ProcessDripEmailsJob)->dailyAt('04:00');
    $schedule->job(new ProcessDunningJob)->dailyAt('05:00');
    $schedule->job(new ProcessBouncedEmailsJob)->dailyAt('06:00');
    $schedule->job(new ProcessNpsTriggerJob)->dailyAt('07:00');
    $schedule->job(new SendWinBackEmailsJob)->dailyAt('08:00');
    $schedule->job(new SendLicenseExpiryRemindersJob)->dailyAt('09:00');
    $schedule->job(new ExpireFlashSalesJob)->dailyAt('10:00');
    $schedule->job(new CalculateMRRJob)->dailyAt('00:00');
    $schedule->job(new UpdateProfileScoresJob)->dailyAt('00:30');
    $schedule->job(new CheckPointsExpiryJob)->dailyAt('01:00');
    $schedule->job(new ProcessFreeTrialChargesJob)->dailyAt('01:30');

    // Africa time zone optimal (9am WAT = 8am UTC)
    $schedule->job(new SendScheduledAnnouncementsJob)->dailyAt('08:00');

    // Weekly jobs (Monday)
    $schedule->job(new ResetWeeklyDownloadCountersJob)->weeklyOn(1, '01:00');
    $schedule->job(new SendWeeklyNewsletterJob)->weeklyOn(1, '06:00');
    $schedule->job(new ResetSponsoredPlacementsJob)->weeklyOn(1, '07:00');
    $schedule->job(new UpdateLeaderboardJob)->weeklyOn(1, '08:00');

    // Monthly (1st of month)
    $schedule->job(new ProcessFreeTrialChargesJob)->monthlyOn(1, '02:00');

    // Directory auto-populate (every 4 hours)
    $schedule->job(new PopulateDirectoryListingsJob)->cron('0 */4 * * *');

    // Blog auto-generate (daily)
    $schedule->job(new GenerateBlogPostDraftsJob)->dailyAt('03:30');

    // Annual recap (January 1st)
    $schedule->job(new SendAnnualRecapEmailsJob)->yearlyOn(1, 1, '09:00');
}
```

---

## MIDDLEWARE (app/Http/Middleware/)

```php
// Custom middleware to create:

TwoFactorMiddleware::class          // Enforce 2FA for admin
IpWhitelistMiddleware::class        // Admin IP restriction
VendorMiddleware::class             // Check vendor status
WebhookVerifyMiddleware::class      // HMAC verification for webhooks
FraudCheckMiddleware::class         // Score and flag suspicious requests
FeatureFlagMiddleware::class        // Check feature flags
TrackPageViewMiddleware::class      // Analytics page view tracking
LocalizationMiddleware::class       // Set locale + currency by IP
LowBandwidthMiddleware::class       // Serve lite version for slow connections

// Register in bootstrap/app.php:
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias([
        '2fa'           => TwoFactorMiddleware::class,
        'ip_whitelist'  => IpWhitelistMiddleware::class,
        'vendor'        => VendorMiddleware::class,
        'webhook.verify'=> WebhookVerifyMiddleware::class,
        'fraud.check'   => FraudCheckMiddleware::class,
        'feature'       => FeatureFlagMiddleware::class,
    ]);
})
```

---

## PAYMENT GATEWAYS — COMPLETE SPEC

### Rule: ALL payment flows must offer ALL enabled gateways

**Phase 1 (Live now):** Paystack + Stripe + LemonSqueezy
**Phase 2 (Add):** MTN MoMo + Airtel Money + M-Pesa + Carbon BNPL
**Phase 3 (Add):** USDT/USDC via NOWPayments (auto-convert, no volatile crypto)

### Paystack (PaystackController)

```php
// Initiate payment
public function initiate(Request $request): JsonResponse {
    $response = Http::withToken(config('paystack.secret_key'))
        ->post('https://api.paystack.co/transaction/initialize', [
            'email'     => auth()->user()->email,
            'amount'    => $request->amount * 100,
            'currency'  => 'NGN',
            'reference' => 'WT-' . uniqid(),
            'callback_url' => route('checkout.paystack.callback'),
            'metadata'  => ['order_id' => $request->order_id],
        ]);
    return response()->json($response->json());
}

// Webhook (always verify HMAC first)
public function handle(Request $request): Response {
    $hash = hash_hmac('sha512', $request->getContent(), config('paystack.webhook_secret'));
    abort_if($hash !== $request->header('X-Paystack-Signature'), 401);
    // Check idempotency
    $event = $request->input('event');
    match($event) {
        'charge.success'          => $this->handleChargeSuccess($request->input('data')),
        'subscription.create'     => $this->handleSubscriptionCreate($request->input('data')),
        'subscription.disable'    => $this->handleSubscriptionDisable($request->input('data')),
        'charge.dispute.create'   => $this->handleDisputeCreate($request->input('data')),
        default => null,
    };
    return response('OK', 200);
}
```

### NOWPayments - USDT/USDC (Phase 3)

```php
// Feature flag check first
if (!config('features.crypto_payments')) {
    abort(404);
}
// Only accept USDT (TRC-20) and USDC (TRC-20 or ERC-20)
// Auto-converts to fiat instantly
// No BTC, ETH, SOL, or volatile coins ever
// Refunds = platform credits only (no on-chain refunds)
// IPN verification:
$sig = hash_hmac('sha512', $sorted_payload, config('nowpayments.ipn_secret'));
```

---

## AI GATEWAY — MULTI-LLM FALLBACK

```php
// app/Services/AIGatewayService.php

// Provider routing by task type:
// blog_post          → Claude (primary) → GPT-4o → Gemini
// directory_listing  → Gemini Flash (near free) → Claude → GPT-4o
// page_generator     → Claude → GPT-4o → Grok
// product_description→ Claude → GPT-4o → Gemini
// support_reply      → Claude Haiku → GPT-4o-mini → Gemini Flash
// semantic_search    → Gemini Flash → Claude Haiku → GPT-4o-mini
// web3_content       → Grok → Claude → GPT-4o

// Fallback chain per provider:
// 1. Claude Sonnet 4 (Anthropic) — best quality, long-form
// 2. Grok-3 (xAI)                — Web3/crypto content
// 3. Gemini 2.5 Flash (Google)   — near-free, fast, real-time
// 4. GPT-4o-mini (OpenAI)        — cheapest, most reliable uptime

// Log all AI usage to ai_usage_log table:
// provider, task_type, tokens_input, tokens_output, cost_usd, latency_ms, success
```

---

## BLADE VIEWS STRUCTURE (resources/views/)

```
views/
├── layouts/
│   ├── app.blade.php          # Main layout (nav + footer)
│   ├── admin.blade.php        # Admin layout
│   ├── auth.blade.php         # Auth pages layout
│   └── vendor.blade.php       # Vendor dashboard layout
├── components/
│   ├── template-card.blade.php
│   ├── kit-card.blade.php
│   ├── directory-card.blade.php
│   ├── pricing-card.blade.php
│   ├── vendor-card.blade.php
│   ├── review-card.blade.php
│   ├── nav.blade.php
│   ├── footer.blade.php
│   ├── marquee.blade.php
│   ├── social-proof-toast.blade.php
│   ├── announcement-banner.blade.php
│   ├── cookie-banner.blade.php
│   ├── dark-mode-toggle.blade.php
│   └── payment-tabs.blade.php
├── home/
│   └── index.blade.php
├── marketplace/
│   ├── index.blade.php
│   ├── preview.blade.php
│   ├── compare.blade.php
│   ├── search.blade.php
│   └── sandbox.blade.php
├── kits/
│   ├── index.blade.php
│   └── show.blade.php
├── web3/
│   └── index.blade.php
├── directory/
│   ├── index.blade.php
│   ├── category.blade.php
│   ├── show.blade.php
│   └── submit.blade.php
├── checkout/
│   ├── index.blade.php
│   ├── success.blade.php
│   └── failed.blade.php
├── dashboard/
│   ├── index.blade.php
│   ├── downloads.blade.php
│   ├── purchases.blade.php
│   ├── subscription.blade.php
│   ├── points.blade.php
│   └── badges.blade.php
├── vendor/
│   ├── register.blade.php
│   ├── dashboard.blade.php
│   ├── products/
│   ├── analytics.blade.php
│   ├── payouts.blade.php
│   └── wallet.blade.php
├── admin/
│   ├── dashboard.blade.php
│   ├── users/
│   ├── products/
│   ├── vendors/
│   ├── directory/
│   ├── orders/
│   ├── analytics/
│   ├── blog/
│   ├── fraud.blade.php
│   └── settings.blade.php
├── community/
│   ├── forum/
│   ├── showcase.blade.php
│   └── leaderboard.blade.php
├── services/
│   ├── index.blade.php
│   └── request.blade.php
├── pages/
│   ├── about.blade.php
│   ├── roadmap.blade.php
│   ├── changelog.blade.php
│   ├── pricing.blade.php
│   ├── licenses.blade.php
│   ├── privacy.blade.php
│   ├── terms.blade.php
│   ├── dmca.blade.php
│   └── developer-hub.blade.php
└── emails/
    ├── welcome.blade.php
    ├── verify-email.blade.php
    ├── purchase-receipt.blade.php
    ├── vendor-sale.blade.php
    └── (25 email templates total)
```

---

## SECURITY REQUIREMENTS

```php
// 1. CSRF — Laravel handles this automatically
// Always use @csrf in forms. Verify on API with Sanctum tokens.

// 2. All DB — Eloquent ORM (prepared statements by default)
// Never: DB::select("SELECT * FROM users WHERE id = " . $id)
// Always: User::find($id) or DB::select('SELECT * FROM users WHERE id = ?', [$id])

// 3. Rate Limiting (routes/web.php + RouteServiceProvider)
RateLimiter::for('login', function (Request $request) {
    return Limit::perMinutes(15, 5)->by($request->ip());
});
RateLimiter::for('checkout', function (Request $request) {
    return Limit::perHour(10)->by($request->user()->id ?? $request->ip());
});
RateLimiter::for('api', function (Request $request) {
    return Limit::perMinute(100)->by($request->user()?->id ?? $request->ip());
});

// 4. Input validation — Form Requests for every controller action
// php artisan make:request StoreProductRequest
// Validate ALL input in handle() method

// 5. File uploads — validate in StoreProductRequest
$rules = [
    'file' => 'required|file|mimes:zip,rar|max:51200', // 50MB max
    'preview_image' => 'required|image|mimes:jpg,jpeg,png,webp|max:5120',
];

// 6. Admin — check 2FA + IP whitelist via middleware stack
// 7. Download tokens — expire 24h, single-use, stored in downloads table
// 8. Webhook HMAC — verify in WebhookVerifyMiddleware before routing
// 9. Passwords — bcrypt (Laravel default, cost factor 12)
// 10. XSS — Blade {{ }} escapes by default. Only use {!! !!} for trusted HTML.
```

---

## TESTING

```php
// php artisan make:test ProductTest
// php artisan make:test CheckoutTest
// php artisan make:test LicenseTest
// php artisan make:test VendorTest
// php artisan make:test WebhookTest

// Key tests to write:
// ✅ User can register + verify email
// ✅ User can login + 2FA
// ✅ Template browsing + filtering
// ✅ Checkout flow (Paystack + Stripe + LemonSqueezy)
// ✅ License key generated on purchase
// ✅ License validation API returns correct response
// ✅ Webhook HMAC verification fails on invalid signature
// ✅ Webhook processes charge.success correctly
// ✅ Vendor can upload product
// ✅ Admin can approve/reject vendor product
// ✅ Download token expires correctly
// ✅ Fraud score calculated on registration
// ✅ Rate limiting blocks after threshold
// ✅ AI gateway falls back on provider failure
// ✅ Directory listing created from auto-populate job

// Run tests:
php artisan test
php artisan test --parallel
```

---

## BUILD PHASES — DETAILED

### PHASE 1 — DEPLOY & GO LIVE (Week 1–2)

```bash
# Files to create first:
php artisan make:model User -m
php artisan make:model Product -m
php artisan make:model Category -m
php artisan make:model Order -m
php artisan make:model Plan -m
php artisan make:model Subscription -m
php artisan make:migration create_plans_table
php artisan migrate --seed

# Seeders to create:
php artisan make:seeder PlansSeeder
php artisan make:seeder CategoriesSeeder
php artisan make:seeder LanguagesSeeder
php artisan make:seeder DripSequencesSeeder

# Phase 1 checklist:
# 1. Laravel project created and configured
# 2. All environment variables set
# 3. Database migrated + seeded
# 4. Authentication working (Breeze + email verify)
# 5. Homepage blade view matches web-temify-v3.html design
# 6. Templates listing page working
# 7. Checkout flow working (Paystack + Stripe + LemonSqueezy)
# 8. Webhook handlers working with HMAC verify
# 9. Download system with token expiry working
# 10. Admin panel accessible (role:admin + 2FA + IP whitelist)
# 11. Supabase storage connected
# 12. All 9 cron jobs running via Laravel Scheduler
# 13. Cloudflare CDN configured for static assets
# 14. Redis caching active for template listings
# 15. SSL certificate active
# 16. .env production values set
# SUCCESS: Site loads at web-temify.com, checkout works end-to-end
```

### PHASE 2 — REVENUE FOUNDATION (Month 1–2)

Priority order:

1. Vendor system (models, controllers, views, payouts)
2. License key system (LicenseService, API endpoint, dashboard)
3. Directory hub (10 categories, DirectoryService, admin CRUD)
4. Services/leads (ServiceRequest model, admin management, emails)
5. Fraud prevention (FraudService, fraud_flags table, admin dashboard)
6. Mobile Money integration (enable FEATURE_MOBILE_MONEY)
7. Chargeback protection (chargeback table, evidence generation)
8. Buyer-vendor messaging (Message, MessageThread models)
9. Vendor wallet system (enable FEATURE_VENDOR_WALLET)
10. Instant payouts (enable FEATURE_INSTANT_PAYOUTS)

### PHASE 3 — GROWTH ENGINE (Month 2–4)

1. Gamification (GamificationService, points, badges, leaderboard)
2. Social login (Socialite — Google + GitHub + Twitter)
3. AI page generator (AIGatewayService, api/ai/generate endpoint)
4. Community forum (Forum models, controllers, views, moderation)
5. Courses builder (Course, Lesson, CourseProgress models)
6. Launch kits section (Kit model, KitController, views)
7. Advanced analytics (geo heatmap, attribution, cohort)
8. Win-back + upgrade nudge campaigns (cron jobs)
9. Exit survey on cancellation
10. Crypto payments (NOWPayments — enable FEATURE_CRYPTO_PAYMENTS)
11. A/B testing framework
12. Preference centre + personalised content

### PHASE 4 — SCALE & AUTOMATE (Month 4–8)

1. Python automation engine (automation/ directory)
2. Programmatic SEO pages (NichePageController, niche_pages table)
3. Mobile app API endpoints (prepare for React Native)
4. ProductHunt-style launch system
5. Affiliate marketplace (public page + automatic tiers)
6. Redis query caching throughout
7. WebP auto-conversion on all image uploads
8. Core Web Vitals dashboard (Google Search Console API)
9. B2B features (PO support, bulk orders, agency portal)
10. Reseller programme

### PHASE 5 — ENTERPRISE & GLOBAL (Month 8–12)

1. SOC 2 readiness checklist
2. White-label platform (multi-tenancy)
3. Merchant of Record setup
4. GDPR CMP v2 (IAB TCF 2.2)
5. Revenue advance for vendors
6. Vendor yield on wallet balance
7. SDK libraries (PHP + JS)
8. iOS + Android React Native apps
9. WCAG 2.2 Level AA full audit
10. Diaspora payment support

---

## COMPANY INFORMATION

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
Footer: "A sister company of Tinlance Limited →"
```

---

## QUICK REFERENCE — KEY ARTISAN COMMANDS

```bash
# Generate key files
php artisan make:model ModelName -mcr    # model + migration + controller + resource
php artisan make:job JobName             # queued job
php artisan make:mail MailName           # mailable
php artisan make:event EventName         # event
php artisan make:listener ListenerName   # listener
php artisan make:policy PolicyName       # authorization policy
php artisan make:request RequestName     # form request validation
php artisan make:service ServiceName     # (no artisan command, create manually)

# Database
php artisan migrate
php artisan migrate:fresh --seed
php artisan db:seed --class=ProductionSeeder

# Queue
php artisan queue:work --queue=high,default,low
php artisan queue:listen --timeout=120

# Cache
php artisan cache:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Scheduler (production — add to crontab)
* * * * * cd /var/www/web-temify && php artisan schedule:run >> /dev/null 2>&1

# Tests
php artisan test
php artisan test --filter=CheckoutTest

# Telescope (dev only)
php artisan telescope:install
php artisan telescope:publish
```

---

## START HERE — PHASE 1 FIRST COMMANDS

When you receive this prompt, run these commands in order:

```bash
# 1. Create project
composer create-project laravel/laravel web-temify "11.*"
cd web-temify

# 2. Install all packages (see LARAVEL PROJECT SETUP above)

# 3. Configure .env (copy all variables above)

# 4. Create database
mysql -u root -p -e "CREATE DATABASE webtemify CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 5. Generate key
php artisan key:generate

# 6. Create all migrations (start with users, products, orders, subscriptions)

# 7. Create seeders

# 8. Run migrations
php artisan migrate --seed

# 9. Build homepage blade view matching web-temify-v3.html exactly

# 10. Configure Supabase storage

# 11. Set up Redis

# 12. Configure Laravel Scheduler

# 13. Deploy to Contabo VPS

# 14. Verify end-to-end: register → browse → checkout → download
```

---

_Web-Temify Laravel Master Build Prompt v4.0 — May 2026_
_332 features · 34 groups · 5 build phases_
_Laravel 11 + MySQL + Redis + Supabase + 6 Payment Gateways_
_Multi-LLM AI: Claude → Grok → Gemini → GPT-4o_
