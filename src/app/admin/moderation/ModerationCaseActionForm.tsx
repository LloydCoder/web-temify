"use client";

import { FormEvent, useMemo, useState } from "react";

type Action = "triage" | "require_action" | "dismiss" | "close";
type ResolutionCode =
  | "listing_review_required"
  | "rights_review_required"
  | "security_review_required"
  | "no_violation_found"
  | "duplicate_report"
  | "insufficient_evidence";

const ACTION_LABELS: Record<Action, string> = {
  triage: "Move to review",
  require_action: "Require follow-up action",
  dismiss: "Dismiss report",
  close: "Close case",
};

const ACTION_RESOLUTIONS: Record<
  "require_action" | "dismiss",
  { value: ResolutionCode; label: string }[]
> = {
  require_action: [
    { value: "listing_review_required", label: "Listing review required" },
    { value: "rights_review_required", label: "Rights review required" },
    { value: "security_review_required", label: "Security review required" },
  ],
  dismiss: [
    { value: "no_violation_found", label: "No violation found" },
    { value: "duplicate_report", label: "Duplicate report" },
    { value: "insufficient_evidence", label: "Insufficient evidence" },
  ],
};

function allowedActions(status: string): Action[] {
  if (status === "open") return ["triage", "dismiss"];
  if (status === "under_review") return ["require_action", "dismiss"];
  if (status === "action_required" || status === "dismissed") return ["close"];
  return [];
}

export function ModerationCaseActionForm({
  caseId,
  status,
  resolutionCode,
}: {
  caseId: string;
  status: string;
  resolutionCode: ResolutionCode | null;
}) {
  const actions = useMemo(() => allowedActions(status), [status]);
  const [action, setAction] = useState<Action>(actions[0] ?? "triage");
  const [selectedResolution, setSelectedResolution] =
    useState<ResolutionCode | null>(() => {
      if (actions[0] === "require_action") return "rights_review_required";
      if (actions[0] === "dismiss") return "no_violation_found";
      return resolutionCode;
    });
  const [note, setNote] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  function changeAction(nextAction: Action) {
    setAction(nextAction);
    if (nextAction === "triage") {
      setSelectedResolution(null);
    } else if (nextAction === "require_action") {
      setSelectedResolution("rights_review_required");
    } else if (nextAction === "dismiss") {
      setSelectedResolution("no_violation_found");
    } else {
      setSelectedResolution(resolutionCode);
    }
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch(
        `/api/admin/moderation-cases/${caseId}/transition`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            action,
            resolutionCode: selectedResolution,
            note,
          }),
        },
      );
      const result = (await response.json()) as { error?: string };
      if (!response.ok) {
        setMessage(
          result.error === "invalid_moderation_transition"
            ? "That transition is no longer valid. Refresh the queue."
            : "The action failed. Check the case status and try again.",
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

  if (actions.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">No actions available.</p>
    );
  }

  const resolutionOptions =
    action === "require_action" || action === "dismiss"
      ? ACTION_RESOLUTIONS[action]
      : [];

  return (
    <form className="mt-4 space-y-2 border-t pt-4" onSubmit={submit}>
      <label
        className="block text-sm font-medium"
        htmlFor={`moderation-action-${caseId}`}
      >
        Action
      </label>
      <select
        id={`moderation-action-${caseId}`}
        className="w-full rounded-md border bg-background px-3 py-2 text-sm"
        value={action}
        onChange={(event) => changeAction(event.target.value as Action)}
      >
        {actions.map((value) => (
          <option key={value} value={value}>
            {ACTION_LABELS[value]}
          </option>
        ))}
      </select>
      {resolutionOptions.length > 0 ? (
        <>
          <label
            className="block text-sm font-medium"
            htmlFor={`moderation-resolution-${caseId}`}
          >
            Resolution
          </label>
          <select
            id={`moderation-resolution-${caseId}`}
            className="w-full rounded-md border bg-background px-3 py-2 text-sm"
            value={selectedResolution ?? ""}
            onChange={(event) =>
              setSelectedResolution(event.target.value as ResolutionCode)
            }
          >
            {resolutionOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </>
      ) : null}
      {action === "close" && resolutionCode ? (
        <p className="text-xs text-muted-foreground">
          Closing preserves the existing resolution:{" "}
          {resolutionCode.replaceAll("_", " ")}.
        </p>
      ) : null}
      <label
        className="block text-sm font-medium"
        htmlFor={`moderation-note-${caseId}`}
      >
        Audit note
      </label>
      <textarea
        id={`moderation-note-${caseId}`}
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
