import { createClient } from "@supabase/supabase-js";
import { getServerEnv } from "@/lib/env";

/** Privileged client for server-only workflows. Never import this from a Client Component. */
export function createSupabaseAdminClient() {
  const env = getServerEnv();
  if (!env.NEXT_PUBLIC_SUPABASE_URL || !env.SUPABASE_SECRET_KEY) {
    throw new Error("Privileged Supabase server configuration is missing.");
  }
  return createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}
