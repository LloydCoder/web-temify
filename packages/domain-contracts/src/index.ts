import { z } from "zod";

export const ProductSlugSchema = z.string().trim().min(1).max(120).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
export const ProductStatusSchema = z.enum(["draft", "in_review", "approved", "published", "suspended", "archived"]);
export const MoneySchema = z.object({ amountMinor: z.number().int().nonnegative(), currency: z.string().length(3).transform((value) => value.toUpperCase()) });
export const ProductSummarySchema = z.object({ id: z.string().uuid(), slug: ProductSlugSchema, name: z.string().trim().min(1).max(160), summary: z.string().trim().max(500), status: ProductStatusSchema });
export type ProductSummary = z.infer<typeof ProductSummarySchema>;
export type ProductStatus = z.infer<typeof ProductStatusSchema>;
