import Link from "next/link";
import { getAdminContext } from "@/server/admin/authorization";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type ModerationCase = {
  id: string;
  product_id: string;
  reporter_id: string;
  reason_code: string;
  description: string;
  status: string;
  resolution_code: string | null;
  resolution_note: string | null;
  created_at: string;
  updated_at: string;
  decided_by: string | null;
  decided_at: string | null;
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
  const adminContext = await getAdminContext("listing_moderation_queue");
  if (!adminContext) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-12">
        <h1 className="text-2xl font-semibold">Moderation queue unavailable</h1>
        <p className="mt-3 text-sm">An authorized administrator session is required.</p>
      </main>
    );
  }

  const { data, error } = await adminContext.admin
    .from("listing_moderation_cases")
    .select("id,product_id,reporter_id,reason_code,description,status,resolution_code,resolution_note,created_at,updated_at,decided_by,decided_at")
    .order("created_at", { ascending: true })
    .limit(50);

  if (error) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-12">
        <h1 className="text-2xl font-semibold">Moderation queue unavailable</h1>
        <p className="mt-3 text-sm">The queue could not be loaded. No underlying database details are exposed.</p>
      </main>
    );
  }

  const cases = (data ?? []) as ModerationCase[];
  return (
    <main className="mx-auto max-w-6xl px-6 py-10">
      <nav className="mb-6 text-sm"><Link href="/admin" className="underline">Admin console</Link> / Moderation</nav>
      <header className="mb-8">
        <h1 className="text-3xl font-semibold">Listing moderation</h1>
        <p className="mt-2 max-w-3xl text-sm text-neutral-600">
          Review reported listings with reason-coded, audited case transitions. This queue records moderation decisions;
          it does not itself unpublish or takedown a listing. Use the rights-review and security workflows for the required enforcement action.
        </p>
      </header>
      {cases.length === 0 ? (
        <section className="rounded-lg border p-6"><h2 className="font-medium">No reports yet</h2><p className="mt-1 text-sm text-neutral-600">New authenticated reports will appear here.</p></section>
      ) : (
        <ol className="space-y-4">
          {cases.map((item) => (
            <li key={item.id} className="rounded-lg border p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <h2 className="font-semibold">{reasonLabels[item.reason_code] ?? "Report"}</h2>
                <span className="rounded border px-2 py-1 text-xs">{item.status.replaceAll("_", " ")}</span>
              </div>
              <p className="mt-3 whitespace-pre-wrap text-sm">{item.description}</p>
              <dl className="mt-4 grid gap-2 text-xs text-neutral-600 sm:grid-cols-2">
                <div><dt className="font-medium">Case</dt><dd className="break-all">{item.id}</dd></div>
                <div><dt className="font-medium">Product ID</dt><dd className="break-all">{item.product_id}</dd></div>
                <div><dt className="font-medium">Reporter ID</dt><dd className="break-all">{item.reporter_id}</dd></div>
                <div><dt className="font-medium">Received</dt><dd>{new Date(item.created_at).toISOString()}</dd></div>
              </dl>
              {item.resolution_code && <p className="mt-3 text-sm">Resolution: {item.resolution_code.replaceAll("_", " ")}</p>}
            </li>
          ))}
        </ol>
      )}
      <p className="mt-8 text-xs text-neutral-500">Showing at most 50 oldest cases. Actions require the audited admin transition API and a reasoned decision.</p>
    </main>
  );
}
