import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";
import { ModerationCaseActionForm } from "./ModerationCaseActionForm";
import { ModerationCaseTakedownForm } from "./ModerationCaseTakedownForm";

export const dynamic = "force-dynamic";

type ResolutionCode =
  | "listing_review_required"
  | "rights_review_required"
  | "security_review_required"
  | "no_violation_found"
  | "duplicate_report"
  | "insufficient_evidence";

type ModerationCase = {
  id: string;
  product_id: string;
  reporter_id: string;
  reason_code: string;
  description: string;
  status: string;
  resolution_code: ResolutionCode | null;
  created_at: string;
};

const reasonLabels: Record<string, string> = {
  ip_rights: "Intellectual property / rights",
  fraud_misrepresentation: "Fraud or misrepresentation",
  malware_security: "Malware or security",
  prohibited_content: "Prohibited content",
  privacy: "Privacy",
  other: "Other",
};

export default async function AdminModerationPage() {
  const context = await getAdminContext("listing_moderation_queue");
  if (!context) notFound();

  const { data, error } = await context.admin
    .from("listing_moderation_cases")
    .select(
      "id,product_id,reporter_id,reason_code,description,status,resolution_code,created_at",
    )
    .order("created_at", { ascending: true })
    .limit(50);

  return (
    <main className="mx-auto w-full max-w-6xl space-y-6 px-4 py-10">
      <header className="space-y-2">
        <p className="text-sm text-muted-foreground">Operations · Phase 5E1</p>
        <h1 className="text-3xl font-semibold tracking-tight">
          Listing moderation
        </h1>
        <p className="max-w-3xl text-muted-foreground">
          Review reported listings with reason-coded, audited case transitions.
          This queue does not itself unpublish listings. Takedown enforcement
          and creator appeals remain separate required workflows.
        </p>
      </header>
      {error ? (
        <p role="status" className="rounded-lg border p-4 text-sm">
          The moderation queue is temporarily unavailable.
        </p>
      ) : !data?.length ? (
        <p className="rounded-lg border p-4 text-sm text-muted-foreground">
          No moderation reports have been submitted.
        </p>
      ) : (
        <ul className="grid gap-4 md:grid-cols-2">
          {(data as ModerationCase[]).map((item) => (
            <li key={item.id} className="rounded-xl border p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h2 className="text-lg font-semibold">
                    {reasonLabels[item.reason_code] ?? "Report"}
                  </h2>
                </div>
                <span className="rounded-full border px-3 py-1 text-xs">
                  {item.status.replaceAll("_", " ")}
                </span>
              </div>
              <p className="mt-3 whitespace-pre-wrap text-sm">
                {item.description}
              </p>
              <dl className="mt-3 space-y-1 text-xs text-muted-foreground">
                <div>
                  <dt className="inline">Case: </dt>
                  <dd className="inline break-all">{item.id}</dd>
                </div>
                <div>
                  <dt className="inline">Product: </dt>
                  <dd className="inline break-all">{item.product_id}</dd>
                </div>
                <div>
                  <dt className="inline">Reporter: </dt>
                  <dd className="inline break-all">{item.reporter_id}</dd>
                </div>
                <div>
                  <dt className="inline">Received: </dt>
                  <dd className="inline">
                    {new Date(item.created_at).toLocaleString()}
                  </dd>
                </div>
                {item.resolution_code && (
                  <div>
                    <dt className="inline">Resolution: </dt>
                    <dd className="inline">
                      {item.resolution_code.replaceAll("_", " ")}
                    </dd>
                  </div>
                )}
              </dl>
              <ModerationCaseActionForm
                caseId={item.id}
                status={item.status}
                resolutionCode={item.resolution_code}
              />
              {item.status === "action_required" &&
              item.resolution_code &&
              [
                "listing_review_required",
                "rights_review_required",
                "security_review_required",
              ].includes(item.resolution_code) ? (
                <ModerationCaseTakedownForm caseId={item.id} />
              ) : null}
            </li>
          ))}
        </ul>
      )}
      <p className="text-xs text-muted-foreground">
        Showing at most 50 oldest cases. Decisions require the audited admin
        transition API and a reasoned outcome.
      </p>
    </main>
  );
}
