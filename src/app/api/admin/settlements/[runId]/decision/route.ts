import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { SettlementExceptionDecisionSchema } from "@/server/commerce/settlement-exception-decision";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

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

  const parsed = SettlementExceptionDecisionSchema.safeParse(untrusted);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_settlement_decision", requestId },
      { status: 400 },
    );
  }

  const { error: auditError } = await adminContext.admin
    .from("audit_events")
    .insert({
      actor_id: adminContext.userId,
      action: "settlement.exception.triage_requested",
      entity_type: "settlement_exception",
      entity_id: `${parsedRunId.data}:${parsed.data.rowId}`,
      request_id: requestId,
      metadata: {
        decision: parsed.data.decision,
        evidence_attached: parsed.data.evidenceSha256 !== null,
      },
    });
  if (auditError) {
    return NextResponse.json(
      { error: "settlement_audit_unavailable", requestId },
      { status: 503 },
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
