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
    .select(
      "id,requester_id,category,subject,description,status,priority,assigned_to,created_at,updated_at",
    )
    .order("updated_at", { ascending: false })
    .limit(100);

  return (
    <main className="mx-auto w-full max-w-6xl space-y-6 px-4 py-10">
      <header className="space-y-2">
        <p className="text-sm text-muted-foreground">Operations · Phase 5D</p>
        <h1 className="text-3xl font-semibold tracking-tight">
          Support case queue
        </h1>
        <p className="max-w-3xl text-muted-foreground">
          Every state transition requires an administrator, a reason, and an
          append-only event. Email notifications and automated SLA escalation
          are not enabled by this workflow.
        </p>
      </header>
      {error ? (
        <p role="status" className="rounded-lg border p-4 text-sm">
          The support queue is temporarily unavailable.
        </p>
      ) : !data?.length ? (
        <p className="rounded-lg border p-4 text-sm text-muted-foreground">
          No support cases are waiting.
        </p>
      ) : (
        <ul className="grid gap-4 md:grid-cols-2">
          {(data as SupportCase[]).map((supportCase) => (
            <li key={supportCase.id} className="rounded-xl border p-5">
              <div className="flex items-start justify...[truncated]