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
      .select("id,category,subject,status,priority,created_at,updated_at,resolved_at,closed_at")
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
          Open a case for account, billing, product-access, rights, or security concerns.
          Never include passwords, payment-card details, or authentication secrets.
        </p>
      </header>
      <section aria-labelledby="open-support-case" className="space-y-3">
        <h2 id="open-support-case" className="text-xl font-semibold">Open a support case</h2>
        <SupportCaseCreateForm />
      </section>
      <section aria-labelledby="your-support-cases" className="space-y-3">
        <h2 id="your-support-cases" className="text-xl font-semibold">Your cases</h2>
        {unavailable ? (
          <p role="status" className="rounded-lg border p-4 text-sm">Support case history is temporarily unavailable.</p>
        ) : cases.length === 0 ? (
          <p className="rounded-lg border p-4 text-sm text-muted-foreground">No support cases yet.</p>
        ) : (
          <ul className="space-y-3">
            {cases.map((supportCase) => (
              <li key={supportCase.id} className="rounded-lg border p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h3 className="font-medium">{supportCase.subject}</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {supportCase.category.replaceAll("_", " ")} · Opened{" "}
                      {new Date(supportCase.created_at).toLocaleString()}
                    </p>
                  </div>
                  <span className="rounded-full border px-3 py-1 text-xs capitalize">
                    {supportCase.status.replaceAll("_", " ")}
                  </span>
                </div>
                <p className="mt-2 text-xs text-muted-foreground">Reference: {supportCase.id}</p>
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  );
}
