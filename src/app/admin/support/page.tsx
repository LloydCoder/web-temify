import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";
import { SupportCaseActionForm } from "./SupportCaseActionForm";

export const dynamic = "force-dynamic";

type SupportCase = {
  id: string;
  requester_id: string;
  category: string;
  subject: string;
  description: string;
  status: string;
  priority: string;
  assigned_to: string | null;
  created_at: string;
  updated_at: string;
};

export default async function AdminSupportPage() {
  const context = await getAdminContext("support_case_queue");
  if (!context) notFound();

  const { data, error } = await context.admin
    .from("support_cases")
    .select("id,requester_id,category,subject,description,status,priority,assigned_to,created_at,updated_at")
    .order("updated_at", { ascending: false })
    .limit(100);

  return (
    <main className="mx-auto w-full max-w-6xl space-y-6 px-4 py-10">
      <header className="space-y-2">
        <p className="text-sm text-muted-foreground">Operations · Phase 5D</p>
        <h1 className="text-3xl font-semibold tracking-tight">Support case queue</h1>
        <p className="max-w-3xl text-muted-foreground">
          Every state transition requires an administrator, a reason, and an append-only event.
          Email notifications and automated SLA escalation are not enabled by this workflow.
        </p>
      </header>
      {error ? (
        <p role="status" className="rounded-lg border p-4 text-sm">The support queue is temporarily unavailable.</p>
      ) : !data?.length ? (
        <p className="rounded-lg border p-4 text-sm text-muted-foreground">No support cases are waiting.</p>
      ) : (
        <ul className="grid gap-4 md:grid-cols-2">
          {(data as SupportCase[]).map((supportCase) => (
            <li key={supportCase.id} className="rounded-xl border p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-xs uppercase tracking-wide text-muted-foreground">
                    {supportCase.category.replaceAll("_", " ")} · {supportCase.priority}
                  </p>
                  <h2 className="mt-1 text-lg font-semibold">{supportCase.subject}</h2>
                </div>
                <span className="rounded-full border px-3 py-1 text-xs capitalize">
                  {supportCase.status.replaceAll("_", " ")}
                </span>
              </div>
              <p className="mt-3 whitespace-pre-wrap text-sm">{supportCase.description}</p>
              <dl className="mt-3 space-y-1 text-xs text-muted-foreground">
                <div><dt className="inline">Case: </dt><dd className="inline break-all">{supportCase.id}</dd></div>
                <div><dt className="inline">Requester: </dt><dd className="inline break-all">{supportCase.requester_id}</dd></div>
                <div><dt className="inline">Updated: </dt><dd className="inline">{new Date(supportCase.updated_at).toLocaleString()}</dd></div>
                <div><dt className="inline">Assignee: </dt><dd className="inline">{supportCase.assigned_to ?? "Unassigned"}</dd></div>
              </dl>
              <SupportCaseActionForm caseId={supportCase.id} status={supportCase.status} adminId={context.userId} />
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
