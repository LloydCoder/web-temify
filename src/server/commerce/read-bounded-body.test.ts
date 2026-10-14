import { describe, expect, it } from "vitest";
import { readBoundedRequestBody } from "./read-bounded-body";

describe("readBoundedRequestBody", () => {
  it("reads a body within the byte limit", async () => {
    const request = new Request("https://example.test/webhook", {
      method: "POST",
      body: '{"ok":true}',
    });
    await expect(readBoundedRequestBody(request, 32)).resolves.toEqual({
      ok: true,
      body: '{"ok":true}',
    });
  });

  it("rejects a body whose streamed bytes exceed the limit", async () => {
    const request = new Request("https://example.test/webhook", {
      method: "POST",
      body: "x".repeat(128),
    });
    await expect(readBoundedRequestBody(request, 32)).resolves.toEqual({
      ok: false,
      reason: "too_large",
    });
  });

  it("rejects an oversized declared content length before reading", async () => {
    const request = new Request("https://example.test/webhook", {
      method: "POST",
      headers: { "content-length": "129" },
      body: "small",
    });
    await expect(readBoundedRequestBody(request, 32)).resolves.toEqual({
      ok: false,
      reason: "too_large",
    });
  });

  it("rejects malformed content length", async () => {
    const request = new Request("https://example.test/webhook", {
      method: "POST",
      headers: { "content-length": "unknown" },
      body: "small",
    });
    await expect(readBoundedRequestBody(request, 32)).resolves.toEqual({
      ok: false,
      reason: "invalid_length",
    });
  });

  it("rejects invalid UTF-8 rather than silently replacing bytes", async () => {
    const request = new Request("https://example.test/webhook", {
      method: "POST",
      body: new Uint8Array([0xff, 0xfe]),
    });
    await expect(readBoundedRequestBody(request, 32)).resolves.toEqual({
      ok: false,
      reason: "invalid_utf8",
    });
  });
});
