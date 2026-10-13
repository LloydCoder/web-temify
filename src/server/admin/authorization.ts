import "server-only";
import { randomUUID } from "node:crypto";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";

/**
 * Resolves the current principal and verifies the authoritative database role
 * before a privileged client is constructed. Callers must fail closed on null.
 */
export async function getAdminContext(surface = "operations_dashboard") {
  try {
    const session = await createSupabaseServerClient();
    const { data: authData, error: authError } = await session.auth.getUser();
    if (authError || !authData.user) return null;

    const { data: isAdmin, error: roleError } = await session.rpc(
      "current_user_has_role",
      { required_role: "admin" },
    );
    if (roleError || isAdmin !== true) return null;

    const admin = createSupabaseAdminClient();
    const { error: auditError } = await admin.from("audit_events").insert({
      actor_id: authData.user.id,
      action: "admin.console.viewed",
      entity_type: "admin_console",
      entity_id: "operations",
      request_id: randomUUID(),
      metadata: { surface },
    });
    // Administrative access is denied if the access audit cannot be persisted.
    if (auditError) return null;

    return { userId: authData.user.id, session, admin };
  } catch {
    return null;
  }
}
