# Server-only adapters

Server-only infrastructure belongs here: authentication/session verification, database access, private storage, provider adapters, email, and Tinlance integration. Never import secret-bearing modules into client components. Add runtime schemas, timeout/retry policy, structured redacted logs, and contract tests with each adapter.