import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createClient: vi.fn(),
  rpc: vi.fn(),
}));

vi.mock("@supabase/supabase-js", () => ({
  createClient: mocks.createClient,
}));

import { POST } from "./route";

const workerToken = "phase5j-dispute-alert-worker-token-32chars";
const job = {
  job_id: "a1000000-0000-4000-8000-000000000291",
  dispute_id: "a2000000-0000-4000-8000-000000000292",
  provider: "sandbox",
  provider_dispute_id: "sandbox-dispute-0291",
  dispute_status: "needs_evidence",
  alert_kind: "due_soon",
  evidence_due_at: "2026-10-18T00:00:00.000Z",
  attempts: 1,
};

function request(token = workerToken) {
  return new Request(
    "https://web-temify.test/api/internal/payment-dispute-alerts",
    {
    method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    },
  );
}

function configureWorker() {
  vi.stubEnv("PAYMENT_DISPUTE_ALERT_WORKER_TOKEN", workerToken);
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://supabase.example.test");
  vi.stubEnv("SUPABASE_SECRET_KEY", "supabase-secret-test-value");
  vi.stubEnv("RESEND_API_KEY", "resend-test-api-key");
  vi.stubEnv("SUPPORT_FROM_EMAIL", "support@example.test");
  vi.stubEnv("DISPUTE_OPERATIONS_EMAIL", "operations@example.test");
  vi.stubEnv("NEXT_PUBLIC_SITE_URL", "https://web-temify.test");

  mocks.rpc.mockResolvedValueOnce({ data: 1, error: null });
  mocks.rpc.mockResolvedValueOnce({ data: [job], error: null });
  mocks.rpc.mockResolvedValueOnce({ data: "sent", error: null });
  mocks.createClient.mockReturnValue({ rpc: mocks.rpc });
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true }));
}

describe("Phase 5J payment dispute deadline alert worker", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it(
    "rejects unauthorized callers before creating a privileged client",
    async () => {
    const response = await POST(request("wrong-token"));
    expect(response.status).toBe(401);
    expect(mocks.createClient).not.toHaveBeenCalled();
      expect(mocks.rpc).not.toHaveBeenCalled();
    },
  );

  it("fails closed when the worker is missing configuration", async () => {
    vi.stubEnv("PAYMENT_DISPUTE_ALERT_WORKER_TOKEN", workerToken);
    const response = await POST(request());
    expect(response.status).toBe(503);
    expect(mocks.createClient).not.toHaveBeenCalled();
  });

  it(
    "sends only a minimal operations alert and records successful delivery",
    async () => {
    configureWorker();

    const response = await POST(request());
    const body = await response.json();
    expect(response.status).toBe(200);
      expect(body).toMatchObject({
        claimed: 1,
        sent: 1,
        retryable: 0,
        blocked: 0,
        scanned: 1,
      });
      expect(mocks.rpc).toHaveBeenNthCalledWith(
        1,
        "enqueue_payment_dispute_deadline_alerts",
        {
          p_now: expect.any(String),
        },
      );
      expect(mocks.rpc).toHaveBeenNthCalledWith(
        2,
        "claim_payment_dispute_alert_jobs",
        {
      p_limit: 3,
          p_request_id: expect.any(String),
        },
      );
      expect(mocks.rpc).toHaveBeenNthCalledWith(
        3,
        "finish_payment_dispute_alert_job",
        {
      p_job_id: job.job_id,
      p_request_id: expect.any(String),
      p_success: true,
          p_error_code: null,
        },
      );

      const fetchMock = vi.mocked(fetch);
      expect(fetchMock).toHaveBeenCalledTimes(1);
      const email = JSON.parse(String(fetchMock.mock.calls[0][1]?.body));
      expect(email.to).toEqual(["operations@example.test"]);
      expect(email.text).toContain(job.provider_dispute_id);
      expect(email.text).not.toContain("customer@example.test");
      expect(email.text).not.toContain("payment card");
    },
  );

  it(
    "records provider failure for bounded retry instead of marking sent",
    async () => {
    configureWorker();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false }));

    mocks.rpc.mockReset();
    mocks.rpc.mockResolvedValueOnce({ data: 1, error: null });
    mocks.rpc.mockResolvedValueOnce({ data: [job], error: null });
    mocks.rpc.mockResolvedValueOnce({ data: "retryable", error: null });

    const response = await POST(request());
    const body = await response.json();
    expect(response.status).toBe(200);
      expect(body).toMatchObject({
        claimed: 1,
        sent: 0,
        retryable: 1,
        blocked: 0,
      });
      expect(mocks.rpc).toHaveBeenLastCalledWith(
        "finish_payment_dispute_alert_job",
        {
      p_job_id: job.job_id,
      p_request_id: expect.any(String),
      p_success: false,
          p_error_code: "email_provider_rejected",
        },
      );
    },
  );

  it("does not report success when durable job completion fails", async () => {
    configureWorker();
    mocks.rpc.mockReset();
    mocks.rpc.mockResolvedValueOnce({ data: 1, error: null });
    mocks.rpc.mockResolvedValueOnce({ data: [job], error: null });
    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: new Error("database unavailable"),
    });

    const response = await POST(request());
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "alert_completion_failed" });
  });
});
