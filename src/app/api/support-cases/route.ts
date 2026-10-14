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
    return NextResponse.json(...[truncated]