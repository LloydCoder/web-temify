import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getAdminContext: vi.fn(),
  rpc: vi.fn(),
  from: vi.fn(),
  queryResult: vi.fn(),
  query: {
    select: vi.fn(),
    order: vi.fn(),
    limit: vi.fn(),
    in: vi.fn(),
    then: vi.fn(),
  },
}));

vi.mock("@/server/admin/authorization", () => ({
  getAdminContext: mocks.getAdminContext,
}));

import { GET, POST } from "./admin/financial-controls/route";
import { POST as review } from "./admin/financial-controls/[requestId]/review/route";

const origin = "https://web-temify.test";
const adminId = "a1000000-0000-4000-8000-000000000001";
const sellerId = "a2000000-0000-4000-8000-000000000002";
const requestId = "a3000000-0000-4000-8000-000000000003";
const holdId = "a4000000-0000-4000-8000-000000000004";

function request(path: string, body: unknown, headers: Record<string, string> = {}) {
  return new Request(new URL(path, origin), {
    method: "POST",
    headers: {
      Origin: origin,
      "Content-Type": "application/json",
      ...headers,
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

const createBody = {
  requestType: "manual_adjustment",
  sellerId,
  amountMinor: "2500",
  currency: "USD",
  evidenceSha256: "a".repeat(64),
  reason: "Manual adjustment requires independent financial review.",
  idempotencyKey: "phase5g-route-test-key-0001",
};

describe("Phase 5G financial control API", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.rpc.mockResolvedValue({ data: requestId, error: null });
    mocks.query.select.mockReturnValue(mocks.query);
    mocks.query.order.mockReturnValue(mocks.query);
    mocks.query.limit.mockReturnValue(mocks.query);
    mocks.query.in.mockReturnValue(mocks.query);
    mocks.queryResult.mockResolvedValue({ data: [], error: null });
    mocks.query.then.mockImplementation((resolve: (value: unknown) => unknown) =>
      mocks.queryResult().then(resolve),
    );
    mocks.from.mockReturnValue(mocks.query);
    mocks.getAdminContext.mockResolvedValue({
      userId: adminId,
      admin: { rpc: mocks.rpc, from: mocks.from },
    });
  });

  it("denies unauthorised queue and create access before privileged queries", async () => {
    mocks.getAdminContext.mockResolvedValueOnce(null);
    const queue = await GET(new Request(new URL("/api/admin/financial-controls", origin)));
    expect(queue.status).toBe(404);
    expect(mocks.from).not.toHaveBeenCalled();

    mocks.getAdminContext.mockResolvedValueOnce(null);
    const created = await POST(request("/api/admin/financial-controls", createBody));
    expect(created.status).toBe(404);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("returns a bounded, no-store queue and supports exact status filters", async () => {
    const response = await GET(new Request(
      new URL("/api/admin/financial-controls?status=requested&status=under_review", origin),
    ));
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(mocks.getAdminContext).toHaveBeenCalledWith("financial_control_queue");
    expect(mocks.from).toHaveBeenCalledWith("financial_control_requests");
    expect(mocks.query.select).toHaveBeenCalledWith(
      "id,request_type,status,seller_id,order_id,target_hold_id,amount_minor,currency,reason,requested_by,approved_at,created_at,updated_at",
    );
    expect(mocks.query.limit).toHaveBeenCalledWith(50);
    expect(mocks.query.in).toHaveBeenCalledWith("status", ["requested", "under_review"]);
  });

  it.each([
    "/api/admin/financial-controls?unexpected=true",
    "/api/admin/financial-controls?status=unknown",
    "/api/admin/financial-controls?status=requested&status=requested",
  ])("rejects invalid queue filters: %s", async (url) => {
    const response = await GET(new Request(new URL(url, origin)));
    expect(response.status).toBe(400);
  });

  it("fails closed when queue data cannot be read", async () => {
    mocks.queryResult.mockResolvedValueOnce({
      data: null,
      error: { message: "private database detail" },
    });
    const response = await GET(new Request(new URL("/api/admin/financial-controls", origin)));
    expect(response.status).toBe(503);
    expect(JSON.stringify(await response.json())).not.toContain("private database detail");
  });

  it("requires same-origin JSON and a bounded strict request schema", async () => {
    const crossOrigin = await POST(request("/api/admin/financial-controls", createBody, {
      Origin: "https://attacker.test",
    }));
    expect(crossOrigin.status).toBe(403);

    const wrongType = await POST(request("/api/admin/financial-controls", createBody, {
      "Content-Type": "text/plain",
    }));
    expect(wrongType.status).toBe(415);

    const extraField = await POST(request("/api/admin/financial-controls", {
      ...createBody,
      requestedBy: sellerId,
    }));
    expect(extraField.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("binds maker identity to the authenticated admin and uses a generated trace id", async () => {
    const response = await POST(request("/api/admin/financial-controls", createBody));
    expect(response.status).toBe(201);
    expect(mocks.getAdminContext).toHaveBeenCalledWith("financial_control_create");
    expect(mocks.rpc).toHaveBeenCalledWith("create_financial_control_request", expect.objectContaining({
      p_actor_id: adminId,
      p_request_type: "manual_adjustment",
      p_seller_id: sellerId,
      p_amount_minor: "2500",
      p_idempotency_key: createBody.idempotencyKey,
      p_request_id: expect.any(String),
    }));
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("requires a target hold only for release requests", async () => {
    const missing = await POST(request("/api/admin/financial-controls", {
      ...createBody,
      requestType: "payout_hold_release",
    }));
    expect(missing.status).toBe(400);

    const extra = await POST(request("/api/admin/financial-controls", {
      ...createBody,
      targetHoldId: holdId,
    }));
    expect(extra.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it.each([
    ["42501", 403, "forbidden"],
    ["22023", 400, "invalid_financial_control_request"],
    ["23505", 409, "financial_control_conflict"],
    ["P0002", 404, "financial_control_target_not_found"],
    ["XX000", 503, "financial_control_unavailable"],
  ])("maps create RPC error %s without exposing database details", async (code, status, error) => {
    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: { code, message: "private database detail" },
    });
    const response = await POST(request("/api/admin/financial-controls", createBody));
    expect(response.status).toBe(status);
    const body = await response.json();
    expect(body.error).toBe(error);
    expect(JSON.stringify(body)).not.toContain("private database detail");
  });

  it("validates review requests and binds reviewer identity to the authenticated admin", async () => {
    const invalid = await review(request(
      `/api/admin/financial-controls/${requestId}/review`,
      { decision: "force_approve", note: "This must not be accepted." },
    ), { params: Promise.resolve({ requestId }) });
    expect(invalid.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();

    mocks.rpc.mockResolvedValueOnce({ data: "under_review", error: null });
    const response = await review(request(
      `/api/admin/financial-controls/${requestId}/review`,
      { decision: "approve", note: "Independent review evidence recorded." },
    ), { params: Promise.resolve({ requestId }) });
    expect(response.status).toBe(200);
    expect(mocks.getAdminContext).toHaveBeenCalledWith("financial_control_review");
    expect(mocks.rpc).toHaveBeenCalledWith("review_financial_control_request", expect.objectContaining({
      p_request_id: requestId,
      p_actor_id: adminId,
      p_decision: "approve",
      p_note: "Independent review evidence recorded.",
      p_request_trace_id: expect.any(String),
    }));
  });

  it("rejects malformed review IDs and cross-origin review mutations", async () => {
    const malformed = await review(request(
      "/api/admin/financial-controls/not-a-uuid/review",
      { decision: "reject", note: "Reject due to insufficient evidence." },
    ), { params: Promise.resolve({ requestId: "not-a-uuid" }) });
    expect(malformed.status).toBe(400);

    const crossOrigin = await review(request(
      `/api/admin/financial-controls/${requestId}/review`,
      { decision: "reject", note: "Reject due to insufficient evidence." },
      { Origin: "https://attacker.test" },
    ), { params: Promise.resolve({ requestId }) });
    expect(crossOrigin.status).toBe(403);
  });

  it.each([
    ["42501", 403, "financial_control_review_forbidden"],
    ["P0002", 404, "financial_control_request_not_found"],
    ["22023", 409, "financial_control_request_not_reviewable"],
    ["23505", 409, "financial_control_duplicate_decision"],
    ["XX000", 503, "financial_control_review_unavailable"],
  ])("maps review RPC error %s safely", async (code, status, error) => {
    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: { code, message: "private database detail" },
    });
    const response = await review(request(
      `/api/admin/financial-controls/${requestId}/review`,
      { decision: "reject", note: "Reject due to insufficient evidence." },
    ), { params: Promise.resolve({ requestId }) });
    expect(response.status).toBe(status);
    const body = await response.json();
    expect(body.error).toBe(error);
    expect(JSON.stringify(body)).not.toContain("private database detail");
  });
});
