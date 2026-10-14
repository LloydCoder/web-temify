import { createHash } from "node:crypto";
import { createServer as createTcpServer } from "node:net";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  constantTimeTokenEquals,
  createScannerServer,
  scanWithClamd,
} from "./server.mjs";

const token = "s".repeat(48);
const bytes = Buffer.from("settlement evidence bytes");
const sha256 = createHash("sha256").update(bytes).digest("hex");
const openServers = [];

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  openServers.push(server);
  return server.address().port;
}

async function closeOpenServers() {
  await Promise.all(
    openServers.splice(0).map(
      (server) =>
        new Promise((resolve) => {
          server.close(() => resolve());
          server.closeAllConnections?.();
        }),
    ),
  );
}

function startGateway(options = {}) {
  return createScannerServer({
    token,
    clamdHost: "127.0.0.1",
    clamdPort: 3310,
    ...options,
  });
}

function authHeaders(digest = sha256) {
  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/octet-stream",
    "X-Evidence-SHA256": digest,
  };
}

function fakeClamd(scanReply = "stream: OK") {
  const streamed = [];
  const server = createTcpServer((socket) => {
    let buffer = Buffer.alloc(0);
    let command = null;
    let fileBytes = Buffer.alloc(0);

    socket.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      if (command === null) {
        const terminator = buffer.indexOf(0);
        if (terminator < 0) return;
        command = buffer.subarray(0, terminator).toString("utf8");
        buffer = buffer.subarray(terminator + 1);
        if (command === "zVERSION") {
          socket.end(Buffer.from("ClamAV 1.5.4/test\0"));
          return;
        }
        if (command !== "zINSTREAM") {
          socket.end(Buffer.from("unknown command\0"));
          return;
        }
      }

      if (command === "zINSTREAM") {
        while (buffer.length >= 4) {
          const chunkLength = buffer.readUInt32BE(0);
          if (buffer.length < 4 + chunkLength) return;
          buffer = buffer.subarray(4);
          if (chunkLength === 0) {
            streamed.push(fileBytes);
            socket.end(Buffer.from(`${scanReply}\0`));
            return;
          }
          fileBytes = Buffer.concat([
            fileBytes,
            buffer.subarray(0, chunkLength),
          ]);
          buffer = buffer.subarray(chunkLength);
        }
      }
    });
  });
  return { server, streamed };
}

afterEach(async () => {
  await closeOpenServers();
});

describe("settlement scanner service", () => {
  it(
    "compares bearer tokens without length-dependent timingSafeEqual errors",
    () => {
    expect(constantTimeTokenEquals(token, token)).toBe(true);
    expect(constantTimeTokenEquals(token, "wrong")).toBe(false);
    expect(constantTimeTokenEquals(token, undefined)).toBe(false);
    },
  );

  it(
    "rejects unauthenticated requests before reading or scanning a payload",
    async () => {
      const scan = vi.fn(async () => ({
        verdict: "clean",
        scannerName: "clamav",
        scannerVersion: "ClamAV test",
      }));
      const port = await listen(startGateway({ scan }));
      const response = await fetch(`http://127.0.0.1:${port}/v1/scan`, {
        method: "POST",
        headers: {
          "Content-Type": "application/octet-stream",
          "X-Evidence-SHA256": sha256,
        },
        body: bytes,
      });

      expect(response.status).toBe(401);
      expect(scan).not.toHaveBeenCalled();
    },
  );

  it("rejects unsupported content types and digest mismatches", async () => {
    const scan = vi.fn(async () => ({
      verdict: "clean",
      scannerName: "clamav",
      scannerVersion: "ClamAV test",
    }));
    const port = await listen(startGateway({ scan }));
    const baseUrl = `http://127.0.0.1:${port}/v1/scan`;

    const contentTypeResponse = await fetch(baseUrl, {
      method: "POST",
      headers: { ...authHeaders(), "Content-Type": "text/plain" },
      body: bytes,
    });
    expect(contentTypeResponse.status).toBe(415);

    const digestResponse = await fetch(baseUrl, {
      method: "POST",
      headers: authHeaders("b".repeat(64)),
      body: bytes,
    });
    expect(digestResponse.status).toBe(422);
    expect(scan).not.toHaveBeenCalled();
  });

  it(
    "returns a clean verdict only after the scanner accepts the exact digest",
    async () => {
      const scan = vi.fn(async () => ({
        verdict: "clean",
        scannerName: "clamav",
        scannerVersion: "ClamAV 1.5.4",
      }));
      const port = await listen(startGateway({ scan }));
      const response = await fetch(`http://127.0.0.1:${port}/v1/scan`, {
        method: "POST",
        headers: authHeaders(),
        body: bytes,
      });

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toEqual({
        verdict: "clean",
        scannerName: "clamav",
        scannerVersion: "ClamAV 1.5.4",
        sha256,
      });
      expect(scan).toHaveBeenCalledOnce();
      expect(scan.mock.calls[0][0]).toEqual(bytes);
    },
  );

  it.each(["infected", "error"])(
    "preserves a scanner %s verdict and never upgrades it to clean",
    async (verdict) => {
      const scan = vi.fn(async () => ({
        verdict,
        scannerName: "clamav",
        scannerVersion: "ClamAV 1.5.4",
      }));
      const port = await listen(startGateway({ scan }));
      const response = await fetch(`http://127.0.0.1:${port}/v1/scan`, {
        method: "POST",
        headers: authHeaders(),
        body: bytes,
      });

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toMatchObject({ verdict });
    },
  );

  it("fails closed when the scanner engine is unavailable", async () => {
    const port = await listen(
      startGateway({
        scan: async () => {
          throw new Error("scanner offline");
        },
      }),
    );
    const response = await fetch(`http://127.0.0.1:${port}/v1/scan`, {
      method: "POST",
      headers: authHeaders(),
      body: bytes,
    });

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      error: "scanner_unavailable",
    });
  });

  it("rejects payloads above the configured byte limit", async () => {
    const port = await listen(
      startGateway({
        maxBytes: 4,
        scan: async () => ({
          verdict: "clean",
          scannerName: "clamav",
          scannerVersion: "ClamAV test",
        }),
      }),
    );
    const oversized = Buffer.from("too many bytes");
    const response = await fetch(`http://127.0.0.1:${port}/v1/scan`, {
      method: "POST",
      headers: authHeaders(
        createHash("sha256").update(oversized).digest("hex"),
      ),
      body: oversized,
    });

    expect(response.status).toBe(413);
    await expect(response.json()).resolves.toEqual({
      error: "scan_payload_too_large",
    });
  });

  it("uses ClamAV INSTREAM framing and recognizes a clean result", async () => {
    const fake = fakeClamd("stream: OK");
    const port = await listen(fake.server);

    await expect(
      scanWithClamd(bytes, { host: "127.0.0.1", port, timeoutMs: 2000 }),
    ).resolves.toEqual({
      verdict: "clean",
      scannerName: "clamav",
      scannerVersion: "ClamAV 1.5.4/test",
    });
    expect(fake.streamed).toHaveLength(1);
    expect(fake.streamed[0]).toEqual(bytes);
  });

  it("recognizes an infected ClamAV response", async () => {
    const fake = fakeClamd("stream: Eicar-Test-Signature FOUND");
    const port = await listen(fake.server);

    await expect(
      scanWithClamd(bytes, { host: "127.0.0.1", port, timeoutMs: 2000 }),
    ).resolves.toMatchObject({
      verdict: "infected",
      scannerName: "clamav",
    });
  });
});
