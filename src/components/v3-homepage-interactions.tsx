"use client";

import { useEffect } from "react";

export default function V3HomepageInteractions() {
  useEffect(() => {
    const root = document.querySelector(".v3-native-home");
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
    const root = document.querySelector(".v3-native-home");
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

    const tabs = Array.from(root.querySelectorAll<HTMLButtonElement>(".dir-tab"));
    tabs.forEach((tab) => {
      tab.setAttribute("aria-pressed", String(tab.classList.contains("active")));
    });

    const onTabClick = (event: Event) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      const tab = target.closest<HTMLButtonElement>(".dir-tab");
      if (!tab) return;
      tabs.forEach((item) => {
        const active = item === tab;
        item.classList.toggle("active", active);
        item.setAttribute("aria-pressed", String(active));
      });
    };

    generateButton?.addEventListener("click", onGenerate);
    root.addEventListener("click", onChipClick);
    root.addEventListener("keydown", onChipKeyDown);
    root.addEventListener("click", onTabClick);

    return () => {
      generateButton?.removeEventListener("click", onGenerate);
      root.removeEventListener("click", onChipClick);
      root.removeEventListener("keydown", onChipKeyDown);
      root.removeEventListener("click", onTabClick);
    };
  }, []);

  return null;
}
