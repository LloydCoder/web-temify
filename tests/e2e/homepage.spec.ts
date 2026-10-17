import { expect, test } from "@playwright/test";

test("homepage renders the V3 marketplace preview as server-rendered page content", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByRole("main", { name: /marketplace preview/i })).toBeVisible();
  await expect(
    page.getByRole("heading", { level: 1, name: /your website, ready in minutes/i }),
  ).toBeVisible();
  await expect(page.getByText(/no products are available for purchase/i)).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /AI Site Builder coming soon/i }),
  ).toBeVisible();
  await expect(
    page.getByText(/Payment providers will be announced after integration and checkout testing/i),
  ).toBeVisible();
  await expect(
    page.getByText(/instant secure download after purchase|Pay via Paystack, Stripe, or LemonSqueezy/i),
  ).toHaveCount(0);
  await expect(page.getByRole("link", { name: /browse catalogue/i }).first()).toHaveAttribute(
    "href",
    "/catalog",
  );
  await expect(page.locator('iframe[title="Web-Temify V3 marketplace experience"]')).toHaveCount(0);
  await expect(page.locator('a[href="#"]')).toHaveCount(0);
  await expect(
    page.getByText(/2,400\+ businesses|1,200\+ curated tools|[0-9,]+ sales/i),
  ).toHaveCount(0);

  const unresolvedAnchorTargets = await page.locator("main a[href^=\"#\"]").evaluateAll(
    (anchors) =>
      anchors
        .map((anchor) => anchor.getAttribute("href")?.slice(1) ?? "")
        .filter((target) => target && !document.getElementById(target)),
  );
  expect(unresolvedAnchorTargets).toEqual([]);
});

test("homepage exposes usable AI prompt chips without claiming the builder is live", async ({
  page,
}) => {
  await page.goto("/");
  const input = page.locator(".ai-input");
  await page.getByRole("button", { name: /use prompt: logistics company/i }).click();
  await expect(input).toHaveValue("Logistics company website");

  await page.getByRole("button", { name: /generate/i }).click();
  await expect(page.getByRole("status")).toContainText(/planned but is not available yet/i);
  await expect(page.getByRole("status")).toContainText(/has not been submitted or processed/i);
});

test("tech directory tabs filter the preview and support keyboard navigation", async ({
  page,
}) => {
  await page.goto("/");
  const cards = page.locator(".dir-card");
  await expect(cards).toHaveCount(6);
  await page.getByRole("tab", { name: "Web3 & Blockchain" }).click();
  await expect(cards.filter({ hasText: "Hardhat" })).toBeVisible();
  await expect(cards.filter({ hasText: "Claude by Anthropic" })).toBeHidden();
  await expect(cards).toHaveCount(6);

  const web3Tab = page.getByRole("tab", { name: "Web3 & Blockchain" });
  await expect(web3Tab).toHaveAttribute("aria-selected", "true");
  await web3Tab.focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.getByRole("tab", { name: "Hosting & Infra" })).toBeFocused();
  await expect(page.getByRole("tab", { name: "Hosting & Infra" })).toHaveAttribute(
    "aria-selected",
    "true",
  );
  await expect(cards.filter({ hasText: "Vercel" })).toBeVisible();
  await expect(cards.filter({ hasText: "Hardhat" })).toBeHidden();
});

test("homepage has no horizontal overflow at mobile and desktop viewport widths", async ({
  page,
}) => {
  for (const viewport of [
    { width: 320, height: 800 },
    { width: 1440, height: 900 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto("/");
    await expect(page.getByRole("main", { name: /marketplace preview/i })).toBeVisible();
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

    const hasHorizontalOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
    );
    expect(hasHorizontalOverflow, `horizontal overflow at ${viewport.width}px viewport`).toBe(false);
  }
});
