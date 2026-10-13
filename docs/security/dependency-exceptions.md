# Dependency audit exception: braces@3.0.3

- Advisory: [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm), high severity.
- Dependency path: `eslint-config-next → @next/eslint-plugin-next → fast-glob → micromatch → braces`.
- Upstream status at review time (2026-10-13): advisory metadata reports no patched upstream release.
- Mitigation: Web-Temify applies a local patch that rejects brace nesting deeper than 100 before recursive expansion, and a security regression test covers both the attack shape and normal nested expansion.
- Scope: development-time lint tooling; the dependency is not included in the production dependency graph.
- Audit handling: the dependency audit runner may ignore only this advisory while the patch and regression test exist. Every other high/critical advisory remains blocking.
- Expiry: 2026-11-12. Before expiry, remove the exception when upstream ships a fix or re-review and renew it with explicit evidence. CI must fail if the patch, test, or expiry condition is missing.

This is a scanner exception for a locally patched package version, not permission to ship an unmitigated vulnerability.
