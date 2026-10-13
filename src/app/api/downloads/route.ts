import { NextResponse } from "next/server";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";
import { z } from "zod";
import { getServerEnv } from "@/lib/env";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
const DownloadRequestSchema = z.object({ grantId: z.string().uuid() }).strict();
const SIGNED_URL_TTL_SECONDS = 60;

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
  const parsed = DownloadRequestSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Invalid download grant." }, { status: 400 });

  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) return NextResponse.json({ error: "Authentication required." }, { status: 401 });

  try {
    const env = getServerEnv();
    const admin = createSupabaseAdminClient();
    const { data: grant, error: grantError } = await admin
      .from("download_grants")
      .select("id,customer_id,product_version_id,artifact_sha256,expires_at,revoked_at")
      .eq("id", parsed.data.grantId)
      .eq("customer_id", authData.user.id)
      .maybeSingle();
    if (grantError || !grant || grant.revoked_at || new Date(grant.expires_at).getTime() <= Date.now()) {
      return NextResponse.json({ error: "Download grant is invalid or expired." }, { status: 404 });
    }

    const { data: release, error: releaseError } = await admin
      .from("product_versions")
      .select("artifact_sha256,artifact_storage_path,release_state,released_at")
      .eq("id", grant.product_version_id)
      .maybeSingle();
    if (releaseError || !release || release.release_state !== "released" ||
      !release.released_at || release.artifact_sha256 !== grant.artifact_sha256 ||
      !release.artifact_storage_path || release.artifact_storage_path.startsWith("/") ||
      release.artifact_storage_path.split("/").some((segment: string) => segment === "." || segment === "..")) {
      return NextResponse.json({ error: "Released artifact is unavailable." }, { status: 404 });
    }

    // Create the URL before consuming the grant; do not return it unless the atomic
    // database function confirms the user still owns a live entitlement and order.
    const { data: signed, error: signingError } = await admin.storage
      .from(env.WEB_TEMIFY_ARTIFACT_BUCKET)
      .createSignedUrl(release.artifact_storage_path, SIGNED_URL_TTL_SECONDS, { download: true });
    if (signingError || !signed?.signedUrl) {
      return NextResponse.json({ error: "Secure download is temporarily unavailable." }, { status: 503 });
    }

    const { data: consumed, error: consumeError } = await session.rpc("consume_download_grant", {
      target_grant_id: grant.id
    });
    if (consumeError || consumed !== true) {
      return NextResponse.json({ error: "Download grant is no longer usable." }, { status: 403 });
    }

    return NextResponse.json({ downloadUrl: signed.signedUrl, expiresInSeconds: SIGNED_URL_TTL_SECONDS }, {
      status: 200,
      headers: { "Cache-Control": "private, no-store, max-age=0", "Referrer-Policy": "no-referrer" }
    });
  } catch {
    return NextResponse.json({ error: "Secure download is temporarily unavailable." }, { status: 503 });
  }
}
