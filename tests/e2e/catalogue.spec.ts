import { expect, test } from "@playwright/test";

test("catalogue is reachable and does not imply checkout is live", async ({
  page,
}) => {
  await page.goto("/catalog");
  await expect(
    page.getByRole("heading", { name: /product catalogue/i }),
  ).toBeVisible();
  await expect(page.getByRole("search")).toBeVisible();
  await expect(
    page.getByText(
      /not configured yet|no verified product releases|no verified products matched/i,
    ),
  ).toBeVisible();
});

test("catalogue preserves semantic landmarks and avoids horizontal overflow", async ({
  page,
}) => {
  for (const viewport of [
    { width: 320, height: 800 },
    { width: 1440, height: 900 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto("/catalog");
    await expect(page.getByRole("main")).toBeVisible();
    await expect(
      page.getByRole("heading", { level: 1, name: /product catalogue/i }),
    ).toBeVisible();
    const hasHorizontalOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth,
    );
    expect(hasHorizontalOverflow).toBe(false);
  }
});

test("unreleased product slugs render a not-found state without product details", async ({
  page,
}) => {
  await page.goto("/catalog/not-a-real-release");
  await expect(
    page.getByRole("heading", { name: /product not found/i }),
  ).toBeVisible();
  await expect(
    page.getByText(/not available as a verified release/i),
  ).toBeVisible();
  await expect(
    page.getByRole("link", { name: /return to catalogue/i }),
  ).toBeVisible();
});
