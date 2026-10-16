import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const PolicySchema = z.object({
  responseTargetHours: z.number().int().min(24).max(720),
  policyVersion: z.string().trim().min(1).max(80),
  approvalNote: z.string().trim().min(10).max(2000),
  legalReviewReference: z.string().trim().min(5).max(2048),
}).strict();

export async function POST(request: Request) {
  const adminContext = await getAdminContext("listing_moderation_appeal_policy");
  if (!adminContext) return NextResponse.json({ error: "not_found" }, { status: 404 });
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json({ error: "same_origin_required" }, { status: 403 });
  }
  if (request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase() !== "application/json") {
    return NextResponse.json({ error: "json_required" }, { status: 415 });
  }
  const bounded = await readBoundedRequestBody(request, 8 * 1024);
  if (!bounded.ok) {
    return NextResponse.json({ error: bounded.reason === "too_large" ? "request_too_large" : "invalid_request_body" }, { status: bounded.reason === "too_large" ? 413 : 400 });
  }
  let body: unknown;
  try { body = JSON.parse(bounded.body); } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  const parsed = PolicySchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "invalid_appeal_policy" }, { status: 400 });

  const requestId = randomUUID();
  try {
    const { data, error } = await adminContext.admin.rpc("admin_configure_listing_moderation_appeal_policy", {
      p_actor_id: adminContext.userId,
      p_response_target_hours: parsed.data.responseTargetHours,
      p_policy_version: parsed.data.policyVersion,
      p_approval_note: parsed.data.approvalNote,
      p_legal_review_reference: parsed.data.legalReviewReference,
      p_request_id: requestId,
    });
    if (error) {
      if (error.code === "42501") return NextResponse.json({ error: "forbidden", requestId }, { status: 403 });
      if (error.code === "22023") return NextResponse.json({ error: "invalid_appeal_policy", requestId }, { status: 400 });
      return NextResponse.json({ error: "appeal_policy_unavailable", requestId }, { status: 503 });
    }
    return NextResponse.json({ policy: data, requestId }, { headers: { "Cache-Control": "no-store" } });
  } catch {
    return NextResponse.json({ error: "appeal_policy_unavailable", requestId }, { status: 503 });
  }
}
