import { NextResponse } from "next/server";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";
import { z } from "zod";
import { getServerEnv } from "@/lib/env";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import {
  SandboxPaymentEventSchema,
  ingestVerifiedSandboxEvent,
} from "@/server/commerce/webhook";
import {
  signSandboxWebhook,
  verifySandboxWebhookSignature,
} from "@/server/commerce/webhook-signature";

export const runtime = "nodejs";
const CompleteSchema = z
  .object({ paymentAttemptId: z.string().uuid() })
  .strict();

export async function POST(request: Request) {
  const env = getServerEnv();
  if (
    process.env.NODE_ENV === "production" ||
    env.PAYMENT_PROVIDER !== "sandbox"
  ) {
    return NextResponse.json(
      { error: "Sandbox completion is disabled." },
      { status: 404 },
    );
  }
  const secret = env.PAYMENT_WEBHOOK_SECRET ?? "";
  if (secret.length < 32)
    return NextResponse.json(
      { error: "Sandbox checkout is not configured." },
      { status: 503 },
    );

  const boundedBody = await readBoundedRequestBody(request, 32 * 1024);
  if (!boundedBody.ok) {
    const tooLarge = boundedBody.reason === "too_large";
    return NextResponse.json(
      {
        error: tooLarge
          ? "Request body is too large."
          : "Invalid request body.",
      },
      { status: tooLarge ? 413 : 400 },
    );
  }
  let body: unknown;
  try {
    body = JSON.parse(boundedBody.body);
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }
  const parsed = CompleteSchema.safeParse(body);
  if (!parsed.success)
    return NextResponse.json(
      { error: "Invalid payment attempt." },
      { status: 400 },
    );

  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user)
    return NextResponse.json(
      { error: "Authentication required." },
      { status: 401 },
    );

  try {
    const admin = createSupabaseAdminClient();
    const { data: attempt, error: attemptError } = await admin
      .from("payment_attempts")
      .select("id,order_id,provider,status,amount_minor,currency")
      .eq("id", parsed.data.paymentAttemptId)
      .maybeSingle();
    if (attemptError || !attempt || attempt.provider !== "sandbox") {
      return NextResponse.json(
        { error: "Payment attempt not found." },
        { status: 404 },
      );
    }
    const { data: ownedOrder, error: ownershipError } = await session
      .from("orders")
      .select("id")
      .eq("id", attempt.order_id)
      .maybeSingle();
    if (ownershipError || !ownedOrder)
      return NextResponse.json(
        { error: "Payment attempt not found." },
        { status: 404 },
      );
    if (!["created", "pending", "succeeded"].includes(attempt.status)) {
      return NextResponse.json(
        { error: "Payment attempt is not eligible for sandbox completion." },
        { status: 409 },
      );
    }

    const event = SandboxPaymentEventSchema.parse({
      id: `sandbox-payment-${attempt.id}`,
      type: "payment.succeeded",
      orderId: attempt.order_id,
      paymentAttemptId: attempt.id,
      amountMinor: attempt.amount_minor,
      currency: attempt.currency,
      providerReference: `sandbox-charge-${attempt.id}`,
    });
    const rawBody = JSON.stringify(event);
    const timestamp = String(Math.floor(Date.now() / 1000));
    const signature = signSandboxWebhook(rawBody, event.id, timestamp, secret);
    if (
      !verifySandboxWebhookSignature({
        rawBody,
        eventId: event.id,
        timestamp,
        signature,
        secret,
      })
    ) {
      return NextResponse.json(
        { error: "Sandbox signature self-check failed." },
        { status: 500 },
      );
    }
    const result = await ingestVerifiedSandboxEvent(admin, event, rawBody);
    if (result.kind === "conflict")
      return NextResponse.json(
        { error: "Sandbox event identity conflict." },
        { status: 409 },
      );
    if (result.kind === "retry")
      return NextResponse.json(
        { error: "Payment processing is pending retry." },
        { status: 503 },
      );
    return NextResponse.json(
      { orderId: attempt.order_id, status: "paid", sandboxOnly: true },
      { status: 200, headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "Sandbox completion is temporarily unavailable." },
      { status: 503 },
    );
  }
}
