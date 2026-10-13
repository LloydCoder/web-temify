# WEB-TEMIFY — EMAIL TEMPLATES SPEC
## 25 Emails via Resend | React Email Components
## Version 5.0 | May 2026

---

## SETUP (src/lib/resend.ts)

```typescript
import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function sendEmail({
  to,
  subject,
  react,
  text,
}: {
  to: string | string[]
  subject: string
  react?: React.ReactElement
  text?: string
}) {
  try {
    const { data, error } = await resend.emails.send({
      from: `${process.env.RESEND_FROM_NAME} <${process.env.RESEND_FROM_EMAIL}>`,
      to,
      subject,
      react,
      text,
      headers: {
        'List-Unsubscribe': `<${process.env.NEXT_PUBLIC_APP_URL}/unsubscribe>`,
        'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
      },
    })
    if (error) throw error
    return data
  } catch (error) {
    console.error('Email send failed:', error)
    throw error
  }
}
```

---

## EMAIL DESIGN SYSTEM

All emails must follow this design:
- Background: #fffbf4 (warm cream)
- Primary colour: #ff5733 (coral)
- Font: system-ui (email safe — Cabinet Grotesk not available in email)
- Max width: 600px centered
- Header: coral background with white Web-Temify logo
- Footer: company details + unsubscribe link + Tinlance mention
- Border radius: 8px on cards
- CTA buttons: #ff5733 background, white text, no border-radius (flat)

---

## ALL 25 EMAIL TEMPLATES

### 1. Welcome (src/emails/welcome.tsx)
```
Trigger: After registration
Subject: Welcome to Web-Temify — your store for premium templates 🎉
Content:
  - Welcome message with user's name
  - 3 quick steps to get started (Browse → Buy → Build)
  - Featured products (3 cards)
  - CTA: Browse Templates →
  - Bonus: "Complete your profile to earn 100 points"
```

### 2. Verify Email (src/emails/verify-email.tsx)
```
Trigger: Registration + email change
Subject: Verify your Web-Temify email address
Content:
  - Single large CTA button: Verify Email Address
  - Link expires in 24 hours note
  - If you didn't request this, ignore it
```

### 3. Password Reset (src/emails/password-reset.tsx)
```
Trigger: Forgot password request
Subject: Reset your Web-Temify password
Content:
  - Reset Password button (expires in 1 hour)
  - Security note: if you didn't request this, contact us
```

### 4. Purchase Receipt (src/emails/purchase-receipt.tsx)
```
Trigger: Successful order completion
Subject: Your purchase is ready — [Product Name]
Content:
  - Order confirmation number
  - Product name + price paid
  - License key (prominently displayed in monospace)
  - Download Now button (→ /my-downloads)
  - License type explanation
  - Support link
  - "Built with Web-Temify" tagline
```

### 5. Subscription Receipt (src/emails/subscription-receipt.tsx)
```
Trigger: New subscription activation
Subject: You're now on Web-Temify [Plan] — let's go 🚀
Content:
  - Plan name + price
  - What's included (feature list)
  - Access your downloads button
  - Next billing date
  - How to cancel (self-service link)
```

### 6. Expiry Reminder (src/emails/expiry-reminder.tsx)
```
Trigger: 3 days before subscription expires (cron)
Subject: Your Web-Temify plan expires in 3 days
Content:
  - Plan name + expiry date
  - What you'll lose access to
  - Renew Now button
  - Option to downgrade to Free
```

### 7. Download Ready (src/emails/download-ready.tsx)
```
Trigger: After purchase completes
Subject: Your download is ready — [Product Name]
Content:
  - Product name
  - Download Now button (secure token link)
  - Token expires in 24 hours note
  - Setup documentation link
  - Support contact
```

### 8. Product Updated (src/emails/product-updated.tsx)
```
Trigger: Vendor releases new version (→ all buyers)
Subject: [Product Name] just updated to v[X.X]
Content:
  - Product name + new version number
  - Changelog (what changed)
  - Re-download Now button
  - "Free update included with your purchase"
```

### 9. Vendor Approved (src/emails/vendor-approved.tsx)
```
Trigger: Admin approves vendor product
Subject: Your product is live on Web-Temify! 🎉
Content:
  - Product name
  - View your listing button
  - Tips for getting first sales
  - Sharing kit (Twitter copy + links)
  - Vendor academy link
```

### 10. Vendor Sale (src/emails/vendor-sale.tsx)
```
Trigger: Someone purchases vendor's product
Subject: 💰 You just made a sale — [Product Name]
Content:
  - Product name
  - Sale amount (after platform commission)
  - Buyer's country (no personal details)
  - Total earnings this month
  - View Earnings button
  - Platform commission rate reminder
```

### 11. Vendor Payout (src/emails/vendor-payout.tsx)
```
Trigger: Payout processed
Subject: Your Web-Temify payout of $[amount] is on its way
Content:
  - Payout amount
  - Gateway used (Paystack/Stripe/LemonSqueezy)
  - Expected arrival time
  - Transaction reference
  - View payout history button
```

### 12. Vendor Rejection (src/emails/vendor-rejection.tsx)
```
Trigger: Admin rejects vendor product submission
Subject: Feedback on your Web-Temify submission — [Product Name]
Content:
  - Product name
  - Specific rejection reasons (from admin notes)
  - How to fix each issue
  - Resubmit button (links to edit product)
  - "We want your product on the platform" encouragement
```

### 13. Affiliate Commission (src/emails/affiliate-commission.tsx)
```
Trigger: Affiliate earns commission on referred sale
Subject: You earned $[amount] in affiliate commission 🎉
Content:
  - Commission amount
  - Product that was purchased
  - Your total earnings this month
  - Affiliate dashboard button
  - Your referral link reminder
```

### 14. Abandoned Checkout (src/emails/abandoned-checkout.tsx)
```
Trigger: User started checkout but didn't complete (cron — 2h delay)
Subject: You left something behind...
Content:
  - Product name + price
  - Product preview image
  - Complete Purchase button
  - Optional: 10% discount code (for high-value products)
  - "Secure checkout • 30-day guarantee"
```

### 15–18. Drip Sequence (src/emails/drip-[1/3/7/14].tsx)
```
Drip Day 1 — Subject: "3 things you can do with Web-Temify today"
  - Browse templates CTA
  - Free templates highlight
  - Quick tutorial video

Drip Day 3 — Subject: "Developers are making $X/month selling here"
  - Vendor success story
  - How to become a vendor CTA
  - Revenue share highlight (70-80%)

Drip Day 7 — Subject: "Your first template, on us"
  - Free template offer
  - 3 best free templates shown
  - No credit card required

Drip Day 14 — Subject: "Still thinking? Here's what you're missing"
  - Platform stats (buyers, products, vendors)
  - Limited time: Pro plan first month 50% off
  - FAQ section (most common objections)
```

### 19–22. Dunning Sequence (src/emails/dunning-[1/2/3/final].tsx)
```
Dunning 1 (Day 1) — Subject: "Payment failed — let's fix this"
  - Failed payment notice
  - Update Payment Method button
  - "Your downloads are still safe for 3 days"

Dunning 2 (Day 3) — Subject: "We tried again — still having issues"
  - Second attempt failed
  - Update payment button
  - "Access suspended in 1 day"

Dunning 3 (Day 6) — Subject: "Last chance to keep your Web-Temify access"
  - Final warning
  - Update payment button
  - Downgrade to Free option

Dunning Final (Day 8) — Subject: "Your subscription has been cancelled"
  - Subscription cancelled notice
  - Reactivate button
  - "Your download history is saved"
  - "Come back anytime"
```

### 23. Suspicious Login (src/emails/suspicious-login.tsx)
```
Trigger: Login from new device/country
Subject: New login to your Web-Temify account
Content:
  - Login time, device, location (IP-based country)
  - "Was this you?" Yes / No CTA
  - If not you: Change Password button immediately
  - Enable 2FA recommendation
```

### 24. Service Request Confirmation (src/emails/service-request-confirm.tsx)
```
Trigger: User submits service request
Subject: We received your project brief — Tinlance will be in touch
Content:
  - Service category + brief summary
  - What happens next (timeline)
  - Tinlance contact details
  - "Meanwhile, browse our template catalogue"
```

### 25. Service Request Admin (src/emails/service-request-admin.tsx)
```
Trigger: User submits service request (→ admin/Tinlance)
Subject: 🔔 New service request — [Category] — $[Budget]
Content:
  - User name + email
  - Service category
  - Budget range
  - Timeline
  - Full project description
  - View in Admin button
```

### Bonus: Win-Back (src/emails/win-back.tsx)
```
Trigger: User inactive 60 days (cron)
Subject: We miss you, [Name] — here's what's new
Content:
  - New products since they last visited (3 cards)
  - "Come back" message
  - 20% discount code
  - CTA: See What's New
```

### Bonus: License Expiry (src/emails/license-expiry.tsx)
```
Trigger: 30 days before annual license expires (cron)
Subject: Your [Product] license expires in 30 days
Content:
  - Product name
  - License type
  - Expiry date
  - Renew License button
  - What happens when it expires
  - Upgrade path options
```

### Bonus: Annual Recap (src/emails/annual-recap.tsx)
```
Trigger: January 1st every year (cron)
Subject: Your Web-Temify Year in Review 🎉
Content:
  - Total templates downloaded
  - Money saved vs building from scratch ($X,XXX)
  - Top categories purchased
  - Badges earned
  - Points balance
  - "Share your recap" social button
  - CTA: Start 2027 right →
```

---

## EMAIL BASE LAYOUT (src/emails/layouts/base.tsx)

```typescript
import {
  Body, Container, Head, Html, Preview,
  Section, Text, Hr, Link, Img
} from '@react-email/components'

export function BaseEmailLayout({
  preview,
  children,
}: {
  preview: string
  children: React.ReactNode
}) {
  return (
    <Html>
      <Head />
      <Preview>{preview}</Preview>
      <Body style={{ backgroundColor: '#fffbf4', fontFamily: 'system-ui, sans-serif' }}>
        <Container style={{ maxWidth: '600px', margin: '0 auto', padding: '20px' }}>

          {/* Header */}
          <Section style={{ backgroundColor: '#ff5733', padding: '24px', textAlign: 'center' }}>
            <Text style={{ color: '#fff', fontSize: '24px', fontWeight: '900', margin: 0 }}>
              Web-Temify ●
            </Text>
          </Section>

          {/* Content */}
          <Section style={{ backgroundColor: '#fff8ed', padding: '32px', border: '2px solid #0f0d0a' }}>
            {children}
          </Section>

          {/* Footer */}
          <Section style={{ padding: '24px', textAlign: 'center' }}>
            <Hr style={{ borderColor: '#0f0d0a', borderWidth: '1px' }} />
            <Text style={{ fontSize: '12px', color: '#6b6559' }}>
              © 2026 Web-Temify LTD · RC: 7999659 · Nigeria
            </Text>
            <Text style={{ fontSize: '12px', color: '#6b6559' }}>
              A sister company of{' '}
              <Link href="https://tinlance.com" style={{ color: '#ff5733' }}>
                Tinlance Limited
              </Link>
            </Text>
            <Text style={{ fontSize: '11px', color: '#6b6559' }}>
              <Link href="{{{UNSUBSCRIBE_URL}}}" style={{ color: '#6b6559' }}>
                Unsubscribe
              </Link>
              {' · '}
              <Link href="https://web-temify.com/privacy" style={{ color: '#6b6559' }}>
                Privacy Policy
              </Link>
            </Text>
          </Section>

        </Container>
      </Body>
    </Html>
  )
}
```
