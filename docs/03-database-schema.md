> **Canonical status (2026-10-13): historical proposal, not executable schema authority.** This file contains a legacy Prisma-shaped 85-table proposal and is retained for requirements reconciliation only. The accepted decision in docs/architecture/decisions/0003-database-migration-authority.md makes supabase/migrations/*.sql the sole schema history. Do not generate Prisma migrations from this document. Every proposed field/table must be reconciled against current domain boundaries, data minimization, RLS, and phase gates before implementation.

# WEB-TEMIFY — LEGACY DATABASE SCHEMA PROPOSAL (HISTORICAL RECONCILIATION ONLY)
## Historical Prisma-shaped model (not executable)
### 85 Tables | Version 5.0 | May 2026

---

## PRISMA SCHEMA (prisma/schema.prisma)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}

// ─── USERS ───────────────────────────────────────────────────────────────────

model User {
  id                String    @id @default(uuid())
  email             String    @unique
  name              String
  username          String?   @unique
  avatar            String?
  bio               String?
  role              Role      @default(USER)
  plan              Plan      @default(FREE)
  planExpiresAt     DateTime?
  trialEndsAt       DateTime?
  trialCharged      Boolean   @default(false)
  status            UserStatus @default(ACTIVE)
  googleId          String?
  githubId          String?
  twitterId         String?
  twoFactorSecret   String?
  twoFactorEnabled  Boolean   @default(false)
  loginAttempts     Int       @default(0)
  lockedUntil       DateTime?
  profileScore      Int       @default(0)
  points            Int       @default(0)
  darkMode          Boolean   @default(false)
  language          String    @default("en")
  timezone          String    @default("Africa/Lagos")
  currency          String    @default("USD")
  referralCode      String?   @unique
  referredById      String?
  deviceFingerprint String?
  fraudScore        Int       @default(0)
  ipAddress         String?
  termsAcceptedAt   DateTime?
  ageVerified       Boolean   @default(false)
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
  deletedAt         DateTime?

  referredBy        User?     @relation("Referrals", fields: [referredById], references: [id])
  referrals         User[]    @relation("Referrals")
  vendor            Vendor?
  orders            Order[]
  subscription      Subscription?
  downloads         Download[]
  reviews           Review[]
  userPoints        UserPoint[]
  userBadges        UserBadge[]
  wishlist          Wishlist[]
  collections       Collection[]
  licenseKeys       LicenseKey[]
  serviceRequests   ServiceRequest[]
  messageThreadsBuyer  MessageThread[] @relation("BuyerThreads")
  messageThreadsVendor MessageThread[] @relation("VendorThreads")
  sentMessages      Message[]
  supportTickets    SupportTicket[]
  notifications     Notification[]
  activityLogs      ActivityLog[]
  apiKeys           ApiKey[]
  fraudFlags        FraudFlag[]
  affiliateLinks    AffiliateLink[]
  forumThreads      ForumThread[]
  forumReplies      ForumReply[]
  showcaseEntries   ShowcaseEntry[]
  courseProgress    CourseProgress[]
  certificates      Certificate[]
  recentlyViewed    RecentlyViewed[]
  npsResponses      NpsResponse[]
  searchLogs        SearchLog[]

  @@map("users")
}

enum Role {
  USER
  VENDOR
  ADMIN
  SUPER_ADMIN
}

enum Plan {
  FREE
  PRO
  BUSINESS
  AGENCY
}

enum UserStatus {
  ACTIVE
  SUSPENDED
  BANNED
}

// ─── VENDORS ─────────────────────────────────────────────────────────────────

model Vendor {
  id                String    @id @default(uuid())
  userId            String    @unique
  businessName      String
  slug              String    @unique
  bio               String?
  avatar            String?
  banner            String?
  website           String?
  socialLinks       Json?
  specialityTags    Json?
  verified          Boolean   @default(false)
  verifiedAt        DateTime?
  idDocument        String?
  tier              VendorTier @default(STARTER)
  commissionRate    Decimal   @default(20.00) @db.Decimal(5,2)
  exclusive         Boolean   @default(false)
  totalEarnings     Decimal   @default(0) @db.Decimal(12,2)
  pendingEarnings   Decimal   @default(0) @db.Decimal(12,2)
  walletBalance     Decimal   @default(0) @db.Decimal(12,2)
  taxReserve        Decimal   @default(0) @db.Decimal(12,2)
  taxReservePercent Decimal   @default(10.00) @db.Decimal(5,2)
  responseTimeAvg   Int?
  chargebackRate    Decimal   @default(0) @db.Decimal(5,4)
  qualityScoreAvg   Decimal   @default(0) @db.Decimal(5,2)
  cacNumber         String?
  cacVerified       Boolean   @default(false)
  status            VendorStatus @default(PENDING)
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt

  user              User      @relation(fields: [userId], references: [id])
  products          Product[]
  payouts           VendorPayout[]
  analytics         VendorAnalytic[]
  walletTransactions VendorWalletTransaction[]
  webhooks          VendorWebhook[]

  @@map("vendors")
}

enum VendorTier {
  STARTER
  PRO
  TOP
  EXCLUSIVE
}

enum VendorStatus {
  PENDING
  ACTIVE
  SUSPENDED
}

// ─── PRODUCTS ────────────────────────────────────────────────────────────────

model Product {
  id              String    @id @default(uuid())
  vendorId        String
  name            String
  slug            String    @unique
  description     String
  shortDesc       String?   @db.VarChar(200)
  categoryId      String
  type            ProductType
  techStack       String?
  pageCount       Int?
  difficulty      Difficulty @default(BEGINNER)
  demoUrl         String?
  downloadFile    String?
  fileVersion     String    @default("1.0.0")
  fileHash        String?
  price           Decimal   @db.Decimal(10,2)
  originalPrice   Decimal?  @db.Decimal(10,2)
  rentalPrice     Decimal?  @db.Decimal(10,2)
  licenseType     LicenseType @default(REGULAR)
  compatibility   String?
  colorScheme     String?
  industryTags    Json?
  status          ProductStatus @default(DRAFT)
  featured        Boolean   @default(false)
  exclusive       Boolean   @default(false)
  qualityScore    Int       @default(0)
  virusScanStatus ScanStatus @default(PENDING)
  virusScanDate   DateTime?
  downloads       Int       @default(0)
  views           Int       @default(0)
  purchases       Int       @default(0)
  ratingAvg       Decimal   @default(0) @db.Decimal(3,2)
  ratingCount     Int       @default(0)
  hasDarkMode     Boolean   @default(false)
  hasRtl          Boolean   @default(false)
  mobileResponsive Boolean  @default(true)
  previewImage    String?
  screenshots     Json?
  demoVideo       String?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  deletedAt       DateTime?

  vendor          Vendor    @relation(fields: [vendorId], references: [id])
  category        Category  @relation(fields: [categoryId], references: [id])
  orders          Order[]
  reviews         Review[]
  licenseKeys     LicenseKey[]
  versions        ProductVersion[]
  wishlist        Wishlist[]
  recentlyViewed  RecentlyViewed[]
  comparisons     ProductComparison[]
  serviceRequests ServiceRequest[]
  courseItems     Course[]

  @@map("products")
}

enum ProductType {
  TEMPLATE
  SCRIPT
  KIT
  COMPONENT
  COURSE
}

enum Difficulty {
  BEGINNER
  INTERMEDIATE
  ADVANCED
}

enum LicenseType {
  REGULAR
  EXTENDED
  WHITE_LABEL
}

enum ProductStatus {
  DRAFT
  PENDING
  APPROVED
  REJECTED
  SUSPENDED
}

enum ScanStatus {
  PENDING
  CLEAN
  INFECTED
  SKIPPED
}

// ─── CATEGORIES ──────────────────────────────────────────────────────────────

model Category {
  id          String    @id @default(uuid())
  name        String
  slug        String    @unique
  description String?
  icon        String?
  color       String?
  count       Int       @default(0)
  sortOrder   Int       @default(0)
  createdAt   DateTime  @default(now())

  products    Product[]

  @@map("categories")
}

// ─── PLANS ───────────────────────────────────────────────────────────────────

model PlanConfig {
  id               String   @id @default(uuid())
  name             String
  slug             String   @unique
  priceMonthly     Decimal  @db.Decimal(10,2)
  priceAnnual      Decimal  @db.Decimal(10,2)
  features         Json
  templateLimit    Int?
  downloadLimit    Int?
  apiAccess        Boolean  @default(false)
  teamSeats        Int      @default(1)
  whiteLabelRights Boolean  @default(false)
  volumeLicensing  Boolean  @default(false)
  sortOrder        Int      @default(0)
  active           Boolean  @default(true)
  createdAt        DateTime @default(now())

  subscriptions Subscription[]

  @@map("plan_configs")
}

// ─── ORDERS ──────────────────────────────────────────────────────────────────

model Order {
  id                  String      @id @default(uuid())
  orderNumber         String      @unique
  userId              String
  productId           String?
  planConfigId        String?
  vendorId            String?
  amount              Decimal     @db.Decimal(10,2)
  currency            String      @default("USD")
  gateway             Gateway
  gatewayRef          String?
  gatewayStatus       String?
  licenseKeyId        String?
  couponId            String?
  fraudScore          Int         @default(0)
  ipAddress           String?
  deviceFingerprint   String?
  status              OrderStatus @default(PENDING)
  idempotencyKey      String?     @unique
  createdAt           DateTime    @default(now())
  updatedAt           DateTime    @updatedAt

  user          User          @relation(fields: [userId], references: [id])
  product       Product?      @relation(fields: [productId], references: [id])
  coupon        Coupon?       @relation(fields: [couponId], references: [id])
  licenseKey    LicenseKey?
  payments      Payment[]
  downloads     Download[]

  @@map("orders")
}

enum Gateway {
  PAYSTACK
  STRIPE
  LEMONSQUEEZY
  NOWPAYMENTS
  MOBILEMONEY
  BNPL
}

enum OrderStatus {
  PENDING
  COMPLETED
  FAILED
  REFUNDED
  DISPUTED
}

// ─── SUBSCRIPTIONS ───────────────────────────────────────────────────────────

model Subscription {
  id                  String             @id @default(uuid())
  userId              String             @unique
  planConfigId        String
  gateway             SubscriptionGateway
  gatewaySubId        String?
  status              SubscriptionStatus @default(ACTIVE)
  paused              Boolean            @default(false)
  pauseReason         String?
  currentPeriodStart  DateTime?
  currentPeriodEnd    DateTime?
  cancelAtPeriodEnd   Boolean            @default(false)
  gracePeriodUntil    DateTime?
  trialEnd            DateTime?
  createdAt           DateTime           @default(now())
  updatedAt           DateTime           @updatedAt

  user        User        @relation(fields: [userId], references: [id])
  planConfig  PlanConfig  @relation(fields: [planConfigId], references: [id])

  @@map("subscriptions")
}

enum SubscriptionGateway {
  PAYSTACK
  STRIPE
  LEMONSQUEEZY
}

enum SubscriptionStatus {
  ACTIVE
  CANCELLED
  EXPIRED
  PAUSED
  PAST_DUE
}

// ─── LICENSE KEYS ────────────────────────────────────────────────────────────

model LicenseKey {
  id              String      @id @default(uuid())
  orderId         String      @unique
  productId       String
  userId          String
  keyHash         String      @unique
  keyDisplay      String      @db.VarChar(40)
  licenseType     LicenseKeyType
  activationLimit Int         @default(1)
  activationCount Int         @default(0)
  domains         Json?
  expiresAt       DateTime?
  revoked         Boolean     @default(false)
  revokedAt       DateTime?
  revokedReason   String?
  createdAt       DateTime    @default(now())

  order           Order       @relation(fields: [orderId], references: [id])
  product         Product     @relation(fields: [productId], references: [id])
  user            User        @relation(fields: [userId], references: [id])
  activations     LicenseActivation[]

  @@map("license_keys")
}

enum LicenseKeyType {
  SINGLE
  MULTI
  AGENCY
  WHITE_LABEL
}

model LicenseActivation {
  id            String    @id @default(uuid())
  licenseKeyId  String
  domain        String
  ipAddress     String?
  userAgent     String?
  activatedAt   DateTime  @default(now())
  deactivatedAt DateTime?
  active        Boolean   @default(true)

  licenseKey    LicenseKey @relation(fields: [licenseKeyId], references: [id])

  @@map("license_activations")
}

// ─── DOWNLOADS ───────────────────────────────────────────────────────────────

model Download {
  id          String    @id @default(uuid())
  userId      String
  productId   String
  orderId     String
  token       String    @unique
  tokenExpiresAt DateTime
  downloadedAt DateTime?
  ipAddress   String?
  count       Int       @default(0)
  createdAt   DateTime  @default(now())

  user    User    @relation(fields: [userId], references: [id])
  order   Order   @relation(fields: [orderId], references: [id])

  @@map("downloads")
}

// ─── REVIEWS ─────────────────────────────────────────────────────────────────

model Review {
  id            String        @id @default(uuid())
  userId        String
  productId     String
  orderId       String?
  rating        Int
  title         String?
  body          String
  status        ReviewStatus  @default(PENDING)
  helpfulCount  Int           @default(0)
  createdAt     DateTime      @default(now())

  user    User    @relation(fields: [userId], references: [id])
  product Product @relation(fields: [productId], references: [id])

  @@map("reviews")
}

enum ReviewStatus {
  PENDING
  APPROVED
  REJECTED
}

// ─── DIRECTORY ───────────────────────────────────────────────────────────────

model DirectoryListing {
  id            String              @id @default(uuid())
  name          String
  slug          String              @unique
  tagline       String?             @db.VarChar(120)
  description   String
  url           String
  logo          String?
  category      DirectoryCategory
  pricingTier   DirectoryPricing    @default(FREEMIUM)
  region        String?
  affiliateUrl  String?
  featured      Boolean             @default(false)
  featuredUntil DateTime?
  sponsored     Boolean             @default(false)
  ratingAvg     Decimal             @default(0) @db.Decimal(3,2)
  ratingCount   Int                 @default(0)
  clickCount    Int                 @default(0)
  status        DirectoryStatus     @default(DRAFT)
  submittedById String?
  approvedAt    DateTime?
  tags          Json?
  createdAt     DateTime            @default(now())
  updatedAt     DateTime            @updatedAt

  reviews DirectoryReview[]

  @@map("directory_listings")
}

enum DirectoryCategory {
  AI_ML
  WEBDEV
  WEB3
  DESIGN
  NOCODE
  HOSTING
  PLUGINS
  BLOCKCHAIN
  FREELANCER
  LEARNING
}

enum DirectoryPricing {
  FREE
  FREEMIUM
  PAID
}

enum DirectoryStatus {
  DRAFT
  APPROVED
  REJECTED
}

model DirectoryReview {
  id          String   @id @default(uuid())
  userId      String
  listingId   String
  rating      Int
  body        String
  status      ReviewStatus @default(PENDING)
  createdAt   DateTime @default(now())

  listing DirectoryListing @relation(fields: [listingId], references: [id])

  @@map("directory_reviews")
}

// ─── PAYMENTS ────────────────────────────────────────────────────────────────

model Payment {
  id              String   @id @default(uuid())
  orderId         String
  userId          String?
  amount          Decimal  @db.Decimal(10,2)
  currency        String   @default("USD")
  gateway         Gateway
  gatewayRef      String?
  gatewayResponse Json?
  status          String
  idempotencyKey  String?  @unique
  createdAt       DateTime @default(now())

  order Order @relation(fields: [orderId], references: [id])

  @@map("payments")
}

model CryptoPayment {
  id              String   @id @default(uuid())
  orderId         String
  userId          String
  currency        String   @default("USDT")
  network         String   @default("TRC20")
  amount          Decimal  @db.Decimal(20,8)
  amountUsd       Decimal  @db.Decimal(10,2)
  paymentAddress  String
  qrCode          String?
  nowpaymentsId   String?
  status          String   @default("waiting")
  expiresAt       DateTime
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt

  @@map("crypto_payments")
}

model MobileMoneyTransaction {
  id            String   @id @default(uuid())
  orderId       String
  userId        String
  provider      String
  phoneNumber   String
  amount        Decimal  @db.Decimal(10,2)
  currency      String
  reference     String?
  status        String   @default("pending")
  createdAt     DateTime @default(now())

  @@map("mobile_money_transactions")
}

model BnplTransaction {
  id            String   @id @default(uuid())
  orderId       String
  userId        String
  provider      String
  totalAmount   Decimal  @db.Decimal(10,2)
  monthlyAmount Decimal  @db.Decimal(10,2)
  tenure        Int      @default(3)
  status        String   @default("pending")
  createdAt     DateTime @default(now())

  @@map("bnpl_transactions")
}

// ─── COUPONS & GIFT CARDS ────────────────────────────────────────────────────

model Coupon {
  id              String    @id @default(uuid())
  code            String    @unique
  type            CouponType
  value           Decimal   @db.Decimal(10,2)
  minPurchase     Decimal?  @db.Decimal(10,2)
  usageLimit      Int?
  usageCount      Int       @default(0)
  expiresAt       DateTime?
  active          Boolean   @default(true)
  createdAt       DateTime  @default(now())

  orders Order[]

  @@map("coupons")
}

enum CouponType {
  PERCENT
  FIXED
}

model GiftCard {
  id          String    @id @default(uuid())
  code        String    @unique
  amount      Decimal   @db.Decimal(10,2)
  balance     Decimal   @db.Decimal(10,2)
  expiresAt   DateTime?
  redeemedBy  String?
  redeemedAt  DateTime?
  createdAt   DateTime  @default(now())

  @@map("gift_cards")
}

model Credit {
  id          String   @id @default(uuid())
  userId      String
  amount      Decimal  @db.Decimal(10,2)
  reason      String?
  expiresAt   DateTime?
  createdAt   DateTime @default(now())

  @@map("credits")
}

// ─── VENDOR FINANCIAL ────────────────────────────────────────────────────────

model VendorPayout {
  id            String   @id @default(uuid())
  vendorId      String
  amount        Decimal  @db.Decimal(10,2)
  currency      String   @default("USD")
  gateway       Gateway
  gatewayRef    String?
  status        String   @default("pending")
  requestedAt   DateTime @default(now())
  processedAt   DateTime?

  vendor Vendor @relation(fields: [vendorId], references: [id])

  @@map("vendor_payouts")
}

model VendorAnalytic {
  id             String   @id @default(uuid())
  vendorId       String
  productId      String?
  date           DateTime @db.Date
  views          Int      @default(0)
  previews       Int      @default(0)
  purchases      Int      @default(0)
  revenue        Decimal  @default(0) @db.Decimal(10,2)
  conversionRate Decimal  @default(0) @db.Decimal(5,4)

  vendor Vendor @relation(fields: [vendorId], references: [id])

  @@unique([vendorId, productId, date])
  @@map("vendor_analytics")
}

model VendorWalletTransaction {
  id          String   @id @default(uuid())
  vendorId    String
  amount      Decimal  @db.Decimal(10,2)
  type        String
  description String?
  reference   String?
  createdAt   DateTime @default(now())

  vendor Vendor @relation(fields: [vendorId], references: [id])

  @@map("vendor_wallet_transactions")
}

// ─── AFFILIATES ──────────────────────────────────────────────────────────────

model AffiliateLink {
  id          String   @id @default(uuid())
  userId      String
  productId   String?
  code        String   @unique
  clicks      Int      @default(0)
  conversions Int      @default(0)
  earnings    Decimal  @default(0) @db.Decimal(10,2)
  tier        String   @default("starter")
  createdAt   DateTime @default(now())

  user        User     @relation(fields: [userId], references: [id])
  commissions AffiliateCommission[]

  @@map("affiliate_links")
}

model AffiliateCommission {
  id            String   @id @default(uuid())
  affiliateLinkId String
  orderId       String
  amount        Decimal  @db.Decimal(10,2)
  status        String   @default("pending")
  paidAt        DateTime?
  createdAt     DateTime @default(now())

  affiliateLink AffiliateLink @relation(fields: [affiliateLinkId], references: [id])

  @@map("affiliate_commissions")
}

// ─── GAMIFICATION ────────────────────────────────────────────────────────────

model Badge {
  id              String   @id @default(uuid())
  name            String
  slug            String   @unique
  description     String?
  icon            String?
  conditionType   String
  conditionValue  Int
  rarity          String   @default("common")
  createdAt       DateTime @default(now())

  userBadges UserBadge[]

  @@map("badges")
}

model UserBadge {
  id        String   @id @default(uuid())
  userId    String
  badgeId   String
  earnedAt  DateTime @default(now())

  user  User  @relation(fields: [userId], references: [id])
  badge Badge @relation(fields: [badgeId], references: [id])

  @@unique([userId, badgeId])
  @@map("user_badges")
}

model UserPoint {
  id          String   @id @default(uuid())
  userId      String
  points      Int
  action      String
  referenceId String?
  description String?
  createdAt   DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("user_points")
}

model Challenge {
  id              String   @id @default(uuid())
  title           String
  description     String?
  rewardPoints    Int      @default(0)
  rewardCredits   Decimal  @default(0) @db.Decimal(10,2)
  startDate       DateTime
  endDate         DateTime
  conditionType   String
  conditionValue  Int
  active          Boolean  @default(true)
  createdAt       DateTime @default(now())

  participants ChallengeParticipant[]

  @@map("challenges")
}

model ChallengeParticipant {
  id          String    @id @default(uuid())
  challengeId String
  userId      String
  progress    Int       @default(0)
  completed   Boolean   @default(false)
  completedAt DateTime?

  challenge Challenge @relation(fields: [challengeId], references: [id])

  @@map("challenge_participants")
}

model LeaderboardSnapshot {
  id        String   @id @default(uuid())
  userId    String?
  vendorId  String?
  period    String
  score     Decimal  @db.Decimal(10,2)
  rank      Int
  category  String
  createdAt DateTime @default(now())

  @@map("leaderboard_snapshots")
}

// ─── MESSAGING & SUPPORT ─────────────────────────────────────────────────────

model MessageThread {
  id            String   @id @default(uuid())
  buyerId       String
  vendorId      String
  productId     String?
  orderId       String?
  lastMessageAt DateTime @default(now())
  createdAt     DateTime @default(now())

  buyer    User      @relation("BuyerThreads", fields: [buyerId], references: [id])
  vendor   User      @relation("VendorThreads", fields: [vendorId], references: [id])
  messages Message[]

  @@map("message_threads")
}

model Message {
  id        String   @id @default(uuid())
  threadId  String
  senderId  String
  body      String
  readAt    DateTime?
  createdAt DateTime @default(now())

  thread MessageThread @relation(fields: [threadId], references: [id])
  sender User          @relation(fields: [senderId], references: [id])

  @@map("messages")
}

model SupportTicket {
  id          String   @id @default(uuid())
  userId      String
  vendorId    String?
  orderId     String?
  productId   String?
  subject     String
  status      String   @default("open")
  priority    String   @default("normal")
  slaDeadline DateTime?
  resolvedAt  DateTime?
  createdAt   DateTime @default(now())

  user    User           @relation(fields: [userId], references: [id])
  replies SupportReply[]

  @@map("support_tickets")
}

model SupportReply {
  id            String   @id @default(uuid())
  ticketId      String
  userId        String
  body          String
  isAiGenerated Boolean  @default(false)
  createdAt     DateTime @default(now())

  ticket SupportTicket @relation(fields: [ticketId], references: [id])

  @@map("support_replies")
}

// ─── COURSES ─────────────────────────────────────────────────────────────────

model Course {
  id               String   @id @default(uuid())
  vendorId         String
  productId        String?
  title            String
  description      String?
  thumbnail        String?
  price            Decimal  @default(0) @db.Decimal(10,2)
  freeWithPurchase Boolean  @default(true)
  lessonCount      Int      @default(0)
  durationMins     Int      @default(0)
  status           String   @default("draft")
  createdAt        DateTime @default(now())

  product  Product?        @relation(fields: [productId], references: [id])
  lessons  CourseLesson[]
  progress CourseProgress[]
  certs    Certificate[]

  @@map("courses")
}

model CourseLesson {
  id                   String   @id @default(uuid())
  courseId             String
  title                String
  body                 String?
  videoUrl             String?
  durationSecs         Int      @default(0)
  sortOrder            Int      @default(0)
  prerequisiteLessonId String?
  createdAt            DateTime @default(now())

  course   Course         @relation(fields: [courseId], references: [id])
  quiz     CourseQuiz?
  progress CourseProgress[]

  @@map("course_lessons")
}

model CourseProgress {
  id          String    @id @default(uuid())
  userId      String
  courseId    String
  lessonId    String
  completed   Boolean   @default(false)
  completedAt DateTime?

  user   User         @relation(fields: [userId], references: [id])
  course Course       @relation(fields: [courseId], references: [id])
  lesson CourseLesson @relation(fields: [lessonId], references: [id])

  @@unique([userId, lessonId])
  @@map("course_progress")
}

model CourseQuiz {
  id          String   @id @default(uuid())
  lessonId    String   @unique
  questions   Json
  passScore   Int      @default(70)

  lesson   CourseLesson   @relation(fields: [lessonId], references: [id])
  attempts QuizAttempt[]

  @@map("course_quizzes")
}

model QuizAttempt {
  id          String   @id @default(uuid())
  userId      String
  quizId      String
  answers     Json
  score       Int
  passed      Boolean
  attemptedAt DateTime @default(now())

  quiz CourseQuiz @relation(fields: [quizId], references: [id])

  @@map("quiz_attempts")
}

model Certificate {
  id        String   @id @default(uuid())
  userId    String
  courseId  String
  issuedAt  DateTime @default(now())
  certUuid  String   @unique @default(uuid())

  user   User   @relation(fields: [userId], references: [id])
  course Course @relation(fields: [courseId], references: [id])

  @@map("certificates")
}

// ─── COMMUNITY ───────────────────────────────────────────────────────────────

model ForumCategory {
  id          String   @id @default(uuid())
  name        String
  slug        String   @unique
  description String?
  icon        String?
  sortOrder   Int      @default(0)

  threads ForumThread[]

  @@map("forum_categories")
}

model ForumThread {
  id          String   @id @default(uuid())
  userId      String
  categoryId  String
  title       String
  slug        String   @unique
  body        String
  views       Int      @default(0)
  replyCount  Int      @default(0)
  pinned      Boolean  @default(false)
  locked      Boolean  @default(false)
  lastReplyAt DateTime @default(now())
  createdAt   DateTime @default(now())

  user     User           @relation(fields: [userId], references: [id])
  category ForumCategory  @relation(fields: [categoryId], references: [id])
  replies  ForumReply[]

  @@map("forum_threads")
}

model ForumReply {
  id           String   @id @default(uuid())
  threadId     String
  userId       String
  body         String
  parentId     String?
  helpfulCount Int      @default(0)
  createdAt    DateTime @default(now())

  thread ForumThread @relation(fields: [threadId], references: [id])
  user   User        @relation(fields: [userId], references: [id])

  @@map("forum_replies")
}

model ShowcaseEntry {
  id          String   @id @default(uuid())
  userId      String
  productId   String?
  title       String
  description String?
  screenshotUrl String?
  siteUrl     String?
  status      String   @default("pending")
  likes       Int      @default(0)
  createdAt   DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("showcase_entries")
}

// ─── SERVICES (→ TINLANCE LEADS) ─────────────────────────────────────────────

model ServiceRequest {
  id          String   @id @default(uuid())
  userId      String
  productId   String?
  category    String
  budgetRange String?
  timeline    String?
  description String
  attachments Json?
  status      String   @default("new")
  adminNotes  String?
  contactedAt DateTime?
  convertedAt DateTime?
  createdAt   DateTime @default(now())

  user    User     @relation(fields: [userId], references: [id])
  product Product? @relation(fields: [productId], references: [id])

  @@map("service_requests")
}

// ─── BLOG ────────────────────────────────────────────────────────────────────

model BlogPost {
  id            String   @id @default(uuid())
  title         String
  slug          String   @unique
  body          String
  excerpt       String?
  coverImage    String?
  categoryId    String?
  authorId      String?
  metaTitle     String?
  metaDesc      String?
  tags          Json?
  status        String   @default("draft")
  aiGenerated   Boolean  @default(false)
  publishedAt   DateTime?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@map("blog_posts")
}

model BlogCategory {
  id        String @id @default(uuid())
  name      String
  slug      String @unique
  createdAt DateTime @default(now())

  @@map("blog_categories")
}

// ─── WISHLISTS & COLLECTIONS ─────────────────────────────────────────────────

model Wishlist {
  id        String   @id @default(uuid())
  userId    String
  productId String
  createdAt DateTime @default(now())

  user    User    @relation(fields: [userId], references: [id])
  product Product @relation(fields: [productId], references: [id])

  @@unique([userId, productId])
  @@map("wishlists")
}

model Collection {
  id          String   @id @default(uuid())
  userId      String
  name        String
  description String?
  public      Boolean  @default(false)
  createdAt   DateTime @default(now())

  user  User              @relation(fields: [userId], references: [id])
  items CollectionItem[]

  @@map("collections")
}

model CollectionItem {
  id           String   @id @default(uuid())
  collectionId String
  productId    String
  sortOrder    Int      @default(0)
  createdAt    DateTime @default(now())

  collection Collection @relation(fields: [collectionId], references: [id])

  @@map("collection_items")
}

// ─── RECENTLY VIEWED ─────────────────────────────────────────────────────────

model RecentlyViewed {
  id        String   @id @default(uuid())
  userId    String
  productId String
  viewedAt  DateTime @default(now())

  user    User    @relation(fields: [userId], references: [id])
  product Product @relation(fields: [productId], references: [id])

  @@unique([userId, productId])
  @@map("recently_viewed")
}

model ProductComparison {
  id        String   @id @default(uuid())
  sessionId String
  productId String
  createdAt DateTime @default(now())

  product Product @relation(fields: [productId], references: [id])

  @@map("product_comparisons")
}

// ─── NOTIFICATIONS ───────────────────────────────────────────────────────────

model Notification {
  id        String   @id @default(uuid())
  userId    String
  type      String
  title     String
  body      String?
  data      Json?
  readAt    DateTime?
  createdAt DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("notifications")
}

// ─── FRAUD & SECURITY ────────────────────────────────────────────────────────

model FraudFlag {
  id          String   @id @default(uuid())
  userId      String
  type        String
  score       Int
  details     Json?
  resolved    Boolean  @default(false)
  createdAt   DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("fraud_flags")
}

model Chargeback {
  id            String   @id @default(uuid())
  orderId       String
  vendorId      String?
  amount        Decimal  @db.Decimal(10,2)
  reason        String?
  evidenceData  Json?
  status        String   @default("open")
  resolvedAt    DateTime?
  createdAt     DateTime @default(now())

  @@map("chargebacks")
}

// ─── ANALYTICS ───────────────────────────────────────────────────────────────

model PageView {
  id        String   @id @default(uuid())
  userId    String?
  path      String
  referrer  String?
  country   String?
  device    String?
  createdAt DateTime @default(now())

  @@map("page_views")
}

model SearchLog {
  id          String   @id @default(uuid())
  userId      String?
  query       String
  resultCount Int      @default(0)
  clicked     Boolean  @default(false)
  createdAt   DateTime @default(now())

  user User? @relation(fields: [userId], references: [id])

  @@map("search_logs")
}

model RevenueAttribution {
  id        String   @id @default(uuid())
  orderId   String
  source    String
  medium    String?
  campaign  String?
  amount    Decimal  @db.Decimal(10,2)
  createdAt DateTime @default(now())

  @@map("revenue_attribution")
}

// ─── CONTENT & SETTINGS ──────────────────────────────────────────────────────

model AnnouncementBanner {
  id          String   @id @default(uuid())
  text        String
  link        String?
  color       String   @default("#ff5733")
  active      Boolean  @default(false)
  startsAt    DateTime?
  endsAt      DateTime?
  createdAt   DateTime @default(now())

  @@map("announcement_banners")
}

model NpsResponse {
  id        String   @id @default(uuid())
  userId    String
  score     Int
  feedback  String?
  createdAt DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("nps_responses")
}

model AiUsageLog {
  id          String   @id @default(uuid())
  provider    String
  taskType    String
  tokensIn    Int      @default(0)
  tokensOut   Int      @default(0)
  costUsd     Decimal  @default(0) @db.Decimal(10,6)
  latencyMs   Int      @default(0)
  success     Boolean  @default(true)
  createdAt   DateTime @default(now())

  @@map("ai_usage_log")
}

model ActivityLog {
  id          String   @id @default(uuid())
  userId      String?
  action      String
  entity      String?
  entityId    String?
  ipAddress   String?
  userAgent   String?
  details     Json?
  createdAt   DateTime @default(now())

  user User? @relation(fields: [userId], references: [id])

  @@map("activity_log")
}

model ApiKey {
  id          String   @id @default(uuid())
  userId      String
  name        String
  keyHash     String   @unique
  lastUsedAt  DateTime?
  expiresAt   DateTime?
  active      Boolean  @default(true)
  createdAt   DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@map("api_keys")
}

model VendorWebhook {
  id        String   @id @default(uuid())
  vendorId  String
  url       String
  events    Json
  secret    String
  active    Boolean  @default(true)
  createdAt DateTime @default(now())

  vendor Vendor @relation(fields: [vendorId], references: [id])

  @@map("vendor_webhooks")
}

model OutgoingWebhook {
  id        String   @id @default(uuid())
  name      String
  url       String
  events    Json
  secret    String?
  active    Boolean  @default(true)
  createdAt DateTime @default(now())

  @@map("outgoing_webhooks")
}

model NichePage {
  id          String   @id @default(uuid())
  title       String
  slug        String   @unique
  keyword     String
  body        String
  metaTitle   String?
  metaDesc    String?
  published   Boolean  @default(false)
  createdAt   DateTime @default(now())

  @@map("niche_pages")
}

model ProductVersion {
  id          String   @id @default(uuid())
  productId   String
  version     String
  changelog   String?
  fileUrl     String?
  createdAt   DateTime @default(now())

  product Product @relation(fields: [productId], references: [id])

  @@map("product_versions")
}

model PressMention {
  id          String   @id @default(uuid())
  outlet      String
  logo        String?
  url         String?
  headline    String?
  sortOrder   Int      @default(0)
  active      Boolean  @default(true)
  createdAt   DateTime @default(now())

  @@map("press_mentions")
}

model EmailCampaign {
  id          String   @id @default(uuid())
  name        String
  subject     String
  body        String
  segment     String?
  status      String   @default("draft")
  sentAt      DateTime?
  openRate    Decimal? @db.Decimal(5,2)
  clickRate   Decimal? @db.Decimal(5,2)
  createdAt   DateTime @default(now())

  @@map("email_campaigns")
}

model DripSequence {
  id        String   @id @default(uuid())
  name      String
  trigger   String
  active    Boolean  @default(true)
  createdAt DateTime @default(now())

  steps DripStep[]

  @@map("drip_sequences")
}

model DripStep {
  id           String   @id @default(uuid())
  sequenceId   String
  delayDays    Int      @default(0)
  subject      String
  body         String
  sortOrder    Int      @default(0)

  sequence DripSequence @relation(fields: [sequenceId], references: [id])

  @@map("drip_steps")
}

model AbandonedCheckout {
  id          String   @id @default(uuid())
  userId      String?
  email       String?
  cartData    Json
  recovered   Boolean  @default(false)
  emailSentAt DateTime?
  createdAt   DateTime @default(now())

  @@map("abandoned_checkouts")
}

model Faq {
  id        String   @id @default(uuid())
  question  String
  answer    String
  category  String?
  sortOrder Int      @default(0)
  active    Boolean  @default(true)
  createdAt DateTime @default(now())

  @@map("faqs")
}

model Testimonial {
  id        String   @id @default(uuid())
  name      String
  role      String?
  company   String?
  avatar    String?
  quote     String
  rating    Int      @default(5)
  active    Boolean  @default(true)
  createdAt DateTime @default(now())

  @@map("testimonials")
}

model RoadmapItem {
  id          String   @id @default(uuid())
  title       String
  description String?
  status      String   @default("planned")
  phase       String?
  votes       Int      @default(0)
  sortOrder   Int      @default(0)
  createdAt   DateTime @default(now())

  @@map("roadmap_items")
}

model ChangelogEntry {
  id          String   @id @default(uuid())
  version     String
  title       String
  body        String
  type        String   @default("feature")
  publishedAt DateTime?
  createdAt   DateTime @default(now())

  @@map("changelog_entries")
}

model LaunchKit {
  id          String   @id @default(uuid())
  name        String
  slug        String   @unique
  description String?
  price       Decimal  @db.Decimal(10,2)
  originalPrice Decimal? @db.Decimal(10,2)
  tag         String?
  active      Boolean  @default(true)
  createdAt   DateTime @default(now())

  items LaunchKitItem[]

  @@map("launch_kits")
}

model LaunchKitItem {
  id        String   @id @default(uuid())
  kitId     String
  productId String
  sortOrder Int      @default(0)

  kit LaunchKit @relation(fields: [kitId], references: [id])

  @@map("launch_kit_items")
}

model TemplateRequest {
  id          String   @id @default(uuid())
  userId      String
  title       String
  description String
  budget      Decimal? @db.Decimal(10,2)
  status      String   @default("open")
  bids        Int      @default(0)
  createdAt   DateTime @default(now())

  @@map("template_requests")
}

model FollowVendor {
  id        String   @id @default(uuid())
  userId    String
  vendorId  String
  createdAt DateTime @default(now())

  @@unique([userId, vendorId])
  @@map("follow_vendors")
}
```

---

## ROW LEVEL SECURITY POLICIES (supabase/migrations/001_rls_policies.sql)

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE downloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE license_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users: can only see own profile
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Products: approved products visible to all
CREATE POLICY "Approved products visible to all"
  ON products FOR SELECT
  USING (status = 'APPROVED');

CREATE POLICY "Vendors can manage own products"
  ON products FOR ALL
  USING (vendor_id IN (
    SELECT id FROM vendors WHERE user_id = auth.uid()
  ));

-- Orders: users see own orders only
CREATE POLICY "Users see own orders"
  ON orders FOR SELECT
  USING (user_id = auth.uid());

-- Downloads: users see own downloads
CREATE POLICY "Users see own downloads"
  ON downloads FOR SELECT
  USING (user_id = auth.uid());

-- License keys: users see own keys
CREATE POLICY "Users see own license keys"
  ON license_keys FOR SELECT
  USING (user_id = auth.uid());

-- Notifications: users see own notifications
CREATE POLICY "Users see own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users update own notifications"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid());

-- Admin bypass (service role bypasses RLS automatically)
```

---

## IMPORTANT DATABASE NOTES FOR BUILDER

1. **Use Prisma for all queries** — never write raw SQL in Next.js code
2. **Supabase RLS is the security layer** — always enable RLS on sensitive tables
3. **Service role key bypasses RLS** — only use server-side, never expose to client
4. **Anon key is safe for client** — respects RLS policies
5. **All UUIDs as primary keys** — already configured in schema
6. **Soft deletes on users and products** — use `deletedAt` field, never hard delete
7. **All Decimal fields use Prisma Decimal type** — for financial accuracy
8. **Json fields for flexible data** — tags, features, social links, screenshots
