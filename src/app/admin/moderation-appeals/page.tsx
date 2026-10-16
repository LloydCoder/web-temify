import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";
import { AppealPolicyForm } from "./AppealPolicyForm";
import { ModerationAppealActionForm } from "./ModerationAppealActionForm";

export const dynamic = "force-dynamic";

type Appeal = {
  id: string;
  enforcement_id: string;
  case_id: string;
  product_id: string;
  creator_id: string;
  statement: string;
  evidence_reference: string | null;
  status: string;
  response_due_at: string | null;
  deadline_policy_version: string | null;
  submitted_at: string;
  decision_note: string | null;
};

type Product = { id: string; name: string; slug: string; creator_id: string };

type AppealPolicy = {
  response_target_hours: number;
  policy_version: string;
  is_approved: boolean;
};

export default async function AdminModerationAppealsPage() {
  const context = await getAdminContext("listing_moderation_appeals_queue");
  if (!context) notFound();

  const [{ data: appealRows, error: appealsError }, { data: policy, error: policyError }] = await Promise.all([
    context.admin.from("listing_moderation_appeals")
      .select("id,enforcement_id,case_id,product_id,creator_id,statement,evidence_reference,status,response_due_at,deadline_policy_version,submitted_at,decision_note")
      .order("submitted_at", { ascending: true })
      .limit(100),
    context.admin.from("listing_moderation_appeal_policy")
      .select("response_target_hours,policy_version,is_approved")
      .eq("singleton", true)
      .maybeSingle(),
  ]);

  const appeals = (appealRows ?? []) as Appeal[];
  const productIds = [...new Set(appeals.map((appeal) => appeal.product_id))];
  const { data: productRows, error: productsError } = productIds.length
    ? await context.admin.from("products").select("id,name,slug,creator_id").in("id", productIds)
    : { data: [], error: null };
  const products = new Map(((productRows ?? []) as Product[]).map((product) => [product.id, product]));

  return (
    <main className="mx-auto w-full max-w-6xl space-y-6 px-4 py-10">
      <header className="space-y-2">
        <p className="text-sm text-muted-foreground">Operations · Phase 5E2</p>
        <h1 className="text-3xl font-semibold tracking-tight">Creator takedown appeals</h1>
        <p className="max-w-3xl text-muted-foreground">
          Appeals are reviewed separately from the original takedown decision. Reversing an appeal restores public visibility only when the product still passes independent rights and released-artifact checks.
        </p>
      </header>
      {policyError ? (
        <p role="status" className="rounded-lg border p-4 text-sm">Appeal response policy could not be loaded. Do not approve new policy changes until the configuration is available.</p>
      ) : (
        <AppealPolicyForm
          approved={(policy as AppealPolicy | null)?.is_approved ?? false}
          responseTargetHours={(policy as AppealPolicy | null)?.response_target_hours ?? 336}
          policyVersion={(policy as AppealPolicy | null)?.policy_version ?? "unapproved-v1"}
        />
      )}
      {appealsError || productsError ? (
        <p role="status" className="rounded-lg border p-4 text-sm">The appeal queue is temporarily unavailable.</p>
      ) : !appeals.length ? (
        <p className="rounded-lg border p-4 text-sm text-muted-foreground">No creator appeals have been submitted.</p>
      ) : (
        <ul className="grid gap-4 md:grid-cols-2">
          {appeals.map((appeal) => {
            const product = products.get(appeal.product_id);
            return (
              <li key={appeal.id} className="rounded-xl border p-5">
                <div className="flex items-start justify-between gap-3">
                  <h2 className="text-lg font-semibold">{product?.name ?? "Listing unavailable"}</h2>
                  <span className="rounded-full border px-3 py-1 text-xs">{appeal.status.replaceAll("_", " ")}</span>
                </div>
                <dl className="mt-3 space-y-1 text-xs text-muted-foreground">
                  <div><dt className="inline">Appeal: </dt><dd className="inline break-all">{appeal.id}</dd></div>
                  <div><dt className="inline">Case: </dt><dd className="inline break-all">{appeal.case_id}</dd></div>
                  <div><dt className="inline">Creator: </dt><dd className="inline break-all">{appeal.creator_id}</dd></div>
                  <div><dt className="inline">Submitted: </dt><dd className="inline">{new Date(appeal.submitted_at).toLocaleString()}</dd></div>
                  <div><dt className="inline">Response target: </dt><dd className="inline">{appeal.response_due_at ? `${new Date(appeal.response_due_at).toLocaleString()} (${appeal.deadline_policy_version})` : "Not assigned — no approved policy existed at submission"}</dd></div>
                  {product?.slug ? <div><dt className="inline">Slug: </dt><dd className="inline">{product.slug}</dd></div> : null}
                </dl>
                <h3 className="mt-4 text-sm font-medium">Creator statement</h3>
                <p className="mt-1 whitespace-pre-wrap text-sm">{appeal.statement}</p>
                {appeal.evidence_reference ? <p className="mt-2 break-all text-xs text-muted-foreground">Evidence reference: {appeal.evidence_reference}</p> : null}
                {appeal.decision_note ? <p className="mt-2 whitespace-pre-wrap text-xs text-muted-foreground">Decision note: {appeal.decision_note}</p> : null}
                <ModerationAppealActionForm appealId={appeal.id} status={appeal.status} />
              </li>
            );
          })}
        </ul>
      )}
      <p className="text-xs text-muted-foreground">Showing at most 100 oldest appeals. All decisions require a reasoned audit note and database-enforced state transition.</p>
    </main>
  );
}
