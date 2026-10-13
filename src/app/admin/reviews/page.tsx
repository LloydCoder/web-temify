import Link from "next/link";
import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";
import { ReviewActionForm } from "./ReviewActionForm";

export const dynamic = "force-dynamic";

export default async function AdminRightsReviewPage() {
  const context = await getAdminContext("product_rights_review_queue");
  if (!context) notFound();

  const { admin } = context;
  const attestations = await admin.from("product_rights_attestations")
    .select("id,product_id,attested_by,rights_basis,statement,evidence_reference,review_status,created_at")
    .in("review_status", ["declared", "under_review"])
    .order("created_at", { ascending: true })
    .limit(50);

  const productIds = [...new Set((attestations.data ?? []).map((item) => item.product_id))];
  const products = productIds.length
    ? await admin.from("products").select("id,name,slug,status,rights_status").in("id", productIds)
    : { data: [], error: null };
  const productById = new Map((products.data ?? []).map((product) => [product.id, product]));
  const unavailable = Boolean(attestations.error || products.error);

  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link className="wordmark" href="/admin" aria-label="Admin operations home">
          Web-Temify<span className="wordmark-dot" aria-hidden="true">.</span>
        </Link>
        <Link className="button button-secondary" href="/admin">Operations overview</Link>
      </header>
      <section className="catalog-heading" aria-labelledby="review-title">
        <p className="eyebrow">Restricted operations · Phase 5B</p>
        <h1 id="review-title">Product rights review</h1>
        <p className="hero-copy">Review creator-submitted rights attestations. A rights decision is not product publication, artifact approval, or legal advice.</p>
        <p className="notice" role="note">Independent review required: you cannot review an attestation you submitted. Decisions and notes are audit-recorded.</p>
      </section>
      {unavailable ? (
        <p className="notice" role="status">The review queue is unavailable. No underlying database details are exposed.</p>
      ) : attestations.data.length === 0 ? (
        <p className="notice" role="status">No product rights attestations are waiting for review.</p>
      ) : (
        <section className="admin-review-list" aria-label="Pending product rights attestations">
          {attestations.data.map((item) => {
            const product = productById.get(item.product_id);
            const safeEvidenceUrl = item.evidence_reference && /^https:\/\/[^\s\r\n]+$/i.test(item.evidence_reference)
              ? item.evidence_reference
              : null;
            return (
              <article className="admin-review-card" key={item.id}>
                <header>
                  <div>
                    <p className="eyebrow">Submitted {new Date(item.created_at).toLocaleDateString("en", { dateStyle: "medium", timeZone: "UTC" })} UTC</p>
                    <h2>{product?.name ?? "Product record unavailable"}</h2>
                    <p>{product?.slug ?? "Slug unavailable"} · rights state: {product?.rights_status ?? "unavailable"}</p>
                  </div>
                  <div className="admin-review-meta"><span>{item.review_status.replaceAll("_", " ")}</span><span>{item.rights_basis.replaceAll("_", " ")}</span></div>
                </header>
                <section aria-label="Creator rights statement">
                  <h3>Creator statement</h3>
                  <p>{item.statement}</p>
                </section>
                <div className="admin-review-evidence">
                  <strong>Evidence reference</strong>
                  <p>{safeEvidenceUrl ? <a href={safeEvidenceUrl} target="_blank" rel="noopener noreferrer">{safeEvidenceUrl}</a> : item.evidence_reference ?? "No evidence reference supplied."}</p>
                </div>
                <ReviewActionForm productId={item.product_id} attestationId={item.id} />
              </article>
            );
          })}
        </section>
      )}
      <footer className="site-footer">
        <span>Restricted product-rights review</span>
        <span>Approval never publishes a product or releases funds.</span>
      </footer>
    </main>
  );
}
