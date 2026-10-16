import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createClient: vi.fn(),
  rpc: vi.fn(),
  getUserById: vi.fn(),
}));

vi.mock("@supabase/supabase-js", () => ({
  createClient: mocks.createClient,
}));

import { POST } from "./route";

const workerToken = "phase5f-worker-token-with-at-least-32-chars";
const job = {
  job_id: "a1000000-0000-4000-8000-000000000001",
  case_id: "a2000000-0000-4000-8000-000000000002",
  event_type: "created",
  case_status: "open",
  recipient_kind: "requester",
  recipient_user_id: "a3000000-0000-4000-8000-000000000003",
  attempts: 1,
};

function request(token = workerToken) {
  return new Request("https://web-temify.test/api/internal/support-notifications", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
  });
}

function configureWorker() {
  vi.stubEnv("SUPPORT_NOTIFICATION_WORKER_TOKEN", workerToken);
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://supabase.example.test");
  vi.stubEnv("SUPABASE_SECRET_KEY", "supabase-secret-test-value");
  vi.stubEnv("RESEND_API_KEY", "resend-test-api-key");
  vi.stubEnv("SUPPORT_FROM_EMAIL", "support@example.test");
  vi.stubEnv("SUPPORT_OPERATIONS_EMAIL", "operations@example.test");
  vi.stubEnv("NEXT_PUBLIC_SITE_URL", "https://web-temify.test");

  mocks.rpc.mockResolvedValueOnce({ data: [job], error: null });
  mocks.rpc.mockResolvedValueOnce({ data: "sent", error: null });
  mocks.getUserById.mockResolvedValue({
    data: { user: { email: "requester@example.test" } },
    error: null,
  });
  mocks.createClient.mockReturnValue({
    rpc: mocks.rpc,
    auth: { admin: { getUserById: mocks.getUserById } },
  });
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true }));
}

describe("Phase 5F support notification worker", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("rejects unauthorized callers before constructing the service client", async () => {
    const response = await POST(request("wrong-worker-token"));
    expect(response.status).toBe(401);
    expect(mocks.createClient).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("fails closed when production worker configuration is incomplete", async () => {
    vi.stubEnv("SUPPORT_NOTIFICATION_WORKER_TOKEN", workerToken);
    const response = await POST(request());
    expect(response.status).toBe(503);
    expect((await response.json()).error).toBe("support_notification_worker_not_configured");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("sends a privacy-minimal requester message and completes the owned lease", async () => {
    configureWorker();
    const response = await POST(request());
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      claimed: 1,
      sent: 1,
      retryable: 0,
      blocked: 0,
    });
    expect(mocks.rpc).toHaveBeenNthCalledWith(1, "claim_support_notification_jobs", {
      p_limit: 3,
      p_request_id: expect.any(String),
    });
    expect(mocks.rpc).toHaveBeenNthCalledWith(2, "finish_support_notification_job", {
      p_job_id: job.job_id,
      p_request_id: expect.any(String),
      p_sent: true,
      p_error_code: null,
    });
    const [url, options] = vi.mocked(fetch).mock.calls[0];
    expect(url).toBe("https://api.resend.com/emails");
    const payload = JSON.parse(String(options?.body));
    expect(payload.to).toEqual(["requester@example.test"]);
    expect(payload.text).toContain(job.case_id);
    expect(payload.text).not.toContain("private case description");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("records a provider timeout as retryable without exposing provider details", async () => {
    configureWorker();
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("private provider timeout detail")));
    mocks.rpc.mockReset();
    mocks.rpc.mockResolvedValueOnce({ data: [job], error: null });
    mocks.rpc.mockResolvedValueOnce({ data: "retryable", error: null });

    const response = await POST(request());
    expect(response.status).toBe(503);
    const body = await response.json();
    expect(body).toMatchObject({ claimed: 1, retryable: 1, sent: 0 });
    expect(JSON.stringify(body)).not.toContain("private provider timeout detail");
    expect(mocks.rpc).toHaveBeenNthCalledWith(2, "finish_support_notification_job", expect.objectContaining({
      p_sent: false,
      p_error_code: "email_provider_unavailable",
    }));
  });

  it("does not report success when the provider accepted mail but lease completion failed", async () => {
    configureWorker();
    mocks.rpc.mockReset();
    mocks.rpc.mockResolvedValueOnce({ data: [job], error: null });
    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: { code: "55000", message: "private lease detail" },
    });

    const response = await POST(request());
    expect(response.status).toBe(503);
    const body = await response.json();
    expect(body.error).toBe("support_notification_completion_failed");
    expect(JSON.stringify(body)).not.toContain("private lease detail");
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(1);
  });

  it("rejects malformed claimed jobs without sending mail", async () => {
    configureWorker();
    mocks.rpc.mockReset();
    mocks.rpc.mockResolvedValueOnce({
      data: [{ ...job, attempts: 6 }],
      error: null,
    });

    const response = await POST(request());
    expect(response.status).toBe(503);
    expect((await response.json()).error).toBe("support_notification_claim_invalid");
    expect(vi.mocked(fetch)).not.toHaveBeenCalled();
    expect(mocks.rpc).toHaveBeenCalledTimes(1);
  });
});
