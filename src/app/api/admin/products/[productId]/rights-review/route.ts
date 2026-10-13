import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";

const reviewSchema = z.object({
  attestationId: z.string().uuid(),
  decision: z.enum(["under_review", "verified", "rejected"]),
  notes: z.string().trim().min(10).max(4000)
}).strict();

export async function POST(
  request: Request,
  context: { params: Promise<{ productId: string }> }
) {
  const adminContext = await getAdminContext("product_rights_review_mutation");
  if (!adminContext) return NextResponse.json({ error: "not_found" }, { status: 404 });

  const requestId = randomUUID();
  const origin = request.headers.get("origin");
  if (!origin || origin !== new URL(request.url).origin) {
    return NextResponse.json({ error: "same_origin_required", requestId }, { status: 403 });
  }

  const { productId } = await context.params;
  const productIdResult = z.string().uuid().safeParse(productId);
  if (!productIdResult.success) return NextResponse.json({ error: "invalid_product_id", requestId }, { status: 400 });

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "invalid_json", requestId }, { status: 400 });
  }
  const parsed = reviewSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "invalid_review_input", requestId }, { status: 400 });

  const { data, error } = await adminContext.admin.rpc("admin_review_product_rights", {
    p_product_id: productIdResult.data,
    p_attestation_id: parsed.data.attestationId,
    p_reviewer_id: adminContext.userId,
    p_decision: parsed.data.decision,
    p_review_notes: parsed.data.notes,
    p_request_id: requestId
  });
  if (error) {
    const status = error.code === "P0002" ? 409 : error.code === "42501" ? 403 : error.code === "22023" ? 400 : 503;
    return NextResponse.json({ error: "review_not_applied", requestId }, { status });
  }
  return NextResponse.json({ ok: true, requestId, result: data }, { status: 200 });
}
