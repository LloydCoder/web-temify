import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const TransitionSchema = z
  .object({
    action: z.enum(["triage", "require_action", "dismiss", "close"]),
    resolutionCode: z
      .enum([
        "listing_review_required",
        "rights_review_required",
        "security_review_required",
        "no_violation_found",
        "duplicate_report",
        "insufficient_evidence",
      ])
      .nullable(),
    note: z.string().trim().min(10).max(2000),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.action === "triage" && value.resolutionCode !== null) {
      context.addIssue({
        code: "custom",
        path: ["resolutionCode"],
        message: "Triage cannot set a resolution.",
      });
    }
    if (
      value.action === "require_action" &&
      ![
        "listing_review_required",
        "rights_review_required",
        "security_review_required",
      ].includes(value.resolutionCode ?? "")
    ) {
      context.addIssue({
        code: "custom",
        path: ["resolutionCode"],
        message: "A follow-up action resolution is required.",
      });
    }
    if (
      value.action === "dismiss" &&
      ![
        "no_violation_found",
        "duplicate_report",
        "insufficient_evidence",
      ].includes(value.resolutionCode ?? "")
    ) {
      context.addIssue({
        code: "custom",
        path: ["resolutionCode"],
        message: "A dismissal reason is required.",
      });
    }
    if (value.action === "close" && value.resolutionCode === null) {
      context.addIssue({
        code: "custom",
        path: ["resolutionCode"],
        message: "The existing resolution code is required.",
      });
    }
  });

export async function POST(
  request: Request,
  context: { params: Promise<{ caseId: string }> },
) {
  const adminContext = await getAdminContext("listing_moderation_transition");
  if (!adminContext) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required" },
      { status: 403 },
    );
  }

  const { caseId } = await context.params;
  if (!z.string().uuid().safeParse(caseId).success) {
    return NextResponse.json({ error: "invalid_case_id" }, { status: 400 });
  }
  if (
    request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase() !==
    "application/json"
  ) {
    return NextResponse.json({ error: "json_required" }, { status: 415 });
  }

  const bounded = await readBoundedRequestBody(request, 8 * 1024);
  if (!bounded.ok) {
    return NextResponse.json(
      {
        error:
          bounded.reason === "too_large"
            ? "request_too_large"
            : "invalid_request_body",
      },
      { status: bounded.reason === "too_large" ? 413 : 400 },
    );
  }

  let body: unknown;
  try {
    body = JSON.parse(bounded.body);
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  const parsed = TransitionSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_moderation_transition" },
      { status: 400 },
    );
  }

  const requestId = randomUUID();
  try {
    const { data, error } = await adminContext.admin.rpc(
      "admin_transition_listing_moderation_case",
      {
        p_case_id: caseId,
        p_actor_id: adminContext.userId,
        p_action: parsed.data.action,
        p_resolution_code: parsed.data.resolutionCode,
        p_note: parsed.data.note,
        p_request_id: requestId,
      },
    );
    if (error) {
      if (error.code === "P0002") {
        return NextResponse.json(
          { error: "moderation_case_not_found", requestId },
          { status: 404 },
        );
      }
      if (error.code === "42501") {
        return NextResponse.json(
          { error: "forbidden", requestId },
          { status: 403 },
        );
      }
      if (error.code === "22023") {
        return NextResponse.json(
          { error: "invalid_moderation_transition", requestId },
          { status: 409 },
        );
      }
      return NextResponse.json(
        { error: "moderation_transition_unavailable", requestId },
        { status: 503 },
      );
    }
    return NextResponse.json(
      { case: data, requestId },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "moderation_transition_unavailable", requestId },
      { status: 503 },
    );
  }
}
