export type BoundedBodyResult =
  | { ok: true; body: string }
  | {
      ok: false;
      reason: "too_large" | "invalid_length" | "invalid_utf8" | "read_error";
    };

/**
 * Read a request body with a hard byte ceiling before allocating an unbounded
 * string. The Content-Length header is an optimization only; streamed bytes
 * are independently counted because the header can be missing or incorrect.
 */
export async function readBoundedRequestBody(
  request: Request,
  maxBytes: number,
): Promise<BoundedBodyResult> {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 0) {
    throw new RangeError("maxBytes must be a non-negative safe integer");
  }

  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (!/^[0-9]+$/.test(contentLength)) {
      return { ok: false, reason: "invalid_length" };
    }
    if (Number(contentLength) > maxBytes) {
      try {
        await request.body?.cancel();
      } catch {
        // Reject the request regardless; cancellation is best-effort.
      }
      return { ok: false, reason: "too_large" };
    }
  }

  if (!request.body) return { ok: true, body: "" };

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        try {
          await reader.cancel();
        } catch {
          // The size limit has already been enforced.
        }
        return { ok: false, reason: "too_large" };
      }
      chunks.push(value);
    }

    const bytes = new Uint8Array(totalBytes);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }

    try {
      return {
        ok: true,
        body: new TextDecoder("utf-8", { fatal: true }).decode(bytes),
      };
    } catch {
      return { ok: false, reason: "invalid_utf8" };
    }
  } catch {
    return { ok: false, reason: "read_error" };
  } finally {
    try {
      reader.releaseLock();
    } catch {
      // Ignore cleanup errors after the request has already been rejected.
    }
  }
}
