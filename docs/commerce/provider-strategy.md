# Web-Temify payment, merchant-of-record, and treasury provider strategy

**Status:** Strategy reconciliation only. This document does not enable live payments, settlement, refunds, seller payouts, or money movement.

## Decision record

The previously accepted commercial architecture separates four distinct responsibilities:

- **Polar:** Primary global merchant-of-record (MoR) route for eligible digital-product sales, subject to its seller onboarding and payout model. It is not a generic card processor or the source of truth for Web-Temify's internal orders, entitlements, or accounting ledger.
- **Paystack:** Candidate for Nigeria/local payments and a specifically approved direct-payment marketplace flow. A browser redirect or client callback is not proof of payment.
- **Sellra:** Unverified secondary MoR/African-rails candidate. Do not treat it as production-approved until official documentation, contracting, supported jurisdictions, settlement reports, refunds, disputes, fees, payout capabilities, and operational support are independently verified.
- **Grey:** Treasury/FX and business-account workflow where eligible. It is not a checkout processor, MoR, or substitute for payment-provider reconciliation.

This role split is the canonical strategy to validate against current onboarding evidence. It supersedes older exploratory lists that included Flutterwave, Wise, Payoneer, Stripe, Paddle, Lemon Squeezy, Dodo, or other providers as possible candidates. Those historical mentions are not approval to integrate them.

## Current repository implementation boundary

The database and application currently support a deliberately restricted sandbox workflow. The financial journal recognizes provider names such as `paystack`, `flutterwave`, `stripe`, and `sandbox` in parts of its schema, but that enum/check constraint is not a decision record and does not prove that any live adapter exists. Polar, Sellra, and Grey are not implemented as live adapters in the current checkout flow. No provider is enabled for production.

Do not force all four roles into a single `payment_provider` enum. Model the distinct concepts separately when implementation begins:

- **Checkout/MoR route:** who contracts with the buyer, handles consumer-facing tax obligations, and is the merchant of record.
- **Payment processor and event source:** who authoritatively reports the payment, refund, dispute, and settlement state.
- **Marketplace proceeds / seller settlement:** whether the provider contract explicitly permits third-party sellers, split settlement, reserves, and the proposed seller jurisdictions.
- **Treasury/FX rail:** movement or conversion of funds after legally and operationally valid settlement; never retroactively establishes that a buyer paid.

A single sale must have one explicitly identified commercial route and a consistent order, tax, refund, and accounting treatment. Do not combine MoR revenue and direct marketplace proceeds in one transaction model unless the contractual and ledger semantics are reviewed.

## Evidence to collect before provider activation

For each provider and legal entity, record dated official evidence and the result of the actual business onboarding process:

1. Web-Temify legal-entity eligibility and required KYC/KYB.
2. Seller onboarding and supported seller residence/business countries, including Nigeria where relevant.
3. Buyer countries, supported transaction currencies, settlement currencies, FX treatment, fees, reserves, payout timing, minimums, and failure handling.
4. Contractual permission for a multi-vendor digital marketplace and each intended category; whether the provider is MoR or Web-Temify remains merchant of record.
5. Signed webhook/event authenticity, event identity, retry semantics, refund state transitions, chargebacks/disputes, settlement report access, and reconciliation keys.
6. Tax/VAT responsibility, invoice/receipt duties, prohibited/restricted products, consumer terms, refunds, data processing, and record-retention requirements.
7. Operational support, escalation path, test/sandbox availability, production credentials, and a tested rollback/disable procedure.

A public support-country page is necessary but not sufficient: it does not establish account approval, product-category approval, marketplace contractual permission, or seller eligibility.

## Evidence-based findings as of 2026-10-14

- Polar's official supported-countries page says it acts as MoR for global sales subject to its stated restrictions and uses Stripe Connect Express for payouts to eligible sellers, including Nigeria. This supports evaluating Polar for the intended MoR role; it does not prove Web-Temify has an approved Polar account or that every marketplace vertical/product is eligible: https://docs.polar.sh/merchant-of-record/supported-countries
- Paystack's official documentation describes split payments through subaccounts, a settlements API, refunds, and dispute workflows. These are relevant technical capabilities to evaluate for a direct marketplace flow, but account-specific approval, country/currency coverage, contract terms, reconciliation fixtures, and production onboarding still need verification:
  - https://paystack.com/docs/payments/multi-split-payments/
  - https://paystack.com/docs/api/settlement/
  - https://paystack.com/docs/payments/refunds/
  - https://paystack.com/docs/payments/manage-disputes/
- No Sellra capability is treated as verified by this record. Do not integrate or advertise Sellra features until primary documentation and account/contract evidence have been reviewed.
- Grey is reserved for treasury/FX workflows only. It must not issue payment-success evidence or mutate marketplace order/payment states.

## Implementation gates

- Keep `PAYMENT_PROVIDER=disabled` as the production default and retain the current sandbox-only adapter until the selected route has passed the evidence checklist.
- Implement each provider as a versioned adapter behind a stable internal contract. Validate webhook signatures using the provider's official raw-body protocol, then process idempotently against immutable internal order/payment references.
- Keep provider settlement imports distinct from payment-success webhooks. Settlement is a later accounting event and must reconcile to verified payment/refund journal batches and statement totals.
- Keep all money movement, refunds, payout initiation, reserves, and manual adjustments fail-closed until the corresponding provider-specific and database state machines pass adversarial tests.
- Record the chosen first-launch route in a separate approved implementation ADR after the account, contract, jurisdiction, category, and operational evidence is available.

## Exit decision

**Current decision: not production-enabled.** The strategy is reconciled, but provider onboarding evidence and the provider-specific implementation gate remain open. This document must not be used as proof that payments, seller payouts, settlement reconciliation, tax calculation, or escrow are live.
