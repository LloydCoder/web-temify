> **LEGACY / NON-CANONICAL — reviewed 2026-10-13.** Retained for historical requirements and design context only. Do not treat its framework, database/migration strategy, provider list, security examples, product count, phase status, pricing, testimonials, metrics, or “built/production-ready” claims as current truth. Canonical authority is in `docs/architecture/overview.md`, `docs/architecture/decisions/`, `docs/roadmap/phase-gates.md`, `docs/security/`, `docs/quality/testing-strategy.md`, the tested source and Supabase migrations, and `LloydCoder/web-temify-products/catalog/products.json`. Implement only through the current phase gates and verified evidence.

# WEB-TEMIFY — ENVIRONMENT VARIABLES & CONFIG

## Version 5.0 | May 2026

---

## .env.local (NEVER COMMIT — add to .gitignore)

```env
# ── APP ──────────────────────────────────────────────────────────────────────
NEXT_PUBLIC_APP_URL=https://web-temify.com
NEXT_PUBLIC_APP_NAME=Web-Temify
NEXT_PUBLIC_APP_DESCRIPTION=Premium website templates, scripts, and Web3 kits for developers and agencies across Africa and globally.

# ── SUPABASE ─────────────────────────────────────────────────────────────────
NEXT_PUBLIC_SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJxxxxxxxxxxxxxxxxxxxxxxxx
SUPABASE_SERVICE_ROLE_KEY=eyJxxxxxxxxxxxxxxxxxxxxxxxx

# ── DATABASE (Prisma → Supabase Postgres) ────────────────────────────────────
# Get from: Supabase Dashboard → Settings → Database → Connection string
DATABASE_URL=postgresql://postgres.[ref]:[password]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.[ref]:[password]@aws-0-eu-central-1.pooler.supabase.com:5432/postgres

# ── PAYSTACK ─────────────────────────────────────────────────────────────────
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_test_your_key_here
PAYSTACK_SECRET_KEY=sk_test_your_key_here
PAYSTACK_WEBHOOK_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx

# ── STRIPE ───────────────────────────────────────────────────────────────────
NEXT_PUBLIC_STRIPE_PUBLIC_KEY=pk_test_your_key_here
STRIPE_SECRET_KEY=sk_test_your_key_here_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here_publishable_key_here

# ── LEMONSQUEEZY ─────────────────────────────────────────────────────────────
LEMONSQUEEZY_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
LEMONSQUEEZY_STORE_ID=xxxxxxxx
LEMONSQUEEZY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx

# ── NOWPAYMENTS (USDT/USDC — Phase 3 only) ───────────────────────────────────
NOWPAYMENTS_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
NOWPAYMENTS_IPN_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_FEATURE_CRYPTO_PAYMENTS=false

# ── MOBILE MONEY (Phase 2 only) ──────────────────────────────────────────────
MOMO_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
MOMO_SUBSCRIPTION_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_FEATURE_MOBILE_MONEY=false

# ── BNPL (Phase 2 only) ──────────────────────────────────────────────────────
CARBON_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_FEATURE_BNPL=false

# ── AI PROVIDERS ─────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx
GROK_API_KEY=xai-xxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_API_KEY=AIzaxxxxxxxxxxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
AI_PRIMARY_PROVIDER=claude

# ── EMAIL (Resend) ────────────────────────────────────────────────────────────
RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxxxxxx
RESEND_FROM_EMAIL=hello@web-temify.com
RESEND_FROM_NAME=Web-Temify

# ── STORAGE (Supabase — buckets) ─────────────────────────────────────────────
SUPABASE_BUCKET_PREVIEWS=template-previews
SUPABASE_BUCKET_SCREENSHOTS=template-screenshots
SUPABASE_BUCKET_VIDEOS=template-videos
SUPABASE_BUCKET_AVATARS=user-avatars
SUPABASE_BUCKET_DOWNLOADS=secure-downloads
SUPABASE_BUCKET_VENDOR_DOCS=vendor-documents

# ── SECURITY ─────────────────────────────────────────────────────────────────
CRON_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
WEBHOOK_SECRET_INTERNAL=xxxxxxxxxxxxxxxxxxxxxxxx
HIGH_VALUE_CHECKOUT_THRESHOLD=200
ADMIN_EMAILS=nwachukwuchinaemerem8@gmail.com

# ── FEATURE FLAGS ────────────────────────────────────────────────────────────
NEXT_PUBLIC_FEATURE_CRYPTO_PAYMENTS=false
NEXT_PUBLIC_FEATURE_MOBILE_MONEY=false
NEXT_PUBLIC_FEATURE_BNPL=false
NEXT_PUBLIC_FEATURE_COURSES=false
NEXT_PUBLIC_FEATURE_FORUM=false
NEXT_PUBLIC_FEATURE_AI_GENERATOR=false
NEXT_PUBLIC_FEATURE_VENDOR_WALLET=false
NEXT_PUBLIC_FEATURE_INSTANT_PAYOUTS=false
NEXT_PUBLIC_FEATURE_DIRECTORY=true
NEXT_PUBLIC_FEATURE_WEB3_HUB=true

# ── INTEGRATIONS ─────────────────────────────────────────────────────────────
NEXT_PUBLIC_GTM_ID=GTM-XXXXXXX
NEXT_PUBLIC_CLARITY_ID=xxxxxxxxxx
MAILCHIMP_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
MAILCHIMP_LIST_ID=xxxxxxxxxx
NEXT_PUBLIC_TAWK_PROPERTY_ID=xxxxxxxxxxxxxxxxxxxxxxxx

# ── COMPANY ──────────────────────────────────────────────────────────────────
NEXT_PUBLIC_COMPANY_NAME=Web-Temify LTD
NEXT_PUBLIC_COMPANY_RC=7999659
NEXT_PUBLIC_COMPANY_TIN=2521759867925
NEXT_PUBLIC_TINLANCE_URL=https://tinlance.com
NEXT_PUBLIC_ADMIN_EMAIL=nwachukwuchinaemerem8@gmail.com
```

---

## .env.example (COMMIT THIS — no real values)

```env
NEXT_PUBLIC_APP_URL=
NEXT_PUBLIC_APP_NAME=Web-Temify
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
DATABASE_URL=
DIRECT_URL=
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=
PAYSTACK_SECRET_KEY=
PAYSTACK_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLIC_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
LEMONSQUEEZY_API_KEY=
LEMONSQUEEZY_STORE_ID=
LEMONSQUEEZY_WEBHOOK_SECRET=
NOWPAYMENTS_API_KEY=
NOWPAYMENTS_IPN_SECRET=
NEXT_PUBLIC_FEATURE_CRYPTO_PAYMENTS=false
ANTHROPIC_API_KEY=
GROK_API_KEY=
GEMINI_API_KEY=
OPENAI_API_KEY=
AI_PRIMARY_PROVIDER=claude
RESEND_API_KEY=
RESEND_FROM_EMAIL=hello@web-temify.com
CRON_SECRET=
ADMIN_EMAILS=
```

---

## next.config.ts

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "*.supabase.co",
        pathname: "/storage/v1/object/public/**",
      },
      {
        protocol: "https",
        hostname: "www.gravatar.com",
      },
    ],
  },
  experimental: {
    serverActions: {
      allowedOrigins: ["web-temify.com", "www.web-temify.com"],
    },
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-XSS-Protection", value: "1; mode=block" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Permissions-Policy",
            value: "geolocation=(), microphone=(), camera=()",
          },
        ],
      },
      {
        // Cache static assets aggressively
        source: "/build/(.*)",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=31536000, immutable",
          },
        ],
      },
    ];
  },
  async redirects() {
    return [
      {
        source: "/home",
        destination: "/",
        permanent: true,
      },
    ];
  },
};

export default nextConfig;
```

---

## tailwind.config.ts

```typescript
import type { Config } from "tailwindcss";
import forms from "@tailwindcss/forms";
import typography from "@tailwindcss/typography";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        bg: "#fffbf4",
        ink: "#0f0d0a",
        coral: "#ff5733",
        yellow: "#ffd60a",
        mint: "#00c48c",
        sky: "#4f8ef7",
        lilac: "#c084fc",
        surface: "#fff8ed",
        muted: "#6b6559",
      },
      fontFamily: {
        display: ["Cabinet Grotesk", "sans-serif"],
        serif: ["Instrument Serif", "serif"],
        mono: ["DM Mono", "monospace"],
        sans: ["Cabinet Grotesk", "sans-serif"],
      },
      boxShadow: {
        brutal: "4px 4px 0 #0f0d0a",
        "brutal-lg": "6px 6px 0 #0f0d0a",
        "brutal-sm": "2px 2px 0 #0f0d0a",
        "brutal-coral": "4px 4px 0 #ff5733",
      },
      borderWidth: {
        DEFAULT: "2px",
      },
      animation: {
        scroll: "scroll 22s linear infinite",
        "fade-up": "fadeUp 0.5s ease forwards",
        blink: "blink 2s ease-in-out infinite",
      },
      keyframes: {
        scroll: {
          from: { transform: "translateX(0)" },
          to: { transform: "translateX(-50%)" },
        },
        fadeUp: {
          from: { opacity: "0", transform: "translateY(20px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        blink: {
          "0%, 100%": { opacity: "1" },
          "50%": { opacity: "0.3" },
        },
      },
    },
  },
  plugins: [forms, typography],
};

export default config;
```

---

## vercel.json

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

## src/middleware.ts

```typescript
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Protected routes — redirect to login if not authenticated
  const protectedRoutes = [
    "/dashboard",
    "/my-downloads",
    "/my-purchases",
    "/my-subscription",
    "/my-invoices",
    "/my-licenses",
    "/my-collections",
    "/my-wishlist",
    "/points-rewards",
    "/badges",
    "/referrals",
    "/account-settings",
    "/profile/edit",
    "/checkout",
    "/vendor",
    "/admin",
  ];

  const isProtected = protectedRoutes.some((route) =>
    request.nextUrl.pathname.startsWith(route),
  );

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("redirectTo", request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }

  // Admin routes — check admin role
  if (request.nextUrl.pathname.startsWith("/admin") && user) {
    const { data: profile } = await supabase
      .from("users")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profile || !["ADMIN", "SUPER_ADMIN"].includes(profile.role)) {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
  }

  // Vendor routes — check vendor status
  if (request.nextUrl.pathname.startsWith("/vendor/dashboard") && user) {
    const { data: vendor } = await supabase
      .from("vendors")
      .select("status")
      .eq("user_id", user.id)
      .single();

    if (!vendor || vendor.status !== "ACTIVE") {
      return NextResponse.redirect(new URL("/vendor/register", request.url));
    }
  }

  // Cron routes — verify secret header
  if (request.nextUrl.pathname.startsWith("/api/cron")) {
    const authHeader = request.headers.get("authorization");
    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

---

## src/lib/supabase/client.ts

```typescript
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
```

## src/lib/supabase/server.ts

```typescript
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {}
        },
      },
    },
  );
}
```

## src/lib/prisma.ts

```typescript
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === "development"
        ? ["query", "error", "warn"]
        : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```
