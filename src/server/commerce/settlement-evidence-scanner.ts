export type SettlementEvidenceScanVerdict = "clean" | "infected" | "error";

export type SettlementEvidenceScanResult =
  | { status: "not_configured" | "unavailable" }
  | {
      status: SettlementEvidenceScanVerdict;
      scannerName: string;
      scannerVersion: string;
      sha256: string;
    };

type ScannerEnvironment = {
  CLAMAV_SCANNER_URL?: string;
  CLAMAV_SCANNER_TOKEN?: string;
  NODE_ENV?: string;
};

const DIGEST_PATTERN = /^[a-f0-9]{64}$/;
const MAX_SCANNER_VERSION_LENGTH = 80;
const SCANNER_TIMEOUT_MS = 25_000;

function isLoopback(hostname: string) {
  return (
    hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "[::1]" ||
    hostname === "::1"
  );
}

function scannerEndpoint(
  env: ScannerEnvironment,
): { url: URL; token: string } | null {
  const endpoint = env.CLAMAV_SCANNER_URL?.trim();
  const token = env.CLAMAV_SCANNER_TOKEN?.trim();
  if (!endpoint || !token || token.length < 32) return null;

  let url: URL;
  try {
    url = new URL(endpoint);
  } catch {
    return null;
  }

  const localDevelopmentHttp =
    env.NODE_ENV !== "production" &&
    url.protocol === "http:" &&
    isLoopback(url.hostname);

  if (
    (url.protocol !== "https:" && !localDevelopmentHttp) ||
    url.username ||
    url.password ||
    url.hash
  ) {
    return null;
  }

  return { url, token };
}

function parseScannerResponse(
  payload: unknown,
  expectedSha256: string,
): SettlementEvidenceScanResult | null {
  if (!payload || typeof payload !== "object") return null;
  const value = payload as Record<string, unknown>;
  const verdict = value.verdict;
  const scannerName = value.scannerName;
  const scannerVersion = value.scannerVersion;
  const sha256 = value.sha256;

  if (
    (verdict !== "clean" && verdict !== "infected" && verdict !== "error") ||
    typeof scannerName !== "string" ||
    scannerName.trim().length < 1 ||
    scannerName.trim().length > 120 ||
    typeof scannerVersion !== "string" ||
    scannerVersion.trim().length < 1 ||
    scannerVersion.trim().length > MAX_SCANNER_VERSION_LENGTH ||
    typeof sha256 !== "string" ||
    !DIGEST_PATTERN.test(sha256) ||
    sha256 !== expectedSha256
  ) {
    return null;
  }

  return {
    status: verdict,
    scannerName: scannerName.trim(),
    scannerVersion: scannerVersion.trim(),
    sha256,
  };
}

/**
 * Calls a private scanner service. A missing or unhealthy scanner is explicitly
 * non-clean: callers must leave the evidence pending and never infer a clean
 * scan.
 */
export async function scanSettlementEvidence(
  bytes: Uint8Array,
  expectedSha256: string,
  env: ScannerEnvironment = process.env,
  fetcher: typeof fetch = fetch,
): Promise<SettlementEvidenceScanResult> {
  if (!DIGEST_PATTERN.test(expectedSha256)) {
    return { status: "unavailable" };
  }

  const endpoint = scannerEndpoint(env);
  if (!endpoint) {
    return env.CLAMAV_SCANNER_URL || env.CLAMAV_SCANNER_TOKEN
      ? { status: "unavailable" }
      : { status: "not_configured" };
  }

  try {
    const response = await fetcher(endpoint.url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${endpoint.token}`,
        "Content-Type": "application/octet-stream",
        "X-Evidence-SHA256": expectedSha256,
      },
      body: Buffer.from(bytes),
      cache: "no-store",
      signal: AbortSignal.timeout(SCANNER_TIMEOUT_MS),
    });

    if (!response.ok) return { status: "unavailable" };

    const payload: unknown = await response.json();
    return (
      parseScannerResponse(payload, expectedSha256) ?? {
        status: "unavailable",
      }
    );
  } catch {
    return { status: "unavailable" };
  }
}
