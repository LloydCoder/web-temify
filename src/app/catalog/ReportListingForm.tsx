"use client";

import { FormEvent, useState } from "react";

type ReportListingFormProps = {
  productId: string;
};

export function ReportListingForm({ productId }: ReportListingFormProps) {
  const [reasonCode, setReasonCode] = useState("ip_rights");
  const [description, setDescription] = useState("");
  const [idempotencyKey, setIdempotencyKey] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    const key = idempotencyKey || crypto.randomUUID();
    setIdempotencyKey(key);

    try {
      const response = await fetch("/api/moderation/reports", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          productId,
          reasonCode,
          description,
          idempotencyKey: key,
        }),
      });
      const result = (await response.json()) as {
        error?: string;
        caseId?: string;
      };
      if (!response.ok) {
        setMessage(
          result.error === "authentication_required"
            ? "Sign in to report a listing."
            : result.error === "same_origin_required"
              ? "The request origin could not be verified. Refresh and try again."
              : "The report could not be submitted. Review the details and try again.",
        );
        return;
      }

      setDescription("");
      setIdempotencyKey("");
      setMessage(`Report ${result.caseId ?? ""} was submitted for review.`);
    } catch {
      setMessage("The moderation service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="space-y-4 rounded-xl border p-5" onSubmit={submit}>
      <div>
        <label
          className="mb-1 block text-sm font-medium"
          htmlFor="moderation-reason"
        >
          Reason for reporting
        </label>
        <select
          id="moderation-reason"
          className="w-full rounded-md border bg-background px-3 py-2"
          value={reasonCode}
          onChange={(event) => setReasonCode(event.target.value)}
        >
          <option value="ip_rights">Intellectual property or rights</option>
          <option value="fraud_misrepresentation">
            Fraud or misrepresentation
          </option>
          <option value="malware_security">Malware or security concern</option>
          <option value="prohibited_content">Prohibited content</option>
          <option value="privacy">Privacy concern</option>
          <option value="other">Other</option>
        </select>
      </div>
      <div>
        <label
          className="mb-1 block text-sm font-medium"
          htmlFor="moderation-description"
        >
          Describe the concern
        </label>
        <textarea
          id="moderation-description"
          className="min-h-32 w-full rounded-md border bg-background px-3 py-2"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          minLength={20}
          maxLength={4000}
          required
        />
        <p className="mt-1 text-xs text-muted-foreground">
          Include enough detail to review the concern. Do not include passwords,
          payment-card details, or authentication secrets.
        </p>
      </div>
      <button
        className="rounded-md bg-primary px-4 py-2 text-primary-foreground disabled:opacity-60"
        type="submit"
        disabled={busy}
      >
        {busy ? "Submitting…" : "Submit report"}
      </button>
      {message ? (
        <p aria-live="polite" role="status" className="text-sm">
          {message}
        </p>
      ) : null}
    </form>
  );
}
