import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createClient: vi.fn(),
  rpc: vi.fn(),
  remove: vi.fn(),
  list: vi.fn(),
  storageFrom: vi.fn(),
}));

vi.mock("@supabase/supabase-js", () => ({
  createClient: mocks.createClient,
}));

import { POST } from "./route";

const token = "retention-worker-token-that-is-long-enough-123456";
const evidenceId = "81000000-0000-4000-8000-000000000080";
const storagePath = `${evidenceId}/${"a".repeat(64)}`;

function request(authorization = `Bearer ${token}`) {
  return new Request("https://web-temify.example/api/internal/settlements/evidence-retention", {
    method: "POST",
    headers: { authorization },
  });
}

describe("settlement evidence retention endpoint", () => {
  beforeEach(() => {
    vi.stubEnv("SETTLEMENT_EVIDENCE_RETENTION_TOKEN", token);
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://database.example");
    vi.stubEnv("SUPABASE_SECRET_KEY", "service-role-secret");
    mocks.createClient.mockReset();
    mocks.rpc.mockReset();
    mocks.remove.mockReset();
    mocks.list.mockReset();
    mocks.storageFrom.mockReset();
    mocks.storageFrom.mockReturnValue({ remove: mocks.remove, list: mocks.list });
    mocks.createClient.mockReturnValue({
      rpc: mocks.rpc,
      storage: { from: mocks.storageFrom },
    });
    mocks.remove.mockResolvedValue({ data: [], error: null });
    mocks.list.mockResolvedValue({ data: [], error: null });
    mocks.rpc.mockImplementation(async (name: string) => {
      if (name === "claim_expired_settlement_evidence") {
        return {
          data: [
            {
              evidence_id: evidenceId,
              storage_path: storagePath,
              source_sha256: "a".repeat(64),
              byte_size: 100,
            },
          ],
          error: null,
        };
      }
      return { data: "deleted", error: null };
    });
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.clearAllMocks();
  });

  it("rejects requests without the exact bearer token before creating a service client", async () => {
    const response = await POST(request("Bearer wrong-token"));

    expect(response.status).toBe(401);
    expect(mocks.createClient).not.toHaveBeenCalled();
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("fails closed when the retention token is missing or too short", async () => {
    vi.stubEnv("SETTLEMENT_EVIDENCE_RETENTION_TOKEN", "short");

    const response = await POST(request());

    expect(response.status).toBe(401);
    expect(mocks.createClient).not.toHaveBeenCalled();
  });

  it("fails closed when Supabase server credentials are unavailable", async () => {
    vi.stubEnv("SUPABASE_SECRET_KEY", "");

    const response = await POST(request());

    expect(response.status).toBe(503);
    expect(mocks.createClient).not.toHaveBeenCalled();
  });

  it("claims a bounded batch and records successful object deletion", async () => {
    const response = await POST(request());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      claimed: 1,
      deleted: 1,
      retryable: 0,
      maxBatchSize: 25,
    });
    expect(mocks.createClient).toHaveBeenCalledWith(
      "https://database.example",
      "service-role-secret",
      expect.any(Object),
    );
    expect(mocks.rpc).toHaveBeenNthCalledWith(
      1,
      "claim_expired_settlement_evidence",
      expect.objectContaining({ p_limit: 25 }),
    );
    expect(mocks.storageFrom).toHaveBeenCalledWith("settlement-evidence");
    expect(mocks.remove).toHaveBeenCalledWith([storagePath]);
    expect(mocks.rpc).toHaveBeenNthCalledWith(
      2,
      "finish_settlement_evidence_retention",
      expect.objectContaining({
        p_evidence_id: evidenceId,
        p_deleted: true,
        p_error_code: null,
      }),
    );
  });

  it("records a failed object removal for bounded retry without claiming success", async () => {
    mocks.remove.mockResolvedValue({
      data: null,
      error: { message: "storage unavailable" },
    });
    mocks.list.mockResolvedValue({
      data: [{ name: "a".repeat(64) }],
      error: null,
    });
    mocks.rpc.mockImplementation(async (name: string) => {
      if (name === "claim_expired_settlement_evidence") {
        return {
          data: [
            {
              evidence_id: evidenceId,
              storage_path: storagePath,
              source_sha256: "a".repeat(64),
              byte_size: 100,
            },
          ],
          error: null,
        };
      }
      return { data: "retryable", error: null };
    });

    const response = await POST(request());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      claimed: 1,
      deleted: 0,
      retryable: 1,
    });
    expect(mocks.rpc).toHaveBeenNthCalledWith(
      2,
      "finish_settlement_evidence_retention",
      expect.objectContaining({
        p_deleted: false,
        p_error_code: "storage_delete_failed",
      }),
    );
  });

  it("treats a missing object as a successful idempotent delete after a retry", async () => {
    mocks.remove.mockResolvedValue({
      data: null,
      error: { message: "object not found" },
    });
    mocks.list.mockResolvedValue({ data: [], error: null });

    const response = await POST(request());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      claimed: 1,
      deleted: 1,
      retryable: 0,
    });
    expect(mocks.rpc).toHaveBeenNthCalledWith(
      2,
      "finish_settlement_evidence_retention",
      expect.objectContaining({ p_deleted: true, p_error_code: null }),
    );
  });

  it("fails closed if the database cannot claim retention work", async () => {
    mocks.rpc.mockResolvedValue({
      data: null,
      error: { message: "database unavailable" },
    });

    const response = await POST(request());

    expect(response.status).toBe(503);
    expect(mocks.remove).not.toHaveBeenCalled();
  });

  it("rejects malformed claims before deleting any object", async () => {
    mocks.rpc.mockResolvedValue({
      data: [
        {
          evidence_id: evidenceId,
          storage_path: "../untrusted-object",
          source_sha256: "a".repeat(64),
          byte_size: 100,
        },
      ],
      error: null,
    });

    const response = await POST(request());

    expect(response.status).toBe(503);
    expect(mocks.remove).not.toHaveBeenCalled();
  });

  it("returns a retryable server failure if deletion finishes but persistence fails", async () => {
    mocks.rpc.mockImplementation(async (name: string) => {
      if (name === "claim_expired_settlement_evidence") {
        return {
          data: [
            {
              evidence_id: evidenceId,
              storage_path: storagePath,
              source_sha256: "a".repeat(64),
              byte_size: 100,
            },
          ],
          error: null,
        };
      }
      return { data: null, error: { message: "database unavailable" } };
    });

    const response = await POST(request());

    expect(response.status).toBe(503);
    expect(mocks.remove).toHaveBeenCalledWith([storagePath]);
  });
});
