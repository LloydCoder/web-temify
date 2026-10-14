export type BoundedBytesResult =
  | { ok: true; bytes: Uint8Array }
  | { ok: false; reason: "too_large" | "unreadable" };

/**
 * Reads an untrusted request body incrementally so chunked uploads cannot bypass
 * the application-level limit by omitting Content-Length.
 */
export async function readBoundedRequestBytes(
  request: Request,
  maxBytes: number,
): Promise<BoundedBytesResult> {
  const declaredLength = request.headers.get("content-length");
  if (declaredLength !== null) {
    if (!/^[0-9]+$/.test(declaredLength)) {
      return { ok: false, reason: "unreadable" };
    }
    if (Number(declaredLength) > maxBytes) {
      return { ok: false, reason: "too_large" };
    }
  }

  if (!request.body) return { ok: false, reason: "unreadable" };

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        return { ok: false, reason: "too_large" };
      }
      chunks.push(value);
    }
  } catch {
    return { ok: false, reason: "unreadable" };
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { ok: true, bytes };
}
