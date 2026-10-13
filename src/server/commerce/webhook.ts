import { createHash } from "node:crypto";
import { z } from "zod";
import type { createSupabaseAdminClient } from "@/lib/supabase/admin";

const eventIdentity = {
  id: z.string().trim().min(1).max(240),
  orderId: z.string().uuid(),
  paymentAttemptId: z.string().uuid(),
  amountMinor: z.number().int().positive().safe(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  providerReference: z.string().trim().min(1).max(240)
};
export const SandboxPaymentEventSchema = z.discriminatedUnion("type", [
  z.object({ ...eventIdentity, type: z.literal("payment.succeeded") }).strict(),
  z.object({ ...eventIdentity, type: z.literal("payment.failed") }).strict(),
  z.object({ ...eventIdentity, type: z.literal("refund.succeeded"), refundId: z.string().uuid() }).strict()
]);
export type SandboxPaymentEvent = z.infer<typeof SandboxPaymentEventSchema>;
type AdminClient = ReturnType<typeof createSupabaseAdminClient>;

export type WebhookIngestResult =
  | { kind: "processed" }
  | { kind: "conflict" }
  | { kind: "retry" };

export async function ingestVerifiedSandboxEvent(
  admin: AdminClient,
  event: SandboxPaymentEvent,
  rawBody: string
): Promise<WebhookIngestResult> {
  const payloadSha256 = createHash("sha256").update(rawBody, "utf8").digest("hex");
  const row = {
    provider: "sandbox",
    provider_event_id: event.id,
    event_type: event.type,
    payload_sha256: payloadSha256,
    signature_verified: true,
    processing_status: "received",
    order_id: event.orderId,
    payment_attempt_id: event.paymentAttemptId,
    refund_id: event.type === "refund.succeeded" ? event.refundId : null,
    amount_minor: event.amountMinor,
    currency: event.currency,
    provider_reference: event.providerReference
  };
  const { error: insertError } = await admin
    .from("payment_webhook_events")
    .upsert(row, { onConflict: "provider,provider_event_id", ignoreDuplicates: true });
  if (insertError) return { kind: "retry" };

  const { data: stored, error: readError } = await admin
    .from("payment_webhook_events")
    .select("id,payload_sha256,processing_status")
    .eq("provider", "sandbox")
    .eq("provider_event_id", event.id)
    .maybeSingle();
  if (readError || !stored) return { kind: "retry" };
  if (stored.payload_sha256 !== payloadSha256) return { kind: "conflict" };
  if (stored.processing_status === "processed" || stored.processing_status === "ignored") return { kind: "processed" };

  const { data: processed, error: processError } = await admin.rpc("process_payment_webhook_event", {
    target_event_id: stored.id
  });
  if (processError || processed !== true) return { kind: "retry" };
  return { kind: "processed" };
}
