import { createHash, timingSafeEqual } from "node:crypto";
import { createServer } from "node:http";
import { createConnection } from "node:net";
import { pathToFileURL } from "node:url";

export const MAX_SCAN_BYTES = 5 * 1024 * 1024;
const MAX_RESPONSE_BYTES = 4096;
const STREAM_CHUNK_BYTES = 64 * 1024;
const DEFAULT_TIMEOUT_MS = 20_000;
const DEFAULT_MAX_CONCURRENT_SCANS = 4;
const DIGEST_PATTERN = /^[a-f0-9]{64}$/;

function parseBoundedInteger(value, fallback, minimum, maximum) {
  if (value === undefined || value.trim() === "") return fallback;
  if (!/^\d+$/.test(value.trim())) return null;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed >= minimum && parsed <= maximum
    ? parsed
    : null;
}

export function constantTimeTokenEquals(expected, supplied) {
  if (typeof expected !== "string" || typeof supplied !== "string") {
    return false;
  }
  const expectedDigest = createHash("sha256").update(expected).digest();
  const suppliedDigest = createHash("sha256").update(supplied).digest();
  return timingSafeEqual(expectedDigest, suppliedDigest);
}

function clamdRequest({ host, port, command, bytes, timeoutMs }) {
  return new Promise((resolve, reject) => {
    const socket = createConnection({ host, port });
    let response = Buffer.alloc(0);
    let settled = false;
    const timer = setTimeout(() => {
      finish(new Error("clamd request timed out"));
    }, timeoutMs);

    function finish(error, value) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      socket.destroy();
      if (error) reject(error);
      else resolve(value);
    }

    socket.setTimeout(timeoutMs, () =>
      finish(new Error("clamd socket timed out")),
    );
    socket.on("error", (error) => finish(error));
    socket.on("end", () => {
      if (response.length > 0) {
        finish(null, response.toString("utf8").replace(/\0.*$/s, "").trim());
      } else {
        finish(new Error("clamd closed without a response"));
      }
    });
    socket.on("data", (chunk) => {
      response = Buffer.concat([response, chunk]);
      if (response.length > MAX_RESPONSE_BYTES) {
        finish(new Error("clamd response exceeded the allowed size"));
        return;
      }
      const terminator = response.indexOf(0);
      if (terminator >= 0) {
        finish(null, response.subarray(0, terminator).toString("utf8").trim());
      }
    });
    socket.on("connect", () => {
      try {
        socket.write(Buffer.from(`z${command}\0`, "utf8"));
        if (bytes !== undefined) {
          for (
            let offset = 0;
            offset < bytes.byteLength;
            offset += STREAM_CHUNK_BYTES
          ) {
            const chunk = Buffer.from(
              bytes.subarray(
                offset,
                Math.min(offset + STREAM_CHUNK_BYTES, bytes.byteLength),
              ),
            );
            const length = Buffer.allocUnsafe(4);
            length.writeUInt32BE(chunk.byteLength, 0);
            socket.write(length);
            socket.write(chunk);
          }
          socket.write(Buffer.alloc(4));
        }
      } catch (error) {
        finish(
          error instanceof Error ? error : new Error("clamd request failed"),
        );
      }
    });
  });
}

function parseSignatureUpdatedAt(versionResponse) {
  const match = versionResponse.match(
    /\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4}\b/,
  );
  if (!match) {
    throw new Error(
      "clamd version response omitted signature database timestamp",
    );
  }
  const parsed = new Date(match[0]);
  if (!Number.isFinite(parsed.getTime()) || parsed.getTime() > Date.now() + 5 * 60_000) {
    throw new Error("clamd signature database timestamp is invalid");
  }
  return parsed.toISOString();
}

export async function scanWithClamd(
  bytes,
  { host = "clamav", port = 3310, timeoutMs = DEFAULT_TIMEOUT_MS } = {},
) {
  const versionResponse = await clamdRequest({
    host,
    port,
    command: "VERSION",
    timeoutMs,
  });
  if (!versionResponse.startsWith("ClamAV ")) {
    throw new Error("clamd returned an invalid version response");
  }
  const scannerVersion = versionResponse.slice(0, 80);
  const signatureUpdatedAt = parseSignatureUpdatedAt(versionResponse);
  const scanResponse = await clamdRequest({
    host,
    port,
    command: "INSTREAM",
    bytes: Buffer.from(bytes),
    timeoutMs,
  });

  if (/:\s*OK$/i.test(scanResponse)) {
    return {
      verdict: "clean",
      scannerName: "clamav",
      scannerVersion,
      signatureUpdatedAt,
    };
  }
  if (/\bFOUND$/i.test(scanResponse)) {
    return {
      verdict: "infected",
      scannerName: "clamav",
      scannerVersion,
      signatureUpdatedAt,
    };
  }
  if (
    /\bERROR$/i.test(scanResponse) ||
    /size limit exceeded/i.test(scanResponse)
  ) {
    return {
      verdict: "error",
      scannerName: "clamav",
      scannerVersion,
      signatureUpdatedAt,
    };
  }
  throw new Error("clamd returned an unrecognized scan response");
}

function sendJson(response, statusCode, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  response.writeHead(statusCode, {
    "Cache-Control": "no-store",
    "Content-Length": String(body.byteLength),
    "Content-Type": "application/json; charset=utf-8",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(body);
}

async function readBoundedBody(request, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalBytes = 0;
    let tooLarge = false;
    request.on("data", (chunk) => {
      totalBytes += chunk.byteLength;
      if (totalBytes > maxBytes) {
        tooLarge = true;
        chunks.length = 0;
        return;
      }
      if (!tooLarge) chunks.push(Buffer.from(chunk));
    });
    request.on("end", () => {
      resolve(tooLarge ? null : Buffer.concat(chunks, totalBytes));
    });
    request.on("error", reject);
    request.on("aborted", () => reject(new Error("request aborted")));
  });
}

function parseBearerToken(header) {
  if (typeof header !== "string" || !header.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length);
  return token.length > 0 ? token : null;
}

export function createScannerServer({
  token,
  clamdHost = "clamav",
  clamdPort = 3310,
  maxBytes = MAX_SCAN_BYTES,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  maxConcurrentScans = DEFAULT_MAX_CONCURRENT_SCANS,
  scan = scanWithClamd,
} = {}) {
  if (typeof token !== "string" || token.length < 32) {
    throw new Error("SCANNER_BEARER_TOKEN must contain at least 32 characters");
  }
  if (!Number.isInteger(clamdPort) || clamdPort < 1 || clamdPort > 65535) {
    throw new Error("CLAMD_PORT must be a valid TCP port");
  }
  if (
    !Number.isInteger(maxBytes) ||
    maxBytes < 1 ||
    maxBytes > MAX_SCAN_BYTES
  ) {
    throw new Error("MAX_SCAN_BYTES must be between 1 byte and 5 MiB");
  }
  if (
    !Number.isInteger(maxConcurrentScans) ||
    maxConcurrentScans < 1 ||
    maxConcurrentScans > 16
  ) {
    throw new Error("MAX_CONCURRENT_SCANS must be between 1 and 16");
  }

  let activeScans = 0;
  const server = createServer(async (request, response) => {
    if (request.method === "GET" && request.url === "/healthz") {
      sendJson(response, 200, { ok: true });
      return;
    }
    if (request.method === "GET" && request.url === "/readyz") {
      try {
        const version = await clamdRequest({
          host: clamdHost,
          port: clamdPort,
          command: "VERSION",
          timeoutMs,
        });
        sendJson(response, version.startsWith("ClamAV ") ? 200 : 503, {
          ok: version.startsWith("ClamAV "),
        });
      } catch {
        sendJson(response, 503, { ok: false });
      }
      return;
    }
    if (request.method !== "POST" || request.url !== "/v1/scan") {
      request.resume();
      sendJson(response, 404, { error: "not_found" });
      return;
    }

    const suppliedToken = parseBearerToken(request.headers.authorization);
    if (!suppliedToken || !constantTimeTokenEquals(token, suppliedToken)) {
      request.resume();
      sendJson(response, 401, { error: "unauthorized" });
      return;
    }

    if (
      request.headers["content-type"]?.split(";")[0]?.trim().toLowerCase() !==
      "application/octet-stream"
    ) {
      request.resume();
      sendJson(response, 415, { error: "content_type_required" });
      return;
    }

    const expectedSha256 = request.headers["x-evidence-sha256"];
    if (
      typeof expectedSha256 !== "string" ||
      !DIGEST_PATTERN.test(expectedSha256)
    ) {
      request.resume();
      sendJson(response, 400, { error: "invalid_evidence_digest" });
      return;
    }

    const contentLength = request.headers["content-length"];
    if (
      typeof contentLength === "string" &&
      /^\d+$/.test(contentLength) &&
      Number(contentLength) > maxBytes
    ) {
      request.resume();
      sendJson(response, 413, { error: "scan_payload_too_large" });
      return;
    }

    if (activeScans >= maxConcurrentScans) {
      request.resume();
      sendJson(response, 429, { error: "scanner_busy" });
      return;
    }

    activeScans += 1;
    try {
      const bytes = await readBoundedBody(request, maxBytes);
      if (!bytes) {
        sendJson(response, 413, { error: "scan_payload_too_large" });
        return;
      }
      if (bytes.byteLength === 0) {
        sendJson(response, 400, { error: "empty_scan_payload" });
        return;
      }

      const sha256 = createHash("sha256").update(bytes).digest("hex");
      if (sha256 !== expectedSha256) {
        sendJson(response, 422, { error: "evidence_digest_mismatch" });
        return;
      }

      let result;
      try {
        result = await scan(bytes, {
          host: clamdHost,
          port: clamdPort,
          timeoutMs,
        });
      } catch {
        sendJson(response, 503, { error: "scanner_unavailable" });
        return;
      }

      if (
        !result ||
        !["clean", "infected", "error"].includes(result.verdict) ||
        result.scannerName !== "clamav" ||
        typeof result.scannerVersion !== "string" ||
        result.scannerVersion.length < 1 ||
        typeof result.signatureUpdatedAt !== "string" ||
        !Number.isFinite(Date.parse(result.signatureUpdatedAt)) ||
        Date.parse(result.signatureUpdatedAt) > Date.now() + 5 * 60_000
      ) {
        sendJson(response, 503, { error: "invalid_scanner_result" });
        return;
      }

      sendJson(response, 200, {
        verdict: result.verdict,
        scannerName: "clamav",
        scannerVersion: result.scannerVersion.slice(0, 80),
        signatureUpdatedAt: new Date(result.signatureUpdatedAt).toISOString(),
        sha256,
      });
    } catch {
      if (!response.headersSent) {
        sendJson(response, 400, { error: "invalid_request" });
      }
    } finally {
      activeScans -= 1;
    }
  });

  server.requestTimeout = timeoutMs + 5_000;
  server.headersTimeout = Math.min(10_000, timeoutMs + 5_000);
  return server;
}

function requiredPort(value, fallback, label) {
  const parsed = parseBoundedInteger(value, fallback, 1, 65535);
  if (parsed === null) throw new Error(`${label} must be a valid TCP port`);
  return parsed;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const token = process.env.SCANNER_BEARER_TOKEN;
  const clamdHost = process.env.CLAMD_HOST || "clamav";
  const clamdPort = requiredPort(process.env.CLAMD_PORT, 3310, "CLAMD_PORT");
  const port = requiredPort(process.env.SCANNER_PORT, 8080, "SCANNER_PORT");
  const maxBytes = parseBoundedInteger(
    process.env.MAX_SCAN_BYTES,
    MAX_SCAN_BYTES,
    1,
    MAX_SCAN_BYTES,
  );
  const timeoutMs = parseBoundedInteger(
    process.env.SCANNER_TIMEOUT_MS,
    DEFAULT_TIMEOUT_MS,
    1000,
    60_000,
  );
  const maxConcurrentScans = parseBoundedInteger(
    process.env.MAX_CONCURRENT_SCANS,
    DEFAULT_MAX_CONCURRENT_SCANS,
    1,
    16,
  );

  if (maxBytes === null || timeoutMs === null || maxConcurrentScans === null) {
    throw new Error("scanner limits are invalid");
  }

  const server = createScannerServer({
    token,
    clamdHost,
    clamdPort,
    maxBytes,
    timeoutMs,
    maxConcurrentScans,
  });
  server.listen(port, "0.0.0.0", () => {
    process.stdout.write(`settlement scanner API listening on port ${port}\n`);
  });
}
