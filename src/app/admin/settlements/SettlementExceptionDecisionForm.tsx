"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";

type Decision =
  | "reimport_required"
  | "manual_review_required"
  | "accepted_with_evidence";

export function SettlementExceptionDecisionForm({
  runId,
  rowId,
  existingDecision,
}: {
  runId: string;
  rowId: string;
  existingDecision: Decision | null;
}) {
  const router = useRouter();
  const [decision, setDecision] =
    useState<Decision>("manual_review_required");
  const [reason, setReason] = useState("");
  const [evidenceSha256, setEvidenceSha256] = useState("");
  const [pending, setPending] = useState(false);
  const [feedback, setFeedback] = useState<{
    kind: "success" | "error";
    message: string;
  } | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending || existingDecision) return;

    setPending(true);
    setFeedback(null);
    try {
      const response = await fetch(
        `/api/admin/settlements/${runId}/decision`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          credentials: "same-origin",
          body: JSON.stringify({
            rowId,
            decision,
            reason,
            evidenceSha256:
              decision === "accepted_with_evidence"
                ? evidenceSha256
                : null,
          }),
        },
      );

      if (!response.ok) {
        setFeedback({
          kind: "error",
          message:
            response.status === 404
              ? "Access denied or this exception is no longer available."
              : "The triage decision could not be recorded. Check the reason and evidence digest.",
        });
        return;
      }

      setReason("");
      setEvidenceSha256("");
      setFeedback({
        kind: "success",
        message: "Immutable triage decision recorded. The accounting exception remains open.",
      });
      router.refresh();
    } catch {
      setFeedback({
        kind: "error",
        message: "The triage service is unavailable. No success was recorded.",
      });
    } finally {
      setPending(false);
    }
  }

  if (existingDecision) {
    return (
      <p className="notice" role="note">
        An immutable triage decision is already recorded for this exception.
        Follow-up requires a new evidence-backed workflow; this record cannot be
        overwritten.
      </p>
    );
  }

  return (
    <form className="admin-review-form" onSubmit={submit}>
      <label>
        Triage decision
        <select
          value={decision}
          onChange={(event) => setDecision(event.target.value as Decision)}
          disabled={pending}
        >
          <option value="manual_review_required">Manual review required</option>
          <option value="reimport_required">Reimport corrected report</option>
          <option value="accepted_with_evidence">Accept triage with evidence digest</option>
        </select>
      </label>
      <label>
        Reason (12–500 characters)
        <textarea
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          minLength={12}
          maxLength={500}
          required
          disabled={pending}
          placeholder="Describe the evidence reviewed and the next operational action."
        />
      </label>
      {decision === "accepted_with_evidence" && (
        <label>
          Evidence SHA-256 (64 lowercase hexadecimal characters)
          <input
            value={evidenceSha256}
            onChange={(event) => setEvidenceSha256(event.target.value)}
            minLength={64}
            maxLength={64}
            pattern="[a-f0-9]{64}"
            required
            disabled={pending}
            autoComplete="off"
            spellCheck={false}
          />
        </label>
      )}
      <button type="submit" disabled={pending}>
        {pending ? "Recording decision…" : "Record triage decision"}
      </button>
      {feedback && (
        <p
          className="admin-review-feedback"
          data-kind={feedback.kind}
          role="status"
        >
          {feedback.message}
        </p>
      )}
    </form>
  );
}
