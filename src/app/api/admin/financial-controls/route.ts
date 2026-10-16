import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";
import { readBoundedRequestBody } from "@/server/commerce/read-bounded-body";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const Uuid = z.string().uuid();
const RequestSchema = z
  .object({
    requestType: z.enum([
      "manual_adjustment",
      "negative_balance_review",
      "payout_hold",
      "payout_hold_release",
    ]),
    sellerId: Uuid,
    orderId: Uuid.nullable().optional(),
    targetHoldId: Uuid.nullable().optional(),
    amountMinor: z.string().regex(/^[1-9][0-9]{0,14}$/),
    currency: z.string().regex(/^[A-Z]{3}$/),
    evidenceSha256: z.string().regex(/^[a-f0-9]{64}$/),
    reason: z.string().trim().min(12).max(1000),
    idempotencyKey: z.string().trim().min(16).max(200),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.requestType === "payout_hold_release" && !value.targetHoldId) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["targetHoldId"],
        message: "A payout hold must be selected for release.",
      });
    }
    if (value.requestType !== "payout_hold_release" && value.targetHoldId) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["targetHoldId"],
        message: "A target hold is only valid for a release request.",
      });
    }
  });

function safeRpcError(code?: string) {
  if (code === "42501") return { status: 403, error: "forbidden" };
  if (code === "22023")
    return { status: 400, error: "invalid_financial_control_request" };
  if (code === "23505")
    return { status: 409, error: "financial_control_conflict" };
  if (code === "P0002")
    return { status: 404, error: "financial_control_target_not_found" };
  return { status: 503, error: "financial_control_unavailable" };
}

export async function GET(request: Request) {
  const context = await getAdminContext("financial_control_queue");
  if (!context) {
    return NextResponse.json(
      { error: "not_found" },
      {
        status: 404,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }

  const url = new URL(request.url);
  const statuses = url.searchParams.getAll("status");
  const allowedStatuses = new Set([
    "requested",
    "under_review",
    "approved",
    "rejected",
    "cancelled",
  ]);
  if (
    [...url.searchParams.keys()].some((key) => key !== "status") ||
    statuses.length > 5 ||
    statuses.some((status) => !allowedStatuses.has(status)) ||
    new Set(statuses).size !== statuses.length
  ) {
    return NextResponse.json(
      { error: "invalid_financial_control_filter" },
      {
        status: 400,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }

  try {
    let query = context.admin
      .from("financial_control_requests")
      .select(
        "id,request_type,status,seller_id,order_id,target_hold_id,amount_minor,currency,reason,requested_by,approved_at,created_at,updated_at",
      )
      .order("created_at", { ascending: false })
      .limit(50);
    if (statuses.length > 0) query = query.in("status", statuses);
    const { data, error } = await query;
    if (error) {
      return NextResponse.json(
        { error: "financial_control_unavailable" },
        {
          status: 503,
          headers: { "Cache-Control": "no-store" },
        },
      );
    }
    return NextResponse.json(
      { requests: data ?? [], limit: 50 },
      {
        headers: { "Cache-Control": "no-store" },
      },
    );
  } catch {
    return NextResponse.json(
      { error: "financial_control_unavailable" },
      {
        status: 503,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
}

export async function POST(request: Request) {
  const context = await getAdminContext("financial_control_create");
  if (!context) {
    return NextResponse.json(
      { error: "not_found" },
      {
        status: 404,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
  if (request.headers.get("origin") !== new URL(request.url).origin) {
    return NextResponse.json(
      { error: "same_origin_required" },
      {
        status: 403,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
  if (
    request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase() !==
    "application/json"
  ) {
    return NextResponse.json(
      { error: "json_required" },
      {
        status: 415,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }

  const bounded = await readBoundedRequestBody(request, 8 * 1024);
  if (!bounded.ok) {
    return NextResponse.json(
      {
        error:
          bounded.reason === "too_large"
            ? "request_too_large"
            : "invalid_request_body",
      },
      {
        status: bounded.reason === "too_large" ? 413 : 400,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
  let body: unknown;
  try {
    body = JSON.parse(bounded.body);
  } catch {
    return NextResponse.json(
      { error: "invalid_json" },
      {
        status: 400,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
  const parsed = RequestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "invalid_financial_control_request" },
      {
        status: 400,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }

  const requestId = randomUUID();
  try {
    const { data, error } = await context.admin.rpc(
      "create_financial_control_request",
      {
        p_actor_id: context.userId,
        p_request_type: parsed.data.requestType,
        p_seller_id: parsed.data.sellerId,
        p_order_id: parsed.data.orderId ?? null,
        p_target_hold_id: parsed.data.targetHoldId ?? null,
        p_amount_minor: parsed.data.amountMinor,
        p_currency: parsed.data.currency,
        p_evidence_sha256: parsed.data.evidenceSha256,
        p_reason: parsed.data.reason,
        p_idempotency_key: parsed.data.idempotencyKey,
        p_request_id: requestId,
      },
    );
    if (error) {
      const mapped = safeRpcError(error.code);
      return NextResponse.json(
        { error: mapped.error, requestId },
        {
          status: mapped.status,
          headers: { "Cache-Control": "no-store" },
        },
      );
    }
    if (typeof data !== "string" || !Uuid.safeParse(data).success) {
      return NextResponse.json(
        { error: "financial_control_unavailable", requestId },
        {
          status: 503,
          headers: { "Cache-Control": "no-store" },
        },
      );
    }
    return NextResponse.json(
      { requestId: data, traceId: requestId },
      {
        status: 201,
        headers: { "Cache-Control": "no-store" },
      },
    );
  } catch {
    return NextResponse.json(
      { error: "financial_control_unavailable", requestId },
      {
        status: 503,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
}
