import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getAdminContext: vi.fn(),
  readBoundedRequestBytes: vi.fn(),
  scanSettlementEvidence: vi.fn(),
  disputeLookup: vi.fn(),
  auditInsert: vi.fn(),
  storageUpload: vi.fn(),
  storageRemove: vi.fn(),
  rpc: vi.fn(),
}));

vi.mock("@/server/admin/authorization", () => ({
  getAdminContext: mocks.getAdminContext,
}));
vi.mock("@/server/commerce/read-bounded-bytes", () => ({
  readBoundedRequestBytes: mocks.readBoundedRequestBytes,
}));
vi.mock("@/server/commerce/settlement-evidence-scanner", () => ({
  scanSettlementEvidence: mocks.scanSettlementEvidence,
}));

import { POST } from "./route";

const disputeId = "a2000000-0000-4000-8000-000000000292";
const userId = "a3000000-0000-4000-8000-000000000293";
const evidenceBytes = Buffer.from("%PDF-1.7\nprivate dispute evidence fixture");

function request(
  overrides: {
    origin?: string;
    contentType?: string;
    filename?: string;
  } = {},
) {
  const url = "https://web-temify.test/api/admin/payment-disputes";
  return new Request(`${url}/${disputeId}/evidence`, {
    method: "POST",
    headers: {
      origin: overrides.origin ?? "https://web-temify.test",
      "content-type": overrides.contentType ?? "application/pdf",
      "x-evidence-filename": overrides.filename ?? "chargeback.pdf",
    },
    body: evidenceBytes,
  });
}

function configureAdmin(status = "needs_evidence") {
  const admin = {
    from: vi.fn((table: string) => {
      if (table === "payment_disputes") {
        return {
          select: vi.fn(() => ({
            eq: vi.fn(() => ({ maybeSingle: mocks.disputeLookup })),
          })),
        };
      }
      return { insert: mocks.auditInsert };
    }),
    storage: {
      from: vi.fn(() => ({
        upload: mocks.storageUpload,
        remove: mocks.storageRemove,
      })),
    },
    rpc: mocks.rpc,
  };

  mocks.getAdminContext.mockResolvedValue({ userId, admin });
  mocks.readBoundedRequestBytes.mockResolvedValue({
    ok: true,
    bytes: evidenceBytes,
  });
  mocks.disputeLookup.mockResolvedValue({
    data: { id: disputeId, status },
    error: null,
  });
  mocks.auditInsert.mockResolvedValue({ error: null });
  mocks.storageUpload.mockResolvedValue({ error: null });
  mocks.storageRemove.mockResolvedValue({ error: null });
  mocks.rpc.mockResolvedValue({ error: null });
  mocks.scanSettlementEvidence.mockImplementation(
    async (_bytes, sha256) => ({
      status: "clean",
      scannerName: "clamav",
      scannerVersion: "1.5.4",
      signatureUpdatedAt: "2026-10-17T00:00:00.000Z",
      sha256,
    }),
  );
}

describe("Phase 5K dispute evidence upload", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    configureAdmin();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("denies callers without an audited admin context", async () => {
    mocks.getAdminContext.mockResolvedValue(null);

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });

    expect(response.status).toBe(404);
    expect(mocks.readBoundedRequestBytes).not.toHaveBeenCalled();
    expect(mocks.storageUpload).not.toHaveBeenCalled();
  });

  it("requires a same-origin request before reading the upload", async () => {
    const response = await POST(request({ origin: "https://attacker.test" }), {
      params: Promise.resolve({ disputeId }),
    });

    expect(response.status).toBe(403);
    expect(mocks.readBoundedRequestBytes).not.toHaveBeenCalled();
    expect(mocks.storageUpload).not.toHaveBeenCalled();
  });

  it("rejects invalid identifiers and unsupported content types", async () => {
    const badIdResponse = await POST(request(), {
      params: Promise.resolve({ disputeId: "not-a-uuid" }),
    });
    expect(badIdResponse.status).toBe(400);

    const mimeResponse = await POST(request({ contentType: "text/html" }), {
      params: Promise.resolve({ disputeId }),
    });
    expect(mimeResponse.status).toBe(415);
    expect(mocks.storageUpload).not.toHaveBeenCalled();
  });

  it("rejects evidence for a terminal dispute", async () => {
    configureAdmin("closed");

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });

    expect(response.status).toBe(409);
    expect(mocks.storageUpload).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("uploads private evidence and records a digest-matched clean scan", async () => {
    const response = await POST(request({ filename: "../../chargeback.pdf" }), {
      params: Promise.resolve({ disputeId }),
    });
    const body = await response.json();

    expect(response.status).toBe(201);
    expect(body).toMatchObject({
      disputeId,
      scanStatus: "clean",
      providerSubmission: "not_submitted",
      sourceAuthenticity: "not_verified",
      filename: "_.._chargeback.pdf",
    });
    expect(body.sha256).toMatch(/^[a-f0-9]{64}$/);
    expect(mocks.storageUpload).toHaveBeenCalledWith(
      expect.stringMatching(
        new RegExp(`^${disputeId}/[0-9a-f-]{36}/${body.sha256}$`),
      ),
      evidenceBytes,
      expect.objectContaining({ upsert: false, cacheControl: "0" }),
    );
    expect(mocks.rpc).toHaveBeenNthCalledWith(
      1,
      "record_payment_dispute_evidence",
      expect.objectContaining({
        p_dispute_id: disputeId,
        p_source_sha256: body.sha256,
        p_uploaded_by: userId,
      }),
    );
    expect(mocks.rpc).toHaveBeenNthCalledWith(
      2,
      "record_payment_dispute_evidence_scan_result",
      expect.objectContaining({
        p_evidence_id: body.id,
        p_source_sha256: body.sha256,
        p_verdict: "clean",
        p_signature_updated_at: "2026-10-17T00:00:00.000Z",
      }),
    );
  });

  it("keeps evidence pending if the scanner is unavailable", async () => {
    mocks.scanSettlementEvidence.mockResolvedValue({ status: "unavailable" });

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });
    const body = await response.json();

    expect(response.status).toBe(202);
    expect(body.scanStatus).toBe("pending");
    expect(body.providerSubmission).toBe("not_submitted");
    expect(mocks.rpc).toHaveBeenCalledTimes(1);
  });

  it("rejects a scanner digest mismatch", async () => {
    mocks.scanSettlementEvidence.mockResolvedValue({
      status: "clean",
      scannerName: "clamav",
      scannerVersion: "1.5.4",
      signatureUpdatedAt: "2026-10-17T00:00:00.000Z",
      sha256: "0".repeat(64),
    });

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });

    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      error: "evidence_scan_digest_mismatch",
      scanStatus: "pending",
    });
    expect(mocks.rpc).toHaveBeenCalledTimes(1);
  });

  it("rejects infected evidence without enabling submission", async () => {
    mocks.scanSettlementEvidence.mockImplementation(
      async (_bytes, sha256) => ({
        status: "infected",
        scannerName: "clamav",
        scannerVersion: "1.5.4",
        signatureUpdatedAt: "2026-10-17T00:00:00.000Z",
        sha256,
      }),
    );

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });
    const body = await response.json();

    expect(response.status).toBe(422);
    expect(body.scanStatus).toBe("infected");
    expect(body.providerSubmission).toBe("not_submitted");
  });

  it("removes the object if immutable metadata recording fails", async () => {
    mocks.rpc.mockResolvedValueOnce({ error: { code: "XX000" } });

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });

    expect(response.status).toBe(503);
    expect(mocks.storageRemove).toHaveBeenCalledWith([
      expect.stringMatching(
        new RegExp(`^${disputeId}/[0-9a-f-]{36}/[a-f0-9]{64}$`),
      ),
    ]);
  });

  it("fails closed if scan attestation persistence fails", async () => {
    mocks.rpc
      .mockResolvedValueOnce({ error: null })
      .mockResolvedValueOnce({ error: { code: "XX000" } });

    const response = await POST(request(), {
      params: Promise.resolve({ disputeId }),
    });
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(body.scanStatus).toBe("pending");
  });
});
