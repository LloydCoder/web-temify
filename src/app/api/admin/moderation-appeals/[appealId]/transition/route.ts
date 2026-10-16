import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const TransitionSchema = z
  .object({
    action: z.enum(["triage", "uphold", "reverse", "reject"]),
    note: z.string().trim().min(10).max(2000),
  })
  .strict();

export async function POST(
  request: Request,
  context: { params: Promise<{ appealId: string }> },
) {
  const adminContext = await getAdminContext(
    "listing_moderation_appeal_transition",
  );
  if (!adminContext)
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required" },
      { status: 403 },
    );
  }
  const { appealId } = await context.params;
  if (!z.string().uuid().safeParse(appealId).success) {
    return NextResponse.json({ error: "invalid_appeal_id" }, { status: 400 });
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
  if (!parsed.success)
    return NextResponse.json(
      { error: "invalid_appeal_transition" },
      { status: 400 },
    );

  const requestId = randomUUID();
  try {
    const { data, error } = await adminContext.admin.rpc(
      "admin_transition_listing_moderation_appeal",
      {
        p_appeal_id: appealId,
        p_actor_id: adminContext.userId,
        p_action: parsed.data.action,
        p_note: parsed.data.note,
        p_request_id: requestId,
      },
    );
    if (error) {
      if (error.code === "P0002")
        return NextResponse.json(
          { error: "appeal_not_found", requestId },
          { status: 404 },
        );
      if (error.code === "42501")
        return NextResponse.json(
          { error: "forbidden", requestId },
          { status: 403 },
        );
      if (error.code === "22023")
        return NextResponse.json(
          { error: "invalid_appeal_transition", requestId },
          { status: 409 },
        );
      return NextResponse.json(
        { error: "appeal_transition_unavailable", requestId },
        { status: 503 },
      );
    }
    return NextResponse.json(
      { appeal: data, requestId },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "appeal_transition_unavailable", requestId },
      { status: 503 },
    );
  }
}
