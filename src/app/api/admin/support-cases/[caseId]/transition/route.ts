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
      { status: bounded.reason === "too_large...[truncated]