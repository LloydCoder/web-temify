"use client";

import { useState } from "react";
import V3PromptChips from "@/components/v3-prompt-chips";

export default function V3AiBuilderPreview() {
  const [description, setDescription] = useState("");

  return (
    <section>
      <div className="ai-box reveal">
        <p className="eyebrow">AI-Powered</p>
        <h2
          className="section-title"
          style={{ textAlign: "center", margin: "0 auto 0.75rem" }}
        >
          AI Site Builder
          <br />
          <span className="serif">coming soon</span>
        </h2>
        <p className="ai-sub">
          The AI Site Builder is planned, but generation is not available yet.
          Explore the concept with the prompt suggestions below.
        </p>
        <div className="ai-input-row">
          <input
            type="text"
            className="ai-input"
            aria-label="Website description (preview only)"
            aria-describedby="ai-builder-status"
            placeholder="e.g. A fintech app for Nigerian SMEs..."
            value={description}
            onChange={(event) => setDescription(event.target.value)}
          />
          <button
            className="btn btn-yellow"
            type="button"
            disabled
            aria-describedby="ai-builder-status"
          >
            Coming soon
          </button>
        </div>
        <p
          id="ai-builder-status"
          className="ai-builder-status"
          role="status"
        >
          AI generation is not live yet.
        </p>
        <V3PromptChips onSelect={setDescription} />
      </div>
    </section>
  );
}
