import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";

const SupportCaseSchema = z
  .object({
    category: z.enum([
      "account",
      "billing",
      "product_access",
      "product_rights",
      "security",
      "other",
    ]),
    subject: z.string().trim().min(5).max(160),
    description: z.string().trim().min(10).max(8000),
    idempotencyKey: z.string().trim().min(16).max(200),
  })
  .strict();

export async function GET() {
  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) {
    return NextResponse.json(
      { error: "authentication_required" },
      { status: 401 },
    );
  }

  try {
    const admin = createSupabaseAdminClient();
    const { data, error } = await admin
      .from("support_cases")
      .select(
        "id,category,subject,status,priority,assigned_to,created_at,updated_at,resolved_at,closed_at",
      )
      .eq("requester_id", authData.user.id)
      .order("created_at", { ascending: false })
      .limit(50);
    if (error) {
      return NextResponse.json(
        { error: "support_cases_unavailable" },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }
    return NextResponse.json(
      { cases: data ?? [] },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "support_cases_unavailable" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}

export async function POST(request: Request) {
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required" },
      { status: 403 },
    );
  }

  const bounded = await readBoundedRequestBody(request, 16 * 1024);
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
  const parsed = SupportCaseSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_support_case" },
      { status: 400 },
    );
  }

  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) {
    return NextResponse.json(
      { error: "authentication_required" },
      { status: 401 },
    );
  }

  const requestId = randomUUID();
  try {
    const admin = createSupabaseAdminClient();
    const { data: caseId, error } = await admin.rpc("create_support_case", {
      p_requester_id: authData.user.id,
      p_category: parsed.data.category,
      p_subject: parsed.data.subject,
      p_description: parsed.data.description,
      p_idempotency_key: parsed.data.idempotencyKey,
      p_request_id: requestId,
    });
    if (error) {
      if (error.code === "23505") {
        return NextResponse.json(
          { error: "idempotency_key_conflict", requestId },
          { status: 409 },
        );
      }
      if (error.code === "22023") {
        return NextResponse.json(
          { error: "invalid_support_case", requestId },
          { status: 400 },
        );
      }
      return NextResponse.json(
        { error: "support_case_creation_unavailable", requestId },
        { status: error.code === "42501" ? 403 : 503 },
      );
    }
    return NextResponse.json(
      { id: caseId, status: "open", requestId },
      { status: 201, headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "support_case_creation_unavailable", requestId },
      { status: 503 },
    );
  }
}
