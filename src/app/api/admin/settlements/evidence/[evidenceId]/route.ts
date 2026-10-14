import { createHash, randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";

export const runtime = "nodejs";

const evidenceIdSchema = z.string().uuid();

function safeDownloadFilename(value: string) {
  const cleaned = value
    .replace(/[\\/]/g, "_")
    .replace(/[^a-zA-Z0-9._-]/g, "_")
    .replace(/^\.+/, "")
    .slice(0, 180);
  return cleaned || "settlement-evidence.bin";
}

export async function GET(
  request: Request,
  context: { params: Promise<{ evidenceId: string }> },
) {
  const adminContext = await getAdminContext("settlement_evidence_download");
  if (!adminContext) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  const requestId = randomUUID();
  const origin = request.headers.get("origin");
  if (origin && origin !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required", requestId },
      { status: 403 },
    );
  }

  const { evidenceId } = await context.params;
  const parsedId = evidenceIdSchema.safeParse(evidenceId);
  if (!parsedId.success) {
    return NextResponse.json(
      { error: "invalid_evidence_id", requestId },
      { status: 400 },
    );
  }

  const { error: accessAuditError } = await adminContext.admin
    .from("audit_events")
    .insert({
      actor_id: adminContext.userId,
      action: "settlement.evidence.download_requested",
      entity_type: "settlement_evidence",
      entity_id: parsedId.data,
      request_id: requestId,
      metadata: {},
    });
  if (accessAuditError) {
    return NextResponse.json(
      { error: "settlement_audit_unavailable", requestId },
      { status: 503 },
    );
  }

  const { data: evidence, error: metadataError } = await adminContext.admin
    .from("settlement_evidence")
    .select("id, storage_path, source_sha256, byte_size, original_filename")
    .eq("id", parsedId.data)
    .maybeSingle();

  if (metadataError) {
    return NextResponse.json(
      { error: "settlement_evidence_unavailable", requestId },
      { status: 503 },
    );
  }
  if (!evidence) {
    return NextResponse.json(
      { error: "not_found", requestId },
      { status: 404 },
    );
  }

  const { data: file, error: storageError } = await adminContext.admin.storage
    .from("settlement-evidence")
    .download(evidence.storage_path);
  if (storageError || !file) {
    return NextResponse.json(
      { error: "settlement_evidence_unavailable", requestId },
      { status: 503 },
    );
  }

  const bytes = new Uint8Array(await file.arrayBuffer());
  const actualSha256 = createHash("sha256").update(bytes).digest("hex");
  if (
    bytes.byteLength !== Number(evidence.byte_size) ||
    actualSha256 !== evidence.source_sha256
  ) {
    await adminContext.admin.from("audit_events").insert({
      actor_id: adminContext.userId,
      action: "settlement.evidence.integrity_check_failed",
      entity_type: "settlement_evidence",
      entity_id: evidence.id,
      request_id: requestId,
      metadata: {
        expected_sha256: evidence.source_sha256,
        actual_sha256: actualSha256,
        expected_byte_size: evidence.byte_size,
        actual_byte_size: bytes.byteLength,
      },
    });
    return NextResponse.json(
      { error: "settlement_evidence_integrity_failure", requestId },
      { status: 503 },
    );
  }

  const filename = safeDownloadFilename(evidence.original_filename);
  const downloadBuffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(downloadBuffer).set(bytes);
  return new Response(downloadBuffer, {
    status: 200,
    headers: {
      "Content-Type": "application/octet-stream",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Content-Length": String(bytes.byteLength),
      "Cache-Control": "no-store, max-age=0",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "X-Request-Id": requestId,
    },
  });
}
