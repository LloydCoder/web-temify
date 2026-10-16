import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createSupabaseAdminClient: vi.fn(),
  createSupabaseServerClient: vi.fn(),
  getAdminContext: vi.fn(),
  getUser: vi.fn(),
  rpc: vi.fn(),
}));

vi.mock("@/lib/supabase/admin", () => ({
  createSupabaseAdminClient: mocks.createSupabaseAdminClient,
}));
vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: mocks.createSupabaseServerClient,
}));
vi.mock("@/server/admin/authorization", () => ({
  getAdminContext: mocks.getAdminContext,
}));

import { POST as submitAppeal } from "./moderation/appeals/route";
import { POST as applyTakedown } from "./admin/moderation-cases/[caseId]/takedown/route";
import { POST as transitionAppeal } from "./admin/moderation-appeals/[appealId]/transition/route";
import { POST as configureAppealPolicy } from "./admin/moderation-appeal-policy/route";

const origin = "https://web-temify.test";
const creatorId = "b1000000-0000-4000-8000-000000000001";
const adminId = "b3000000-0000-4000-8000-000000000003";
const caseId = "b5000000-0000-4000-8000-000000000005";
const appealId = "b6000000-0000-4000-8000-000000000006";
const enforcementId = "b7000000-0000-4000-8000-000000000007";

function request(
  path: string,
  body: unknown,
  headers: Record<string, string> = {},
) {
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

const creatorAppealBody = {
  enforcementId,
  statement:
    "I am appealing this takedown and can provide evidence of my rights.",
  evidenceReference: null,
  idempotencyKey: "appeal-route-test-key-0001",
};
const policyBody = {
  responseTargetHours: 336,
  policyVersion: "appeals-v1",
  approvalNote: "Approved for internal operational response tracking.",
  legalReviewReference: "LEGAL-REVIEW-2026-001",
};

describe("Phase 5E2 moderation API routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.rpc.mockResolvedValue({ data: { id: "result-id" }, error: null });
    mocks.createSupabaseAdminClient.mockReturnValue({ rpc: mocks.rpc });
    mocks.createSupabaseServerClient.mockReturnValue({
      auth: { getUser: mocks.getUser },
    });
    mocks.getUser.mockResolvedValue({
      data: { user: { id: creatorId } },
      error: null,
    });
    mocks.getAdminContext.mockResolvedValue({
      userId: adminId,
      admin: { rpc: mocks.rpc },
    });
  });

  it("rejects creator appeals without same-origin and authenticated identity before privileged access", async () => {
    const crossOrigin = await submitAppeal(
      request("/api/moderation/appeals", creatorAppealBody, {
        Origin: "https://attacker.test",
      }),
    );
    expect(crossOrigin.status).toBe(403);
    expect(mocks.createSupabaseServerClient).not.toHaveBeenCalled();

    mocks.getUser.mockResolvedValueOnce({
      data: { user: null },
      error: null,
    });
    const unauthenticated = await submitAppeal(
      request("/api/moderation/appeals", creatorAppealBody),
    );
    expect(unauthenticated.status).toBe(401);
    expect(mocks.createSupabaseAdminClient).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("validates creator appeal bodies and binds the RPC actor to the authenticated user", async () => {
    const invalid = await submitAppeal(
      request("/api/moderation/appeals", {
        ...creatorAppealBody,
        creatorId: adminId,
      }),
    );
    expect(invalid.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();

    const response = await submitAppeal(
      request("/api/moderation/appeals", creatorAppealBody),
    );
    expect(response.status).toBe(201);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(mocks.rpc).toHaveBeenCalledWith(
      "create_listing_moderation_appeal",
      expect.objectContaining({
        p_creator_id: creatorId,
        p_enforcement_id: enforcementId,
        p_statement: creatorAppealBody.statement,
        p_idempotency_key: creatorAppealBody.idempotencyKey,
      }),
    );
  });

  it.each([
    ["P0002", 404, "active_takedown_not_found"],
    ["42501", 403, "appeal_not_authorized"],
    ["22023", 400, "invalid_moderation_appeal"],
    ["23505", 409, "appeal_conflict"],
    ["XX000", 503, "moderation_appeal_unavailable"],
  ])(
    "maps creator appeal RPC error %s to a safe response",
    async (code, status, error) => {
      mocks.rpc.mockResolvedValueOnce({
        data: null,
        error: { code, message: "sensitive database detail" },
      });
      const response = await submitAppeal(
        request("/api/moderation/appeals", creatorAppealBody),
      );
      expect(response.status).toBe(status);
      const body = await response.json();
      expect(body.error).toBe(error);
      expect(JSON.stringify(body)).not.toContain("sensitive database detail");
    },
  );

  it("requires an admin context and rejects malformed takedown requests before the RPC", async () => {
    mocks.getAdminContext.mockResolvedValueOnce(null);
    const denied = await applyTakedown(
      request(`/api/admin/moderation-cases/${caseId}/takedown`, {
        note: "Apply this reviewed listing takedown.",
      }),
      { params: Promise.resolve({ caseId }) },
    );
    expect(denied.status).toBe(404);

    const invalid = await applyTakedown(
      request(`/api/admin/moderation-cases/${caseId}/takedown`, {
        note: "short",
        reasonCode: "rights_review_required",
      }),
      { params: Promise.resolve({ caseId }) },
    );
    expect(invalid.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("forwards takedown actor and case from the authenticated admin context", async () => {
    const response = await applyTakedown(
      request(`/api/admin/moderation-cases/${caseId}/takedown`, {
        note: "Apply the reviewed rights takedown to this listing.",
      }),
      { params: Promise.resolve({ caseId }) },
    );
    expect(response.status).toBe(200);
    expect(mocks.getAdminContext).toHaveBeenCalledWith(
      "listing_moderation_takedown",
    );
    expect(mocks.rpc).toHaveBeenCalledWith(
      "admin_apply_listing_takedown",
      expect.objectContaining({ p_case_id: caseId, p_actor_id: adminId }),
    );
  });

  it.each([
    ["P0002", 404, "moderation_case_not_found"],
    ["42501", 403, "forbidden"],
    ["22023", 409, "takedown_not_allowed"],
    ["23505", 409, "takedown_already_recorded"],
  ])("maps takedown RPC error %s safely", async (code, status, error) => {
    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: { code, message: "sensitive database detail" },
    });
    const response = await applyTakedown(
      request(`/api/admin/moderation-cases/${caseId}/takedown`, {
        note: "Apply the reviewed rights takedown to this listing.",
      }),
      { params: Promise.resolve({ caseId }) },
    );
    expect(response.status).toBe(status);
    expect((await response.json()).error).toBe(error);
  });

  it("validates and forwards appeal transitions through the admin RPC", async () => {
    const invalid = await transitionAppeal(
      request(`/api/admin/moderation-appeals/${appealId}/transition`, {
        action: "publish",
        note: "Attempt an unsupported transition.",
      }),
      { params: Promise.resolve({ appealId }) },
    );
    expect(invalid.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();

    const response = await transitionAppeal(
      request(`/api/admin/moderation-appeals/${appealId}/transition`, {
        action: "reverse",
        note: "Appeal approved after independent evidence review.",
      }),
      { params: Promise.resolve({ appealId }) },
    );
    expect(response.status).toBe(200);
    expect(mocks.getAdminContext).toHaveBeenCalledWith(
      "listing_moderation_appeal_transition",
    );
    expect(mocks.rpc).toHaveBeenCalledWith(
      "admin_transition_listing_moderation_appeal",
      expect.objectContaining({
        p_appeal_id: appealId,
        p_actor_id: adminId,
        p_action: "reverse",
      }),
    );
  });

  it("validates appeal-policy approval data and maps persistence failures safely", async () => {
    const invalid = await configureAppealPolicy(
      request("/api/admin/moderation-appeal-policy", {
        ...policyBody,
        legalReviewReference: "",
      }),
    );
    expect(invalid.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();

    mocks.rpc.mockResolvedValueOnce({
      data: null,
      error: { code: "XX000", message: "sensitive database detail" },
    });
    const failed = await configureAppealPolicy(
      request("/api/admin/moderation-appeal-policy", policyBody),
    );
    expect(failed.status).toBe(503);
    const body = await failed.json();
    expect(body.error).toBe("appeal_policy_unavailable");
    expect(JSON.stringify(body)).not.toContain("sensitive database detail");

    mocks.rpc.mockResolvedValueOnce({
      data: { is_approved: true },
      error: null,
    });
    const success = await configureAppealPolicy(
      request("/api/admin/moderation-appeal-policy", policyBody),
    );
    expect(success.status).toBe(200);
    expect(mocks.rpc).toHaveBeenLastCalledWith(
      "admin_configure_listing_moderation_appeal_policy",
      expect.objectContaining({
        p_actor_id: adminId,
        p_response_target_hours: 336,
        p_legal_review_reference: policyBody.legalReviewReference,
      }),
    );
  });

  it("rejects non-JSON and oversized admin requests before database mutation", async () => {
    const wrongType = await configureAppealPolicy(
      request("/api/admin/moderation-appeal-policy", policyBody, {
        "Content-Type": "text/plain",
      }),
    );
    expect(wrongType.status).toBe(415);

    const oversized = await applyTakedown(
      request(
        `/api/admin/moderation-cases/${caseId}/takedown`,
        JSON.stringify({ note: "x".repeat(9000) }),
      ),
      { params: Promise.resolve({ caseId }) },
    );
    expect(oversized.status).toBe(413);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
