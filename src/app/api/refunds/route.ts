import { NextResponse } from "next/server";
import { z } from "zod";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
const RefundRequestSchema = z.object({
  orderId: z.string().uuid(),
  amountMinor: z.number().int().positive().safe(),
  reason: z.string().trim().min(10).max(1000),
  idempotencyKey: z.string().trim().min(16).max(200)
}).strict();

export async function POST(request: Request) {
  let body: unknown;
  try { body = await request.json(); } catch { return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 }); }
  const parsed = RefundRequestSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Invalid refund request." }, { status: 400 });

  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) return NextResponse.json({ error: "Authentication required." }, { status: 401 });

  try {
    const { data: order, error: orderError } = await session
      .from("orders")
      .select("id,status,total_minor,currency")
      .eq("id", parsed.data.orderId)
      .maybeSingle();
    if (orderError || !order) return NextResponse.json({ error: "Order not found." }, { status: 404 });
    if (!["paid", "partially_refunded"].includes(order.status) || parsed.data.amountMinor > order.total_minor) {
      return NextResponse.json({ error: "Order is not eligible for this refund request." }, { status: 409 });
    }

    const admin = createSupabaseAdminClient();
    const { data: existing, error: existingError } = await admin
      .from("refunds")
      .select("id,order_id,amount_minor,currency,status,idempotency_key,reason")
      .eq("idempotency_key", parsed.data.idempotencyKey)
      .maybeSingle();
    if (existingError) return NextResponse.json({ error: "Refund request could not be checked." }, { status: 503 });
    if (existing) {
      if (existing.order_id !== order.id || existing.amount_minor !== parsed.data.amountMinor || existing.currency !== order.currency || existing.reason !== parsed.data.reason) {
        return NextResponse.json({ error: "Idempotency key was reused with different refund details." }, { status: 409 });
      }
      return NextResponse.json({ refundId: existing.id, status: existing.status }, { status: 200, headers: { "Cache-Control": "no-store" } });
    }

    const { data: attempt, error: attemptError } = await admin
      .from("payment_attempts")
      .select("id")
      .eq("order_id", order.id)
      .in("status", ["succeeded", "partially_refunded"])
      .maybeSingle();
    if (attemptError || !attempt) return NextResponse.json({ error: "Settled payment attempt not found." }, { status: 409 });

    const { data: refund, error: refundError } = await admin
      .from("refunds")
      .insert({
        order_id: order.id,
        payment_attempt_id: attempt.id,
        amount_minor: parsed.data.amountMinor,
        currency: order.currency,
        reason: parsed.data.reason,
        idempotency_key: parsed.data.idempotencyKey,
        requested_by: authData.user.id
      })
      .select("id,status")
      .single();
    if (refundError || !refund) return NextResponse.json({ error: "Refund request could not be recorded." }, { status: 409 });

    // This records a request only. No money moves until a provider-specific refund
    // adapter, staff approval workflow, and settlement reconciliation are enabled.
    return NextResponse.json({ refundId: refund.id, status: refund.status, moneyMoved: false }, {
      status: 202,
      headers: { "Cache-Control": "no-store" }
    });
  } catch {
    return NextResponse.json({ error: "Refund request is temporarily unavailable." }, { status: 503 });
  }
}
