import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const ReviewSchema = z.object({
  decision: z.enum(["approve", "reject"]),
  note: z.string().trim().min(10).max(1000),
}).strict();

export async function POST(
  request: Request,
  context: { params: Promise<{ requestId: string }> },
) {
  const adminContext = await getAdminContext("financial_control_review");
  if (!adminContext) {
    return NextResponse.json({ error: "not_found" }, {
      status: 404,
      headers: { "Cache-Control": "no-store" },
    });
  }
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json({ error: "same_origin_required" }, {
      status: 403,
      headers: { "Cache-Control": "no-store" },
    });
  }
  const { requestId } = await context.params;
  if (!z.string().uuid().safeParse(requestId).success) {
    return NextResponse.json({ error: "invalid_request_id" }, {
      status: 400,
      headers: { "Cache-Control": "no-store" },
    });
  }
  if (
    request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase() !==
    "application/json"
  ) {
    return NextResponse.json({ error: "json_required" }, {
      status: 415,
      headers: { "Cache-Control": "no-store" },
    });
  }
  const bounded = await readBoundedRequestBody(request, 8 * 1024);
  if (!bounded.ok) {
    return NextResponse.json({
      error: bounded.reason === "too_large" ? "request_too_large" : "invalid_request_body",
    }, {
      status: bounded.reason === "too_large" ? 413 : 400,
      headers: { "Cache-Control": "no-store" },
    });
  }
  let body: unknown;
  try {
    body = JSON.parse(bounded.body);
  } catch {
    return NextResponse.json({ error: "invalid_json" }, {
      status: 400,
      headers: { "Cache-Control": "no-store" },
    });
  }
  const parsed = ReviewSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_financial_control_review" }, {
      status: 400,
      headers: { "Cache-Control": "no-store" },
    });
  }

  const traceId = randomUUID();
  try {
    const { data, error } = await adminContext.admin.rpc("review_financial_control_request", {
      p_request_id: requestId,
      p_actor_id: adminContext.userId,
      p_decision: parsed.data.decision,
      p_note: parsed.data.note,
      p_request_trace_id: traceId,
    });
    if (error) {
      let status = 503;
      let safeError = "financial_control_review_unavailable";
      if (error.code === "42501") {
        status = 403;
        safeError = "financial_control_review_forbidden";
      } else if (error.code === "P0002") {
        status = 404;
        safeError = "financial_control_request_not_found";
      } else if (error.code === "22023") {
        status = 409;
        safeError = "financial_control_request_not_reviewable";
      } else if (error.code === "23505") {
        status = 409;
        safeError = "financial_control_duplicate_decision";
      }
      return NextResponse.json({ error: safeError, traceId }, {
        status,
        headers: { "Cache-Control": "no-store" },
      });
    }
    if (data !== "under_review" && data !== "approved" && data !== "rejected") {
      return NextResponse.json({ error: "financial_control_review_unavailable", traceId }, {
        status: 503,
        headers: { "Cache-Control": "no-store" },
      });
    }
    return NextResponse.json({ status: data, traceId }, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return NextResponse.json({ error: "financial_control_review_unavailable", traceId }, {
      status: 503,
      headers: { "Cache-Control": "no-store" },
    });
  }
}
