import { notFound } from "next/navigation";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SupportCaseCreateForm } from "./SupportCaseCreateForm";

export const dynamic = "force-dynamic";

type SupportCase = {
  id: string;
  category: string;
  subject: string;
  status: string;
  priority: string;
  created_at: string;
  updated_at: string;
  resolved_at: string | null;
  closed_at: string | null;
};

export default async function SupportPage() {
  const session = await createSupabaseServerClient();
  const { data: authData, error: authError } = await session.auth.getUser();
  if (authError || !authData.user) notFound();

  let cases: SupportCase[] = [];
  let unavailable = false;
  try {
    const admin = createSupabaseAdminClient();
    const { data, error } = await admin
      .from("support_cases")
      .select(
        "id,category,subject,status,priority,created_at,updated_at,resolved_at,closed_at",
      )
      .eq("requester_id", authData.user.id)
      .order("created_at", { ascending: false })
      .limit(50);
    if (error) unavailable = true;
    else cases = (data ?? []) as SupportCase[];
  } catch {
    unavailable = true;
  }

  return (
    <main className="mx-auto w-full max-w-4xl space-y-8 px-4 py-10">
      <header className="space-y-2">
        <p className="text-sm text-muted-foreground">Web-Temify support</p>
        <h1 className="text-3xl font-semibold tracking-tight">Support cases</h1>
        <p className="max-w-2xl text-muted-foreground">
          Open a case for account, billing, product-access, rights, or security
          concerns. Never include passwords, payment-card details, or
          authentication secrets.
        </p>
      </header>
      <section aria-labelledby="open-support-case" className="space-y-3">
        <h2 id="open-support-case" className="text-xl font-semibold">
          Open a support case
        </h2>
        ...[truncated]