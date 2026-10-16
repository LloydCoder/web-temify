import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const ReportSchema = z.object({
  productId: z.string().uuid(),
  reasonCode: z.enum([
    "ip_rights",
    "fraud_misrepresentation",
    "malware_security",
    "prohibited_content",
    "privacy",
    "other",
  ]),
  description: z.string().trim().min(20).max(4000),
  idempotencyKey: z.string().min(16).max(200),
}).strict();

export async function POST(request: Request) {
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json({ error: "same_origin_required" }, { status: 403 });
  }
  const contentType = request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase();
  if (contentType !== "application/json") {
    return NextResponse.json({ error: "json_required" }, { status: 415 });
  }

  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) {
    return NextResponse.json({ error: "authentication_required" }, { status: 401 });
  }

  const bounded = await readBoundedRequestBody(request, 8 * 1024);
  if (!bounded.ok) {
    return NextResponse.json(
      { error: bounded.reason === "too_large" ? "request_too_large" : "invalid_request_body" },
      { status: bounded.reason === "too_large" ? 413 : 400 },
    );
  }
  let body: unknown;
  try {
    body = JSON.parse(bounded.body);
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  const parsed = ReportSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_moderation_report" }, { status: 400 });
  }

  const requestId = randomUUID();
  try {
    const admin = createSupabaseAdminClient();
    const { data, error } = await admin.rpc("create_listing_moderation_case", {
      p_reporter_id: authData.user.id,
      p_product_id: parsed.data.productId,
      p_reason_code: parsed.data.reasonCode,
      p_description: parsed.data.description,
      p_idempotency_key: parsed.data.idempotencyKey,
      p_request_id: requestId,
    });
    if (error) {
      if (error.code === "P0002") return NextResponse.json({ error: "product_not_found", requestId }, { status: 404 });
      if (error.code === "22023") return NextResponse.json({ error: "invalid_moderation_report", requestId }, { status: 400 });
      if (error.code === "23505") return NextResponse.json({ error: "idempotency_conflict", requestId }, { status: 409 });
      return NextResponse.json({ error: "moderation_report_unavailable", requestId }, { status: 503 });
    }
    return NextResponse.json(
      { caseId: data, requestId },
      { status: 201, headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json({ error: "moderation_report_unavailable", requestId }, { status: 503 });
  }
}
