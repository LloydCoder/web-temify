import Link from "next/link";
import { notFound } from "next/navigation";
import { getAdminContext } from "@/server/admin/authorization";
import { parseAuditFilters } from "@/server/admin/audit-filters";

export const dynamic = "force-dynamic";

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function formatTimestamp(value: string) {
  return `${new Date(value).toLocaleString("en", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC"
  })} UTC`;
}

function buildNextHref(filters: { action?: string; entityType?: string }, cursor: string) {
  const params = new URLSearchParams({ cursor });
  if (filters.action) params.set("action", filters.action);
  if (filters.entityType) params.set("entityType", filters.entityType);
  return `/admin/audit?${params.toString()}`;
}

export default async function AdminAuditExplorerPage({ searchParams }: PageProps) {
  const context = await getAdminContext("audit_explorer");
  if (!context) notFound();

  const filters = parseAuditFilters(await searchParams);
  let events: Array<{
    id: number;
    action: string;
    entity_type: string;
    entity_id: string | null;
    request_id: string | null;
    created_at: string;
  }> = [];
  let queryFailed = false;
  let hasMore = false;

  if (!filters.invalid) {
    try {
      let query = context.admin
        .from("audit_events")
        .select("id,action,entity_type,entity_id,request_id,created_at")
        .order("id", { ascending: false })
        .limit(51);
      if (filters.action) query = query.eq("action", filters.action);
      if (filters.entityType) query = query.eq("entity_type", filters.entityType);
      if (filters.cursor) query = query.lt("id", filters.cursor);

      const result = await query;
      queryFailed = Boolean(result.error);
      if (!result.error && result.data) {
        hasMore = result.data.length > 50;
        events = result.data.slice(0, 50);
      }
    } catch {
      queryFailed = true;
    }
  }

  const lastEvent = events.at(-1);
  const nextHref = hasMore && lastEvent ? buildNextHref(filters, String(lastEvent.id)) : null;

  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link className="wordmark" href="/admin" aria-label="Admin operations home">
          Web-Temify<span className="wordmark-dot" aria-hidden="true">.</span>
        </Link>
        <nav className="admin-audit-nav" aria-label="Admin navigation">
          <Link className="button button-secondary" href="/admin/reviews">Rights review</Link>
          <Link className="button button-secondary" href="/admin">Operations overview</Link>
        </nav>
      </header>

      <section className="catalog-heading" aria-labelledby="audit-explorer-title">
        <p className="eyebrow">Restricted operations · Phase 5C</p>
        <h1 id="audit-explorer-title">Audit explorer</h1>
        <p className="hero-copy">Search the append-only audit stream using exact action and entity-type filters. Sensitive event metadata is intentionally not exposed.</p>
      </section>

      <form className="admin-audit-filters" method="get" action="/admin/audit" aria-label="Audit filters">
        <label>
          Action
          <input name="action" maxLength={120} defaultValue={filters.action ?? ""} autoComplete="off" placeholder="e.g. admin.product_rights.reviewed" />
        </label>
        <label>
          Entity type
          <input name="entityType" maxLength={120} defaultValue={filters.entityType ?? ""} autoComplete="off" placeholder="e.g. product" />
        </label>
        <div className="admin-audit-filter-actions">
          <button className="button button-primary" type="submit">Apply filters</button>
          <Link className="button button-secondary" href="/admin/audit">Clear filters</Link>
        </div>
      </form>

      {filters.invalid ? (
        <p className="notice" role="alert">One or more audit filters are invalid. Use exact action/entity values and clear the filters to continue.</p>
      ) : queryFailed ? (
        <p className="notice" role="status">The audit stream is unavailable. No underlying database details are exposed.</p>
      ) : (
        <>
          <p className="admin-audit-count" role="status">
            Showing {events.length} event{events.length === 1 ? "" : "s"}{filters.action ? ` for action “${filters.action}”` : ""}{filters.entityType ? ` for entity type “${filters.entityType}”` : ""}.
          </p>
          {events.length === 0 ? (
            <p className="notice" role="status">No audit events match these filters.</p>
          ) : (
            <section className="admin-audit-list" aria-label="Audit events">
              {events.map((event) => (
                <article className="admin-audit-item admin-audit-record" key={event.id}>
                  <div className="admin-audit-record-main">
                    <p className="eyebrow">Event #{event.id}</p>
                    <h2>{event.action}</h2>
                    <p><strong>Entity:</strong> {event.entity_type}{event.entity_id ? ` · ${event.entity_id}` : ""}</p>
                    {event.request_id && <p><strong>Request ID:</strong> <code>{event.request_id}</code></p>}
                  </div>
                  <time dateTime={event.created_at}>{formatTimestamp(event.created_at)}</time>
                </article>
              ))}
            </section>
          )}
          {nextHref && (
            <nav className="admin-audit-pagination" aria-label="Audit pagination">
              <Link className="button button-secondary" href={nextHref}>Next page</Link>
            </nav>
          )}
        </>
      )}

      <footer className="site-footer">
        <span>Restricted administrative surface</span>
        <span>Audit metadata and financial secrets are not exposed by this view.</span>
      </footer>
    </main>
  );
}
