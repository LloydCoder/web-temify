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
