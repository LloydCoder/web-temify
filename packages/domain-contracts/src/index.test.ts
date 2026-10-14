import { describe, expect, it } from "vitest";
import {
  MoneySchema,
  ProductCatalogItemSchema,
  ProductRightsAttestationInputSchema,
  ProductStatusSchema,
  SettlementImportSchema,
  SettlementProviderSchema,
} from "./index";

describe("shared domain contracts", () => {
  it("uses the database-authoritative product lifecycle states", () => {
    expect(ProductStatusSchema.parse("pending_review")).toBe("pending_review");
    expect(ProductStatusSchema.safeParse("in_review").success).toBe(false);
    expect(ProductStatusSchema.safeParse("approved").success).toBe(false);
  });

  it("normalizes valid currency codes and rejects malformed codes", () => {
    expect(
      MoneySchema.parse({ amountMinor: 1299, currency: "usd" }).currency,
    ).toBe("USD");
    expect(
      MoneySchema.safeParse({ amountMinor: 1.5, currency: "USD" }).success,
    ).toBe(false);
    expect(
      MoneySchema.safeParse({
        amountMinor: Number.MAX_SAFE_INTEGER + 1,
        currency: "USD",
      }).success,
    ).toBe(false);
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
    expect(
      ProductCatalogItemSchema.safeParse({ ...valid, rightsStatus: "declared" })
        .success,
    ).toBe(false);
    expect(
      ProductCatalogItemSchema.safeParse({
        ...valid,
        artifactSha256: "not-a-digest",
      }).success,
    ).toBe(false);
  });

  it("validates a rights declaration without allowing a client to assert verification", () => {
    const input = {
      productId: "73000000-0000-4000-8000-000000000073",
      rightsBasis: "original_work",
      statement:
        "I created this work and have the rights required to distribute it.",
    };
    expect(ProductRightsAttestationInputSchema.safeParse(input).success).toBe(
      true,
    );
    expect(
      ProductRightsAttestationInputSchema.safeParse({
        ...input,
        statement: "yes",
      }).success,
    ).toBe(false);
    expect(
      ProductRightsAttestationInputSchema.safeParse({
        ...input,
        rightsStatus: "verified",
      }).success,
    ).toBe(false);
  });
});

describe("settlement source provider policy", () => {
  it("matches the accepted provider strategy without enabling live integrations", () => {
    expect(SettlementProviderSchema.parse("polar")).toBe("polar");
    expect(SettlementProviderSchema.parse("paystack")).toBe("paystack");
    expect(SettlementProviderSchema.parse("sandbox")).toBe("sandbox");
    expect(SettlementProviderSchema.safeParse("stripe").success).toBe(false);
    expect(
      SettlementProviderSchema.safeParse("flutterwave").success,
    ).toBe(false);
  });
});

describe("Phase 4D2 settlement import contract", () => {
  const validReport = {
    contractVersion: "1.0" as const,
    provider: "sandbox" as const,
    providerAccountReference: "sandbox-account-01",
    reportReference: "settlement-batch-2026-10-13",
    reportPeriodStart: "2026-10-13",
    reportPeriodEnd: "2026-10-13",
    reportTimezone: "UTC",
    sourceSha256: "b".repeat(64),
    sourceAuthenticated: true as const,
    currency: "USD",
    rows: [
      {
        rowId: "row-payment-01",
        rowType: "payment" as const,
        providerReference: "provider-payment-01",
        paymentReference: "order-payment-01",
        occurredAt: "2026-10-13T10:00:00Z",
        currency: "USD",
        grossMinor: 10000,
        feeMinor: 300,
        netMinor: 9700,
      },
      {
        rowId: "row-fee-01",
        rowType: "fee" as const,
        occurredAt: "2026-10-13T10:00:00Z",
        currency: "USD",
        grossMinor: 0,
        feeMinor: 300,
        netMinor: -300,
      },
    ],
  };

  it("accepts a valid settlement report", () => {
    expect(SettlementImportSchema.safeParse(validReport).success).toBe(true);
  });

  it("rejects invalid auth assertions and extra fields", () => {
    expect(
      SettlementImportSchema.safeParse({
        ...validReport,
        sourceAuthenticated: false,
      }).success,
    ).toBe(false);
    expect(
      SettlementImportSchema.safeParse({
        ...validReport,
        contractVersion: "2.0",
      }).success,
    ).toBe(false);
    expect(
      SettlementImportSchema.safeParse({
        ...validReport,
        rawProviderPayload: "must-not-be-added",
      }).success,
    ).toBe(false);
  });

  it("rejects duplicate row IDs and currency mismatch", () => {
    const duplicate = {
      ...validReport,
      rows: [validReport.rows[0], { ...validReport.rows[0] }],
    };
    expect(SettlementImportSchema.safeParse(duplicate).success).toBe(false);
    const wrongCurrency = {
      ...validReport,
      rows: [{ ...validReport.rows[0], currency: "EUR" }],
    };
    expect(SettlementImportSchema.safeParse(wrongCurrency).success).toBe(false);
  });

  it("rejects out-of-period rows and invalid signs", () => {
    const outsidePeriod = {
      ...validReport,
      rows: [
        {
          ...validReport.rows[0],
          occurredAt: "2026-10-12T23:59:59Z",
        },
      ],
    };
    expect(SettlementImportSchema.safeParse(outsidePeriod).success).toBe(false);
    const positiveRefund = {
      ...validReport,
      rows: [
        {
          ...validReport.rows[0],
          rowType: "refund",
          grossMinor: 100,
        },
      ],
    };
    expect(
      SettlementImportSchema.safeParse(positiveRefund).success,
    ).toBe(false);
    const positiveFee = {
      ...validReport,
      rows: [
        {
          ...validReport.rows[1],
          netMinor: 300,
        },
      ],
    };
    expect(SettlementImportSchema.safeParse(positiveFee).success).toBe(false);
  });

  it("checks report-period boundaries in the declared timezone", () => {
    const localDateOutsidePeriod = {
      ...validReport,
      reportTimezone: "Europe/Berlin",
      rows: [
        {
          ...validReport.rows[0],
          occurredAt: "2026-10-13T23:30:00Z",
        },
      ],
    };
    expect(
      SettlementImportSchema.safeParse(localDateOutsidePeriod).success,
    ).toBe(false);
    expect(
      SettlementImportSchema.safeParse({
        ...validReport,
        reportTimezone: "Not/A_Timezone",
      }).success,
    ).toBe(false);
  });

  it("rejects invalid periods and source digests", () => {
    expect(
      SettlementImportSchema.safeParse({
        ...validReport,
        reportPeriodStart: "2026-10-14",
      }).success,
    ).toBe(false);
    expect(
      SettlementImportSchema.safeParse({
        ...validReport,
        sourceSha256: "not-a-digest",
      }).success,
    ).toBe(false);
  });
});
