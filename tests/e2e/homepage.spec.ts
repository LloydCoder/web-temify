import { expect, test } from "@playwright/test";

test("homepage identifies the preview state and does not claim checkout is live", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /from idea to/i })).toBeVisible();
  await expect(page.getByRole("status")).toContainText(/not live yet/i);
});


test("homepage has semantic landmarks and no horizontal overflow on mobile or desktop", async ({ page }) => {
  for (const viewport of [{ width: 320, height: 800 }, { width: 1440, height: 900 }]) {
    await page.setViewportSize(viewport);
    await page.goto("/");
    await expect(page.getByRole("main")).toBeVisible();
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    const hasHorizontalOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth,
    );
    expect(hasHorizontalOverflow, `horizontal overflow at ${viewport.width}px viewport`).toBe(false);
  }
});
