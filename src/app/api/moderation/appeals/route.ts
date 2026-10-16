import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const AppealSchema = z.object({
  enforcementId: z.string().uuid(),
  statement: z.string().trim().min(20).max(4000),
  evidenceReference: z.string().trim().max(2048).nullable(),
  idempotencyKey: z.string().min(16).max(200),
}).strict();

export async function POST(request: Request) {
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json({ error: "same_origin_required" }, { status: 403 });
  }
  if (request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase() !== "application/json") {
    return NextResponse.json({ error: "json_required" }, { status: 415 });
  }
  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) return NextResponse.json({ error: "authentication_required" }, { status: 401 });

  const bounded = await readBoundedRequestBody(request, 8 * 1024);
  if (!bounded.ok) {
    return NextResponse.json({ error: bounded.reason === "too_large" ? "request_too_large" : "invalid_request_body" }, { status: bounded.reason === "too_large" ? 413 : 400 });
  }
  let body: unknown;
  try { body = JSON.parse(bounded.body); } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  const parsed = AppealSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "invalid_moderation_appeal" }, { status: 400 });

  const requestId = randomUUID();
  try {
    const admin = createSupabaseAdminClient();
    const { data, error } = await admin.rpc("create_listing_moderation_appeal", {
      p_creator_id: authData.user.id,
      p_enforcement_id: parsed.data.enforcementId,
      p_statement: parsed.data.statement,
      p_evidence_reference: parsed.data.evidenceReference,
      p_idempotency_key: parsed.data.idempotencyKey,
      p_request_id: requestId,
    });
    if (error) {
      if (error.code === "P0002") return NextResponse.json({ error: "active_takedown_not_found", requestId }, { status: 404 });
      if (error.code === "42501") return NextResponse.json({ error: "appeal_not_authorized", requestId }, { status: 403 });
      if (error.code === "22023") return NextResponse.json({ error: "invalid_moderation_appeal", requestId }, { status: 400 });
      if (error.code === "23505") return NextResponse.json({ error: "appeal_conflict", requestId }, { status: 409 });
      return NextResponse.json({ error: "moderation_appeal_unavailable", requestId }, { status: 503 });
    }
    return NextResponse.json({ appeal: data, requestId }, { status: 201, headers: { "Cache-Control": "no-store" } });
  } catch {
    return NextResponse.json({ error: "moderation_appeal_unavailable", requestId }, { status: 503 });
  }
}
