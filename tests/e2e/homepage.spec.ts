import { expect, test } from "@playwright/test";

test("homepage identifies the preview state and does not claim checkout is live", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /from idea to/i })).toBeVisible();
  await expect(page.getByRole("status")).toContainText(/not live yet/i);
});
