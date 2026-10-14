import { createHmac, timingSafeEqual } from "node:crypto";

export const SANDBOX_WEBHOOK_TOLERANCE_SECONDS = 300;

export function signSandboxWebhook(
  rawBody: string,
  eventId: string,
  timestamp: string,
  secret: string,
): string {
  return `v1=${createHmac("sha256", secret).update(`${eventId}.${timestamp}.${rawBody}`, "utf8").digest("hex")}`;
}

export function verifySandboxWebhookSignature(input: {
  rawBody: string;
  eventId: string;
  timestamp: string;
  signature: string;
  secret: string;
  nowSeconds?: number;
}): boolean {
  const { rawBody, eventId, timestamp, signature, secret } = input;
  if (!eventId || eventId.length > 240 || secret.length < 32) return false;
  if (!/^[0-9]{1,12}$/.test(timestamp) || !/^v1=[a-f0-9]{64}$/i.test(signature))
    return false;
  const timestampSeconds = Number(timestamp);
  const nowSeconds = input.nowSeconds ?? Math.floor(Date.now() / 1000);
  if (
    !Number.isSafeInteger(timestampSeconds) ||
    Math.abs(nowSeconds - timestampSeconds) > SANDBOX_WEBHOOK_TOLERANCE_SECONDS
  ) {
    return false;
  }
  const expected = Buffer.from(
    signSandboxWebhook(rawBody, eventId, timestamp, secret).slice(3),
    "hex",
  );
  const supplied = Buffer.from(signature.slice(3), "hex");
  return (
    expected.length === supplied.length && timingSafeEqual(expected, supplied)
  );
}
