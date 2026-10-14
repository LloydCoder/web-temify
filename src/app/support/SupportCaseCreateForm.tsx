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
        body: JSON.stringify({
          category,
          subject,
          description,
          idempotencyKey: key,
        }),
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
        <label
          className="mb-1 block text-sm font-medium"
          htmlFor="support-category"
        >
          Category
        </label>
        <select
          id="support-category"
          ...[truncated]