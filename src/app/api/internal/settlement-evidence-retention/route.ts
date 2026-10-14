import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
export const maxDuration = 30;

const STORAGE_BUCKET = "settlement-evidence";
const MAX_JOBS_PER_RUN = 10;
const STORAGE_PATH_PATTERN = /^([0-9a-f-]{36})\/([a-f0-9]{64})$/;

function tokenMatches(expected: string, supplied: string) {
  const expectedDigest = createHash("sha256").update(expected).digest();
  const suppliedDigest = createHash("sha256").update(supplied).digest();
  return timingSafeEqual(expectedDigest, suppliedDigest);
}

function authorized(request: Request, secret: string) {
  const header = request.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return false;
  return tokenMatches(secret, header.slice("Bearer ".length));
}

export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || secret.length < 32) {
    return NextResponse.json(
      { error: "retention_cron_secret_not_configured" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
  if (!authorized(request, secret)) {
    return NextResponse.json(
      { error: "unauthorized" },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  }

  const requestId = randomUUID();
  let admin;
  try {
    admin = createSupabaseAdminClient();
  } catch {
    return NextResponse.json(
      { error: "retention_worker_unavailable", requestId },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const { data: jobs, error: claimError } = await admin.rpc(
    "claim_settlement_evidence_retention_jobs",
    {
      p_limit: MAX_JOBS_PER_RUN,
      p_worker_id: "vercel-cron",
      p_request_id: requestId,
    },
  );
  if (claimError) {
    return NextResponse.json(
      { error: "retention_jobs_unavailable", requestId },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  let deleted = 0;
  let deferred = 0;
  let failed = 0;

  for (const job of jobs ?? []) {
    const { data: authorization, error: authorizationError } = await admin.rpc(
      "authorize_settlement_evidence_retention_deletion",
      {
        p_job_id: job.job_id,
        p_claim_token: job.claim_token,
        p_request_id: requestId,
      },
    );

    if (authorizationError) {
      failed += 1;
      continue;
    }

    const authorizedJob = Array.isArray(authorization)
      ? authorization[0]
      : authorization;
    if (!authorizedJob) {
      deferred += 1;
      continue;
    }

    const pathMatch =
      typeof authorizedJob.storage_path === "string"
        ? STORAGE_PATH_PATTERN.exec(authorizedJob.storage_path)
        : null;
    if (
      !pathMatch ||
      pathMatch[1] !== authorizedJob.evidence_id ||
      pathMatch[2] !== authorizedJob.source_sha256
    ) {
      const { error: completionError } = await admin.rpc(
        "complete_settlement_evidence_retention_job",
        {
          p_job_id: authorizedJob.job_id,
          p_claim_token: authorizedJob.claim_token,
          p_success: false,
          p_error_code: "unknown",
          p_request_id: requestId,
        },
      );
      if (completionError) failed += 1;
      else failed += 1;
      continue;
    }

    const { data: objects, error: listError } = await admin.storage
      .from(STORAGE_BUCKET)
      .list(pathMatch[1], { search: pathMatch[2], limit: 10 });

    if (listError) {
      const { error: completionError } = await admin.rpc(
        "complete_settlement_evidence_retention_job",
        {
          p_job_id: authorizedJob.job_id,
          p_claim_token: authorizedJob.claim_token,
          p_success: false,
          p_error_code: "storage_list_failed",
          p_request_id: requestId,
        },
      );
      if (completionError) failed += 1;
      else failed += 1;
      continue;
    }

    const objectExists = (objects ?? []).some(
      (object) => object.name === pathMatch[2],
    );
    if (objectExists) {
      const { error: removeError } = await admin.storage
        .from(STORAGE_BUCKET)
        .remove([authorizedJob.storage_path]);
      if (removeError) {
        const { error: completionError } = await admin.rpc(
          "complete_settlement_evidence_retention_job",
          {
            p_job_id: authorizedJob.job_id,
            p_claim_token: authorizedJob.claim_token,
            p_success: false,
            p_error_code: "storage_delete_failed",
            p_request_id: requestId,
          },
        );
        if (completionError) failed += 1;
        else failed += 1;
        continue;
      }
    }

    const { error: completionError } = await admin.rpc(
      "complete_settlement_evidence_retention_job",
      {
        p_job_id: authorizedJob.job_id,
        p_claim_token: authorizedJob.claim_token,
        p_success: true,
        p_error_code: null,
        p_request_id: requestId,
      },
    );
    if (completionError) {
      failed += 1;
      continue;
    }
    deleted += 1;
  }

  return NextResponse.json(
    {
      requestId,
      claimed: jobs?.length ?? 0,
      deleted,
      deferred,
      failed,
    },
    { status: 200, headers: { "Cache-Control": "no-store" } },
  );
}
