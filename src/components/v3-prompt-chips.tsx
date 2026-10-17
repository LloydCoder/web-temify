"use client";

const prompts = [
  "Logistics company",
  "NFT marketplace",
  "Loan app Nigeria",
  "SaaS dashboard",
  "Crypto exchange",
  "Real estate agency",
];

export default function V3PromptChips() {
  const fillAiPrompt = (prompt: string) => {
    const input = document.querySelector<HTMLInputElement>(".v3-app .ai-input");
    if (!input) return;
    input.value = `${prompt} website`;
    input.focus();
  };

  return (
    <div className="ai-chips">
      {prompts.map((prompt) => (
        <button
          key={prompt}
          className="ai-chip"
          type="button"
          aria-label={`Use ${prompt} prompt`}
          onClick={() => fillAiPrompt(prompt)}
        >
          {prompt}
        </button>
      ))}
    </div>
  );
}
