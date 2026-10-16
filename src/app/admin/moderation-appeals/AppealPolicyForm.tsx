"use client";

import { FormEvent, useState } from "react";

export function AppealPolicyForm({
  approved,
  responseTargetHours,
  policyVersion,
}: {
  approved: boolean;
  responseTargetHours: number;
  policyVersion: string;
}) {
  const [hours, setHours] = useState(String(responseTargetHours));
  const [version, setVersion] = useState(
    policyVersion === "unapproved-v1" ? "internal-sla-v1" : policyVersion,
  );
  const [approvalNote, setApprovalNote] = useState("");
  const [legalReference, setLegalReference] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/admin/moderation-appeal-policy", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          responseTargetHours: Number(hours),
          policyVersion: version,
          approvalNote,
          legalReviewReference: legalReference,
        }),
      });
      const result = (await response.json()) as { error?: string };
      if (!response.ok) {
        setMessage(
          "Policy was not saved. Check the response target and legal-review reference.",
        );
        return;
      }
      window.location.reload();
    } catch {
      setMessage("The policy service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="space-y-3 rounded-xl border p-5" onSubmit={submit}>
      <h2 className="text-lg font-semibold">Appeal response target</h2>
      <p className="text-sm text-muted-foreground">
        This is an internal service-level target, not a statutory deadline.
        Appeals submitted before approval remain accepted without an invented
        due date. Approval requires a recorded legal-review reference.
      </p>
      <p className="text-sm">
        Current policy: {approved ? "approved" : "not approved"} ·{" "}
        {responseTargetHours} hours · {policyVersion}
      </p>
      <label
        className="block text-sm font-medium"
        htmlFor="appeal-policy-hours"
      >
        Response target (24–720 hours)
      </label>
      <input
        id="appeal-policy-hours"
        className="w-full rounded-md border bg-background px-3 py-2 text-sm"
        type="number"
        min={24}
        max={720}
        step={1}
        value={hours}
        onChange={(event) => setHours(event.target.value)}
        required
      />
      <label
        className="block text-sm font-medium"
        htmlFor="appeal-policy-version"
      >
        Policy version
      </label>
      <input
        id="appeal-policy-version"
        className="w-full rounded-md border bg-background px-3 py-2 text-sm"
        minLength={1}
        maxLength={80}
        value={version}
        onChange={(event) => setVersion(event.target.value)}
        required
      />
      <label className="block text-sm font-medium" htmlFor="appeal-policy-note">
        Approval note
      </label>
      <textarea
        id="appeal-policy-note"
        className="min-h-16 w-full rounded-md border bg-background px-3 py-2 text-sm"
        minLength={10}
        maxLength={2000}
        value={approvalNote}
        onChange={(event) => setApprovalNote(event.target.value)}
        required
      />
      <label
        className="block text-sm font-medium"
        htmlFor="appeal-policy-legal-reference"
      >
        Legal-review reference
      </label>
      <input
        id="appeal-policy-legal-reference"
        className="w-full rounded-md border bg-background px-3 py-2 text-sm"
        minLength={5}
        maxLength={2048}
        value={legalReference}
        onChange={(event) => setLegalReference(event.target.value)}
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
        disabled={
          busy ||
          Number(hours) < 24 ||
          Number(hours) > 720 ||
          approvalNote.trim().length < 10 ||
          legalReference.trim().length < 5
        }
      >
        {busy ? "Saving…" : "Approve and record policy"}
      </button>
    </form>
  );
}
