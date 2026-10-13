import { NextResponse } from "next/server";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";
import { z } from "zod";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
const IssueGrantSchema = z.object({ entitlementId: z.string().uuid() }).strict();

export async function POST(request: Request) {
  const boundedBody = await readBoundedRequestBody(request, 32 * 1024);
  if (!boundedBody.ok) {
    const tooLarge = boundedBody.reason === "too_large";
    return NextResponse.json(
      { error: tooLarge ? "Request body is too large." : "Invalid request body." },
      { status: tooLarge ? 413 : 400 }
    );
  }
  let body: unknown;
  try {
    body = JSON.parse(boundedBody.body);
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }
  const parsed = IssueGrantSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Invalid entitlement." }, { status: 400 });

  try {
    const session = await createSupabaseServerClient();
    const { data: authData, error: authError } = await session.auth.getUser();
    if (authError || !authData.user) return NextResponse.json({ error: "Authentication required." }, { status: 401 });

    // The authenticated RLS read prevents this endpoint from becoming an entitlement oracle.
    const { data: entitlement, error: entitlementError } = await session
      .from("entitlements")
      .select("id,status,expires_at")
      .eq("id", parsed.data.entitlementId)
      .maybeSingle();
    if (entitlementError || !entitlement || entitlement.status !== "active" ||
      (entitlement.expires_at && new Date(entitlement.expires_at).getTime() <= Date.now())) {
      return NextResponse.json({ error: "Active entitlement not found." }, { status: 404 });
    }

    const admin = createSupabaseAdminClient();
    const { data, error } = await admin.rpc("issue_download_grant", {
      target_customer_id: authData.user.id,
      target_entitlement_id: entitlement.id
    });
    const grant = Array.isArray(data) ? data[0] as { grant_id: string; expires_at: string } | undefined : undefined;
    if (error || !grant) {
      return NextResponse.json({ error: "A secure download grant could not be issued." }, { status: 409 });
    }
    return NextResponse.json({ grantId: grant.grant_id, expiresAt: grant.expires_at }, {
      status: 201,
      headers: { "Cache-Control": "private, no-store, max-age=0" }
    });
  } catch {
    return NextResponse.json({ error: "A secure download grant could not be issued." }, { status: 503 });
  }
}
