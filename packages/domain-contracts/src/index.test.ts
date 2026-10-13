import { describe, expect, it } from "vitest";
import {
  MoneySchema,
  ProductCatalogItemSchema,
  ProductRightsAttestationInputSchema,
  ProductStatusSchema,
} from "./index";

describe("shared domain contracts", () => {
  it("uses the database-authoritative product lifecycle states", () => {
    expect(ProductStatusSchema.parse("pending_review")).toBe("pending_review");
    expect(ProductStatusSchema.safeParse("in_review").success).toBe(false);
    expect(ProductStatusSchema.safeParse("approved").success).toBe(false);
  });

  it("normalizes valid currency codes and rejects malformed codes", () => {
    expect(MoneySchema.parse({ amountMinor: 1299, currency: "usd" }).currency).toBe("USD");
    expect(MoneySchema.safeParse({ amountMinor: 1.5, currency: "USD" }).success).toBe(false);
    expect(MoneySchema.safeParse({ amountMinor: Number.MAX_SAFE_INTEGER + 1, currency: "USD" }).success).toBe(false);
  });

  it("requires a verified rights state and immutable artifact digest for public catalogue data", () => {
    const valid = {
      id: "73000000-0000-4000-8000-000000000073",
      slug: "verified-product",
      name: "Verified Product",
      summary: "A tested product summary",
      productType: "template",
      priceMinor: 1299,
      currency: "USD",
      licenseType: "standard",
      rightsStatus: "verified",
      releaseVersion: "1.0.0",
      artifactSha256: "a".repeat(64),
      compatibility: { node: ">=22" },
      techStack: ["TypeScript"],
      tags: ["starter"],
    };
    expect(ProductCatalogItemSchema.safeParse(valid).success).toBe(true);
    expect(ProductCatalogItemSchema.safeParse({ ...valid, rightsStatus: "declared" }).success).toBe(false);
    expect(ProductCatalogItemSchema.safeParse({ ...valid, artifactSha256: "not-a-digest" }).success).toBe(false);
  });

  it("validates a rights declaration without allowing a client to assert verification", () => {
    const input = {
      productId: "73000000-0000-4000-8000-000000000073",
      rightsBasis: "original_work",
      statement: "I created this work and have the rights required to distribute it.",
    };
    expect(ProductRightsAttestationInputSchema.safeParse(input).success).toBe(true);
    expect(ProductRightsAttestationInputSchema.safeParse({ ...input, statement: "yes" }).success).toBe(false);
    expect(ProductRightsAttestationInputSchema.safeParse({ ...input, rightsStatus: "verified" }).success).toBe(false);
  });
});
