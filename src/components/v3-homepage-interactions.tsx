"use client";

import { useEffect } from "react";

export default function V3HomepageInteractions() {
  useEffect(() => {
    const root = document.querySelector<HTMLElement>(".v3-app");
    if (!root) return;

    const revealItems = root.querySelectorAll<HTMLElement>(".reveal");
    if (
      "IntersectionObserver" in window &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry, index) => {
            if (!entry.isIntersecting) return;
            const target = entry.target as HTMLElement;
            target.style.transitionDelay = `${Math.min(index, 8) * 35}ms`;
            target.classList.add("visible");
            observer.unobserve(target);
          });
        },
        { threshold: 0.08 },
      );
      revealItems.forEach((item) => observer.observe(item));
      return () => observer.disconnect();
    }

    revealItems.forEach((item) => item.classList.add("visible"));
  }, []);

  return null;
}
