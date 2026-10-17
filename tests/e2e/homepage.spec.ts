import { expect, test } from "@playwright/test";

test("homepage renders the V3 experience as native Next.js content", async ({
  page,
}) => {
  await page.goto("/");
  await expect(
    page.getByRole("main", { name: /web-temify marketplace preview/i }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", {
      level: 1,
      name: /your website, ready in minutes/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByText(/no products are available for purchase/i),
  ).toBeVisible();
  await expect(page.locator("iframe")).toHaveCount(0);
  await expect(page.locator(".cat-card").first()).toHaveAttribute("href", /\/catalog\?q=/;
  await expect(page.locator(".web3-card").first()).toHaveAttribute("href", "/catalog");
  await expect(page.locator('a[href="#"]')).toHaveCount(0);
  await expect(page.locator(".ai-input-row button")).toBeDisabled();
  await expect(page.getByText(/AI generation is not live yet/i)).toBeVisible();
  const unresolvedAnchorTargets = await page
    .locator('a[href^="#"]')
    .evaluateAll((anchors) =>
      anchors
        .map((anchor) => anchor.getAttribute("href")?.slice(1) ?? "")
        .filter((target) => target && !document.getElementById(target)),
    );
  expect(unresolvedAnchorTargets).toEqual([]);
});

test("homepage has no horizontal overflow on mobile or desktop", async ({
  page,
}) => {
  for (const viewport of [
    { width: 320, height: 800 },
    { width: 390, height: 844 },
    { width: 768, height: 1024 },
    { width: 1440, height: 900 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth,
    );
    expect(
      overflow,
      `horizontal overflow at ${viewport.width}px viewport`,
    ).toBe(false);
  }
});

test("mobile navigation opens and closes accessibly", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const toggle = page.getByRole("button", { name: /toggle navigation/i });
  const navigation = page.locator("#primary-navigation");
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await expect(
    navigation.getByRole("link", { name: "Templates" }),
  ).toBeVisible();
  await navigation.getByRole("link", { name: "Templates" }).click();
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
});

test("directory tabs filter the visible external tool cards", async ({
  page,
}) => {
  await page.goto("/");
  const cards = page.locator(".dir-card");
  const allCount = await cards.count();
  expect(allCount).toBeGreaterThan(0);
  await page.getByRole("button", { name: "AI & ML" }).click();
  await expect(page.getByRole("button", { name: "AI & ML" })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  await expect
    .poll(() =>
      cards.evaluateAll(
        (items) => items.filter((item) => !item.hasAttribute("hidden")).length,
      ),
    )
    .toBeLessThan(allCount);
  await page.getByRole("button", { name: "All Tools" }).click();
  await expect
    .poll(() =>
      cards.evaluateAll(
        (items) => items.filter((item) => !item.hasAttribute("hidden")).length,
      ),
    )
    .toBe(allCount);
});

test("native AI prompt buttons populate the planned builder input without implying generation is live", async ({
  page,
}) => {
  await page.goto("/");
  const input = page.locator(".ai-input");
  await page
    .getByRole("button", { name: /use logistics company prompt/i })
    .click();
  await expect(input).toHaveValue("Logistics company website");
  await expect(page.locator(".ai-input-row button")).toBeDisabled();
});
