import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

const RetentionSettingsSchema = z.object({
  enabled: z.boolean(),
  legalBasis: z.string().trim().min(20).max(1000),
});

export async function GET() {
  const context = await getAdminContext("settlement_evidence_retention_policy");
  if (!context) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  const { data, error } = await context.admin.rpc(
    "get_settlement_evidence_retention_settings",
  );
  if (error) {
    return NextResponse.json(
      { error: "settlement_retention_settings_unavailable" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const settings = Array.isArray(data) ? data[0] ?? null : data;
  return NextResponse.json(
    { settings },
    { status: 200, headers: { "Cache-Control": "no-store" } },
  );
}

export async function POST(request: Request) {
  const context = await getAdminContext("settlement_evidence_retention_policy");
  if (!context) {
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

  const parsed = RetentionSettingsSchema.safeParse(untrusted);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_settlement_retention_settings", requestId },
      { status: 400 },
    );
  }

  const { error } = await context.admin.rpc(
    "set_settlement_evidence_retention_enabled",
    {
      p_enabled: parsed.data.enabled,
      p_legal_basis: parsed.data.legalBasis,
      p_actor_id: context.userId,
      p_request_id: requestId,
    },
  );

  if (error) {
    const status =
      error.code === "42501" ? 403 : error.code === "23514" ? 400 : 503;
    return NextResponse.json(
      { error: "settlement_retention_settings_not_applied", requestId },
      { status },
    );
  }

  return NextResponse.json(
    { ok: true, enabled: parsed.data.enabled, requestId },
    { status: 200, headers: { "Cache-Control": "no-store" } },
  );
}
