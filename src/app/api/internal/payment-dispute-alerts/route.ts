import { randomUUID, timingSafeEqual } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const maxDuration = 60;

const MAX_BATCH_SIZE = 3;
const MIN_TOKEN_LENGTH = 32;

type DisputeAlertJob = {
  job_id: string;
  dispute_id: string;
  provider: string;
  provider_dispute_id: string;
  dispute_status: string;
  alert_kind: "due_soon" | "overdue";
  evidence_due_at: string;
  attempts: number;
};

function isAuthorized(request: Request) {
  const expectedToken =
    process.env.PAYMENT_DISPUTE_ALERT_WORKER_TOKEN ||
    process.env.SUPPORT_NOTIFICATION_WORKER_TOKEN ||
    process.env.CRON_SECRET;
  const supplied = request.headers
    .get("authorization")
    ?.match(/^Bearer\s+(\S+)$/i)?.[1];

  if (!expectedToken || expectedToken.length < MIN_TOKEN_LENGTH || !supplied) {
    return false;
  }

  const expected = Buffer.from(expectedToken, "utf8");
  const actual = Buffer.from(supplied, "utf8");
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

function createWorkerClient() {
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

async function sendAlert(
  job: DisputeAlertJob,
  apiKey: string,
  from: string,
  operationsEmail: string,
  siteUrl: string,
) {
  const deadline = new Date(job.evidence_due_at);
  if (Number.isNaN(deadline.getTime())) return "invalid_deadline";
  const urgency =
    job.alert_kind === "overdue" ? "OVERDUE" : "DUE WITHIN 48 HOURS";
  const subject = `[Web-Temify] Payment dispute evidence deadline ${urgency}`;
  const body = [
    "A payment-dispute deadline needs operations review.",
    "",
    `Provider: ${job.provider}`,
    `Provider dispute reference: ${job.provider_dispute_id}`,
    `Internal dispute reference: ${job.dispute_id}`,
    `Current status: ${job.dispute_status}`,
    `Deadline (UTC): ${deadline.toISOString()}`,
    `Alert: ${urgency}`,
    "",
    `Open the restricted operations console: ${siteUrl}/admin/financial-controls`,
    "",
    "This automated alert does not submit evidence, change dispute state, or move funds.",
  ].join("\n");

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [operationsEmail],
        subject,
        text: body,
      }),
      signal: AbortSignal.timeout(12_000),
    });
    return response.ok ? null : "email_provider_rejected";
  } catch {
    return "email_provider_unavailable";
  }
}

export async function POST(request: Request) {
  if (!isAuthorized(request)) {
    return NextResponse.json(
      { error: "unauthorized" },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  }

  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.SUPPORT_FROM_EMAIL;
  const operationsEmail = process.env.DISPUTE_OPERATIONS_EMAIL;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL;
  const client = createWorkerClient();

  if (!apiKey || !from || !operationsEmail || !siteUrl || !client) {
    return NextResponse.json(
      { error: "worker_not_configured" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const requestId = randomUUID();
  const enqueue = await client.rpc("enqueue_payment_dispute_deadline_alerts", {
    p_now: new Date().toISOString(),
  });
  if (enqueue.error) {
    return NextResponse.json(
      { error: "alert_enqueue_failed" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const claimed = await client.rpc("claim_payment_dispute_alert_jobs", {
    p_limit: MAX_BATCH_SIZE,
    p_request_id: requestId,
  });
  if (claimed.error || !Array.isArray(claimed.data)) {
    return NextResponse.json(
      { error: "alert_claim_failed" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  let sent = 0;
  let retryable = 0;
  let blocked = 0;

  for (const rawJob of claimed.data as DisputeAlertJob[]) {
    if (
      !rawJob ||
      typeof rawJob.job_id !== "string" ||
      typeof rawJob.dispute_id !== "string" ||
      typeof rawJob.provider_dispute_id !== "string" ||
      !["due_soon", "overdue"].includes(rawJob.alert_kind) ||
      !["open", "needs_evidence"].includes(rawJob.dispute_status)
    ) {
      return NextResponse.json(
        { error: "invalid_claimed_alert" },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    const errorCode = await sendAlert(
      rawJob,
      apiKey,
      from,
      operationsEmail,
      siteUrl,
    );
    const finished = await client.rpc("finish_payment_dispute_alert_job", {
      p_job_id: rawJob.job_id,
      p_request_id: requestId,
      p_success: errorCode === null,
      p_error_code: errorCode,
    });

    if (finished.error || typeof finished.data !== "string") {
      return NextResponse.json(
        { error: "alert_completion_failed" },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    if (finished.data === "sent") sent += 1;
    else if (finished.data === "blocked") blocked += 1;
    else retryable += 1;
  }

  return NextResponse.json(
    {
      claimed: claimed.data.length,
      sent,
      retryable,
      blocked,
      scanned: typeof enqueue.data === "number" ? enqueue.data : 0,
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}

