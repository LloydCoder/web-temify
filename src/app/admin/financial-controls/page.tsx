import Link from "next/link";
import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";
import FinancialControlsClient from "./FinancialControlsClient";

export const dynamic = "force-dynamic";

export default async function FinancialControlsPage() {
  const context = await getAdminContext("financial_control_page");
  if (!context) notFound();

  const { data, error } = await context.admin
    .from("financial_control_requests")
    .select(
      "id,request_type,status,seller_id,order_id,target_hold_id,amount_minor,currency,reason,requested_by,approved_at,created_at,updated_at",
    )
    .order("created_at", { ascending: false })
    .limit(50);

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
          <Link className="button button-secondary" href="/admin">
            Operations
          </Link>
          <Link className="button button-secondary" href="/admin/audit">
            Audit explorer
          </Link>
          <Link className="button button-secondary" href="/">
            Public site
          </Link>
        </nav>
      </header>
      <section
        className="catalog-heading"
        aria-labelledby="financial-controls-title"
      >
        <p className="eyebrow">Restricted operations · maker/checker</p>
        <h1 id="financial-controls-title">Financial control requests</h1>
        <p className="hero-copy">
          Requests require two distinct administrators. The requester cannot
          approve their own request. Approval does not post journal entries,
          move funds, or prove that a payout provider enforces a hold.
        </p>
      </section>
      {error ? (
        <p className="notice" role="status">
          Financial control data is unavailable. No database details are
          exposed.
        </p>
      ) : (
        <FinancialControlsClient
          requests={(data ?? []).map((row) => ({
            id: row.id,
            requestType: row.request_type,
            status: row.status,
            sellerId: row.seller_id,
            orderId: row.order_id,
            targetHoldId: row.target_hold_id,
            amountMinor: String(row.amount_minor),
            currency: row.currency,
            reason: row.reason,
            requestedBy: row.requested_by,
            approvedAt: row.approved_at,
            createdAt: row.created_at,
          }))}
        />
      )}
      <footer className="site-footer">
        <span>Internal control workflow only</span>
        <span>Live payouts and manual journal posting remain disabled.</span>
      </footer>
    </main>
  );
}
