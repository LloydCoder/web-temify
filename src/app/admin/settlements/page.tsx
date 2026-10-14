import Link from "next/link";
import type { UrlObject } from "url";
import { notFound } from "next/navigation";
import { z } from "zod";
import { getAdminContext } from "@/server/admin/authorization";

export const dynamic = "force-dynamic";

const queueItemSchema = z
  .object({
    run_id: z.string().uuid(),
    row_id: z.string().min(1).max(240),
    result_code: z.enum([
      "missing_internal_match",
      "duplicate_reference",
      "amount_mismatch",
      "currency_mismatch",
      "unsupported_row_type",
    ]),
    result_created_at: z.string().datetime({ offset: true }),
    provider: z.string().min(1).max(40),
    report_reference: z.string().min(1).max(240),
    report_period_start: z.string().date(),
    report_period_end: z.string().date(),
    report_timezone: z.string().min(1).max(100),
    currency: z.string().regex(/^[A-Z]{3}$/),
    row_type: z.enum(["payment", "refund", "fee", "payout", "adjustment"]),
    provider_reference: z.string().max(240).nullable(),
    payment_reference: z.string().max(240).nullable(),
    gross_minor: z.string().regex(/^-?[0-9]{1,19}$/),
    fee_minor: z.string().regex(/^[0-9]{1,19}$/),
    net_minor: z.string().regex(/^-?[0-9]{1,19}$/),
    triage_decision: z
      .enum([
        "reimport_required",
        "manual_review_required",
        "accepted_with_evidence",
      ])
      .nullable(),
    triage_reason: z.string().max(500).nullable(),
    triage_created_at: z.string().datetime({ offset: true }).nullable(),
  })
  .strict();

const cursorSchema = z
  .object({
    cursorAt: z.string().datetime({ offset: true }),
    cursorRunId: z.string().uuid(),
    cursorRowId: z.string().min(1).max(240),
  })
  .strict();

type QueueItem = z.infer<typeof queueItemSchema>;

function formatMinorUnits(value: string) {
  return BigInt(value).toLocaleString("en");
}

function formatTimestamp(value: string) {
  return `${new Date(value).toLocaleString("en", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  })} UTC`;
}

function nextPageHref(item: QueueItem): UrlObject {
  return {
    pathname: "/admin/settlements",
    query: {
      cursorAt: item.result_created_at,
      cursorRunId: item.run_id,
      cursorRowId: item.row_id,
    },
  };
}

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function AdminSettlementExceptionsPage({
  searchParams,
}: PageProps) {
  const context = await getAdminContext("settlement_exception_queue");
  if (!context) notFound();

  const params = await searchParams;
  const cursorInput = {
    cursorAt: params.cursorAt,
    cursorRunId: params.cursorRunId,
    cursorRowId: params.cursorRowId,
  };
  const hasAnyCursor = Object.values(cursorInput).some(
    (value) => value !== undefined,
  );
  const cursor = hasAnyCursor ? cursorSchema.safeParse(cursorInput) : null;
  const cursorInvalid = hasAnyCursor && (!cursor || !cursor.success);
  let rows: QueueItem[] = [];
  let hasMore = false;
  let queryFailed = false;

  if (!cursorInvalid) {
    try {
      const { data, error } = await context.admin.rpc(
        "list_settlement_exception_queue",
        {
          p_admin_id: context.userId,
          p_limit: 51,
          p_before_created_at: cursor?.success ? cursor.data.cursorAt : null,
          p_before_run_id: cursor?.success ? cursor.data.cursorRunId : null,
          p_before_row_id: cursor?.success ? cursor.data.cursorRowId : null,
        },
      );
      if (error || !Array.isArray(data)) {
        queryFailed = true;
      } else {
        const parsed = z.array(queueItemSchema).max(51).safeParse(data);
        if (!parsed.success) {
          queryFailed = true;
        } else {
          hasMore = parsed.data.length > 50;
          rows = parsed.data.slice(0, 50);
        }
      }
    } catch {
      queryFailed = true;
    }
  }

  const lastRow = rows.at(-1);
  const nextHref = hasMore && lastRow ? nextPageHref(lastRow) : null;

  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link
          className="wordmark"
          href="/admin"
          aria-label="Admin operations home"
        >
          Web-Temify
          <span className="wordmark-dot" aria-hidden="true">
            .
          </span>
        </Link>
        <nav className="admin-audit-nav" aria-label="Admin navigation">
          <Link className="button button-secondary" href="/admin">
            Operations overview
          </Link>
          <Link className="button button-secondary" href="/admin/audit">
            Audit explorer
          </Link>
          <Link className="button button-secondary" href="/admin/reviews">
            Rights review
          </Link>
        </nav>
      </header>

      <section
        className="catalog-heading"
        aria-labelledby="settlement-exceptions-title"
      >
        <p className="eyebrow">Restricted operations · Phase 4D2</p>
        <h1 id="settlement-exceptions-title">Settlement exceptions</h1>
        <p className="hero-copy">
          Read-only view of immutable settlement reconciliation exceptions. A
          triage decision records follow-up intent; it does not resolve an
          accounting exception or authorize journal posting, refunds, or
          payouts.
        </p>
      </section>

      {cursorInvalid ? (
        <p className="notice" role="alert">
          The pagination cursor is invalid. Return to the first page.
        </p>
      ) : queryFailed ? (
        <p className="notice" role="status">
          The settlement exception queue is unavailable. No underlying database
          details are exposed.
        </p>
      ) : rows.length === 0 ? (
        <p className="notice" role="status">
          No settlement exceptions are currently available.
        </p>
      ) : (
        <>
          <p className="admin-audit-count" role="status">
            Showing {rows.length} exception{rows.length === 1 ? "" : "s"}
            {hasMore ? " · more available" : ""}.
          </p>
          <section
            className="admin-review-list"
            aria-label="Settlement exception records"
          >
            {rows.map((item) => (
              <article
                className="admin-review-card"
                key={`${item.run_id}:${item.row_id}`}
              >
                <header>
                  <div>
                    <p className="eyebrow">
                      {item.provider} · {item.report_reference}
                    </p>
                    <h2>{item.result_code.replaceAll("_", " ")}</h2>
                    <p>
                      Row: <code>{item.row_id}</code> · Type: {item.row_type}
                    </p>
                  </div>
                  <div className="admin-review-meta">
                    <span>{item.currency}</span>
                    <span>
                      {item.triage_decision?.replaceAll("_", " ") ??
                        "awaiting triage"}
                    </span>
                  </div>
                </header>
                <dl className="admin-settlement-details">
                  <div>
                    <dt>Report period</dt>
                    <dd>
                      {item.report_period_start} – {item.report_period_end}
                    </dd>
                  </div>
                  <div>
                    <dt>Report timezone</dt>
                    <dd>{item.report_timezone}</dd>
                  </div>
                  <div>
                    <dt>Provider reference</dt>
                    <dd>{item.provider_reference ?? "Not supplied"}</dd>
                  </div>
                  <div>
                    <dt>Internal payment reference</dt>
                    <dd>{item.payment_reference ?? "Not supplied"}</dd>
                  </div>
                  <div>
                    <dt>Gross (minor units)</dt>
                    <dd>{formatMinorUnits(item.gross_minor)}</dd>
                  </div>
                  <div>
                    <dt>Fee (minor units)</dt>
                    <dd>{formatMinorUnits(item.fee_minor)}</dd>
                  </div>
                  <div>
                    <dt>Net (minor units)</dt>
                    <dd>{formatMinorUnits(item.net_minor)}</dd>
                  </div>
                  <div>
                    <dt>Reconciliation recorded</dt>
                    <dd>{formatTimestamp(item.result_created_at)}</dd>
                  </div>
                  <div>
                    <dt>Triage reason</dt>
                    <dd>
                      {item.triage_reason ?? "No triage decision recorded"}
                    </dd>
                  </div>
                </dl>
              </article>
            ))}
          </section>
          {nextHref && (
            <nav
              className="admin-audit-pagination"
              aria-label="Settlement exception pagination"
            >
              <Link className="button button-secondary" href={nextHref}>
                Next 50 exceptions
              </Link>
            </nav>
          )}
        </>
      )}

      <footer className="site-footer">
        <span>Read-only settlement exception queue</span>
        <span>
          Live provider processing and financial exception resolution remain
          disabled.
        </span>
      </footer>
    </main>
  );
}
