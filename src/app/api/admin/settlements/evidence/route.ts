import { createHash, randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBytes } from "@/server/commerce/read-bounded-bytes";
import { scanSettlementEvidence } from "@/server/commerce/settlement-evidence-scanner";

export const runtime = "nodejs";
export const maxDuration = 30;

const MAX_EVIDENCE_BYTES = 5 * 1024 * 1024;
const ALLOWED_CONTENT_TYPES = new Set([
  "text/csv",
  "application/json",
  "application/pdf",
  "application/octet-stream",
]);

function safeFilename(value: string | null) {
  const cleaned = (value ?? "settlement-evidence.bin")
    .replace(/[\\/]/g, "_")
    .replace(/[^a-zA-Z0-9._-]/g, "_")
    .replace(/^\.+/, "")
    .slice(0, 180);
  return cleaned || "settlement-evidence.bin";
}

export async function POST(request: Request) {
  const context = await getAdminContext("settlement_evidence_upload");
  if (!context) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  const requestId = randomUUID();
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required", requestId },
      { status: 403 },
    );
  }

  const contentType = request.headers
    .get("content-type")
    ?.split(";")[0]
    ?.trim()
    .toLowerCase();
  if (!contentType || !ALLOWED_CONTENT_TYPES.has(contentType)) {
    return NextResponse.json(
      { error: "unsupported_evidence_content_type", requestId },
      { status: 415 },
    );
  }

  const body = await readBoundedRequestBytes(request, MAX_EVIDENCE_BYTES);
  if (!body.ok) {
    const tooLarge = body.reason === "too_large";
    return NextResponse.json(
      {
        error: tooLarge ? "evidence_file_too_large" : "invalid_evidence_body",
        requestId,
      },
      { status: tooLarge ? 413 : 400 },
    );
  }
  if (body.bytes.byteLength === 0) {
    return NextResponse.json(
      { error: "empty_evidence_file", requestId },
      { status: 400 },
    );
  }

  const sourceSha256 = createHash("sha256").update(body.bytes).digest("hex");
  const evidenceId = randomUUID();
  const storagePath = `${evidenceId}/${sourceSha256}`;
  const filename = safeFilename(request.headers.get("x-evidence-filename"));

  const { error: intentError } = await context.admin
    .from("audit_events")
    .insert({
      actor_id: context.userId,
      action: "settlement.evidence.upload_requested",
      entity_type: "settlement_evidence",
      entity_id: evidenceId,
      request_id: requestId,
      metadata: {
        source_sha256: sourceSha256,
        byte_size: body.bytes.byteLength,
        content_type: contentType,
      },
    });
  if (intentError) {
    return NextResponse.json(
      { error: "settlement_audit_unavailable", requestId },
      { status: 503 },
    );
  }

  const { error: storageError } = await context.admin.storage
    .from("settlement-evidence")
    .upload(storagePath, body.bytes, {
      contentType,
      cacheControl: "0",
      upsert: false,
    });
  if (storageError) {
    return NextResponse.json(
      { error: "settlement_evidence_storage_unavailable", requestId },
      { status: 503 },
    );
  }

  const { error: recordError } = await context.admin.rpc(
    "record_settlement_evidence",
    {
      p_id: evidenceId,
      p_storage_path: storagePath,
      p_source_sha256: sourceSha256,
      p_mime_type: contentType,
      p_byte_size: body.bytes.byteLength,
      p_original_filename: filename,
      p_uploaded_by: context.userId,
      p_request_id: requestId,
    },
  );
  if (recordError) {
    await context.admin.storage
      .from("settlement-evidence")
      .remove([storagePath]);
    return NextResponse.json(
      { error: "settlement_evidence_record_failed", requestId },
      { status: recordError.code === "42501" ? 403 : 503 },
    );
  }

  const scan = await scanSettlementEvidence(body.bytes, sourceSha256);
  let scanStatus: "pending" | "clean" | "infected" | "error" = "pending";

  if (
    scan.status === "clean" ||
    scan.status === "infected" ||
    scan.status === "error"
  ) {
    const { error: scanRecordError } = await context.admin.rpc(
      "record_settlement_evidence_scan_result",
      {
        p_evidence_id: evidenceId,
        p_source_sha256: sourceSha256,
        p_verdict: scan.status,
        p_scanner_name: scan.scannerName,
        p_scanner_version: scan.scannerVersion,
        p_request_id: requestId,
      },
    );

    if (scanRecordError) {
      return NextResponse.json(
        {
          error: "settlement_evidence_scan_record_failed",
          requestId,
          scanStatus: "pending",
        },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    scanStatus = scan.status;
  }

  return NextResponse.json(
    {
      id: evidenceId,
      sha256: sourceSha256,
      byteSize: body.bytes.byteLength,
      filename,
      requestId,
      scanStatus,
      sourceAuthenticity: "not_verified",
    },
    {
      status:
        scanStatus === "clean"
          ? 201
          : scanStatus === "infected"
            ? 422
            : 202,
      headers: { "Cache-Control": "no-store" },
    },
  );
}
