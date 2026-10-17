"use client";

type V3PromptChipsProps = {
  onSelect: (description: string) => void;
};

const prompts = [
  "Logistics company",
  "NFT marketplace",
  "Loan app Nigeria",
  "SaaS dashboard",
  "Crypto exchange",
  "Real estate agency",
];

export default function V3PromptChips({ onSelect }: V3PromptChipsProps) {
  return (
    <div className="ai-chips">
      {prompts.map((prompt) => (
        <button
          key={prompt}
          className="ai-chip"
          type="button"
          aria-label={`Use ${prompt} prompt`}
          onClick={() => onSelect(`${prompt} website`)}
        >
          {prompt}
        </button>
      ))}
    </div>
  );
}
