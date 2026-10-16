"use client";

import { FormEvent, useState } from "react";

export function CreatorAppealForm({
  enforcementId,
}: {
  enforcementId: string;
}) {
  const [statement, setStatement] = useState("");
  const [evidenceReference, setEvidenceReference] = useState("");
  const [idempotencyKey, setIdempotencyKey] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    const key = idempotencyKey || window.crypto.randomUUID();
    setIdempotencyKey(key);
    try {
      const response = await fetch("/api/moderation/appeals", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          enforcementId,
          statement,
          evidenceReference: evidenceReference.trim() || null,
          idempotencyKey: key,
        }),
      });
      const result = (await response.json()) as { error?: string };
      if (!response.ok) {
        setMessage(
          result.error === "appeal_conflict"
            ? "An appeal already exists for this takedown or the idempotency key conflicts."
            : "Appeal submission failed. Review the fields and try again.",
        );
        return;
      }
      window.location.reload();
    } catch {
      setMessage("The appeal service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="mt-4 space-y-3 border-t pt-4" onSubmit={submit}>
      <label
        className="block text-sm font-medium"
        htmlFor={`appeal-statement-${enforcementId}`}
      >
        Why should this takedown be reconsidered?
      </label>
      <textarea
        id={`appeal-statement-${enforcementId}`}
        className="min-h-28 w-full rounded-md border bg-background px-3 py-2 text-sm"
        minLength={20}
        maxLength={4000}
        value={statement}
        onChange={(event) => {
          setStatement(event.target.value);
          setIdempotencyKey("");
        }}
        required
      />
      <label
        className="block text-sm font-medium"
        htmlFor={`appeal-evidence-${enforcementId}`}
      >
        Evidence reference (optional)
      </label>
      <input
        id={`appeal-evidence-${enforcementId}`}
        className="w-full rounded-md border bg-background px-3 py-2 text-sm"
        maxLength={2048}
        value={evidenceReference}
        onChange={(event) => {
          setEvidenceReference(event.target.value);
          setIdempotencyKey("");
        }}
      />
      <p className="text-xs text-muted-foreground">
        Do not include passwords, payment data, or other unnecessary sensitive
        information. A response due date is assigned only when an approved
        internal response policy exists.
      </p>
      {message ? (
        <p role="status" className="text-sm">
          {message}
        </p>
      ) : null}
      <button
        className="rounded-md border px-3 py-2 text-sm disabled:opacity-60"
        type="submit"
        disabled={busy || statement.trim().length < 20}
      >
        {busy ? "Submitting…" : "Submit appeal"}
      </button>
    </form>
  );
}
