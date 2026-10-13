import Link from "next/link";
import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";

export const dynamic = "force-dynamic";

type CountResult = { count: number | null; error: boolean };
async function countRows(
  query: PromiseLike<{ count: number | null; error: unknown }>,
): Promise<CountResult> {
  const result = await query;
  return { count: result.count, error: Boolean(result.error) };
}

function displayCount(value: number | null) {
  return value === null ? "—" : new Intl.NumberFormat("en").format(value);
}

export default async function AdminOperationsPage() {
  const context = await getAdminContext();
  if (!context) notFound();

  const { admin } = context;
  const [
    products,
    pendingReview,
    orders,
    paidOrders,
    failedWebhooks,
    refunds,
    auditEvents,
  ] = await Promise.all([
    countRows(
      admin.from("products").select("id", { count: "exact", head: true }),
    ),
    countRows(
      admin
        .from("products")
        .select("id", { count: "exact", head: true })
        .eq("status", "pending_review"),
    ),
    countRows(
      admin.from("orders").select("id", { count: "exact", head: true }),
    ),
    countRows(
      admin
        .from("orders")
        .select("id", { count: "exact", head: true })
        .eq("status", "paid"),
    ),
    countRows(
      admin
        .from("payment_webhook_events")
        .select("id", { count: "exact", head: true })
        .eq("processing_status", "failed"),
    ),
    countRows(
      admin.from("refunds").select("id", { count: "exact", head: true }),
    ),
    admin
      .from("audit_events")
      .select("id,action,entity_type,entity_id,request_id,created_at")
      .order("created_at", { ascending: false })
      .limit(20),
  ]);

  const metrics = [
    { label: "Catalogue records", result: products },
    { label: "Awaiting review", result: pendingReview },
    { label: "Orders", result: orders },
    { label: "Paid orders", result: paidOrders },
    { label: "Failed webhook events", result: failedWebhooks },
    { label: "Refund records", result: refunds },
  ];
  const snapshotAvailable =
    metrics.every((metric) => !metric.result.error) && !auditEvents.error;

  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link className="wordmark" href="/" aria-label="Web-Temify home">
          Web-Temify
          <span className="wordmark-dot" aria-hidden="true">
            .
          </span>
        </Link>
        <nav className="admin-audit-nav" aria-label="Admin navigation">
          <Link className="button button-secondary" href="/admin/reviews">
            Rights review
          </Link>
          <Link className="button button-secondary" href="/admin/audit">
            Audit explorer
          </Link>
          <Link className="button button-secondary" href="/">
            Public site
          </Link>
        </nav>
      </header>
      <section className="catalog-heading" aria-labelledby="admin-title">
        <p className="eyebrow">Restricted operations</p>
        <h1 id="admin-title">Admin operations</h1>
        <p className="hero-copy">
          Read-only operational snapshot. This console does not authorize
          financial changes, publish products, or trigger provider actions.
        </p>
        {!snapshotAvailable && (
          <p className="notice" role="status">
            Some operational data is unavailable. No underlying database details
            are exposed.
          </p>
        )}
      </section>
      <section className="catalog-grid" aria-label="Operational metrics">
        {metrics.map((metric) => (
          <article className="catalog-card" key={metric.label}>
            <p className="eyebrow">{metric.label}</p>
            <h2>
              {metric.result.error
                ? "Unavailable"
                : displayCount(metric.result.count)}
            </h2>
          </article>
        ))}
      </section>
      <section className="admin-audit" aria-labelledby="audit-title">
        <h2 id="audit-title">Recent audit activity</h2>
        {auditEvents.error ? (
          <p className="notice" role="status">
            Audit activity is unavailable.
          </p>
        ) : auditEvents.data.length === 0 ? (
          <p className="notice" role="status">
            No audit events have been recorded yet.
          </p>
        ) : (
          <div className="admin-audit-list">
            {auditEvents.data.map((event) => (
              <article className="admin-audit-item" key={event.id}>
                <div>
                  <strong>{event.action}</strong>
                  <p>
                    {event.entity_type}
                    {event.entity_id ? ` · ${event.entity_id}` : ""}
                  </p>
                </div>
                <time dateTime={event.created_at}>
                  {new Date(event.created_at).toLocaleString("en", {
                    dateStyle: "medium",
                    timeStyle: "short",
                    timeZone: "UTC",
                  })}{" "}
                  UTC
                </time>
              </article>
            ))}
          </div>
        )}
      </section>
      <footer className="site-footer">
        <span>Restricted administrative surface</span>
        <span>Financial mutations remain disabled in this console.</span>
      </footer>
    </main>
  );
}
