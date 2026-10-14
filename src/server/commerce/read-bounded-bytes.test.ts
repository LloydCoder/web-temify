import { describe, expect, it } from "vitest";
import { readBoundedRequestBytes } from "./read-bounded-bytes";

describe("readBoundedRequestBytes", () => {
  it("preserves exact bytes within the configured limit", async () => {
    const bytes = new Uint8Array([0, 255, 13, 10]);
    const request = new Request("https://example.test/evidence", {
      method: "POST",
      body: bytes,
    });

    const result = await readBoundedRequestBytes(request, 8);
    expect(result.ok).toBe(true);
    if (result.ok) expect([...result.bytes]).toEqual([...bytes]);
  });

  it("rejects streamed bodies larger than the limit", async () => {
    const request = new Request("https://example.test/evidence", {
      method: "POST",
      body: new Uint8Array(33),
    });
    await expect(readBoundedRequestBytes(request, 32)).resolves.toEqual({
      ok: false,
      reason: "too_large",
    });
  });

  it("rejects oversized declared content length before reading", async () => {
    const request = new Request("https://example.test/evidence", {
      method: "POST",
      headers: { "content-length": "33" },
      body: new Uint8Array([1]),
    });
    await expect(readBoundedRequestBytes(request, 32)).resolves.toEqual({
      ok: false,
      reason: "too_large",
    });
  });

  it("rejects malformed content length", async () => {
    const request = new Request("https://example.test/evidence", {
      method: "POST",
      headers: { "content-length": "unknown" },
      body: new Uint8Array([1]),
    });
    await expect(readBoundedRequestBytes(request, 32)).resolves.toEqual({
      ok: false,
      reason: "unreadable",
    });
  });

  it("rejects a missing request body", async () => {
    const request = new Request("https://example.test/evidence", {
      method: "POST",
    });
    await expect(readBoundedRequestBytes(request, 32)).resolves.toEqual({
      ok: false,
      reason: "unreadable",
    });
  });
});
