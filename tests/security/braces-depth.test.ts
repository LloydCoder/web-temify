import { describe, expect, it } from "vitest";
import braces from "braces";

describe("patched braces nesting limit", () => {
  it("rejects deeply nested patterns before recursive expansion can exhaust the stack", () => {
    const pattern = "{".repeat(101) + "value" + "}".repeat(101);

    expect(() => braces(pattern)).toThrow(
      "Brace nesting exceeds maximum depth",
    );
  });

  it("preserves ordinary nested brace expansion", () => {
    expect(braces("{a,{b,c}}")).toEqual(["a", "b", "c"]);
  });
});
