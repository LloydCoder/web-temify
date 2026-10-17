import { randomUUID, timingSafeEqual } from "node:crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const maxDuration = 60;

const MAX_BATCH_SIZE = 3;
const MIN_TOKEN_LENGTH = 32;

type NotificationJob = {
  job_id: string;
  case_id: string;
  event_type: string;
  case_status: string;
  recipient_kind: "requester" | "operations";
  recipient_user_id: string | null;
  attempts: number;
};

function isAuthorized(request: Request) {
  const expectedToken = process.env.SUPPORT_NOTIFICATION_WORKER_TOKEN;
  const authorization = request.headers.get("authorization");
  const supplied = authorization?.match(/^Bearer\s+(\S+)$/i)?.[1];

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

function eventLabel(eventType: string) {
  const labels: Record<string, string> = {
    created: "created",
    triaged: "triaged",
    waiting_on_requester: "waiting for your response",
    escalated: "escalated",
    resolved: "resolved",
    closed: "closed",
    reopened: "reopened",
    assigned: "assigned",
  };
  return labels[eventType] ?? "updated";
}

async function sendNotification(
  job: NotificationJob,
  client: SupabaseClient,
  apiKey: string,
  from: string,
  operationsEmail: string,
  siteUrl: string,
) {
  let recipient: string;

  if (job.recipient_kind === "operations") {
    recipient = operationsEmail;
  } else {
    if (!job.recipient_user_id) return "recipient_unavailable";
    const { data, error } = await client.auth.admin.getUserById(
      job.recipient_user_id,
    );
    if (error || !data.user?.email) return "recipient_unavailable";
    recipient = data.user.email;
  }

  const action = eventLabel(job.event_type);
  const link =
    job.recipient_kind === "operations"
      ? `${siteUrl}/admin/support?caseId=${encodeURIComponent(job.case_id)}`
      : `${siteUrl}/support`;
  const subject = `Web-Temify support case ${job.case_id} ${action}`;
  const body = [
    "A Web-Temify support case event needs your attention.",
    "",
    `Case reference: ${job.case_id}`,
    `Event: ${action}`,
    `Status at event time: ${job.case_status}`,
    "",
    `Open the relevant support page: ${link}`,
    "",
    "This notification deliberately excludes case descriptions, private notes, payment details, and credentials.",
  ].join("\n");

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to: [recipient], subject, text: body }),
      signal: AbortSignal.timeout(12_000),
    });
    return response.ok ? null : "email_provider_rejected";
  } catch {
    return "email_provider_unavailable";
  }
}

async function runWorker(request: Request) {
  if (!isAuthorized(request)) {
    return NextResponse.json(
      { error: "unauthorized" },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  }

  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.SUPPORT_FROM_EMAIL;
  const operationsEmail = process.env.SUPPORT_OPERATIONS_EMAIL;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL;
  const client = createWorkerClient();

  if (
    !apiKey ||
    !from ||
    !operationsEmail ||
    !siteUrl ||
    !client ||
    !/^https:\/\//.test(siteUrl)
  ) {
    return NextResponse.json(
      { error: "support_notification_worker_not_configured" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  const requestId = randomUUID();
  const { data, error } = await client.rpc("claim_support_notification_jobs", {
    p_limit: MAX_BATCH_SIZE,
    p_request_id: requestId,
  });

  if (error || !Array.isArray(data)) {
    return NextResponse.json(
      { error: "support_notification_claim_failed", requestId },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  let sent = 0;
  let retryable = 0;
  let blocked = 0;

  for (const job of data as NotificationJob[]) {
    if (
      !job ||
      !/^[0-9a-f-]{36}$/i.test(job.job_id) ||
      !/^[0-9a-f-]{36}$/i.test(job.case_id) ||
      !["requester", "operations"].includes(job.recipient_kind) ||
      !Number.isInteger(job.attempts) ||
      job.attempts < 1 ||
      job.attempts > 5
    ) {
      return NextResponse.json(
        { error: "support_notification_claim_invalid", requestId, sent },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    const deliveryError = await sendNotification(
      job,
      client,
      apiKey,
      from,
      operationsEmail,
      siteUrl.replace(/\/$/, ""),
    );
    const { data: nextStatus, error: finishError } = await client.rpc(
      "finish_support_notification_job",
      {
        p_job_id: job.job_id,
        p_request_id: requestId,
        p_sent: deliveryError === null,
        p_error_code: deliveryError,
      },
    );

    if (finishError || typeof nextStatus !== "string") {
      return NextResponse.json(
        {
          error: "support_notification_completion_failed",
          requestId,
          sent,
          retryable,
          blocked,
        },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    if (deliveryError === null && nextStatus === "sent") {
      sent += 1;
    } else if (nextStatus === "retryable") {
      retryable += 1;
    } else if (nextStatus === "blocked") {
      blocked += 1;
    } else {
      return NextResponse.json(
        { error: "support_notification_state_invalid", requestId, sent },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }
  }

  return NextResponse.json(
    {
      requestId,
      claimed: data.length,
      sent,
      retryable,
      blocked,
      maxBatchSize: MAX_BATCH_SIZE,
    },
    {
      status: retryable > 0 || blocked > 0 ? 503 : 200,
      headers: { "Cache-Control": "no-store" },
    },
  );
}

export async function GET(request: Request) {
  return runWorker(request);
}

export async function POST(request: Request) {
  return runWorker(request);
}
