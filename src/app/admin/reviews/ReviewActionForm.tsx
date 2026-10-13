"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";

type Decision = "under_review" | "verified" | "rejected";

export function ReviewActionForm({ productId, attestationId }: { productId: string; attestationId: string }) {
  const router = useRouter();
  const [decision, setDecision] = useState<Decision>("under_review");
  const [notes, setNotes] = useState("");
  const [pending, setPending] = useState(false);
  const [feedback, setFeedback] = useState<{ kind: "success" | "error"; message: string } | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    setPending(true);
    setFeedback(null);
    try {
      const response = await fetch(`/api/admin/products/${productId}/rights-review`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({ attestationId, decision, notes })
      });
      if (!response.ok) {
        setFeedback({ kind: "error", message: response.status === 404 ? "Review access denied or evidence no longer available." : "The review could not be saved. Check the note and current review state." });
        return;
      }
      setNotes("");
      setFeedback({ kind: "success", message: `Decision recorded: ${decision.replaceAll("_", " ")}.` });
      router.refresh();
    } catch {
      setFeedback({ kind: "error", message: "The review service is unavailable. No success was recorded." });
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="admin-review-form" onSubmit={submit}>
      <label>
        Decision
        <select value={decision} onChange={(event) => setDecision(event.target.value as Decision)} disabled={pending}>
          <option value="under_review">Request more evidence / keep under review</option>
          <option value="verified">Verify rights evidence</option>
          <option value="rejected">Reject rights evidence</option>
        </select>
      </label>
      <label>
        Reviewer notes (10–4,000 characters)
        <textarea value={notes} onChange={(event) => setNotes(event.target.value)} minLength={10} maxLength={4000} required disabled={pending} placeholder="Record the evidence examined and rationale for this decision." />
      </label>
      <button type="submit" disabled={pending}>{pending ? "Saving review…" : "Save review decision"}</button>
      {feedback && <p className="admin-review-feedback" data-kind={feedback.kind} role="status">{feedback.message}</p>}
    </form>
  );
}
