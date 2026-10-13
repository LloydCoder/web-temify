import { expect, test } from "@playwright/test";

test("admin operations console denies unauthenticated visitors", async ({ page }) => {
  const response = await page.goto("/admin");
  expect(response?.status()).toBe(404);
  await expect(page.getByRole("heading", { name: /admin operations/i })).toHaveCount(0);
});
