> **LEGACY / NON-CANONICAL — reviewed 2026-10-13.** Retained for historical requirements and design context only. Do not treat its framework, database/migration strategy, provider list, security examples, product count, phase status, pricing, testimonials, metrics, or “built/production-ready” claims as current truth. Canonical authority is in `docs/architecture/overview.md`, `docs/architecture/decisions/`, `docs/roadmap/phase-gates.md`, `docs/security/`, `docs/quality/testing-strategy.md`, the tested source and Supabase migrations, and `LloydCoder/web-temify-products/catalog/products.json`. Implement only through the current phase gates and verified evidence.

# WEB-TEMIFY — API ROUTES & PAYMENT INTEGRATION
## Version 5.0 | May 2026

---

## PAYMENT RULES (READ FIRST)

1. Every checkout page shows ALL enabled gateways as tabs
2. All webhooks verify HMAC signature BEFORE processing anything
3. All webhook handlers check idempotency key to prevent duplicate processing
4. NOWPayments = USDT/USDC only, TRC-20 preferred, auto-converts to fiat
5. Refunds on crypto = platform credits only, never on-chain
6. License key generated AUTOMATICALLY after every successful purchase
7. Download token generated AUTOMATICALLY after license key created
8. Points awarded AUTOMATICALLY after every purchase

---

## PAYSTACK WEBHOOK (src/app/api/webhooks/paystack/route.ts)

```typescript
import { headers } from 'next/headers'
import { NextResponse } from 'next/server'
import crypto from 'crypto'
import { prisma } from '@/lib/prisma'
import { handleOrderCompleted } from '@/lib/payments/handlers'

export async function POST(request: Request) {
  const body = await request.text()
  const headersList = await headers()
  const signature = headersList.get('x-paystack-signature')

  // 1. ALWAYS verify signature first
  const hash = crypto
    .createHmac('sha512', process.env.PAYSTACK_WEBHOOK_SECRET!)
    .update(body)
    .digest('hex')

  if (hash !== signature) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
  }

  const event = JSON.parse(body)

  // 2. Check idempotency
  const existing = await prisma.payment.findFirst({
    where: { gatewayRef: event.data?.reference }
  })
  if (existing) {
    return NextResponse.json({ received: true })
  }

  // 3. Handle events
  switch (event.event) {
    case 'charge.success':
      await handleOrderCompleted({
        gateway: 'PAYSTACK',
        reference: event.data.reference,
        amount: event.data.amount / 100,
        currency: event.data.currency,
        email: event.data.customer.email,
        metadata: event.data.metadata,
      })
      break

    case 'subscription.create':
      await handleSubscriptionCreated({
        gateway: 'PAYSTACK',
        subscriptionCode: event.data.subscription_code,
        planCode: event.data.plan.plan_code,
        email: event.data.customer.email,
      })
      break

    case 'subscription.disable':
      await handleSubscriptionCancelled({
        gateway: 'PAYSTACK',
        subscriptionCode: event.data.subscription_code,
      })
      break

    case 'charge.dispute.create':
      await handleChargebackOpened({
        gateway: 'PAYSTACK',
        reference: event.data.transaction_reference,
        amount: event.data.amount / 100,
      })
      break

    default:
      break
  }

  return NextResponse.json({ received: true })
}
```

---

## STRIPE WEBHOOK (src/app/api/webhooks/stripe/route.ts)

```typescript
import { headers } from 'next/headers'
import { NextResponse } from 'next/server'
import Stripe from 'stripe'
import { handleOrderCompleted } from '@/lib/payments/handlers'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(request: Request) {
  const body = await request.text()
  const headersList = await headers()
  const sig = headersList.get('stripe-signature')!

  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    )
  } catch (err) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
  }

  switch (event.type) {
    case 'payment_intent.succeeded':
      const pi = event.data.object as Stripe.PaymentIntent
      await handleOrderCompleted({
        gateway: 'STRIPE',
        reference: pi.id,
        amount: pi.amount / 100,
        currency: pi.currency.toUpperCase(),
        email: pi.receipt_email ?? '',
        metadata: pi.metadata,
      })
      break

    case 'customer.subscription.created':
      const sub = event.data.object as Stripe.Subscription
      await handleSubscriptionCreated({
        gateway: 'STRIPE',
        subscriptionId: sub.id,
        priceId: sub.items.data[0].price.id,
        customerId: sub.customer as string,
      })
      break

    case 'customer.subscription.deleted':
      const cancelledSub = event.data.object as Stripe.Subscription
      await handleSubscriptionCancelled({
        gateway: 'STRIPE',
        subscriptionId: cancelledSub.id,
      })
      break

    case 'invoice.payment_failed':
      await handlePaymentFailed({
        gateway: 'STRIPE',
        invoiceId: (event.data.object as Stripe.Invoice).id,
      })
      break

    case 'charge.dispute.created':
      const dispute = event.data.object as Stripe.Dispute
      await handleChargebackOpened({
        gateway: 'STRIPE',
        reference: dispute.charge as string,
        amount: dispute.amount / 100,
      })
      break

    default:
      break
  }

  return NextResponse.json({ received: true })
}
```

---

## LEMONSQUEEZY WEBHOOK (src/app/api/webhooks/lemonsqueezy/route.ts)

```typescript
import { headers } from 'next/headers'
import { NextResponse } from 'next/server'
import crypto from 'crypto'

export async function POST(request: Request) {
  const body = await request.text()
  const headersList = await headers()
  const signature = headersList.get('x-signature')

  // Verify HMAC SHA-256
  const hash = crypto
    .createHmac('sha256', process.env.LEMONSQUEEZY_WEBHOOK_SECRET!)
    .update(body)
    .digest('hex')

  if (hash !== signature) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
  }

  const event = JSON.parse(body)
  const eventName = event.meta?.event_name

  switch (eventName) {
    case 'order_created':
      await handleOrderCompleted({
        gateway: 'LEMONSQUEEZY',
        reference: event.data.id,
        amount: event.data.attributes.total / 100,
        currency: event.data.attributes.currency,
        email: event.data.attributes.user_email,
        metadata: event.meta?.custom_data,
      })
      break

    case 'subscription_created':
      await handleSubscriptionCreated({
        gateway: 'LEMONSQUEEZY',
        subscriptionId: event.data.id,
        variantId: event.data.attributes.variant_id,
        email: event.data.attributes.user_email,
      })
      break

    case 'subscription_cancelled':
      await handleSubscriptionCancelled({
        gateway: 'LEMONSQUEEZY',
        subscriptionId: event.data.id,
      })
      break

    case 'subscription_payment_failed':
      await handlePaymentFailed({
        gateway: 'LEMONSQUEEZY',
        subscriptionId: event.data.id,
      })
      break

    default:
      break
  }

  return NextResponse.json({ received: true })
}
```

---

## NOWPAYMENTS WEBHOOK (src/app/api/webhooks/nowpayments/route.ts)

```typescript
import { headers } from 'next/headers'
import { NextResponse } from 'next/server'
import crypto from 'crypto'

// PHASE 3 ONLY — check feature flag
export async function POST(request: Request) {
  if (process.env.NEXT_PUBLIC_FEATURE_CRYPTO_PAYMENTS !== 'true') {
    return NextResponse.json({ error: 'Not enabled' }, { status: 404 })
  }

  const body = await request.text()
  const headersList = await headers()
  const signature = headersList.get('x-nowpayments-sig')

  // Sort payload alphabetically then verify
  const parsed = JSON.parse(body)
  const sorted = Object.keys(parsed)
    .sort()
    .reduce((acc: Record<string, unknown>, key) => {
      acc[key] = parsed[key]
      return acc
    }, {})

  const hash = crypto
    .createHmac('sha512', process.env.NOWPAYMENTS_IPN_SECRET!)
    .update(JSON.stringify(sorted))
    .digest('hex')

  if (hash !== signature) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
  }

  // Only process confirmed payments
  if (parsed.payment_status === 'confirmed' || parsed.payment_status === 'finished') {
    await handleOrderCompleted({
      gateway: 'NOWPAYMENTS',
      reference: parsed.payment_id,
      amount: parseFloat(parsed.price_amount),
      currency: 'USD',
      email: parsed.order_description,
      metadata: { orderId: parsed.order_id },
    })
  }

  return NextResponse.json({ received: true })
}

// NOWPAYMENTS RULES:
// - Accept USDT (TRC-20) and USDC (TRC-20/ERC-20) ONLY
// - Auto-converts to fiat — never hold crypto
// - Refunds = platform credits only, NEVER on-chain
// - Show QR code + wallet address + 30-minute countdown to buyer
```

---

## ORDER COMPLETION HANDLER (src/lib/payments/handlers.ts)

```typescript
import { prisma } from '@/lib/prisma'
import { generateLicenseKey } from '@/lib/license'
import { generateDownloadToken } from '@/lib/download'
import { awardPoints } from '@/lib/gamification'
import { sendEmail } from '@/lib/resend'
import { PurchaseReceiptEmail } from '@/emails/purchase-receipt'

interface OrderCompletedPayload {
  gateway: string
  reference: string
  amount: number
  currency: string
  email: string
  metadata: Record<string, string>
}

export async function handleOrderCompleted(payload: OrderCompletedPayload) {
  const { gateway, reference, amount, currency, email, metadata } = payload

  // Find the pending order
  const order = await prisma.order.findFirst({
    where: {
      OR: [
        { gatewayRef: reference },
        { id: metadata?.orderId },
      ],
      status: 'PENDING',
    },
    include: {
      user: true,
      product: true,
    },
  })

  if (!order) return

  // Update order status
  await prisma.order.update({
    where: { id: order.id },
    data: {
      status: 'COMPLETED',
      gatewayRef: reference,
      gatewayStatus: 'paid',
    },
  })

  // Generate license key if product purchase
  if (order.productId) {
    const licenseKey = await generateLicenseKey({
      orderId: order.id,
      productId: order.productId,
      userId: order.userId,
      licenseType: order.product?.licenseType ?? 'REGULAR',
    })

    // Generate download token (expires 24h, single use)
    await generateDownloadToken({
      userId: order.userId,
      productId: order.productId,
      orderId: order.id,
    })

    // Update license key on order
    await prisma.order.update({
      where: { id: order.id },
      data: { licenseKeyId: licenseKey.id },
    })
  }

  // Award points (purchases = 10 points per $1 spent)
  await awardPoints({
    userId: order.userId,
    points: Math.floor(amount * 10),
    action: 'PURCHASE',
    referenceId: order.id,
    description: `Purchase: ${order.product?.name ?? 'Subscription'}`,
  })

  // Send receipt email
  await sendEmail({
    to: order.user.email,
    subject: `Your purchase is ready — Web-Temify`,
    react: PurchaseReceiptEmail({
      userName: order.user.name,
      productName: order.product?.name ?? 'Subscription',
      amount,
      currency,
      downloadUrl: `${process.env.NEXT_PUBLIC_APP_URL}/my-downloads`,
      orderId: order.id,
    }),
  })

  // Log activity
  await prisma.activityLog.create({
    data: {
      userId: order.userId,
      action: 'ORDER_COMPLETED',
      entity: 'Order',
      entityId: order.id,
      details: { gateway, amount, currency },
    },
  })

  // Notify vendor of sale
  if (order.vendorId) {
    await notifyVendorOfSale(order)
  }
}
```

---

## LICENSE VALIDATION API (src/app/api/v1/validate-license/route.ts)

```typescript
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { headers } from 'next/headers'

export async function POST(request: Request) {
  const { key, domain } = await request.json()

  if (!key || !domain) {
    return NextResponse.json(
      { valid: false, error: 'key and domain are required' },
      { status: 400 }
    )
  }

  // Hash the provided key for comparison
  const crypto = await import('crypto')
  const keyHash = crypto.createHash('sha256').update(key).digest('hex')

  const license = await prisma.licenseKey.findUnique({
    where: { keyHash },
    include: { product: true },
  })

  // License not found
  if (!license) {
    return NextResponse.json({ valid: false, error: 'License not found' })
  }

  // License revoked
  if (license.revoked) {
    return NextResponse.json({
      valid: false,
      error: 'License has been revoked',
      revokedReason: license.revokedReason,
    })
  }

  // License expired
  if (license.expiresAt && license.expiresAt < new Date()) {
    return NextResponse.json({
      valid: false,
      error: 'License has expired',
      expiresAt: license.expiresAt,
    })
  }

  // Check domain activation
  const domains = (license.domains as string[]) ?? []
  const isDomainActivated = domains.includes(domain)

  if (!isDomainActivated) {
    // Check activation limit
    if (license.activationCount >= license.activationLimit) {
      return NextResponse.json({
        valid: false,
        error: `Activation limit reached (${license.activationLimit} domains)`,
      })
    }

    // Activate new domain
    await prisma.$transaction([
      prisma.licenseActivation.create({
        data: {
          licenseKeyId: license.id,
          domain,
          active: true,
        },
      }),
      prisma.licenseKey.update({
        where: { id: license.id },
        data: {
          activationCount: { increment: 1 },
          domains: [...domains, domain],
        },
      }),
    ])
  }

  // Valid license response
  return NextResponse.json({
    valid: true,
    licenseType: license.licenseType,
    product: license.product.name,
    expiresAt: license.expiresAt,
    activationLimit: license.activationLimit,
    activationCount: license.activationCount + (isDomainActivated ? 0 : 1),
    domain,
  })
}
```

---

## SECURE DOWNLOAD (src/app/api/download/[token]/route.ts)

```typescript
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createClient } from '@/lib/supabase/server'

export async function GET(
  request: Request,
  { params }: { params: { token: string } }
) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  const download = await prisma.download.findUnique({
    where: { token: params.token },
    include: { product: true },
  })

  // Token not found
  if (!download) {
    return NextResponse.json({ error: 'Invalid download token' }, { status: 404 })
  }

  // Token belongs to different user
  if (download.userId !== user.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })
  }

  // Token expired
  if (download.tokenExpiresAt < new Date()) {
    return NextResponse.json({ error: 'Download token expired' }, { status: 410 })
  }

  // Check download abuse limit (max 5 downloads per token)
  if (download.count >= 5) {
    return NextResponse.json({ error: 'Download limit reached' }, { status: 429 })
  }

  // Generate signed URL from Supabase Storage (expires in 5 minutes)
  const { data: signedUrl } = await supabase.storage
    .from(process.env.SUPABASE_BUCKET_DOWNLOADS!)
    .createSignedUrl(download.product.downloadFile!, 300)

  if (!signedUrl) {
    return NextResponse.json({ error: 'File not found' }, { status: 404 })
  }

  // Increment download count
  await prisma.download.update({
    where: { id: download.id },
    data: {
      count: { increment: 1 },
      downloadedAt: new Date(),
    },
  })

  // Increment product download counter
  await prisma.product.update({
    where: { id: download.productId },
    data: { downloads: { increment: 1 } },
  })

  // Redirect to signed URL
  return NextResponse.redirect(signedUrl.signedUrl)
}
```

---

## AI GATEWAY (src/lib/ai-gateway.ts)

```typescript
import Anthropic from '@anthropic-ai/sdk'
import { prisma } from '@/lib/prisma'

const taskRouting: Record<string, string[]> = {
  blog_post:           ['claude', 'openai', 'gemini'],
  directory_listing:   ['gemini', 'claude', 'openai'],
  page_generator:      ['claude', 'openai', 'grok'],
  product_description: ['claude', 'openai', 'gemini'],
  support_reply:       ['claude', 'gemini', 'openai'],
  semantic_search:     ['gemini', 'claude', 'openai'],
  web3_content:        ['grok', 'claude', 'openai'],
  review_summary:      ['claude', 'gemini', 'openai'],
  pricing_advice:      ['claude', 'openai', 'gemini'],
}

export async function aiComplete(
  prompt: string,
  task: string = 'general',
  maxTokens: number = 1000
): Promise<string> {
  const providers = taskRouting[task] ?? ['claude', 'openai', 'gemini']
  const startTime = Date.now()

  for (const provider of providers) {
    try {
      const result = await callProvider(provider, prompt, maxTokens)
      const latency = Date.now() - startTime

      // Log usage
      await prisma.aiUsageLog.create({
        data: {
          provider,
          taskType: task,
          tokensIn: Math.ceil(prompt.length / 4),
          tokensOut: Math.ceil(result.length / 4),
          costUsd: estimateCost(provider, prompt, result),
          latencyMs: latency,
          success: true,
        },
      }).catch(() => {}) // Don't fail if logging fails

      return result
    } catch (error) {
      console.error(`AI provider ${provider} failed:`, error)
      continue
    }
  }

  return getFallbackResponse(task)
}

async function callProvider(
  provider: string,
  prompt: string,
  maxTokens: number
): Promise<string> {
  switch (provider) {
    case 'claude':
      return callClaude(prompt, maxTokens)
    case 'grok':
      return callGrok(prompt, maxTokens)
    case 'gemini':
      return callGemini(prompt, maxTokens)
    case 'openai':
      return callOpenAI(prompt, maxTokens)
    default:
      throw new Error(`Unknown provider: ${provider}`)
  }
}

async function callClaude(prompt: string, maxTokens: number): Promise<string> {
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
  const message = await client.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: maxTokens,
    messages: [{ role: 'user', content: prompt }],
  })
  return (message.content[0] as { text: string }).text
}

async function callGrok(prompt: string, maxTokens: number): Promise<string> {
  const response = await fetch('https://api.x.ai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.GROK_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'grok-3',
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  })
  const data = await response.json()
  return data.choices[0].message.content
}

async function callGemini(prompt: string, maxTokens: number): Promise<string> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: maxTokens },
      }),
    }
  )
  const data = await response.json()
  return data.candidates[0].content.parts[0].text
}

async function callOpenAI(prompt: string, maxTokens: number): Promise<string> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  })
  const data = await response.json()
  return data.choices[0].message.content
}

function estimateCost(provider: string, prompt: string, result: string): number {
  const inputTokens = prompt.length / 4
  const outputTokens = result.length / 4
  const rates: Record<string, [number, number]> = {
    claude:  [0.000003, 0.000015],
    openai:  [0.00000015, 0.0000006],
    gemini:  [0.00000010, 0.00000040],
    grok:    [0.000003, 0.000015],
  }
  const [inputRate, outputRate] = rates[provider] ?? [0, 0]
  return (inputTokens * inputRate) + (outputTokens * outputRate)
}

function getFallbackResponse(task: string): string {
  const fallbacks: Record<string, string> = {
    semantic_search: '',
    support_reply: 'Thank you for reaching out. Our team will respond shortly.',
    default: 'AI service temporarily unavailable. Please try again.',
  }
  return fallbacks[task] ?? fallbacks.default
}
```

---

## CRON JOB EXAMPLE (src/app/api/cron/expiry-reminders/route.ts)

```typescript
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { sendEmail } from '@/lib/resend'
import { ExpiryReminderEmail } from '@/emails/expiry-reminder'
import { addDays } from 'date-fns'

// All cron routes are protected by middleware (CRON_SECRET check)
export async function GET() {
  const threeDaysFromNow = addDays(new Date(), 3)
  const now = new Date()

  // Find subscriptions expiring in 3 days
  const expiring = await prisma.subscription.findMany({
    where: {
      status: 'ACTIVE',
      currentPeriodEnd: {
        gte: now,
        lte: threeDaysFromNow,
      },
      cancelAtPeriodEnd: false,
    },
    include: { user: true, planConfig: true },
  })

  let sent = 0
  for (const sub of expiring) {
    try {
      await sendEmail({
        to: sub.user.email,
        subject: 'Your Web-Temify plan expires in 3 days',
        react: ExpiryReminderEmail({
          userName: sub.user.name,
          planName: sub.planConfig.name,
          expiryDate: sub.currentPeriodEnd!,
          renewUrl: `${process.env.NEXT_PUBLIC_APP_URL}/my-subscription`,
        }),
      })
      sent++
    } catch (error) {
      console.error(`Failed to send expiry reminder to ${sub.user.email}:`, error)
    }
  }

  return NextResponse.json({ success: true, sent })
}
```

---

## CHECKOUT FLOW (src/actions/checkout.actions.ts)

```typescript
'use server'

import { prisma } from '@/lib/prisma'
import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { headers } from 'next/headers'
import { z } from 'zod'

const CheckoutSchema = z.object({
  productId: z.string().uuid().optional(),
  planId: z.string().uuid().optional(),
  gateway: z.enum(['PAYSTACK', 'STRIPE', 'LEMONSQUEEZY']),
  couponCode: z.string().optional(),
  giftCardCode: z.string().optional(),
})

export async function initiateCheckout(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login?redirectTo=/checkout')

  const validated = CheckoutSchema.safeParse({
    productId: formData.get('productId'),
    planId: formData.get('planId'),
    gateway: formData.get('gateway'),
    couponCode: formData.get('couponCode'),
    giftCardCode: formData.get('giftCardCode'),
  })

  if (!validated.success) {
    return { error: 'Invalid checkout data' }
  }

  const headersList = await headers()
  const ip = headersList.get('x-forwarded-for') ?? '0.0.0.0'

  // Fraud check — high value purchases require 2FA
  let amount = 0
  if (validated.data.productId) {
    const product = await prisma.product.findUnique({
      where: { id: validated.data.productId }
    })
    amount = product?.price.toNumber() ?? 0
  }

  if (amount > parseInt(process.env.HIGH_VALUE_CHECKOUT_THRESHOLD ?? '200')) {
    // Check 2FA is enabled for this user
    const userRecord = await prisma.user.findUnique({
      where: { id: user.id },
      select: { twoFactorEnabled: true }
    })
    if (!userRecord?.twoFactorEnabled) {
      return { requiresTwoFactor: true }
    }
  }

  // Create pending order
  const order = await prisma.order.create({
    data: {
      orderNumber: `WT-${Date.now()}`,
      userId: user.id,
      productId: validated.data.productId,
      planConfigId: validated.data.planId,
      amount,
      currency: 'USD',
      gateway: validated.data.gateway,
      status: 'PENDING',
      ipAddress: ip,
      idempotencyKey: `${user.id}-${Date.now()}`,
    },
  })

  // Route to correct payment gateway
  switch (validated.data.gateway) {
    case 'PAYSTACK':
      return initiatePaystack(order, user)
    case 'STRIPE':
      return initiateStripe(order, user)
    case 'LEMONSQUEEZY':
      return initiateLemonSqueezy(order, user)
    default:
      return { error: 'Invalid gateway' }
  }
}
```
