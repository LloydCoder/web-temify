import { NextResponse } from "next/server";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { getServerEnv } from "@/lib/env";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
const CheckoutRequestSchema = z
  .object({
    items: z
      .array(
        z
          .object({
            productVersionId: z.string().uuid(),
            quantity: z.number().int().min(1).max(100),
          })
          .strict(),
      )
      .min(1)
      .max(20),
    idempotencyKey: z.string().trim().min(16).max(200),
  })
  .strict();

export async function POST(request: Request) {
  const env = getServerEnv();
  // No live provider has been selected or approved. Sandbox is non-production only.
  if (
    process.env.NODE_ENV === "production" ||
    env.PAYMENT_PROVIDER !== "sandbox"
  ) {
    return NextResponse.json(
      { error: "Checkout is not enabled for a live payment provider." },
      { status: 503 },
    );
  }
  if ((env.PAYMENT_WEBHOOK_SECRET ?? "").length < 32) {
    return NextResponse.json(
      { error: "Sandbox checkout is not configured." },
      { status: 503 },
    );
  }

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
  let input: unknown;
  try {
    input = JSON.parse(boundedBody.body);
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }
  const parsed = CheckoutRequestSchema.safeParse(input);
  if (!parsed.success)
    return NextResponse.json(
      { error: "Invalid checkout request." },
      { status: 400 },
    );
  const uniqueIds = new Set(
    parsed.data.items.map((item) => item.productVersionId),
  );
  if (uniqueIds.size !== parsed.data.items.length) {
    return NextResponse.json(
      {
        error:
          "Each release may appear only once; use quantity for multiple licenses.",
      },
      { status: 400 },
    );
  }

  const sessionClient = await createSupabaseServerClient();
  const { data: authData, error: authError } =
    await sessionClient.auth.getUser();
  if (authError || !authData.user)
    return NextResponse.json(
      { error: "Authentication required." },
      { status: 401 },
    );

  try {
    const admin = createSupabaseAdminClient();
    const { data: orderRows, error: orderError } = await admin.rpc(
      "create_order_for_checkout",
      {
        p_customer_id: authData.user.id,
        p_items: parsed.data.items.map((item) => ({
          product_version_id: item.productVersionId,
          quantity: item.quantity,
        })),
        p_idempotency_key: parsed.data.idempotencyKey,
      },
    );
    const order = Array.isArray(orderRows)
      ? (orderRows[0] as
          | {
              order_id: string;
              status: string;
              total_minor: number;
              currency: string;
            }
          | undefined)
      : undefined;
    if (orderError || !order) {
      return NextResponse.json(
        {
          error:
            "Checkout could not be created. Verify that all releases are currently purchasable.",
        },
        { status: 409 },
      );
    }
    if (order.status === "paid") {
      return NextResponse.json({
        orderId: order.order_id,
        status: "paid",
        amountMinor: order.total_minor,
        currency: order.currency,
      });
    }
    if (
      order.status === "cancelled" ||
      order.status === "refunded" ||
      order.status === "partially_refunded"
    ) {
      return NextResponse.json(
        { error: "This order cannot be checked out again." },
        { status: 409 },
      );
    }

    const { data: priorAttempt, error: priorError } = await admin
      .from("payment_attempts")
      .select("id,status,amount_minor,currency")
      .eq("order_id", order.order_id)
      .eq("provider", "sandbox")
      .in("status", [
        "created",
        "pending",
        "succeeded",
        "partially_refunded",
        "refunded",
      ])
      .maybeSingle();
    if (priorError)
      return NextResponse.json(
        { error: "Unable to retrieve the existing payment attempt." },
        { status: 503 },
      );

    let attemptId: string;
    let attemptStatus: string;
    if (priorAttempt) {
      attemptId = priorAttempt.id;
      attemptStatus = priorAttempt.status;
    } else {
      const { data: attempt, error: attemptError } = await admin
        .from("payment_attempts")
        .insert({
          order_id: order.order_id,
          provider: "sandbox",
          amount_minor: order.total_minor,
          currency: order.currency,
          idempotency_key: `checkout:${order.order_id}:${randomUUID()}`,
        })
        .select("id,status")
        .single();
      if (attemptError || !attempt) {
        // A concurrent request may have won the unique active-attempt constraint.
        // Re-read that attempt rather than creating a second charge or failing a safe retry.
        const { data: racedAttempt, error: racedError } = await admin
          .from("payment_attempts")
          .select("id,status")
          .eq("order_id", order.order_id)
          .eq("provider", "sandbox")
          .in("status", ["created", "pending"])
          .maybeSingle();
        if (racedError || !racedAttempt) {
          return NextResponse.json(
            { error: "Unable to create the payment attempt." },
            { status: 409 },
          );
        }
        attemptId = racedAttempt.id;
        attemptStatus = racedAttempt.status;
      } else {
        attemptId = attempt.id;
        attemptStatus = attempt.status;
      }
    }
    if (attemptStatus === "created") {
      const { error: pendingError } = await admin
        .from("payment_attempts")
        .update({ status: "pending" })
        .eq("id", attemptId);
      if (pendingError)
        return NextResponse.json(
          { error: "Unable to start the sandbox payment attempt." },
          { status: 503 },
        );
    }

    return NextResponse.json(
      {
        orderId: order.order_id,
        paymentAttemptId: attemptId,
        status: "pending",
        amountMinor: order.total_minor,
        currency: order.currency,
        provider: "sandbox",
        sandboxOnly: true,
        completeEndpoint: "/api/checkout/sandbox/complete",
      },
      { status: 201, headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json(
      { error: "Checkout is temporarily unavailable." },
      { status: 503 },
    );
  }
}
