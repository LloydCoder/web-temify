import { NextResponse } from "next/server";
import { getServerEnv } from "@/lib/env";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { SandboxPaymentEventSchema, ingestVerifiedSandboxEvent } from "@/server/commerce/webhook";
import { verifySandboxWebhookSignature } from "@/server/commerce/webhook-signature";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";
const MAX_WEBHOOK_BYTES = 64 * 1024;

export async function POST(request: Request) {
  const env = getServerEnv();
  if (process.env.NODE_ENV === "production" || env.PAYMENT_PROVIDER !== "sandbox") {
    return NextResponse.json({ error: "Payment webhook provider is not enabled." }, { status: 503 });
  }
  const secret = env.PAYMENT_WEBHOOK_SECRET ?? "";
  if (secret.length < 32) {
    return NextResponse.json({ error: "Webhook verification is not configured." }, { status: 503 });
  }
  // Enforce the limit during streaming, before creating the full body string.
  const boundedBody = await readBoundedRequestBody(request, MAX_WEBHOOK_BYTES);
  if (!boundedBody.ok) {
    if (boundedBody.reason === "too_large") {
      return NextResponse.json({ error: "Webhook payload is too large." }, { status: 413 });
    }
    return NextResponse.json({ error: "Invalid webhook request body." }, { status: 400 });
  }
  const rawBody = boundedBody.body;
  const eventId = request.headers.get("x-web-temify-event-id") ?? "";
  const timestamp = request.headers.get("x-web-temify-timestamp") ?? "";
  const signature = request.headers.get("x-web-temify-signature") ?? "";
  if (!verifySandboxWebhookSignature({ rawBody, eventId, timestamp, signature, secret })) {
    return NextResponse.json({ error: "Invalid webhook signature." }, { status: 401 });
  }

  let untrusted: unknown;
  try {
    untrusted = JSON.parse(rawBody);
  } catch {
    return NextResponse.json({ error: "Invalid webhook JSON." }, { status: 400 });
  }
  const parsed = SandboxPaymentEventSchema.safeParse(untrusted);
  if (!parsed.success || parsed.data.id !== eventId) {
    return NextResponse.json({ error: "Invalid webhook event schema or event ID." }, { status: 400 });
  }

  try {
    const result = await ingestVerifiedSandboxEvent(createSupabaseAdminClient(), parsed.data, rawBody);
    if (result.kind === "conflict") {
      return NextResponse.json({ error: "Event ID was reused with a different payload." }, { status: 409 });
    }
    if (result.kind === "retry") {
      return NextResponse.json({ error: "Event accepted but processing did not complete; retry safely." }, { status: 503 });
    }
    return NextResponse.json({ received: true }, { status: 200, headers: { "Cache-Control": "no-store" } });
  } catch {
    return NextResponse.json({ error: "Webhook processing is temporarily unavailable." }, { status: 503 });
  }
}
