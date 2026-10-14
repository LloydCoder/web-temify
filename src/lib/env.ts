import { z } from "zod";
const optionalUrl = z.string().url().optional().or(z.literal(""));
const serverEnvSchema = z.object({
  NEXT_PUBLIC_SITE_URL: z.string().url().default("http://localhost:3000"),
  NEXT_PUBLIC_SUPABASE_URL: optionalUrl,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z.string().optional(),
  SUPABASE_SECRET_KEY: z.string().optional(),
  PAYMENT_PROVIDER: z.enum(["disabled", "sandbox"]).default("disabled"),
  PAYMENT_WEBHOOK_SECRET: z.string().optional(),
  WEB_TEMIFY_ARTIFACT_BUCKET: z
    .string()
    .trim()
    .min(1)
    .max(100)
    .default("products-private"),
  TINLANCE_AGENT_SYSTEM_ENABLED: z.enum(["true", "false"]).default("false"),
  TINLANCE_AGENT_SYSTEM_BASE_URL: optionalUrl,
  TINLANCE_AGENT_SYSTEM_TOKEN: z.string().optional(),
});
export function getServerEnv() {
  return serverEnvSchema.parse(process.env);
}
