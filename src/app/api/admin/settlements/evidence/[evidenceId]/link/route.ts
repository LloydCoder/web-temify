import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const evidenceIdSchema = z.string().uuid();
const linkRequestSchema = z.object({ importId: z.string().uuid() }).strict();

export async function POST(
  request: Request,
  context: { params: Promise<{ evidenceId: string }> },
) {
  const adminContext = await getAdminContext("settlement_evidence_link");
  if (!adminContext) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  const requestId = randomUUID();
  if (request.headers.get("origin") !== new URL(request.url).origin) {
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

  const { evidenceId } = await context.params;
  const parsedEvidenceId = evidenceIdSchema.safeParse(evidenceId);
  if (!parsedEvidenceId.success) {
    return NextResponse.json(
      { error: "invalid_evidence_id", requestId },
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

  const parsed = linkRequestSchema.safeParse(untrusted);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_settlement_evidence_link", requestId },
      { status: 400 },
    );
  }

  const { error: auditError } = await adminContext.admin
    .from("audit_events")
    .insert({
      actor_id: adminContext.userId,
      action: "settlement.evidence.link_requested",
      entity_type: "settlement_evidence",
      entity_id: parsedEvidenceId.data,
      request_id: requestId,
      metadata: { import_id: parsed.data.importId },
    });
  if (auditError) {
    return NextResponse.json(
      { error: "settlement_audit_unavailable", requestId },
      { status: 503 },
    );
  }

  const { data: linkId, error } = await adminContext.admin.rpc(
    "link_settlement_evidence",
    {
      p_evidence_id: parsedEvidenceId.data,
      p_import_id: parsed.data.importId,
      p_linked_by: adminContext.userId,
      p_request_id: requestId,
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
      { error: "settlement_evidence_link_not_applied", requestId },
      { status },
    );
  }

  return NextResponse.json(
    { ok: true, linkId, requestId },
    { status: 200, headers: { "Cache-Control": "no-store" } },
  );
}
