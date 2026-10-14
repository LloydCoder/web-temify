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
  let requesterId: string;
  try {
    const session = await createSupabaseServerClient();
    const { data: authData, error: authError } = await session.auth.getUser();
    if (authError) {
      if (authError.name === "AuthSessionMissingError") {
        return NextResponse.json(
          { error: "authentication_required" },
          { status: 401, headers: { "Cache-Control": "no-store" } },
        );
      }
      return NextResponse.json(
        { error: "authentication_unavailable" },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }
    if (!authData.user) {
      return NextResponse.json(
        { error: "authentication_required" },
        { status: 401, headers: { "Cache-Control": "no-store" } },
      );
    }
    requesterId = authData.user.id;
  } catch {
    return NextResponse.json(
      { error: "support_cases_unavailable" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  try {
    const admin = createSupabaseAdminClient();
    const { data, error } = await admin
      .from("support_cases")
      .select(
        "id,category,subject,status,priority,assigned_to,created_at,updated_at,resolved_at,closed_at",
      )
      .eq("requester_id", requ...[truncated]