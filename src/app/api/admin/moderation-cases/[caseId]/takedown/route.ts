import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const TakedownSchema = z
  .object({ note: z.string().trim().min(10).max(2000) })
  .strict();

export async function POST(
  request: Request,
  context: { params: Promise<{ caseId: string }> },
) {
  const adminContext = await getAdminContext("listing_moderation_takedown");
  if (!adminContext)
    return NextResponse.json({ error: "not_found" }, { status: 404 });
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
  const parsed = TakedownSchema.safeParse(body);
  if (!parsed.success)
    return NextResponse.json(
      { error: "invalid_takedown_request" },
      { status: 400 },
    );

  const requestId = randomUUID();
  try {
    const { data, error } = await adminContext.admin.rpc(
      "admin_apply_listing_takedown",
      {
        p_case_id: caseId,
        p_actor_id: adminContext.userId,
        p_note: parsed.data.note,
        p_request_id: requestId,
      },
    );
    if (error) {
      if (error.code === "P0002")
        return NextResponse.json(
          { error: "moderation_case_not_found", requestId },
          { status: 404 },
        );
      if (error.code === "42501")
        return NextResponse.json(
          { error: "forbidden", requestId },
          { status: 403 },
        );
      if (error.code === "22023")
        return NextResponse.json(
          { error: "takedown_not_allowed", requestId },
          { status: 409 },
        );
      if (error.code === "23505")
        return NextResponse.json(
          { error: "takedown_already_recorded", requestId },
          { status: 409 },
        );
      return NextResponse.json(
        { error: "takedown_unavailable", requestId },
        { status: 503 },
      );
    }
    return NextResponse.json(
      { enforcement: data, requestId },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "takedown_unavailable", requestId },
      { status: 503 },
    );
  }
}
