"use client";

import { FormEvent, useMemo, useState } from "react";

type Action =
  | "triage"
  | "request_info"
  | "escalate"
  | "resolve"
  | "close"
  | "reopen"
  | "assign";

const ACTION_LABELS: Record<Action, string> = {
  triage: "Move to triaged",
  request_info: "Request more information",
  escalate: "Escalate",
  resolve: "Resolve",
  close: "Close resolved case",
  reopen: "Reopen",
  assign: "Assign to me",
};

function allowedActions(status: string): Action[] {
  const actions: Action[] = [];
  if (status === "open" || status === "escalated") actions.push("triage");
  if (status === "triaged" || status === "escalated")
    actions.push("request_info");
  if (["open", "triaged", "waiting_on_requester"].includes(status))
    actions.push("escalate");
  if (["triaged", "waiting_on_requester", "escalated"].includes(status))
    actions.push("resolve");
  if (status === "resolved") actions.push("close");
  if (status === "resolved" || status === "closed") actions.push("reopen");
  if (status !== "closed") actions.push("assign");
  return actions;
}

export function SupportCaseActionForm({
  caseId,
  status,
  adminId,
}: {
  caseId: string;
  status: string;
  adminId: string;
}) {
  const actions = useMemo(() => allowedActions(status), [status]);
  const [action, setAction] = useState<Action>(actions[0] ?? "assign");
  const [note, setNote] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch(
        `/api/admin/support-cases/${caseId}/transition`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            action,
            note,
            ...(action === "assign" ? { assigneeId: adminId } : {}),
          }),
        },
      );
      const result = (await response.json()) as { error?: string };
      if (!response.ok) {
        setMessage(
          result.error === "invalid_support_case_transition"
            ? "That transition is no longer valid. Refresh the queue."
            : "The action failed. Check the case status and try again.",
        );
        return;
      }
      window.location.reload();
    } catch {
      setMessage("The support service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  if (actions.length === 0)
    return (
      <p className="text-sm text-muted-foreground">No actions available.</p>
    );

  return (
    <form className="mt-4 space-y-2 border-t pt-4" onSubmit={submit}>
      <label
        className="block text-sm font-medium"
        htmlFor={`support-action-${caseId}`}
      >
        Action
      </label>
      <select
        id={`support-action-${caseId}`}
        className="w-full rounded-md border bg-background px-3 py-2 text-sm"
        value={action}
        onChange={(event) => setAction(event.target.value as Action)}
      >
        {actions.map((value) => (
          <option key={value} value={value}>
            {ACTION_LABELS[value]}
          </option>
        ))}
      </select>
      <label
        className="block text-sm font-medium"
        htmlFor={`support-note-${caseId}`}
      >
        Audit note
      </label>
      <textarea
        id={`support-note-${caseId}`}
        className="min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
        minLength={10}
        maxLength={2000}
        value={note}
        onChange={(event) => setNote(event.target.value)}
        required
      />
      <button
        className="rounded-md border px-3 py-2 text-sm disabled:opacity-60"
        type="submit"
        disabled={busy || note.trim().length < 10}
      >
        {busy ? "Saving…" : "Apply action"}
      </button>
      {message ? (
        <p
          role="status"
          aria-live="polite"
          className="text-sm text-destructive"
        >
          {message}
        </p>
      ) : null}
    </form>
  );
}
