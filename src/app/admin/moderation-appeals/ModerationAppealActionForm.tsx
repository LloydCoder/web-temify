"use client";

import { FormEvent, useState } from "react";

type AppealAction = "triage" | "uphold" | "reverse" | "reject";

export function ModerationAppealActionForm({ appealId, status }: { appealId: string; status: string }) {
  const actions: AppealAction[] = status === "submitted"
    ? ["triage"]
    : status === "under_review"
      ? ["uphold", "reverse", "reject"]
      : [];
  const labels: Record<AppealAction, string> = {
    triage: "Start independent review",
    uphold: "Uphold takedown",
    reverse: "Reverse takedown",
    reject: "Reject appeal",
  };
  const [action, setAction] = useState<AppealAction>(actions[0] ?? "triage");
  const [note, setNote] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch(`/api/admin/moderation-appeals/${appealId}/transition`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action, note }),
      });
      const result = (await response.json()) as { error?: string };
      if (!response.ok) {
        setMessage(result.error === "invalid_appeal_transition"
          ? "This appeal changed state. Refresh the queue."
          : "The appeal action failed. Refresh and try again.");
        return;
      }
      window.location.reload();
    } catch {
      setMessage("The moderation service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  if (actions.length === 0) return <p className="text-sm text-muted-foreground">No further actions available.</p>;

  return (
    <form className="mt-4 space-y-2 border-t pt-4" onSubmit={submit}>
      <label className="block text-sm font-medium" htmlFor={`appeal-action-${appealId}`}>Review action</label>
      <select id={`appeal-action-${appealId}`} className="w-full rounded-md border bg-background px-3 py-2 text-sm" value={action} onChange={(event) => setAction(event.target.value as AppealAction)}>
        {actions.map((value) => <option key={value} value={value}>{labels[value]}</option>)}
      </select>
      <label className="block text-sm font-medium" htmlFor={`appeal-note-${appealId}`}>Decision / audit note</label>
      <textarea id={`appeal-note-${appealId}`} className="min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm" minLength={10} maxLength={2000} value={note} onChange={(event) => setNote(event.target.value)} required />
      {message ? <p role="status" className="text-sm">{message}</p> : null}
      <button className="rounded-md border px-3 py-2 text-sm disabled:opacity-60" type="submit" disabled={busy || note.trim().length < 10}>{busy ? "Saving…" : labels[action]}</button>
    </form>
  );
}
