# Initial threat model

## Assets
Customer accounts/data; orders/payment references; financial ledger/vendor balances; licenses/entitlements; paid artifacts; admin credentials; provider secrets; AI prompts/results; Tinlance tokens; audit evidence.

## Trust boundaries
Browser/application; application/PostgreSQL; application/payment/email/AI providers; artifact upload/scanning/preview; Web-Temify/Tinlance; CI/repository/deployment secrets.

| Threat | Impact | Minimum controls |
|---|---|---|
| Broken object authorization | Cross-user exposure | Server authorization, RLS, negative tests |
| Forged/replayed webhook | False payment or duplicate grant | Raw-body signature, idempotency, state machine |
| Payment race | Duplicate grants or bad ledger | Unique event keys, transactions, concurrency tests |
| Malicious artifact | Platform compromise | Quarantine, scanning, isolated preview/build |
| Signed URL leakage | Unauthorized distribution | Short expiry, scoped objects, no URL logging |
| Admin/session compromise | Money/permission abuse | Least privilege, MFA/step-up, audit, recovery |
| Prompt injection/unsafe AI | Data leakage or action | Untrusted output, tool allowlists, human approval |
| Agent token overreach | Cross-domain writes | Scoped capability, tenant binding, policy gateway, kill switch |
| Secret committed | Account/financial loss | Secret scanning and rotation playbook |
| Supply-chain compromise | Build/runtime compromise | Lockfile, review, CI isolation, dependency updates |
| Forged product rights/publication | IP claims, unsafe or unauthorized releases | Separate attestation/reviewer identities, column-scoped creator writes, RLS, release digest gate, negative tests |\n| False marketing claims | Trust/legal exposure | Evidence-backed metrics/testimonials |
| Regulated product risk | Legal/customer harm | Product category and jurisdiction review |

## Open questions
Data residency/jurisdictions; role/tenant model; artifact scanning and sandbox; provider eligibility, tax/refunds/disputes/payouts; retention/deletion; incident response ownership; legal review of financial, health, crypto, and identity products.