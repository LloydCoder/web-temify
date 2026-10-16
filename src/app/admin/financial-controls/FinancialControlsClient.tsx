"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";

type RequestType =
  | "manual_adjustment"
  | "negative_balance_review"
  | "payout_hold"
  | "payout_hold_release";

type ControlRequest = {
  id: string;
  requestType: string;
  status: string;
  sellerId: string;
  orderId: string | null;
  targetHoldId: string | null;
  amountMinor: string;
  currency: string;
  reason: string;
  requestedBy: string;
  approvedAt: string | null;
  createdAt: string;
};

const requestTypes: { value: RequestType; label: string }[] = [
  { value: "manual_adjustment", label: "Manual adjustment review" },
  { value: "negative_balance_review", label: "Negative balance review" },
  { value: "payout_hold", label: "Place internal payout hold" },
  { value: "payout_hold_release", label: "Release internal payout hold" },
];

function displayDate(value: string) {
  return new Date(value).toLocaleString("en", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }) + " UTC";
}

export default function FinancialControlsClient({
  requests,
}: {
  requests: ControlRequest[];
}) {
  const router = useRouter();
  const [requestType, setRequestType] = useState<RequestType>("manual_adjustment");
  const [sellerId, setSellerId] = useState("");
  const [orderId, setOrderId] = useState("");
  const [targetHoldId, setTargetHoldId] = useState("");
  const [amountMinor, setAmountMinor] = useState("");
  const [currency, setCurrency] = useState("USD");
  const [evidenceSha256, setEvidenceSha256] = useState("");
  const [reason, setReason] = useState("");
  const [idempotencyKey, setIdempotencyKey] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  async function submitRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/admin/financial-controls", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          requestType,
          sellerId,
          orderId: orderId.trim() || null,
          targetHoldId: requestType === "payout_hold_release" ? targetHoldId.trim() : null,
          amountMinor,
          currency,
          evidenceSha256,
          reason,
          idempotencyKey: idempotencyKey.trim() || crypto.randomUUID(),
        }),
      });
      const result = await response.json();
      if (!response.ok) {
        setMessage("Request was not created. Check the fields and your authorization, then try again.");
        return;
      }
      setMessage(`Request recorded: ${result.requestId}. It requires two distinct approvals.`);
      setOrderId("");
      setTargetHoldId("");
      setAmountMinor("");
      setEvidenceSha256("");
      setReason("");
      setIdempotencyKey("");
      router.refresh();
    } catch {
      setMessage("Financial control service is unavailable. No success is assumed.");
    } finally {
      setBusy(false);
    }
  }

  async function reviewRequest(id: string, decision: "approve" | "reject") {
    const note = window.prompt(
      decision === "approve"
        ? "Record the independent review rationale (minimum 10 characters):"
        : "Record the rejection rationale (minimum 10 characters):",
    );
    if (note === null) return;
    if (note.trim().length < 10 || note.trim().length > 1000) {
      setMessage("Review note must contain 10–1,000 characters.");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch(`/api/admin/financial-controls/${id}/review`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ decision, note }),
      });
      if (!response.ok) {
        setMessage("Review was not recorded. The request may be ineligible or you may be the requester.");
        return;
      }
      const result = await response.json();
      setMessage(`Review recorded. Current status: ${result.status}.`);
      router.refresh();
    } catch {
      setMessage("Financial control service is unavailable. No success is assumed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <section className="admin-audit" aria-labelledby="create-financial-control">
        <h2 id="create-financial-control">Create a controlled request</h2>
        <p className="notice">
          Evidence SHA-256 is a reference digest only. Upload and verify the underlying evidence separately;
          never paste credentials, payment data, or private customer content into the reason field.
        </p>
        <form className="support-case-form" onSubmit={submitRequest}>
          <label>
            Request type
            <select value={requestType} onChange={(event) => setRequestType(event.target.value as RequestType)}>
              {requestTypes.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
            </select>
          </label>
          <label>
            Seller user ID
            <input required value={sellerId} onChange={(event) => setSellerId(event.target.value)} placeholder="UUID" />
          </label>
          <label>
            Order ID (optional)
            <input value={orderId} onChange={(event) => setOrderId(event.target.value)} placeholder="UUID" />
          </label>
          {requestType === "payout_hold_release" && (
            <label>
              Active payout hold ID
              <input required value={targetHoldId} onChange={(event) => setTargetHoldId(event.target.value)} placeholder="UUID" />
            </label>
          )}
          <label>
            Amount in minor currency units
            <input required inputMode="numeric" pattern="[1-9][0-9]{0,14}" value={amountMinor} onChange={(event) => setAmountMinor(event.target.value)} placeholder="e.g. 2500 = USD 25.00" />
          </label>
          <label>
            ISO currency code
            <input required minLength={3} maxLength={3} pattern="[A-Z]{3}" value={currency} onChange={(event) => setCurrency(event.target.value.toUpperCase())} />
          </label>
          <label>
            Evidence SHA-256 digest
            <input required minLength={64} maxLength={64} pattern="[a-f0-9]{64}" value={evidenceSha256} onChange={(event) => setEvidenceSha256(event.target.value)} placeholder="64 lowercase hexadecimal characters" />
          </label>
          <label>
            Reason / review context
            <textarea required minLength={12} maxLength={1000} value={reason} onChange={(event) => setReason(event.target.value)} />
          </label>
          <label>
            Idempotency key (optional; generated if blank)
            <input maxLength={200} value={idempotencyKey} onChange={(event) => setIdempotencyKey(event.target.value)} />
          </label>
          <button className="button button-primary" type="submit" disabled={busy}>
            {busy ? "Submitting…" : "Submit for independent review"}
          </button>
        </form>
        {message && <p className="notice" role="status" aria-live="polite">{message}</p>}
      </section>

      <section className="admin-audit" aria-labelledby="financial-control-queue">
        <h2 id="financial-control-queue">Latest requests (maximum 50)</h2>
        {requests.length === 0 ? (
          <p className="notice">No financial control requests have been recorded.</p>
        ) : (
          <div className="admin-audit-list">
            {requests.map((item) => (
              <article className="admin-audit-item" key={item.id}>
                <div>
                  <strong>{item.requestType.replaceAll("_", " ")} · {item.status}</strong>
                  <p>Seller: {item.sellerId}</p>
                  <p>Amount: {item.currency} {item.amountMinor} minor units</p>
                  <p>{item.reason}</p>
                  <p>Requester: {item.requestedBy}</p>
                  <p>Created: {displayDate(item.createdAt)}</p>
                  {item.orderId && <p>Order: {item.orderId}</p>}
                  {item.targetHoldId && <p>Target hold: {item.targetHoldId}</p>}
                  {item.approvedAt && <p>Approved: {displayDate(item.approvedAt)}</p>}
                </div>
                {(item.status === "requested" || item.status === "under_review") && (
                  <div className="admin-audit-nav" aria-label={`Review controls for ${item.id}`}>
                    <button className="button button-primary" type="button" disabled={busy} onClick={() => void reviewRequest(item.id, "approve")}>
                      Approve
                    </button>
                    <button className="button button-secondary" type="button" disabled={busy} onClick={() => void reviewRequest(item.id, "reject")}>
                      Reject
                    </button>
                  </div>
                )}
              </article>
            ))}
          </div>
        )}
      </section>
    </>
  );
}
