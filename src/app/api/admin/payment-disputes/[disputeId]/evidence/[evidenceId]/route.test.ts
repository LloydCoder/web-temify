import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getAdminContext: vi.fn(),
  rpc: vi.fn(),
  createSignedUrl: vi.fn(),
}));

vi.mock("@/server/admin/authorization", () => ({
  getAdminContext: mocks.getAdminContext,
}));

import { GET } from "./route";

const disputeId = "a2000000-0000-4000-8000-000000000292";
const evidenceId = "a4000000-0000-4000-8000-000000000294";
const userId = "a3000000-0000-4000-8000-000000000293";
const digest = "a".repeat(64);

function request() {
  return new Request(
    `https://web-temify.test/api/admin/payment-disputes/${disputeId}/evidence/${evidenceId}`,
  );
}

function configureAccess() {
  const admin = {
    rpc: mocks.rpc,
    storage: {
      from: vi.fn(() => ({ createSignedUrl: mocks.createSignedUrl })),
    },
  };
  mocks.getAdminContext.mockResolvedValue({ userId, admin });
  mocks.rpc.mockResolvedValue({
    data: [
      {
        storage_path: `${disputeId}/${evidenceId}/${digest}`,
        source_sha256: digest,
        mime_type: "application/pdf",
        byte_size: 1024,
        original_filename: "chargeback.pdf",
        scan_id: "a5000000-0000-4000-8000-000000000295",
        scanner_name: "clamav",
        scanner_version: "1.5.4",
        signature_updated_at: "2026-10-17T00:00:00.000Z",
        scanned_at: "2026-10-17T05:00:00.000Z",
      },
    ],
    error: null,
  });
  mocks.createSignedUrl.mockResolvedValue({
    data: { signedUrl: "https://storage.example.test/signed/private-evidence" },
    error: null,
  });
}

describe("Phase 5K audited dispute evidence access", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    configureAccess();
  });

  it("denies callers without an audited admin context", async () => {
    mocks.getAdminContext.mockResolvedValue(null);

    const response = await GET(request(), {
      params: Promise.resolve({ disputeId, evidenceId }),
    });

    expect(response.status).toBe(404);
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.createSignedUrl).not.toHaveBeenCalled();
  });

  it("issues a 60-second URL only after the audited clean-scan RPC succeeds", async () => {
    const response = await GET(request(), {
      params: Promise.resolve({ disputeId, evidenceId }),
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      disputeId,
      evidenceId,
      signedUrl: "https://storage.example.test/signed/private-evidence",
      expiresInSeconds: 60,
      sha256: digest,
      scan: { verdict: "clean", scannerName: "clamav" },
    });
    expect(mocks.rpc).toHaveBeenCalledWith(
      "get_payment_dispute_evidence_for_admin",
      {
        p_dispute_id: disputeId,
        p_evidence_id: evidenceId,
        p_actor_id: userId,
        p_request_id: expect.any(String),
      },
    );
    expect(mocks.createSignedUrl).toHaveBeenCalledWith(
      `${disputeId}/${evidenceId}/${digest}`,
      60,
      { download: true },
    );
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("does not issue a URL when the evidence is missing or the scan is not clean/current", async () => {
    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: { code: "55000" },
    });

    const response = await GET(request(), {
      params: Promise.resolve({ disputeId, evidenceId }),
    });

    expect(response.status).toBe(409);
    expect(mocks.createSignedUrl).not.toHaveBeenCalled();
  });

  it("fails closed when returned metadata does not bind the path to the digest", async () => {
    mocks.rpc.mockResolvedValueOnce({
      data: [
        {
          storage_path: `${disputeId}/${evidenceId}/${"b".repeat(64)}`,
          source_sha256: digest,
          mime_type: "application/pdf",
          byte_size: 1024,
          original_filename: "chargeback.pdf",
          scan_id: "a5000000-0000-4000-8000-000000000295",
          scanner_name: "clamav",
          scanner_version: "1.5.4",
          signature_updated_at: "2026-10-17T00:00:00.000Z",
          scanned_at: "2026-10-17T05:00:00.000Z",
        },
      ],
      error: null,
    });

    const response = await GET(request(), {
      params: Promise.resolve({ disputeId, evidenceId }),
    });

    expect(response.status).toBe(503);
    expect(mocks.createSignedUrl).not.toHaveBeenCalled();
  });

  it("does not return a URL when private storage cannot sign it", async () => {
    mocks.createSignedUrl.mockResolvedValueOnce({
      data: null,
      error: new Error("storage unavailable"),
    });

    const response = await GET(request(), {
      params: Promise.resolve({ disputeId, evidenceId }),
    });

    expect(response.status).toBe(503);
  });
});
