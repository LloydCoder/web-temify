import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";

/**
 * Resolves the current principal and verifies the authoritative database role
 * before a privileged client is constructed. Callers must fail closed on null.
 */
export async function getAdminContext() {
  try {
    const session = await createSupabaseServerClient();
    const { data: authData, error: authError } = await session.auth.getUser();
    if (authError || !authData.user) return null;

    const { data: isAdmin, error: roleError } = await session.rpc(
      "current_user_has_role",
      { required_role: "admin" }
    );
    if (roleError || isAdmin !== true) return null;

    return {
      userId: authData.user.id,
      session,
      admin: createSupabaseAdminClient()
    };
  } catch {
    return null;
  }
}
