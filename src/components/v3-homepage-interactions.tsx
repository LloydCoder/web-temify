"use client";

import { useEffect } from "react";

export default function V3HomepageInteractions() {
  useEffect(() => {
    const root = document.querySelector<HTMLElement>(".v3-native-home");
    if (!root) return;

    const revealItems = root.querySelectorAll<HTMLElement>(".reveal");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    if ("IntersectionObserver" in window && !reducedMotion.matches) {
      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add("visible");
              observer.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.08 },
      );
      revealItems.forEach((element) => observer.observe(element));
      return () => observer.disconnect();
    }

    revealItems.forEach((element) => element.classList.add("visible"));
  }, []);

  useEffect(() => {
    const root = document.querySelector<HTMLElement>(".v3-native-home");
    if (!root) return;

    const input = root.querySelector<HTMLInputElement>(".ai-input");
    const aiBox = root.querySelector<HTMLElement>(".ai-box");
    const generateButton = aiBox?.querySelector<HTMLButtonElement>("button");
    let status = aiBox?.querySelector<HTMLElement>(".v3-feature-status");

    if (aiBox && !status) {
      status = document.createElement("p");
      status.className = "v3-feature-status";
      status.setAttribute("role", "status");
      status.setAttribute("aria-live", "polite");
      status.hidden = true;
      aiBox.querySelector(".ai-input-row")?.insertAdjacentElement("afterend", status);
    }

    const setStatus = (message: string) => {
      if (!status) return;
      status.textContent = message;
      status.hidden = false;
    };

    const onChipClick = (event: Event) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      const chip = target.closest<HTMLElement>(".ai-chip");
      if (!chip || !input) return;
      input.value = `${chip.textContent?.trim() ?? ""} website`;
      input.focus();
      input.dispatchEvent(new Event("input", { bubbles: true }));
    };

    const onChipKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      const target = event.target;
      if (!(target instanceof HTMLElement) || !target.matches(".ai-chip")) return;
      event.preventDefault();
      target.click();
    };

    const onGenerate = (event: Event) => {
      event.preventDefault();
      setStatus(
        "The AI Site Builder is planned but is not available yet. Your prompt has not been submitted or processed.",
      );
    };

    root.querySelectorAll<HTMLElement>(".ai-chip").forEach((chip) => {
      chip.setAttribute("role", "button");
      chip.setAttribute("tabindex", "0");
      chip.setAttribute("aria-label", `Use prompt: ${chip.textContent?.trim() ?? "website"}`);
    });

    const tabList = root.querySelector<HTMLElement>(".dir-tabs");
    const directory = root.querySelector<HTMLElement>(".dir-grid");
    const tabs = Array.from(root.querySelectorAll<HTMLButtonElement>(".dir-tab"));
    const cards = Array.from(root.querySelectorAll<HTMLElement>(".dir-card"));
    let emptyState = directory?.querySelector<HTMLElement>(".dir-empty-state");

    if (tabList) tabList.setAttribute("role", "tablist");
    if (directory) directory.setAttribute("aria-live", "polite");
    if (directory && !emptyState) {
      emptyState = document.createElement("p");
      emptyState.className = "dir-empty-state";
      emptyState.textContent = "No matching tools are included in this preview yet.";
      emptyState.hidden = true;
      emptyState.style.gridColumn = "1 / -1";
      emptyState.style.padding = "1rem";
      emptyState.style.color = "var(--muted)";
      directory.append(emptyState);
    }

    const termsByTab: Record<string, string[]> = {
      "all tools": [],
      "ai & ml": [" ai ", "coding", "analysis"],
      "web3 & blockchain": ["web3", "blockchain", "ethereum"],
      "hosting & infra": ["hosting", "ci/cd", "infra"],
      "design tools": ["design", "ui/ux", "figma"],
      "no-code": ["no-code", "nocode"],
      "dev tools": ["coding", "database", "baas", "ci/cd", "ethereum"],
      "freelancer resources": ["freelancer", "freelance", "portfolio"],
    };

    const activateTab = (selected: HTMLButtonElement) => {
      const label = selected.textContent?.trim().toLowerCase() ?? "all tools";
      const terms = termsByTab[label] ?? [];
      tabs.forEach((tab) => {
        const active = tab === selected;
        tab.classList.toggle("active", active);
        tab.setAttribute("role", "tab");
        tab.setAttribute("aria-selected", String(active));
        tab.setAttribute("aria-pressed", String(active));
        tab.tabIndex = active ? 0 : -1;
      });

      let visibleCount = 0;
      cards.forEach((card) => {
        const text = ` ${card.textContent?.toLowerCase() ?? ""} `;
        const visible = terms.length === 0 || terms.some((term) => text.includes(term));
        card.hidden = !visible;
        card.style.display = visible ? "" : "none";
        if (visible) visibleCount += 1;
      });
      if (emptyState) emptyState.hidden = visibleCount > 0;
    };

    tabs.forEach((tab) => {
      tab.setAttribute("role", "tab");
      tab.tabIndex = tab.classList.contains("active") ? 0 : -1;
    });
    if (tabs[0]) activateTab(tabs.find((tab) => tab.classList.contains("active")) ?? tabs[0]);

    const onTabClick = (event: Event) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      const tab = target.closest<HTMLButtonElement>(".dir-tab");
      if (tab) activateTab(tab);
    };

    const onTabKeyDown = (event: KeyboardEvent) => {
      const target = event.target;
      if (!(target instanceof HTMLButtonElement) || !target.matches(".dir-tab")) return;
      const index = tabs.indexOf(target);
      let nextIndex = index;
      if (event.key === "ArrowRight") nextIndex = (index + 1) % tabs.length;
      else if (event.key === "ArrowLeft") nextIndex = (index - 1 + tabs.length) % tabs.length;
      else return;
      event.preventDefault();
      tabs[nextIndex]?.focus();
      if (tabs[nextIndex]) activateTab(tabs[nextIndex]);
    };

    generateButton?.addEventListener("click", onGenerate);
    root.addEventListener("click", onChipClick);
    root.addEventListener("keydown", onChipKeyDown);
    root.addEventListener("click", onTabClick);
    root.addEventListener("keydown", onTabKeyDown);

    return () => {
      generateButton?.removeEventListener("click", onGenerate);
      root.removeEventListener("click", onChipClick);
      root.removeEventListener("keydown", onChipKeyDown);
      root.removeEventListener("click", onTabClick);
      root.removeEventListener("keydown", onTabKeyDown);
    };
  }, []);

  return null;
}
