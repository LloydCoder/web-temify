# Legacy documentation reconciliation register

**Status:** In progress. The full audit of uploaded legacy files begins only after the user confirms upload completion.

| Area | Known issue | Resolution |
|---|---|---|
| Framework | Canonical overview says Next.js App Router; older Laravel/PHP prompts remain | Mark old prompts historical/non-canonical |
| Feature counts | Different totals and built counts appear | One canonical inventory with stable IDs, phase, owner, evidence, status |
| Data schema | 85-table model and two migration directories | Accept ADR-0003 before schema generation; validate model |
| Payment gateways | Providers span launch and later phases | Gate each by eligibility, sandbox evidence, idempotency, legal/security review |
| Product catalogue | Counts/duplicates and unsupported claims | Deduplicate, stable IDs, verify rights, review regulated categories |
| Homepage | Placeholder links/inert controls/unverified metrics | Keep visual direction; remove unsupported proof and implement interactions |
| Tinlance | Integration needs runtime/permission verification | Disabled until contract, controls, tests, and evidence exist |

## After upload completion
Inventory supplied files and versions; identify duplicates and conflicts; trace requirements to domain, routes, data, tests and evidence; produce canonical decisions and seek approval for material choices.