import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { getAdminContext } from "@/server/admin/authorization";

export const runtime = "nodejs";
export const maxDuration = 15;

const SIGNED_URL_TTL_SECONDS = 60;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DIGEST_PATTERN = /^[a-f0-9]{64}$/;
const ALLOWED_CONTENT_TYPES = new Set([
  "application/pdf",
  "image/png",
  "image/jpeg",
  "text/plain",
  "application/octet-stream",
]);

type RouteContext = {
  params: Promise<{ disputeId: string; evidenceId: string }>;
};

function response(body: Record<string, unknown>, status: number) {
  return NextResponse.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

/**
 * Returns a short-lived signed URL only after the database verifies an admin,
 * a matching evidence/dispute pair, and a current clean digest-bound scan.
 * The database writes the access audit event before this route signs the URL.
 */
export async function GET(request: Request, context: RouteContext) {
  const adminContext = await getAdminContext("payment_dispute_evidence_access");
  if (!adminContext) return response({ error: "not_found" }, 404);

  const { disputeId, evidenceId } = await context.params;
  if (!UUID_PATTERN.test(disputeId) || !UUID_PATTERN.test(evidenceId)) {
    return response({ error: "invalid_evidence_reference" }, 400);
  }

  const requestId = randomUUID();
  const { data, error } = await adminContext.admin.rpc(
    "get_payment_dispute_evidence_for_admin",
    {
      p_dispute_id: disputeId,
      p_evidence_id: evidenceId,
      p_actor_id: adminContext.userId,
      p_request_id: requestId,
    },
  );

  if (error) {
    const status =
      error.code === "P0002"
        ? 404
        : error.code === "42501"
          ? 403
          : error.code === "55000"
            ? 409
            : 503;
    return response(
      {
        error:
          status === 404
            ? "evidence_not_found"
            : status === 403
              ? "evidence_access_forbidden"
              : status === 409
                ? "evidence_not_clean_or_scan_stale"
                : "evidence_access_unavailable",
        requestId,
      },
      status,
    );
  }

  if (!Array.isArray(data) || data.length !== 1) {
    return response({ error: "evidence_access_unavailable", requestId }, 503);
  }

  const evidence = data[0] as {
    storage_path?: unknown;
    source_sha256?: unknown;
    mime_type?: unknown;
    byte_size?: unknown;
    original_filename?: unknown;
    scan_id?: unknown;
    scanner_name?: unknown;
    scanner_version?: unknown;
    signature_updated_at?: unknown;
    scanned_at?: unknown;
  };

  if (
    typeof evidence.storage_path !== "string" ||
    typeof evidence.source_sha256 !== "string" ||
    !DIGEST_PATTERN.test(evidence.source_sha256) ||
    evidence.storage_path !==
      `${disputeId}/${evidenceId}/${evidence.source_sha256}` ||
    typeof evidence.mime_type !== "string" ||
    !ALLOWED_CONTENT_TYPES.has(evidence.mime_type) ||
    !Number.isSafeInteger(Number(evidence.byte_size)) ||
    Number(evidence.byte_size) < 1 ||
    Number(evidence.byte_size) > 5 * 1024 * 1024 ||
    typeof evidence.original_filename !== "string" ||
    evidence.original_filename.length < 1 ||
    evidence.original_filename.length > 180 ||
    typeof evidence.scan_id !== "string" ||
    typeof evidence.scanner_name !== "string" ||
    typeof evidence.scanner_version !== "string" ||
    typeof evidence.signature_updated_at !== "string" ||
    typeof evidence.scanned_at !== "string"
  ) {
    return response({ error: "evidence_access_invalid", requestId }, 503);
  }

  const { data: signed, error: signedUrlError } = await adminContext.admin.storage
    .from("payment-dispute-evidence")
    .createSignedUrl(evidence.storage_path, SIGNED_URL_TTL_SECONDS);

  if (signedUrlError || typeof signed?.signedUrl !== "string") {
    return response({ error: "evidence_storage_unavailable", requestId }, 503);
  }

  return response(
    {
      requestId,
      evidenceId,
      disputeId,
      signedUrl: signed.signedUrl,
      expiresInSeconds: SIGNED_URL_TTL_SECONDS,
      sha256: evidence.source_sha256,
      mimeType: evidence.mime_type,
      byteSize: Number(evidence.byte_size),
      filename: evidence.original_filename,
      scan: {
        id: evidence.scan_id,
        verdict: "clean",
        scannerName: evidence.scanner_name,
        scannerVersion: evidence.scanner_version,
        signatureUpdatedAt: evidence.signature_updated_at,
        scannedAt: evidence.scanned_at,
      },
    },
    200,
  );
}
