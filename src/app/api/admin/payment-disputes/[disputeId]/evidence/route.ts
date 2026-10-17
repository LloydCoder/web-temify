import { createHash, randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBytes } from "@/server/commerce/read-bounded-bytes";
import { scanSettlementEvidence } from "@/server/commerce/settlement-evidence-scanner";

export const runtime = "nodejs";
export const maxDuration = 30;

const MAX_EVIDENCE_BYTES = 5 * 1024 * 1024;
const ALLOWED_CONTENT_TYPES = new Set([
  "application/pdf",
  "image/png",
  "image/jpeg",
  "text/plain",
  "application/octet-stream",
]);
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function response(body: Record<string, unknown>, status: number) {
  return NextResponse.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

function safeFilename(value: string | null) {
  const cleaned = (value ?? "dispute-evidence.bin")
    .replace(/[\\/]/g, "_")
    .replace(/[^a-zA-Z0-9._-]/g, "_")
    .replace(/^\.+/, "")
    .slice(0, 180);
  return cleaned || "dispute-evidence.bin";
}

function contentMatchesDeclaredType(contentType: string, bytes: Uint8Array) {
  if (contentType === "application/octet-stream") return true;
  if (contentType === "application/pdf") {
    return Buffer.from(bytes.subarray(0, 5)).toString("ascii") === "%PDF-";
  }
  if (contentType === "image/png") {
    return Buffer.from(bytes.subarray(0, 8)).equals(
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    );
  }
  if (contentType === "image/jpeg") {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (contentType === "text/plain") {
    if (bytes.includes(0)) return false;
    try {
      new TextDecoder("utf-8", { fatal: true }).decode(bytes);
      return true;
    } catch {
      return false;
    }
  }
  return false;
}

type RouteContext = {
  params: Promise<{ disputeId: string }>;
};

/**
 * Stores private evidence and records a digest-bound malware scan result.
 * A clean scan is necessary for later provider submission, but does not prove
 * provider authenticity and does not submit the evidence or change dispute state.
 */
export async function POST(request: Request, context: RouteContext) {
  const adminContext = await getAdminContext("payment_dispute_evidence_upload");
  if (!adminContext) return response({ error: "not_found" }, 404);

  const requestId = randomUUID();
  const { disputeId } = await context.params;
  if (!UUID_PATTERN.test(disputeId)) {
    return response({ error: "invalid_dispute_id", requestId }, 400);
  }

  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return response({ error: "same_origin_required", requestId }, 403);
  }

  const contentType = request.headers
    .get("content-type")
    ?.split(";")[0]
    ?.trim()
    .toLowerCase();
  if (!contentType || !ALLOWED_CONTENT_TYPES.has(contentType)) {
    return response(
      { error: "unsupported_evidence_content_type", requestId },
      415,
    );
  }

  const body = await readBoundedRequestBytes(request, MAX_EVIDENCE_BYTES);
  if (!body.ok) {
    return response(
      {
        error:
          body.reason === "too_large"
            ? "evidence_file_too_large"
            : "invalid_evidence_body",
        requestId,
      },
      body.reason === "too_large" ? 413 : 400,
    );
  }
  if (body.bytes.byteLength === 0) {
    return response({ error: "empty_evidence_file", requestId }, 400);
  }
  if (!contentMatchesDeclaredType(contentType, body.bytes)) {
    return response({ error: "evidence_content_type_mismatch", requestId }, 415);
  }

  const { data: dispute, error: disputeError } = await adminContext.admin
    .from("payment_disputes")
    .select("id,status")
    .eq("id", disputeId)
    .maybeSingle();

  if (disputeError) {
    return response({ error: "dispute_lookup_unavailable", requestId }, 503);
  }
  if (!dispute) {
    return response({ error: "dispute_not_found", requestId }, 404);
  }
  if (dispute.status !== "open" && dispute.status !== "needs_evidence") {
    return response(
      { error: "dispute_not_accepting_evidence", requestId },
      409,
    );
  }

  const sourceSha256 = createHash("sha256").update(body.bytes).digest("hex");
  const evidenceId = randomUUID();
  const storagePath = `${disputeId}/${evidenceId}/${sourceSha256}`;
  const filename = safeFilename(request.headers.get("x-evidence-filename"));

  const { error: intentError } = await adminContext.admin
    .from("audit_events")
    .insert({
      actor_id: adminContext.userId,
      action: "payment_dispute.evidence.upload_requested",
      entity_type: "payment_dispute_evidence",
      entity_id: evidenceId,
      request_id: requestId,
      metadata: {
        dispute_id: disputeId,
        source_sha256: sourceSha256,
        byte_size: body.bytes.byteLength,
        content_type: contentType,
      },
    });
  if (intentError) {
    return response({ error: "evidence_audit_unavailable", requestId }, 503);
  }

  const bucket = adminContext.admin.storage.from("payment-dispute-evidence");
  const { error: storageError } = await bucket.upload(storagePath, body.bytes, {
    contentType,
    cacheControl: "0",
    upsert: false,
  });
  if (storageError) {
    return response({ error: "evidence_storage_unavailable", requestId }, 503);
  }

  const { error: recordError } = await adminContext.admin.rpc(
    "record_payment_dispute_evidence",
    {
      p_id: evidenceId,
      p_dispute_id: disputeId,
      p_storage_path: storagePath,
      p_source_sha256: sourceSha256,
      p_mime_type: contentType,
      p_byte_size: body.bytes.byteLength,
      p_original_filename: filename,
      p_uploaded_by: adminContext.userId,
      p_request_id: requestId,
    },
  );
  if (recordError) {
    await bucket.remove([storagePath]);
    return response(
      {
        error:
          recordError.code === "42501"
            ? "evidence_upload_forbidden"
            : "evidence_record_failed",
        requestId,
      },
      recordError.code === "42501" ? 403 : 503,
    );
  }

  const scan = await scanSettlementEvidence(body.bytes, sourceSha256);
  let scanStatus: "pending" | "clean" | "infected" | "error" = "pending";

  if (
    (scan.status === "clean" ||
      scan.status === "infected" ||
      scan.status === "error") &&
    scan.sha256 !== sourceSha256
  ) {
    return response(
      {
        error: "evidence_scan_digest_mismatch",
        requestId,
        scanStatus: "pending",
      },
      503,
    );
  }

  if (
    scan.status === "clean" ||
    scan.status === "infected" ||
    scan.status === "error"
  ) {
    const { error: scanRecordError } = await adminContext.admin.rpc(
      "record_payment_dispute_evidence_scan_result",
      {
        p_evidence_id: evidenceId,
        p_source_sha256: sourceSha256,
        p_verdict: scan.status,
        p_scanner_name: scan.scannerName,
        p_scanner_version: scan.scannerVersion,
        p_signature_updated_at: scan.signatureUpdatedAt,
        p_request_id: requestId,
      },
    );

    if (scanRecordError) {
      return response(
        {
          error: "evidence_scan_record_failed",
          requestId,
          scanStatus: "pending",
        },
        503,
      );
    }
    scanStatus = scan.status;
  }

  return response(
    {
      id: evidenceId,
      disputeId,
      sha256: sourceSha256,
      byteSize: body.bytes.byteLength,
      filename,
      requestId,
      scanStatus,
      providerSubmission: "not_submitted",
      sourceAuthenticity: "not_verified",
    },
    scanStatus === "clean" ? 201 : scanStatus === "infected" ? 422 : 202,
  );
}
