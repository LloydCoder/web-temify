import { timingSafeEqual, randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const maxDuration = 60;

const MAX_BATCH_SIZE = 25;
const MIN_TOKEN_LENGTH = 32;

function authorized(request: Request, expectedToken: string | undefined) {
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!expectedToken || expectedToken.length < MIN_TOKEN_LENGTH || !supplied) {
    return false;
  }
  const expected = Buffer.from(expectedToken, "utf8");
  const actual = Buffer.from(supplied, "utf8");
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

function createRetentionClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!url || !secret) return null;
  return createClient(url, secret, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

type RetentionClaim = {
  evidence_id: string;
  storage_path: string;
  source_sha256: string;
  byte_size: number;
};

export async function POST(request: Request) {
  if (!authorized(request, process.env.SETTLEMENT_EVIDENCE_RETENTION_TOKEN)) {
    return NextResponse.json(
      { error: "unauthorized" },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  }

  const client = createRetentionClient();
  if (!client) {
    return NextResponse.json(
      { error: "retention_worker_not_configured" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const requestId = randomUUID();
  const { data, error } = await client.rpc(
    "claim_expired_settlement_evidence",
    {
    p_limit: MAX_BATCH_SIZE,
      p_request_id: requestId,
    },
  );

  if (error || !Array.isArray(data)) {
    return NextResponse.json(
      { error: "retention_claim_failed", requestId },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const claims = data as RetentionClaim[];
  let deleted = 0;
  let retryable = 0;

  for (const claim of claims) {
    if (
      !claim ||
      typeof claim.evidence_id !== "string" ||
      typeof claim.storage_path !== "string" ||
      !/^[0-9a-f-]{36}\/[a-f0-9]{64}$/.test(claim.storage_path) ||
      claim.storage_path.split("/")[0] !== claim.evidence_id ||
      !/^[a-f0-9]{64}$/.test(claim.source_sha256) ||
      !Number.isSafeInteger(Number(claim.byte_size)) ||
      Number(claim.byte_size) < 1 ||
      Number(claim.byte_size) > 5 * 1024 * 1024
    ) {
      return NextResponse.json(
        { error: "retention_claim_invalid", requestId },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    const bucket = client.storage.from("settlement-evidence");
    const { error: storageError } = await bucket.remove([claim.storage_path]);
    let deletionConfirmed = !storageError;

    if (storageError) {
      // A previous run may have removed the object but failed before recording
      // completion. Confirm absence before scheduling another destructive retry.
      const { data: remainingObjects, error: listError } = await bucket.list(
        claim.evidence_id,
        { limit: 10, search: claim.source_sha256 },
      );
      deletionConfirmed =
        !listError &&
        Array.isArray(remainingObjects) &&
        !remainingObjects.some((object) => object.name === claim.source_sha256);
    }

    const { data: completionStatus, error: completionError } = await client.rpc(
      "finish_settlement_evidence_retention",
      {
        p_evidence_id: claim.evidence_id,
        p_request_id: requestId,
        p_deleted: deletionConfirmed,
        p_error_code: deletionConfirmed ? null : "storage_delete_failed",
      },
    );

    if (completionError || typeof completionStatus !== "string") {
      // A storage delete may have succeeded before the completion RPC failed.
      // The lease allows a later run to retry the idempotent object removal.
      return NextResponse.json(
        { error: "retention_completion_failed", requestId, deleted, retryable },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    if (!deletionConfirmed || completionStatus !== "deleted") {
      retryable += 1;
    } else {
      deleted += 1;
    }
  }

  return NextResponse.json(
    {
      requestId,
      claimed: claims.length,
      deleted,
      retryable,
      maxBatchSize: MAX_BATCH_SIZE,
    },
    { status: 200, headers: { "Cache-Control": "no-store" } },
  );
}
