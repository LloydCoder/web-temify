> **LEGACY / NON-CANONICAL — reviewed 2026-10-13.** Retained for historical requirements and design context only. Do not treat its framework, database/migration strategy, provider list, security examples, product count, phase status, pricing, testimonials, metrics, or “built/production-ready” claims as current truth. Canonical authority is in `docs/architecture/overview.md`, `docs/architecture/decisions/`, `docs/roadmap/phase-gates.md`, `docs/security/`, `docs/quality/testing-strategy.md`, the tested source and Supabase migrations, and `LloydCoder/web-temify-products/catalog/products.json`. Implement only through the current phase gates and verified evidence.

# WEB-TEMIFY — SECURITY RULES & BUILDER GUIDELINES

## Version 5.0 | May 2026

---

## ABSOLUTE SECURITY RULES (NEVER BREAK THESE)

### Rule 1 — Secret Keys Stay Server-Side Only

```
❌ NEVER:
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY) // in client component
fetch('/api', { headers: { key: process.env.STRIPE_SECRET_KEY } }) // client-side

✅ ALWAYS:
// Only in server components, server actions, or API routes
import { stripe } from '@/lib/stripe' // server-only module
```

### Rule 2 — Always Verify Auth Before Any Data Access

```typescript
// Every server action and API route must start with:
const supabase = await createClient();
const {
  data: { user },
} = await supabase.auth.getUser();
if (!user) {
  return { error: "Unauthorized" };
  // OR: redirect('/login')
  // OR: return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
}
```

### Rule 3 — Validate ALL Input with Zod

```typescript
// Every server action and API route:
const Schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  amount: z.number().positive().max(10000),
});

const result = Schema.safeParse(input);
if (!result.success) {
  return { error: result.error.flatten() };
}
// Use result.data — never raw input
```

### Rule 4 — Webhook HMAC Verification (ALWAYS FIRST LINE)

```typescript
// Paystack
const hash = crypto
  .createHmac("sha512", process.env.PAYSTACK_WEBHOOK_SECRET!)
  .update(rawBody)
  .digest("hex");
if (hash !== req.headers["x-paystack-signature"]) {
  return NextResponse.json({ error: "Invalid" }, { status: 401 });
}

// Stripe
const event = stripe.webhooks.constructEvent(
  rawBody,
  sig,
  process.env.STRIPE_WEBHOOK_SECRET!,
);

// LemonSqueezy
const hash = crypto
  .createHmac("sha256", process.env.LEMONSQUEEZY_WEBHOOK_SECRET!)
  .update(rawBody)
  .digest("hex");
if (hash !== req.headers["x-signature"]) {
  return NextResponse.json({ error: "Invalid" }, { status: 401 });
}

// NOWPayments
const sorted = Object.keys(parsed)
  .sort()
  .reduce((acc, key) => ({ ...acc, [key]: parsed[key] }), {});
const hash = crypto
  .createHmac("sha512", process.env.NOWPAYMENTS_IPN_SECRET!)
  .update(JSON.stringify(sorted))
  .digest("hex");
```

### Rule 5 — Idempotency on ALL Webhooks

```typescript
// Check if we already processed this event
const existing = await prisma.payment.findFirst({
  where: { gatewayRef: event.data.reference },
});
if (existing) {
  return NextResponse.json({ received: true }); // silently ignore
}
```

### Rule 6 — Secure Downloads Only (Signed URLs)

```typescript
// NEVER: return { url: `https://storage.supabase.co/public/${filename}` }
// ALWAYS: generate signed URL that expires
const { data } = await supabase.storage
  .from("secure-downloads")
  .createSignedUrl(filename, 300); // 5 minutes
return NextResponse.redirect(data.signedUrl);
```

### Rule 7 — Row Level Security on Supabase

```sql
-- Every table with user data MUST have RLS enabled
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "own_orders" ON orders
  FOR SELECT USING (auth.uid() = user_id);

-- Admins use service_role key which bypasses RLS
-- Service role key NEVER goes to client
```

### Rule 8 — Rate Limiting on All Public Routes

```typescript
// Use Vercel's built-in rate limiting or implement manually
// Add to API routes that accept public input:
const rateLimitHeaders = {
  "X-RateLimit-Limit": "100",
  "X-RateLimit-Remaining": remaining.toString(),
  "X-RateLimit-Reset": reset.toString(),
};
// License validation: 1000/hour per IP
// Search: 100/minute per IP
// Checkout initiate: 10/hour per user
// Register: 5/hour per IP
```

### Rule 9 — Admin Routes Protection

```typescript
// middleware.ts already handles this, but double-check in every admin route:
const { data: profile } = await supabase
  .from("users")
  .select("role")
  .eq("id", user.id)
  .single();

if (!["ADMIN", "SUPER_ADMIN"].includes(profile?.role ?? "")) {
  redirect("/dashboard");
}
```

### Rule 10 — Cron Route Protection

```typescript
// All /api/cron/* routes:
const authHeader = request.headers.get("authorization");
if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
  return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
}
// Vercel automatically sends this header when triggering cron jobs
```

---

## TYPESCRIPT RULES

### Strict Mode (tsconfig.json)

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUncheckedIndexedAccess": true
  }
}
```

### No `any` Types

```typescript
// ❌ NEVER
const data: any = await fetchSomething();
function process(input: any) {}

// ✅ ALWAYS use proper types
const data: Product = await fetchSomething();
function process(input: ProcessInput): ProcessOutput {}
```

### Server vs Client Components

```typescript
// Default to Server Components (no 'use client' directive)
// Add 'use client' ONLY when you need:
// - useState, useEffect, useReducer
// - Event listeners (onClick, onChange)
// - Browser APIs (localStorage, window)
// - Third-party client libraries

// ❌ Wrong — makes entire page client-side
'use client'
export default function ProductPage() {
  const data = await fetch('/api/products') // can't await in client component
}

// ✅ Right — server fetches, client handles interaction
// page.tsx (server)
export default async function ProductPage() {
  const products = await prisma.product.findMany()
  return <ProductGrid products={products} />
}

// ProductGrid.tsx (client — only if needs interactivity)
'use client'
export function ProductGrid({ products }: { products: Product[] }) {
  const [filter, setFilter] = useState('all')
  // ...
}
```

---

## DATABASE RULES

### Always Use Prisma (Never Raw SQL in App Code)

```typescript
// ❌ NEVER
const result = await prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;

// ✅ ALWAYS
const user = await prisma.user.findUnique({ where: { id: userId } });
```

### Select Only What You Need

```typescript
// ❌ Wrong — fetches all columns
const products = await prisma.product.findMany();

// ✅ Right — only fetch what the UI needs
const products = await prisma.product.findMany({
  select: {
    id: true,
    name: true,
    slug: true,
    price: true,
    previewImage: true,
    ratingAvg: true,
    purchases: true,
  },
  where: { status: "APPROVED" },
  take: 12,
});
```

### Always Handle Prisma Errors

```typescript
try {
  const user = await prisma.user.create({ data: userData });
  return { success: true, user };
} catch (error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === "P2002") {
      return { error: "Email already exists" };
    }
  }
  throw error;
}
```

---

## FILE UPLOAD RULES

```typescript
// Validate before uploading to Supabase Storage
const ALLOWED_TEMPLATE_TYPES = [
  "application/zip",
  "application/x-zip-compressed",
];
const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_TEMPLATE_SIZE = 50 * 1024 * 1024; // 50MB
const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB

// Always check file type from buffer (not just extension)
import { fileTypeFromBuffer } from "file-type";
const fileType = await fileTypeFromBuffer(buffer);
if (!ALLOWED_TEMPLATE_TYPES.includes(fileType?.mime ?? "")) {
  return { error: "Invalid file type" };
}

// Trigger VirusTotal scan on template uploads
// Store scan result in product.virusScanStatus
// Only allow download after scan returns 'CLEAN'
```

---

## PAYMENT SECURITY RULES

```typescript
// High-value purchases require 2FA
const HIGH_VALUE_THRESHOLD = parseInt(
  process.env.HIGH_VALUE_CHECKOUT_THRESHOLD ?? "200",
);
if (amount > HIGH_VALUE_THRESHOLD) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { twoFactorEnabled: true },
  });
  if (!user?.twoFactorEnabled) {
    return { requiresTwoFactor: true, redirectTo: "/2fa-setup" };
  }
}

// Fraud score check before processing
const fraudScore = await calculateFraudScore({
  userId,
  ipAddress,
  amount,
  gateway,
});
if (fraudScore > 80) {
  // Flag for manual review — don't process automatically
  await prisma.fraudFlag.create({
    data: { userId, type: "HIGH_RISK_PURCHASE", score: fraudScore },
  });
  return { error: "Payment under review. Our team will contact you." };
}

// NOWPayments — crypto rules
// USDT (TRC-20) and USDC only — never accept other coins
// Always auto-convert — never hold crypto
// Refunds always = platform credits, never on-chain
const ACCEPTED_CRYPTO_CURRENCIES = ["USDT", "USDC"];
const ACCEPTED_NETWORKS = ["TRC20", "ERC20"];
```

---

## ERROR HANDLING

```typescript
// Global error boundary (app/error.tsx)
'use client'
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={() => reset()}>Try again</button>
    </div>
  )
}

// API route errors — always return consistent format
return NextResponse.json(
  { error: 'Human-readable message', code: 'MACHINE_READABLE_CODE' },
  { status: 400 }
)

// Server action errors
return { error: 'Human-readable message' }
// Never throw unhandled errors in server actions
```

---

## PERFORMANCE RULES

```typescript
// 1. Use Next.js caching for public data
export const revalidate = 3600 // revalidate every hour

// 2. Parallel data fetching with Promise.all
const [products, categories, featured] = await Promise.all([
  prisma.product.findMany({ where: { status: 'APPROVED' }, take: 12 }),
  prisma.category.findMany(),
  prisma.product.findMany({ where: { featured: true }, take: 3 }),
])

// 3. Streaming with Suspense for slow data
import { Suspense } from 'react'
export default function Page() {
  return (
    <>
      <HeroSection /> {/* Fast — static */}
      <Suspense fallback={<ProductGridSkeleton />}>
        <ProductGrid /> {/* Slow — streams when ready */}
      </Suspense>
    </>
  )
}

// 4. Image optimization — always use next/image
import Image from 'next/image'
<Image
  src={product.previewImageUrl}
  alt={product.name}
  width={400}
  height={300}
  loading="lazy"
  placeholder="blur"
/>

// 5. Never fetch in loops
// ❌ Wrong
for (const product of products) {
  const vendor = await prisma.vendor.findUnique({ where: { id: product.vendorId } })
}

// ✅ Right — include in original query
const products = await prisma.product.findMany({
  include: { vendor: { select: { businessName: true, slug: true } } }
})
```

---

## COMPONENT RULES

```typescript
// 1. Loading states — always show skeleton
export function ProductCard({ product }: { product: Product }) {
  return <div>...</div>
}

export function ProductCardSkeleton() {
  return <div className="animate-pulse bg-surface border-2 border-ink h-64 rounded" />
}

// 2. Empty states — always handle no data
if (products.length === 0) {
  return <EmptyState message="No templates found" action="Clear filters" />
}

// 3. Error states — always handle fetch errors
if (error) {
  return <ErrorState message="Failed to load templates" retry={refetch} />
}

// 4. Feature flags — never show broken UI
import { useFeatureFlag } from '@/hooks/useFeatureFlag'
export function CryptoPaymentTab() {
  const enabled = useFeatureFlag('CRYPTO_PAYMENTS')
  if (!enabled) return null
  return <div>USDT/USDC payment</div>
}
```

---

## GIT & DEPLOYMENT RULES

```
Branch strategy:
  main        → production (Vercel auto-deploys)
  develop     → staging (Vercel preview)
  feature/*   → feature branches (PR previews)

Never commit:
  .env.local
  .env.*.local
  node_modules/
  .next/
  prisma/generated/

Always commit:
  .env.example (with no real values)
  vercel.json
  prisma/schema.prisma
  prisma/migrations/

Before merging to main:
  ✅ npm run build (no errors)
  ✅ npm run lint (no warnings)
  ✅ TypeScript strict (no type errors)
  ✅ All webhooks tested
  ✅ Payment flow tested end-to-end
  ✅ Dark mode verified on changed pages
  ✅ Mobile responsive verified
```
