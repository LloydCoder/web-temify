import { describe, expect, it, vi } from "vitest";
import { scanSettlementEvidence } from "./settlement-evidence-scanner";

const digest = "a".repeat(64);
const bytes = Buffer.from("private settlement evidence");
const token = "t".repeat(48);

function scannerResponse(
  verdict: "clean" | "infected" | "error" = "clean",
  sha256 = digest,
) {
  return new Response(
    JSON.stringify({
      verdict,
      scannerName: "clamav",
      scannerVersion: "ClamAV 1.5.4",
      sha256,
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

type TestEnvironment = {
  NODE_ENV?: string;
  CLAMAV_SCANNER_URL?: string;
  CLAMAV_SCANNER_TOKEN?: string;
};

function configuredEnv(
  overrides: Partial<TestEnvironment> = {},
): TestEnvironment {
  return {
    NODE_ENV: "test",
    CLAMAV_SCANNER_URL: "http://127.0.0.1:8088/v1/scan",
    CLAMAV_SCANNER_TOKEN: token,
    ...overrides,
  };
}

describe("scanSettlementEvidence", () => {
  it("leaves evidence pending when the scanner is not configured", async () => {
    const fetcher = vi.fn<typeof fetch>();

    await expect(
      scanSettlementEvidence(
        bytes,
        digest,
        { NODE_ENV: "test" },
        fetcher,
      ),
    ).resolves.toEqual({ status: "not_configured" });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("fails closed for an invalid or non-HTTPS remote endpoint", async () => {
    const fetcher = vi.fn<typeof fetch>();

    await expect(
      scanSettlementEvidence(
        bytes,
        digest,
        configuredEnv({
          CLAMAV_SCANNER_URL: "http://scanner.internal/v1/scan",
        }),
        fetcher,
      ),
    ).resolves.toEqual({ status: "unavailable" });
    expect(fetcher).not.toHaveBeenCalled();
  });

  it(
    "fails closed in production when the scanner URL is HTTP even on loopback",
    async () => {
      const fetcher = vi.fn<typeof fetch>();

      await expect(
        scanSettlementEvidence(
          bytes,
          digest,
          configuredEnv({ NODE_ENV: "production" }),
          fetcher,
        ),
      ).resolves.toEqual({ status: "unavailable" });
      expect(fetcher).not.toHaveBeenCalled();
    },
  );

  it(
    "sends the exact bytes and digest to the private scanner and accepts a clean result",
    async () => {
      const fetcher = vi.fn<typeof fetch>().mockResolvedValue(scannerResponse());

      await expect(
        scanSettlementEvidence(bytes, digest, configuredEnv(), fetcher),
      ).resolves.toEqual({
        status: "clean",
        scannerName: "clamav",
        scannerVersion: "ClamAV 1.5.4",
        sha256: digest,
      });

      const [url, init] = fetcher.mock.calls[0]!;
      expect(String(url)).toBe("http://127.0.0.1:8088/v1/scan");
      expect(init?.method).toBe("POST");
      expect(new Headers(init?.headers).get("authorization")).toBe(
        `Bearer ${token}`,
      );
      expect(new Headers(init?.headers).get("x-evidence-sha256")).toBe(digest);
      expect(Buffer.from(init?.body as Uint8Array)).toEqual(bytes);
      expect(init?.cache).toBe("no-store");
      expect(init?.signal).toBeInstanceOf(AbortSignal);
    },
  );

  it.each(["infected", "error"] as const)(
    "preserves the scanner's %s verdict rather than treating it as clean",
    async (verdict) => {
      const fetcher = vi
        .fn<typeof fetch>()
        .mockResolvedValue(scannerResponse(verdict));

      await expect(
        scanSettlementEvidence(bytes, digest, configuredEnv(), fetcher),
      ).resolves.toMatchObject({ status: verdict, sha256: digest });
    },
  );

  it("rejects a scanner response for a different digest", async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(
      scannerResponse("clean", "b".repeat(64)),
    );

    await expect(
      scanSettlementEvidence(bytes, digest, configuredEnv(), fetcher),
    ).resolves.toEqual({ status: "unavailable" });
  });

  it("rejects malformed verdict metadata", async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(
      new Response(
        JSON.stringify({
          verdict: "probably_clean",
          scannerName: "clamav",
          scannerVersion: "1.5.4",
          sha256: digest,
        }),
        { status: 200 },
      ),
    );

    await expect(
      scanSettlementEvidence(bytes, digest, configuredEnv(), fetcher),
    ).resolves.toEqual({ status: "unavailable" });
  });

  it(
    "does not claim a scan when the private scanner times out or is unreachable",
    async () => {
      const fetcher = vi
        .fn<typeof fetch>()
        .mockRejectedValue(new Error("offline"));

      await expect(
        scanSettlementEvidence(bytes, digest, configuredEnv(), fetcher),
      ).resolves.toEqual({ status: "unavailable" });
    },
  );
});
