import Link from "next/link";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { CreatorAppealForm } from "./CreatorAppealForm";

export const dynamic = "force-dynamic";

type OwnedProduct = { id: string; slug: string; name: string; status: string };
type Enforcement = {
  id: string;
  product_id: string;
  case_id: string;
  reason_code: string;
  applied_at: string;
};
type Appeal = {
  id: string;
  enforcement_id: string;
  status: string;
  response_due_at: string | null;
  deadline_policy_version: string | null;
  submitted_at: string;
  decision_note: string | null;
};

export default async function CreatorModerationAppealsPage() {
  let userId: string | null = null;
  try {
    const session = await createSupabaseServerClient();
    const { data, error } = await session.auth.getUser();
    if (!error && data.user) userId = data.user.id;
  } catch {
    userId = null;
  }

  if (!userId) {
    return (
      <main className="mx-auto w-full max-w-3xl space-y-4 px-4 py-12">
        <h1 className="text-3xl font-semibold">Creator takedown appeals</h1>
        <p role="status" className="rounded-lg border p-4 text-sm">
          Sign in with the account that owns the affected listing to review or
          submit an appeal.
        </p>
        <Link className="underline" href="/catalog">
          Return to catalogue
        </Link>
      </main>
    );
  }

  let products: OwnedProduct[] = [];
  let enforcements: Enforcement[] = [];
  let appeals: Appeal[] = [];
  let unavailable = false;
  try {
    const admin = createSupabaseAdminClient();
    const productsResult = await admin
      .from("products")
      .select("id,slug,name,status")
      .eq("creator_id", userId)
      .eq("status", "archived")
      .limit(200);
    if (productsResult.error) throw new Error("products_unavailable");
    products = (productsResult.data ?? []) as OwnedProduct[];
    const productIds = products.map((product) => product.id);
    if (productIds.length) {
      const enforcementResult = await admin
        .from("listing_moderation_enforcements")
        .select("id,product_id,case_id,reason_code,applied_at")
        .eq("status", "active")
        .in("product_id", productIds)
        .order("applied_at", { ascending: false })
        .limit(200);
      if (enforcementResult.error) throw new Error("enforcements_unavailable");
      enforcements = (enforcementResult.data ?? []) as Enforcement[];
    }
    const appealResult = await admin
      .from("listing_moderation_appeals")
      .select(
        "id,enforcement_id,status,response_due_at,deadline_policy_version,submitted_at,decision_note",
      )
      .eq("creator_id", userId)
      .order("submitted_at", { ascending: false })
      .limit(200);
    if (appealResult.error) throw new Error("appeals_unavailable");
    appeals = (appealResult.data ?? []) as Appeal[];
  } catch {
    unavailable = true;
  }

  const productById = new Map(products.map((product) => [product.id, product]));
  const appealByEnforcement = new Map(
    appeals.map((appeal) => [appeal.enforcement_id, appeal]),
  );

  return (
    <main className="mx-auto w-full max-w-5xl space-y-6 px-4 py-10">
      <header className="space-y-2">
        <p className="text-sm text-muted-foreground">Creator account</p>
        <h1 className="text-3xl font-semibold tracking-tight">
          Takedown appeals
        </h1>
        <p className="max-w-3xl text-muted-foreground">
          Only active takedowns for listings owned by your signed-in account are
          shown. Appeals are recorded and reviewed independently; submitting one
          does not automatically restore publication.
        </p>
      </header>
      {unavailable ? (
        <p role="status" className="rounded-lg border p-4 text-sm">
          Appeal information is temporarily unavailable. No action has been
          submitted.
        </p>
      ) : null}
      {!unavailable && enforcements.length === 0 ? (
        <p className="rounded-lg border p-4 text-sm text-muted-foreground">
          No active takedowns were found for your archived listings.
        </p>
      ) : null}
      {!unavailable && enforcements.length ? (
        <ul className="space-y-4">
          {enforcements.map((enforcement) => {
            const product = productById.get(enforcement.product_id);
            const appeal = appealByEnforcement.get(enforcement.id);
            return (
              <li key={enforcement.id} className="rounded-xl border p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h2 className="text-lg font-semibold">
                      {product?.name ?? "Archived listing"}
                    </h2>
                    {product?.slug ? (
                      <p className="text-sm text-muted-foreground">
                        Slug: {product.slug}
                      </p>
                    ) : null}
                  </div>
                  <span className="rounded-full border px-3 py-1 text-xs">
                    Takedown active
                  </span>
                </div>
                <dl className="mt-3 space-y-1 text-xs text-muted-foreground">
                  <div>
                    <dt className="inline">Case: </dt>
                    <dd className="inline break-all">{enforcement.case_id}</dd>
                  </div>
                  <div>
                    <dt className="inline">Enforcement: </dt>
                    <dd className="inline break-all">{enforcement.id}</dd>
                  </div>
                  <div>
                    <dt className="inline">Reason: </dt>
                    <dd className="inline">
                      {enforcement.reason_code.replaceAll("_", " ")}
                    </dd>
                  </div>
                  <div>
                    <dt className="inline">Applied: </dt>
                    <dd className="inline">
                      {new Date(enforcement.applied_at).toLocaleString()}
                    </dd>
                  </div>
                </dl>
                {appeal ? (
                  <div className="mt-4 rounded-lg border p-4">
                    <p className="text-sm font-medium">
                      Appeal status: {appeal.status.replaceAll("_", " ")}
                    </p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {appeal.response_due_at
                        ? `Internal response target: ${new Date(appeal.response_due_at).toLocaleString()} (${appeal.deadline_policy_version})`
                        : "No approved response target existed when this appeal was submitted."}
                    </p>
                    {appeal.decision_note ? (
                      <p className="mt-2 whitespace-pre-wrap text-sm">
                        {appeal.decision_note}
                      </p>
                    ) : null}
                  </div>
                ) : (
                  <CreatorAppealForm enforcementId={enforcement.id} />
                )}
              </li>
            );
          })}
        </ul>
      ) : null}
      {appeals.length ? (
        <section className="space-y-3" aria-labelledby="appeal-history-title">
          <h2 id="appeal-history-title" className="text-xl font-semibold">
            Your appeal history
          </h2>
          <ul className="space-y-2">
            {appeals.map((appeal) => (
              <li key={appeal.id} className="rounded-lg border p-3 text-sm">
                <p className="font-medium">
                  {appeal.status.replaceAll("_", " ")}
                </p>
                <p className="break-all text-xs text-muted-foreground">
                  Appeal {appeal.id} · submitted{" "}
                  {new Date(appeal.submitted_at).toLocaleString()}
                </p>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </main>
  );
}
