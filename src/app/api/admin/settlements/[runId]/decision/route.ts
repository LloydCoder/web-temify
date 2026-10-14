import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

const decisionSchema = z
  .object({
    rowId: z.string().min(1).max(240),
    decision: z.enum([
      "reimport_required",
      "manual_review_required",
      "accepted_with_evidence",
    ]),
    reason: z.string().trim().min(12).max(500),
    evidenceSha256: z.string().regex(/^[a-f0-9]{64}$/).nullable(),
  })
  .strict()
  .superRefine((value, context) => {
    if (
      value.decision === "accepted_with_evidence" &&
      value.evidenceSha256 === null
    ) {
      context.addIssue({
        code: "custom",
        path: ["evidenceSha256"],
        message: "Evidence digest is required for this decision.",
      });
    }
    if (
      value.decision !== "accepted_with_evidence" &&
      value.evidenceSha256 !== null
    ) {
      context.addIssue({
        code: "custom",
        path: ["evidenceSha256"],
        message: "Evidence digest is only accepted with evidence-backed triage.",
      });
    }
  });

export async function POST(
  request: Request,
  context: { params: Promise<{ runId: string }> },
) {
  const adminContext = await getAdminContext("settlement_exception_decision");
  if (!adminContext) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  const requestId = randomUUID();
  const origin = request.headers.get("origin");
  if (!origin || origin !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required", requestId },
      { status: 403 },
    );
  }

  const contentType = request.headers
    .get("content-type")
    ?.split(";")[0]
    ?.trim()
    .toLowerCase();
  if (contentType !== "application/json") {
    return NextResponse.json(
      { error: "json_content_type_required", requestId },
      { status: 415 },
    );
  }

  const { runId } = await context.params;
  const parsedRunId = z.string().uuid().safeParse(runId);
  if (!parsedRunId.success) {
    return NextResponse.json(
      { error: "invalid_run_id", requestId },
      { status: 400 },
    );
  }

  const boundedBody = await readBoundedRequestBody(request, 8 * 1024);
  if (!boundedBody.ok) {
    const tooLarge = boundedBody.reason === "too_large";
    return NextResponse.json(
      {
        error: tooLarge ? "request_body_too_large" : "invalid_request_body",
        requestId,
      },
      { status: tooLarge ? 413 : 400 },
    );
  }

  let untrusted: unknown;
  try {
    untrusted = JSON.parse(boundedBody.body);
  } catch {
    return NextResponse.json(
      { error: "invalid_json", requestId },
      { status: 400 },
    );
  }

  const parsed = decisionSchema.safeParse(untrusted);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_settlement_decision", requestId },
      { status: 400 },
    );
  }

  const { error } = await adminContext.admin.rpc(
    "decide_settlement_exception",
    {
      p_run_id: parsedRunId.data,
      p_row_id: parsed.data.rowId,
      p_decision: parsed.data.decision,
      p_reason: parsed.data.reason,
      p_evidence_sha256: parsed.data.evidenceSha256,
      p_decided_by: adminContext.userId,
    },
  );

  if (error) {
    const status =
      error.code === "P0002"
        ? 404
        : error.code === "42501"
          ? 403
          : error.code === "23514"
            ? 409
            : 503;
    return NextResponse.json(
      { error: "settlement_decision_not_applied", requestId },
      { status },
    );
  }

  return NextResponse.json(
    { ok: true, requestId },
    { status: 200, headers: { "Cache-Control": "no-store" } },
  );
}
