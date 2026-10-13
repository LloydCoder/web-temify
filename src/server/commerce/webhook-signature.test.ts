import { describe, expect, it } from "vitest";
import {
  signSandboxWebhook,
  verifySandboxWebhookSignature,
} from "./webhook-signature";

describe("sandbox webhook signature verification", () => {
  const secret = "test-only-secret-with-at-least-32-characters";
  const nowSeconds = 1_800_000_000;
  const rawBody = '{"id":"evt-1","type":"payment.succeeded"}';
  const eventId = "evt-1";
  const timestamp = String(nowSeconds);
  const signature = signSandboxWebhook(rawBody, eventId, timestamp, secret);

  it("verifies the exact raw body and event identity", () => {
    expect(
      verifySandboxWebhookSignature({
        rawBody,
        eventId,
        timestamp,
        signature,
        secret,
        nowSeconds,
      }),
    ).toBe(true);
  });

  it("rejects a body changed after signing", () => {
    expect(
      verifySandboxWebhookSignature({
        rawBody: rawBody + " ",
        eventId,
        timestamp,
        signature,
        secret,
        nowSeconds,
      }),
    ).toBe(false);
  });

  it("rejects a mismatched event ID", () => {
    expect(
      verifySandboxWebhookSignature({
        rawBody,
        eventId: "evt-other",
        timestamp,
        signature,
        secret,
        nowSeconds,
      }),
    ).toBe(false);
  });

  it("rejects stale signatures to limit replay windows", () => {
    expect(
      verifySandboxWebhookSignature({
        rawBody,
        eventId,
        timestamp,
        signature,
        secret,
        nowSeconds: nowSeconds + 301,
      }),
    ).toBe(false);
  });

  it("fails closed for short secrets and malformed signatures", () => {
    expect(
      verifySandboxWebhookSignature({
        rawBody,
        eventId,
        timestamp,
        signature,
        secret: "short",
        nowSeconds,
      }),
    ).toBe(false);
    expect(
      verifySandboxWebhookSignature({
        rawBody,
        eventId,
        timestamp,
        signature: "invalid",
        secret,
        nowSeconds,
      }),
    ).toBe(false);
  });
});
