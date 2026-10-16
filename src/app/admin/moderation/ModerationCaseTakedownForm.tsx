"use client";

import { FormEvent, useState } from "react";

export function ModerationCaseTakedownForm({ caseId }: { caseId: string }) {
  const [note, setNote] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch(
        `/api/admin/moderation-cases/${caseId}/takedown`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ note }),
        },
      );
      const result = (await response.json()) as { error?: string };
      if (!response.ok) {
        setMessage(
          result.error === "takedown_not_allowed"
            ? "The case or listing is no longer eligible. Refresh the queue."
            : "Takedown failed. Refresh the case and try again.",
        );
        return;
      }
      window.location.reload();
    } catch {
      setMessage("The moderation service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form
      className="mt-3 space-y-2 rounded-lg border border-amber-500/50 p-3"
      onSubmit={submit}
    >
      <p className="text-sm font-medium">Apply listing suppression</p>
      <p className="text-xs text-muted-foreground">
        This archives the published listing and records an enforcement event.
        The creator may submit one appeal.
      </p>
      <label
        className="block text-sm font-medium"
        htmlFor={`takedown-note-${caseId}`}
      >
        Enforcement rationale
      </label>
      <textarea
        id={`takedown-note-${caseId}`}
        className="min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
        minLength={10}
        maxLength={2000}
        value={note}
        onChange={(event) => setNote(event.target.value)}
        required
      />
      {message ? (
        <p role="status" className="text-sm">
          {message}
        </p>
      ) : null}
      <button
        className="rounded-md border px-3 py-2 text-sm disabled:opacity-60"
        type="submit"
        disabled={busy || note.trim().length < 10}
      >
        {busy ? "Applying…" : "Apply takedown"}
      </button>
    </form>
  );
}
