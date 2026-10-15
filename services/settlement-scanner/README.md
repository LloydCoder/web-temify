# Private settlement-evidence malware scanner

This service scans settlement-evidence bytes with ClamAV before Web-Temify
can bind the evidence to an import or use it for sandbox fee posting. It is
separate from the Next.js app so the antivirus engine and signature database
can be updated independently.

## Trust and data flow

1. The authenticated admin upload route stores the original bytes in the private
   Supabase Storage bucket and records immutable metadata with the
   server-computed SHA-256.
2. If CLAMAV_SCANNER_URL and CLAMAV_SCANNER_TOKEN are configured, the Next.js
   route posts the exact in-memory bytes and expected digest to this service
   over HTTPS.
3. The gateway independently recomputes SHA-256, rejects digest mismatches, and
   streams the bytes to ClamAV using its INSTREAM protocol.
4. Only a digest-matched clean result is accepted as clean. Infected and error
   results are recorded as such; timeouts, missing configuration, invalid
   responses, or unavailable scanners leave the evidence pending.
5. Web-Temify records the scanner verdict through the service-role-only
   record_settlement_evidence_scan_result RPC. Database guards require the
   latest verdict to be clean for the exact evidence digest and require the
   signature database update timestamp to be within 48 hours at both linkage
   and journal-posting time.

A scan verdict is not proof of provider origin or report authenticity. The
provider-ingress gate remains separate.

## Run locally

Requirements: Docker Compose v2 and a root .env file. Generate a token with:

    openssl rand -hex 32

Use the same random value for SCANNER_BEARER_TOKEN (scanner service) and
CLAMAV_SCANNER_TOKEN (Web-Temify app). For local development, add these to the
root .env file:

    SCANNER_BEARER_TOKEN=replace-with-a-random-secret-at-least-32-characters
    CLAMAV_SCANNER_URL=http://127.0.0.1:8088/v1/scan
    CLAMAV_SCANNER_TOKEN=replace-with-the-same-random-secret

Start the scanner stack from the repository root:

    docker compose -f services/settlement-scanner/compose.yaml up -d --build

The gateway binds to 127.0.0.1:8088 by default. The ClamAV daemon's TCP port is
not published to the host; it is reachable only from the private Docker backend
network. Check status with:

    docker compose -f services/settlement-scanner/compose.yaml ps
    curl --fail http://127.0.0.1:8088/healthz
    curl --fail http://127.0.0.1:8088/readyz

/healthz checks gateway liveness. /readyz succeeds only when the gateway can
query the ClamAV daemon. Neither endpoint exposes the scanner version.

## Production deployment requirements

- Deploy the gateway behind an HTTPS endpoint and set CLAMAV_SCANNER_URL to
  https://your-private-scanner.example/v1/scan. The app client rejects plain
  HTTP in production.
- Configure the same high-entropy bearer token in the gateway and Web-Temify
  server environment. Rotate it by coordinated secret update and service
  restart; never put it in a NEXT*PUBLIC*\* variable.
- Pin CLAMAV_IMAGE to a reviewed, platform-appropriate image digest for
  production instead of relying on a floating tag. The compose file defaults
  to the official ClamAV 1.5.4-debian13-slim image tag for local
  reproducibility.
- Restrict gateway ingress to the application or trusted private ingress,
  enforce TLS, and monitor scanner readiness, timeouts, infected verdicts,
  signature-database freshness, and capacity.
- Do not expose ClamAV's TCP port outside the private Docker network. ClamAV
  documents that its TCP protocol is not encrypted or authenticated; see the
  official ClamD protocol guide:
  https://docs.clamav.net/manual/Usage/ClamdProtocol.html
- The gateway caps input at 5 MiB, rejects unauthenticated calls before reading
  the body, compares the supplied digest with a fresh SHA-256, and limits
  concurrent scans. It never logs evidence contents or malware signature names.
- If the scanner is unavailable or misconfigured, evidence uploads may be
  stored but remain pending and cannot be linked or posted. Do not bypass the
  database gate or mark files clean manually.
- A detected file remains in the private bucket for controlled investigation;
  automated quarantine review, retention/deletion enforcement, incident
  escalation, and operational runbooks are separate launch gates.

## API contract

POST /v1/scan

- Requires Authorization: Bearer <SCANNER_BEARER_TOKEN>.
- Requires Content-Type: application/octet-stream and X-Evidence-SHA256 with
  64 lowercase hex characters.
- Body is the raw file bytes, capped at 5 MiB.
- A successful HTTP 200 response contains verdict, scannerName, scannerVersion,
  the signature database update time parsed from ClamAV VERSION, and the
  gateway-computed sha256. Missing or invalid timestamps fail closed. Stale
  signature definitions may be retained for audit but cannot authorize linkage
  or journal posting.
- A digest mismatch is HTTP 422. Invalid requests are rejected. Scanner outages
  return HTTP 503 without a clean verdict.
- The caller must compare the returned digest with its own expected digest
  before persisting the verdict.

The service does not authenticate payment providers, reconcile reports, post
financial entries, or move money. Live provider processing and payouts remain
disabled.
