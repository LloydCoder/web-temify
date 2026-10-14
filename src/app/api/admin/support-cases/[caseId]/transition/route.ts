import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const TransitionSchema = z
  .object({
    action: z.enum([
      "triage",
      "request_info",
      "escalate",
      "resolve",
      "close",
      "reopen",
      "assign",
    ]),
    note: z.string().trim().min(10).max(2000),
    assigneeId: z.string().uuid().optional(),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.action === "assign" && !value.assigneeId) {
      context.addIssue({
        code: "custom",
        path: ["assigneeId"],
        message: "An administrator assignee is required.",
      });
    }
    if (value.action !== "assign" && value.assigneeId) {
      context.addIssue({
        code: "custom",
        path: ["assigneeId"],
        message: "Assignee is only valid for assignment actions.",
      });
    }
  });

export async function POST(
  request: Request,
  context: { params: Promise<{ caseId: string }> },
) {
  const adminContext = await getAdminContext("support_case_transition");
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
      { error: "invalid_support_case_action" },
      { status: 400 },
    );
  }

  const requestId = randomUUID();
  try {
    const { data, error } = await adminContext.admin.rpc(
      "admin_transition_support_case",
      {
        p_case_id: caseId,
        p_actor_id: adminContext.userId,
        p_action: parsed.data.action,
        p_note: parsed.data.note,
        p_assignee_id: parsed.data.assigneeId ?? null,
        p_request_id: requestId,
      },
    );
    if (error) {
      if (error.code === "P0002") {
        return NextResponse.json(
          { error: "support_case_not_found", requestId },
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
          { error: "invalid_support_case_transition", requestId },
          { status: 409 },
        );
      }
      return NextResponse.json(
        { error: "support_case_action_unavailable", requestId },
        { status: 503 },
      );
    }
    return NextResponse.json(
      { case: data, requestId },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "support_case_action_unavailable", requestId },
      { status: 503 },
    );
  }
}
