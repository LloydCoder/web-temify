"use client";

import { FormEvent, useState } from "react";

export function SupportCaseCreateForm() {
  const [category, setCategory] = useState("product_access");
  const [subject, setSubject] = useState("");
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
      const response = await fetch("/api/support-cases", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category, subject, description, idempotencyKey: key }),
      });
      const result = (await response.json()) as { error?: string; id?: string };
      if (!response.ok) {
        setMessage(
          result.error === "authentication_required"
            ? "Sign in to open a support case."
            : result.error === "same_origin_required"
              ? "The request origin could not be verified. Refresh and try again."
              : "The support request could not be submitted. Review the fields and try again.",
        );
        return;
      }
      setSubject("");
      setDescription("");
      setIdempotencyKey("");
      setMessage(`Support case ${result.id ?? ""} was submitted.`);
    } catch {
      setMessage("The support service is temporarily unavailable.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="space-y-4 rounded-xl border p-5" onSubmit={submit}>
      <div>
        <label className="mb-1 block text-sm font-medium" htmlFor="support-category">Category</label>
        <select
          id="support-category"
          className="w-full rounded-md border bg-background px-3 py-2"
          value={category}
          onChange={(event) => setCategory(event.target.value)}
        >
          <option value="account">Account</option>
          <option value="billing">Billing</option>
          <option value="product_access">Product access or download</option>
          <option value="product_rights">Product rights or intellectual property</option>
          <option value="security">Security concern</option>
          <option value="other">Other</option>
        </select>
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium" htmlFor="support-subject">Subject</label>
        <input
          id="support-subject"
          className="w-full rounded-md border bg-background px-3 py-2"
          value={subject}
          onChange={(event) => setSubject(event.target.value)}
          minLength={5}
          maxLength={160}
          required
        />
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium" htmlFor="support-description">What happened?</label>
        <textarea
          id="support-description"
          className="min-h-32 w-full rounded-md border bg-background px-3 py-2"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          minLength={10}
          maxLength={8000}
          required
        />
        <p className="mt-1 text-xs text-muted-foreground">Do not include passwords, payment-card details, or authentication secrets.</p>
      </div>
      <button
        className="rounded-md bg-primary px-4 py-2 text-primary-foreground disabled:opacity-60"
        type="submit"
        disabled={busy}
      >
        {busy ? "Submitting…" : "Open support case"}
      </button>
      {message ? <p aria-live="polite" role="status" className="text-sm">{message}</p> : null}
    </form>
  );
}
