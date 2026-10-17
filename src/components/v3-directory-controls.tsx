"use client";

import { useEffect, useState } from "react";

const directoryFilters: Record<string, string[]> = {
  "All Tools": [],
  "AI & ML": ["ai", "ml", "coding", "assistant"],
  "Web3 & Blockchain": ["web3", "blockchain", "crypto", "nft", "wallet"],
  "Hosting & Infra": ["hosting", "infra", "cloud", "deploy"],
  "Design Tools": ["design", "creative", "ui", "ux"],
  "No-Code": ["no"],
  "Dev Tools": ["dev", "coding", "developer", "api", "git"],
  "Freelancer Resources": ["freelancer", "resources", "client", "invoice"],
};

const directoryLabels = Object.keys(directoryFilters);

export default function V3DirectoryControls() {
  const [activeDirectory, setActiveDirectory] = useState("All Tools");

  useEffect(() => {
    const root = document.querySelector<HTMLElement>(".v3-app");
    if (!root) return;

    const allowed = directoryFilters[activeDirectory] ?? [];
    const cards = Array.from(root.querySelectorAll<HTMLElement>(".dir-card"));
    let visibleCount = 0;

    cards.forEach((card) => {
      const tags = (card.dataset.directory ?? "").toLowerCase().split(/\s+/);
      card.hidden =
        allowed.length > 0 &&
        !allowed.some((filter) => tags.some((tag) => tag.includes(filter)));
      if (!card.hidden) visibleCount += 1;
    });

    const emptyState = root.querySelector<HTMLElement>(".dir-empty-state");
    if (emptyState) emptyState.hidden = visibleCount > 0;
  }, [activeDirectory]);

  return (
    <div
      className="dir-tabs reveal"
      role="group"
      aria-label="Filter external tools"
    >
      {directoryLabels.map((label) => (
        <button
          key={label}
          className={`dir-tab${activeDirectory === label ? " active" : ""}`}
          type="button"
          aria-pressed={activeDirectory === label}
          onClick={() => setActiveDirectory(label)}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
