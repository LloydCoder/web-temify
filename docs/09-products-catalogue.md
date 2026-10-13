> **LEGACY / NON-CANONICAL — reviewed 2026-10-13.** Retained for historical requirements and design context only. Do not treat its framework, database/migration strategy, provider list, security examples, product count, phase status, pricing, testimonials, metrics, or “built/production-ready” claims as current truth. Canonical authority is in `docs/architecture/overview.md`, `docs/architecture/decisions/`, `docs/roadmap/phase-gates.md`, `docs/security/`, `docs/quality/testing-strategy.md`, the tested source and Supabase migrations, and `LloydCoder/web-temify-products/catalog/products.json`. Implement only through the current phase gates and verified evidence.

# WEB-TEMIFY — PRODUCT CATALOGUE
## 44 Products to Build and List on the Marketplace
## Version 5.0 | May 2026

---

## BUILD ORDER (FOLLOW EXACTLY)

1. Tier 1 (6 templates) — Build first, list on platform day one
2. Tier 4 (4 launch kits) — Highest revenue, build second
3. Tier 5 (6 Africa niche) — Zero competition, build third
4. Tier 2 (12 scripts/templates) — Medium effort, build fourth
5. Tier 3 (16 complex products) — Build last as revenue grows

---

## TIER 1 — BUILD FIRST (6 Products)

### 1. Courier & Logistics Pro Template
```
Price:        $79 (Regular) | $149 (Extended) | $199 (White-Label)
Type:         Website Template
Tech stack:   HTML5 + CSS3 + Bootstrap 5 + Vanilla JS
Pages:        10 pages
Target buyer: Courier companies, dispatch services, logistics startups

Must include:
- Hero section with tracking input field
- Live parcel tracking UI (dummy data animated)
- Rate calculator (weight + distance = price)
- Service categories (express, standard, bulk, international)
- Coverage areas map (Google Maps embed placeholder)
- Fleet/vehicle showcase gallery
- Driver recruitment page
- Mobile app download section
- WhatsApp order integration button
- Contact + quote request form
- Dark mode toggle
- RTL support
- Paystack payment button (for COD)

Variants: Dark theme + Light theme (2 versions)
Colour scheme: Orange/Navy or Green/White
```

### 2. Loan & Lending Company Template
```
Price:        $99 (Regular) | $179 (Extended) | $249 (White-Label)
Type:         Website Template
Tech stack:   HTML5 + CSS3 + Bootstrap 5 + JavaScript
Pages:        12 pages
Target buyer: Microfinance companies, credit unions, fintech lenders,
              cooperative societies, SACCO managers

Must include:
- Trust-first hero (compliance badges, CBN-mention placeholder)
- Interactive loan calculator (amount slider + tenure + interest rate)
- Eligibility checker (multi-step form)
- Loan products (personal, business, emergency, student)
- Application process (4-step visual)
- Rates & fees transparency page
- Documents required section
- Customer testimonials
- Partner banks logos strip
- Compliance/regulatory section
- SMS/USSD loan application mention
- Blog/financial tips section
- FAQs with accordion
- Paystack repayment button integration

Colour scheme: Deep green + gold (trust and wealth)
Key differentiator: Nigeria/Africa compliance language built in
```

### 3. NeoBank & Digital Banking Template
```
Price:        $99 (Regular) | $199 (Extended) | $299 (White-Label)
Type:         Website Template
Tech stack:   React 18 + Next.js 15 + Tailwind CSS
Pages:        14 pages + Islamic banking variant
Target buyer: Neobanks, digital wallets, fintech startups,
              cooperative banks, digital lending apps

Must include:
- Bold animated hero (phone mockup + account dashboard preview)
- Account opening CTA (3-step visual)
- Features grid (transfers, bills, savings, loans, cards)
- Mobile app mockup section (iOS + Android badges)
- Security trust section (encryption, 2FA, NDIC mention)
- Personal + Business + Corporate plan pages
- Savings calculator (interest rate display)
- Card products page (virtual + physical)
- Referral programme section
- API for developers section
- Islamic banking variant (Murabaha, Ijara, zakat calc)
- Social proof (users, transactions, countries)
- App store screenshots gallery

Islamic variant: Full RTL, Arabic typography support
Colour scheme: Dark navy + coral OR Clean white + electric blue
```

### 4. Digital Agency Pro Template
```
Price:        $49 (Regular) | $79 (Extended) | $99 (White-Label)
Type:         Website Template
Tech stack:   HTML5 + CSS3 + Bootstrap 5 + AOS animations
Pages:        10 pages
Target buyer: Creative agencies, web development studios,
              marketing agencies, design freelancers

Must include:
- Bold hero with animated text (rotating service words)
- Services grid (Web Design, Dev, Branding, SEO, Social, Mobile)
- Case studies grid (before/after style)
- Portfolio grid with filter (All, Web, Mobile, Brand, Web3)
- Team section with hover effect
- Clients logo strip (animated scroll)
- Awards/recognition section
- Pricing packages (3 tiers)
- Process/methodology section (4 steps)
- Blog section
- Contact form + WhatsApp button
- Dark mode (brutalist dark version included)

Variants: Light (cream/coral) + Dark (ink/coral) — match Web-Temify brand
```

### 5. SaaS & Startup Landing Page
```
Price:        $49 (Regular) | $79 (Extended) | $99 (White-Label)
Type:         Website Template
Tech stack:   HTML5 + Tailwind CSS + Alpine.js
Pages:        8 pages + waitlist mode variant
Target buyer: SaaS founders, indie hackers, startup CTOs,
              product hunt launchers

Must include:
- Conversion-optimised hero (headline + subline + CTA + social proof)
- Feature sections (alternating image/text layout)
- Interactive demo/product screenshot section
- Pricing table (3 tiers, monthly/annual toggle)
- Social proof bar (customer logos + stats)
- Testimonials (3 cards)
- FAQ accordion
- Blog section
- Newsletter/waitlist capture
- Waitlist mode variant (coming soon + email capture + countdown)
- Integration logos section (connects with X, Y, Z)
- Footer with all links

Variants: Standard mode + Waitlist/Coming Soon mode
Colour scheme: Multiple (coral, blue, green, purple options)
```

### 6. Portfolio & Freelancer Template
```
Price:        $29 (Regular) | $49 (Extended) | $79 (White-Label)
Type:         Website Template
Tech stack:   HTML5 + CSS3 + Vanilla JS
Pages:        6 pages
Target buyer: Developers, designers, Web3 creators,
              copywriters, consultants, digital freelancers

Must include:
- Minimal brutalist hero (name + title + availability badge)
- Projects/work showcase grid (filterable)
- Skills section (visual skill bars or icon grid)
- Work experience timeline
- Services + pricing
- Testimonials (3)
- Blog/writing section
- Contact form + WhatsApp + Calendly link placeholder
- Social links (GitHub, LinkedIn, Twitter, Dribbble)
- Downloadable CV button (PDF)
- Dark mode (developer-preferred)
- Multiple colour accent options

Variants: Developer focus + Designer focus + Web3 focus (3 homepages)
```

---

## TIER 4 — LAUNCH KITS (4 Products — Build Second)

### 34. SaaS Starter Kit
```
Price:        $299 (bundle) | normally $490 individual
Contents:
  1. SaaS Landing Page Template (from Tier 1)
  2. Auth pages (login, register, forgot, reset, verify)
  3. SaaS Admin Dashboard UI (from Tier 2)
  4. Billing/pricing page templates (Stripe + Paystack ready)
  5. Email templates (25 branded emails — React Email)
  6. Onboarding flow templates (3-step wizard UI)

Tech: HTML5 + React/Next.js versions included for all
Docs: Complete README + setup guide + deployment checklist
```

### 35. Web3 DApp Starter Kit
```
Price:        $399 (bundle) | normally $620 individual
Contents:
  1. Web3 dApp Landing Page (from Tier 3)
  2. Wallet connection UI component (MetaMask, WalletConnect, Coinbase)
  3. NFT Gallery + Mint page templates
  4. DAO Governance UI
  5. Token Dashboard UI
  6. DeFi Staking interface

Tech: React + Ethers.js + Wagmi/Viem
Docs: README + web3 setup guide + contract integration hints
```

### 36. Fintech Launch Kit
```
Price:        $349 (bundle) | normally $560 individual
Contents:
  1. NeoBank/Digital Banking Template (from Tier 1)
  2. Loan & Lending Template (from Tier 1)
  3. Loan Calculator standalone component
  4. KYC/Onboarding flow pages
  5. Paystack integration guide + code snippets
  6. Compliance pages (Privacy, Terms, CBN disclosure)

Tech: HTML5 + Bootstrap (Paystack-ready)
Docs: README + Paystack setup guide + compliance checklist
Special: Africa-first — all Naira/NGN pricing psychology built in
```

### 37. Agency Starter Kit
```
Price:        $249 (bundle) | normally $390 individual
Contents:
  1. Digital Agency Pro Template (from Tier 1)
  2. Case study page template
  3. Proposal/quote page template
  4. Client portal landing page
  5. Lead capture forms (5 variants)
  6. Pricing page templates (3 variants)

Tech: HTML5 + Bootstrap
Docs: README + client pitch tips + conversion optimisation notes
```

---

## TIER 5 — AFRICA NICHE (6 Products — Zero Competition)

### 38. Ajo / Esusu / Cooperative Savings Script
```
Price:        $149 (Regular) | $249 (Extended) | $399 (White-Label)
Type:         Full PHP Script
Tech:         PHP 8.2 + MySQL + Paystack + MTN MoMo
Competition:  ZERO on any marketplace
Target:       Community savings groups, cooperative societies,
              NGOs, church/mosque savings programmes

Features:
  - Group creation and management
  - Member invitation + onboarding
  - Contribution schedule (weekly/monthly)
  - Payout rotation tracker (who gets paid next)
  - Automatic reminder notifications (SMS + email)
  - Paystack collection integration
  - MTN MoMo collection
  - Mobile money disbursement
  - Transaction history per member
  - Group admin dashboard
  - Dispute/complaint system
  - PDF statement generation
  - Multi-group management
  - SMS OTP verification
```

### 39. Islamic Finance / Halal Banking Template
```
Price:        $99 (Regular) | $179 (Extended) | $249 (White-Label)
Type:         Website Template
Tech:         HTML5 + Bootstrap 5 (full RTL support)
Competition:  ZERO on any marketplace
Target:       Islamic banks, Halal microfinance, Takaful companies,
              Waqf institutions, Islamic cooperative societies

Features:
  - Full RTL layout (Arabic + English dual)
  - Murabaha product page (cost-plus financing)
  - Ijara product page (lease financing)
  - Sukuk investment page
  - Zakat calculator (interactive)
  - Sadaqah/donation flow
  - Shariah compliance certificates section
  - Prayer time widget (optional)
  - No-interest language throughout
  - Northern Nigeria + East Africa market language
  - Hausa translation variant
```

### 40. Agritech & Farm Marketplace Template
```
Price:        $79 (Regular) | $129 (Extended) | $179 (White-Label)
Type:         Website Template
Tech:         HTML5 + Bootstrap 5 + Leaflet.js maps
Competition:  Very low — Africa-specific
Target:       Agricultural cooperatives, farm-to-table platforms,
              produce aggregators, agri-startups

Features:
  - Farm produce listing (categories: grains, vegetables, fruits, livestock)
  - Farmer profile pages
  - Bulk order request system
  - Price discovery board (current market prices)
  - Seasonal availability calendar
  - Cold chain/logistics partner section
  - Farm location map (Leaflet.js)
  - Harvest schedule display
  - Cooperative membership section
  - Mobile money payment (Paystack + MoMo)
  - WeatherAPI widget integration placeholder
  - WhatsApp order integration
```

### 41. ISP & Telecom Company Template
```
Price:        $79 (Regular) | $129 (Extended) | $179 (White-Label)
Type:         Website Template
Tech:         HTML5 + Bootstrap 5 + JavaScript
Competition:  Low — Nigeria-specific ISPs underserved
Target:       ISPs, WISPs, fiber companies, VSAT providers,
              state telecom companies

Features:
  - Coverage checker (postcode/area input)
  - Data plan comparison table (Home/SME/Enterprise)
  - Speed test embed placeholder (Fast.com / Speedtest)
  - Router/equipment catalogue
  - Installation booking form
  - SLA/uptime display (99.9% badge)
  - Support ticket portal link
  - Bulk SMS/data reseller section
  - Corporate/B2B section
  - NCC regulatory compliance mention
  - Paystack plan subscription
  - Network status widget
```

### 42. Solar Energy & Power Company Template
```
Price:        $79 (Regular) | $129 (Extended) | $179 (White-Label)
Type:         Website Template
Tech:         HTML5 + Bootstrap 5 + JavaScript calculator
Competition:  Low — Nigeria off-grid solar underserved
Target:       Solar installers, inverter companies,
              battery distributors, renewable energy startups

Features:
  - NEPA bill savings calculator (hours/day → monthly savings)
  - Product catalogue (panels, inverters, batteries, accessories)
  - Installation portfolio with before/after
  - System sizing guide (home vs commercial)
  - Financing/payment plan section
  - 25-year warranty display
  - Installation process (4 steps)
  - Service coverage map
  - Technical specs comparison table
  - Energy monitoring app mockup section
  - NERC/regulatory compliance
  - WhatsApp quote request
  - Paystack deposit integration
```

### 43. Ride-Hailing / Okada App Landing Page
```
Price:        $59 (Regular) | $99 (Extended) | $149 (White-Label)
Type:         Website Template
Tech:         HTML5 + React + Google Maps API placeholder
Competition:  Low — Nigeria dispatch/ride-hailing specific
Target:       Logistics dispatch services, bike-hailing startups,
              ride-hailing apps, courier-on-demand services

Features:
  - Split driver/rider hero sections
  - App download CTAs (iOS + Android badges)
  - How it works (3 steps: Request → Match → Arrive)
  - Safety features showcase
  - Coverage area interactive map
  - Pricing/fare estimator
  - Driver earnings calculator
  - Partner/driver application form
  - Corporate/business accounts section
  - Insurance coverage section
  - Customer testimonials
  - Press mentions section
  - FAQ (rider + driver split)
```

---

## TIER 2 — MEDIUM TERM (12 Products)

### Product Specs Summary

| # | Product | Type | Stack | Price | Key Feature |
|---|---|---|---|---|---|
| 7 | P2P Crypto Trading Script | Full Script | PHP+Laravel | $299–$799 | Escrow, dispute, ratings |
| 8 | Online Banking Lite Script | Full Script | PHP+MySQL | $199–$499 | Transfers, bills, 2FA |
| 9 | Loan Management Script | Full Script | PHP+MySQL | $199–$499 | Approval flow, repayment |
| 10 | NFT Marketplace Template | Template | Next.js+Web3 | $99–$249 | Wallet connect, mint |
| 11 | Real Estate Template | Template | Next.js+Maps | $79–$199 | Property search, agent |
| 12 | Invoice & Billing Script | Full Script | PHP+Paystack | $149–$399 | PDF invoices, recurring |
| 13 | E-commerce Store Template | Template | WP+WooCommerce | $79–$199 | Cart, checkout, Paystack |
| 14 | Restaurant Template | Template | HTML5+WhatsApp | $79–$199 | Menu, booking, delivery |
| 15 | Hospital & Clinic Template | Template | HTML5+Bootstrap | $79–$199 | Appointments, doctors |
| 16 | School & Education Template | Template | HTML5+LMS | $79–$199 | Courses, admissions |
| 17 | SaaS Admin Dashboard | UI Kit | HTML5+React | $99–$249 | 40+ pages, charts |
| 18 | POS System Script | Full Script | PHP+Barcode | $149–$399 | Sales, inventory, receipt |

---

## TIER 3 — LATER (16 Products)

### Product Specs Summary

| # | Product | Type | Price | Notes |
|---|---|---|---|---|
| 19 | CEX Lite Exchange | Full Script | $499–$999 | Trading engine, order book |
| 20 | DeFi Dashboard | Template | $199–$499 | Staking, LP, yield UI |
| 21 | Fleet Management | Full Script | $199–$499 | GPS tracking, maintenance |
| 22 | Crowdfunding Platform | Full Script | $199–$499 | Campaigns, pledges, rewards |
| 23 | Crypto Trading Dashboard | Template | $99–$249 | CoinGecko API, charts |
| 24 | Web3 dApp Landing | Template | $79–$199 | Tokenomics, roadmap, GSAP |
| 25 | Blockchain Agency | Template | $79–$199 | Smart contracts, audits |
| 26 | Token Launch / ICO | Script+Template | $149–$399 | Presale, whitelist, KYC |
| 27 | Event Ticketing | Full Script | $99–$249 | QR codes, seating, Paystack |
| 28 | Multi-Vendor Marketplace | Full Script | $299–$799 | Essentially Web-Temify lite |
| 29 | DAO Governance | Template | $99–$249 | Proposals, voting, treasury |
| 30 | LMS Lite | Full Script | $149–$399 | Courses, quizzes, certs |
| 31 | Pharmacy Store | Template | $79–$179 | WooCommerce, prescriptions |
| 32 | Construction Company | Template | $59–$149 | Portfolio, estimates |
| 33 | Travel Agency | Template | $59–$149 | Tours, booking, packages |
| 34 | Ajo/Esusu Script (Tier 2) | Full Script | $149–$399 | Already in Tier 5 |

---

## PRODUCT UPLOAD CHECKLIST
(Complete for every product before listing)

```
Files to include in ZIP:
  ✅ Main template/script files (organised folders)
  ✅ README.md (setup instructions)
  ✅ CHANGELOG.md (version history)
  ✅ LICENSE.txt (Regular license terms)
  ✅ .env.example (if applicable)
  ✅ Screenshots folder (5-10 high quality)
  ✅ Demo video link (60 seconds minimum)

README.md must include:
  ✅ Product description
  ✅ Requirements (PHP version, Node version, etc.)
  ✅ Installation steps (numbered, clear)
  ✅ Configuration guide
  ✅ Payment gateway setup
  ✅ Deployment instructions
  ✅ Support contact
  ✅ Web-Temify credit: "Get more templates at web-temify.com"

Screenshots required:
  ✅ Homepage hero (1920x1080)
  ✅ Mobile view (375x812)
  ✅ Dark mode (if applicable)
  ✅ Admin panel (if applicable)
  ✅ Key feature pages (3-5 more)

Admin panel listing:
  ✅ Product name
  ✅ Short description (200 chars max)
  ✅ Full description (Markdown supported)
  ✅ Category selection
  ✅ Tech stack tags
  ✅ Price (Regular + Extended + White-Label)
  ✅ Demo URL (live demo link)
  ✅ Difficulty level
  ✅ Page count
  ✅ Dark mode: Yes/No
  ✅ RTL support: Yes/No
  ✅ Mobile responsive: Yes (always)
```

---

## MULTI-PLATFORM LISTING STRATEGY

After listing on Web-Temify, submit to:

| Platform | Submit Templates | Submit Scripts | Revenue Share |
|---|---|---|---|
| Web-Temify (own) | ✅ All | ✅ All | 100% |
| Gumroad | ✅ All | ✅ All | 90% |
| Payhip | ✅ All | ✅ All | 95% |
| LemonSqueezy | ✅ All | ✅ All | ~93% |
| ThemeForest | ✅ Templates only | ❌ | 50% (non-exclusive ONLY) |
| CodeCanyon | ❌ | ✅ Scripts only | 50% (non-exclusive ONLY) |
| Creative Market | ✅ Design-heavy | ❌ | 70% |
| Whop | ✅ Dev tools | ✅ Scripts | 97% |

**CRITICAL:** Always select NON-EXCLUSIVE on ThemeForest/CodeCanyon.
Never allow exclusive — it prevents selling everywhere else.
