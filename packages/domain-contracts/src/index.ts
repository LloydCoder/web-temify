import { z } from "zod";

export const ProductSlugSchema = z
  .string()
  .trim()
  .min(1)
  .max(120)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
export const ProductStatusSchema = z.enum([
  "draft",
  "pending_review",
  "published",
  "rejected",
  "archived",
]);
export const ProductRightsStatusSchema = z.enum([
  "unverified",
  "declared",
  "under_review",
  "verified",
  "rejected",
]);
export const ProductLicenseSchema = z.enum([
  "standard",
  "commercial",
  "extended",
  "open_source",
  "custom",
]);
export const ProductTypeSchema = z.enum([
  "template",
  "starter_kit",
  "script",
  "application",
  "package",
  "other",
]);
export const ProductReleaseVersionSchema = z
  .string()
  .regex(
    /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/,
  );
export const Sha256Schema = z.string().regex(/^[a-f0-9]{64}$/);
export const MoneySchema = z.object({
  amountMinor: z.number().int().nonnegative().safe(),
  currency: z
    .string()
    .regex(/^[A-Za-z]{3}$/)
    .transform((value) => value.toUpperCase()),
});
export const ProductSummarySchema = z.object({
  id: z.string().uuid(),
  slug: ProductSlugSchema,
  name: z.string().trim().min(1).max(180),
  summary: z.string().trim().max(500),
  status: ProductStatusSchema,
});
export const ProductCatalogItemSchema = z.object({
  id: z.string().uuid(),
  slug: ProductSlugSchema,
  name: z.string().trim().min(1).max(180),
  summary: z.string().max(500),
  productType: ProductTypeSchema,
  priceMinor: z.number().int().nonnegative().safe(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  licenseType: ProductLicenseSchema,
  rightsStatus: z.literal("verified"),
  releaseVersion: ProductReleaseVersionSchema,
  artifactSha256: Sha256Schema,
  compatibility: z.record(z.string(), z.unknown()),
  techStack: z.array(z.string().max(80)).max(40),
  tags: z.array(z.string().trim().min(1).max(40)).max(30),
});
export const ProductRightsAttestationInputSchema = z
  .object({
    productId: z.string().uuid(),
    rightsBasis: z.enum([
      "original_work",
      "authorized_distribution",
      "open_source_compliance",
      "licensed_assets",
      "other",
    ]),
    statement: z.string().trim().min(20).max(4000),
    evidenceReference: z.string().trim().max(2048).optional(),
  })
  .strict();
export type ProductSummary = z.infer<typeof ProductSummarySchema>;
export type ProductStatus = z.infer<typeof ProductStatusSchema>;
export type ProductCatalogItem = z.infer<typeof ProductCatalogItemSchema>;
export type ProductRightsAttestationInput = z.infer<
  typeof ProductRightsAttestationInputSchema
>;


// Phase 4D2: provider-neutral settlement import contract.
// This validates normalized data only; it does not authenticate source files,
// reconcile transactions, or authorize journal posting.
export const SettlementProviderSchema = z.enum([
  "paystack",
  "flutterwave",
  "stripe",
  "sandbox",
]);
export const SettlementRowTypeSchema = z.enum([
  "payment",
  "refund",
  "fee",
  "payout",
  "adjustment",
]);
export const SettlementImportRowSchema = z
  .object({
    rowId: z.string().trim().min(1).max(240),
    rowType: SettlementRowTypeSchema,
    providerReference: z.string().trim().min(1).max(240).optional(),
    paymentReference: z.string().trim().min(1).max(240).optional(),
    occurredAt: z.string().datetime({ offset: true }),
    currency: z.string().regex(/^[A-Z]{3}$/),
    grossMinor: z.number().int().safe(),
    feeMinor: z.number().int().nonnegative().safe(),
    netMinor: z.number().int().safe(),
    exceptionCode: z
      .enum([
        "missing_internal_match",
        "duplicate_reference",
        "amount_mismatch",
        "currency_mismatch",
        "period_mismatch",
        "unsupported_row_type",
        "unexplained_adjustment",
      ])
      .optional(),
  })
  .strict()
  .superRefine((row, ctx) => {
    if (row.rowType === "payment" && row.grossMinor <= 0) {
      ctx.addIssue({
        code: "custom",
        path: ["grossMinor"],
        message: "Payment gross must be positive",
      });
    }
    if (row.rowType === "refund" && row.grossMinor >= 0) {
      ctx.addIssue({
        code: "custom",
        path: ["grossMinor"],
        message: "Refund gross must be negative",
      });
    }
    if (row.rowType === "fee" && row.netMinor >= 0) {
      ctx.addIssue({
        code: "custom",
        path: ["netMinor"],
        message: "Fee rows must have a negative net amount",
      });
    }
  });
export const SettlementImportSchema = z
  .object({
    contractVersion: z.literal("1.0"),
    provider: SettlementProviderSchema,
    providerAccountReference: z.string().trim().min(1).max(240),
    reportReference: z.string().trim().min(1).max(240),
    reportPeriodStart: z.string().date(),
    reportPeriodEnd: z.string().date(),
    reportTimezone: z.string().trim().min(1).max(100),
    sourceSha256: Sha256Schema,
    sourceAuthenticated: z.literal(true),
    currency: z.string().regex(/^[A-Z]{3}$/),
    rows: z.array(SettlementImportRowSchema).min(1).max(100_000),
  })
  .strict()
  .superRefine((report, ctx) => {
    if (report.reportPeriodStart > report.reportPeriodEnd) {
      ctx.addIssue({
        code: "custom",
        path: ["reportPeriodEnd"],
        message: "Report period end must not precede its start",
      });
    }
    const rowIds = new Set<string>();
    report.rows.forEach((row, index) => {
      if (rowIds.has(row.rowId)) {
        ctx.addIssue({
          code: "custom",
          path: ["rows", index, "rowId"],
          message: "Row identifiers must be unique within a report",
        });
      }
      rowIds.add(row.rowId);
      if (row.currency !== report.currency) {
        ctx.addIssue({
          code: "custom",
          path: ["rows", index, "currency"],
          message: "Row currency must match report currency in contract v1",
        });
      }
      const occurredDate = row.occurredAt.slice(0, 10);
      if (
        occurredDate < report.reportPeriodStart ||
        occurredDate > report.reportPeriodEnd
      ) {
        ctx.addIssue({
          code: "custom",
          path: ["rows", index, "occurredAt"],
          message: "Row timestamp falls outside the declared report period",
        });
      }
    });
  });
export type SettlementImport = z.infer<typeof SettlementImportSchema>;
export type SettlementImportRow = z.infer<typeof SettlementImportRowSchema>;
