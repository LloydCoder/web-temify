# Domain boundaries and ownership

| Context | Owns | Must not own |
|---|---|---|
| Identity/access | profile mapping, roles, permissions, session integration | payment truth, provider credentials |
| Catalogue | products, versions, categories, asset metadata, publication state | orders, settlement |
| Cart/checkout | customer intent, price snapshot, checkout session | final payment truth |
| Orders | purchase intent, lifecycle, item snapshots | processor-side transaction status |
| Payments/ledger | verified events, provider references, fees, ledger, reconciliation | client payment claims |
| Entitlements/licenses | purchase grants, terms, revocation, validation | arbitrary download URLs |
| Secure delivery | artifact storage, scan status, access checks, signed URL issuance | product rights or payment decisions |
| Vendor operations | rights declarations, review, payout eligibility | unreviewed automatic payouts |
| Moderation/admin | review decisions, appeals, audited admin actions | silent privilege escalation |
| Notifications | templates, delivery attempts, preferences | authority to mutate commerce state |
| AI | run metadata, budgets, routing, safety results | authoritative legal/financial decisions |
| Tinlance integration | task requests, signed events, mapping, approvals | direct mutation of marketplace records |

## Transaction invariants
1. A customer redirect never marks an order paid.
2. Provider events are validated against signature, provider, event type, amount, currency, merchant account, and internal order reference.
3. Webhooks are at-least-once; processing must be idempotent and concurrency-safe.
4. Entitlements are granted only after internal payment/order policy confirms payment.
5. Refunds/chargebacks create auditable compensating ledger entries; history is not destructively rewritten.
6. Downloads require identity, active entitlement, license checks, and published artifact before a short-lived URL is issued.
7. Vendor payouts require reconciliation, risk checks, and eligibility.
8. Admin/agent actions record actor, scope, reason, correlation ID, and outcome.
9. Async jobs need retry limits, dead-letter visibility, and safe replay.
10. Regulated/high-risk products require separate policy and release gates.

## Tinlance Agent System
Tinlance is the governed automation/engineering layer, not Web-Temify's database owner. Requests such as artifact validation, draft listing preparation, approved sandbox builds, and internal support summaries use versioned contracts. Publishing, money changes, access changes, customer contact, or production deployment require explicit policy and approval. Start read-only and sandboxed.