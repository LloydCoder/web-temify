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
      name: /your next website, starts here/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByText(/no products are available for purchase/i),
  ).toBeVisible();
  await expect(page.locator("iframe")).toHaveCount(0);
  await expect(page.locator('link[rel="icon"]')).toHaveAttribute(
    "href",
    /icon\.svg/,
  );
  await expect(page.locator(".cat-card").first()).toHaveAttribute(
    "href",
    /\/catalog\?q=/,
  );
  await expect(page.locator(".web3-card").first()).toHaveAttribute(
    "href",
    /\/catalog\?q=/,
  );
  await expect(page.locator('a[href="#"]')).toHaveCount(0);
  await expect(page.locator(".ai-input-row button")).toBeDisabled();
  await expect(page.getByText(/AI generation is not live yet/i)).toBeVisible();
  await expect(
    page.getByRole("textbox", {
      name: /website description/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("textbox", {
      name: /email address for future web-temify updates/i,
    }),
  ).toBeDisabled();
  await expect(page.locator("#newsletter-status")).toContainText(
    /no email is collected/i,
  );
  await expect(
    page.getByText("Payment adapter concept", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Paystack Ready", { exact: true }),
  ).toHaveCount(0);
  await expect(
    page.getByText("Stripe Billing", { exact: true }),
  ).toHaveCount(0);
  const ecosystem = page.locator("#ecosystem");
  await expect(ecosystem.getByRole("article")).toHaveCount(9);
  for (const href of [
    "/catalog",
    "/hosting",
    "/ai-site-builder",
    "/directory",
    "/automations",
    "/specialists",
    "/implementation",
    "/platform",
    "/tech-hub",
  ]) {
    await expect(ecosystem.locator(`a[href="${href}"]`)).toHaveCount(1);
  }
  await expect(
    ecosystem.getByText(/planned cards are roadmap disclosures/i),
  ).toBeVisible();
  const unresolvedAnchorTargets = await page
    .locator('a[href^="#"]')
    .evaluateAll((anchors) =>
      anchors
        .map((anchor) => anchor.getAttribute("href")?.slice(1) ?? "")
        .filter((target) => target && !document.getElementById(target)),
    );
  expect(unresolvedAnchorTargets).toEqual([]);
});

test("catalogue uses a page-specific SEO title", async ({ page }) => {
  await page.goto("/catalog");
  await expect(page).toHaveTitle(/Product Catalogue \| Web-Temify/);
  await expect(
    page.getByRole("heading", { name: "Product catalogue" }),
  ).toBeVisible();
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
  const toggle = page.getByRole("button", { name: /navigation/i });
  const navigation = page.locator("#primary-navigation");
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(toggle).toHaveAccessibleName("Open navigation");
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await expect(toggle).toHaveAccessibleName("Close navigation");
  await expect(
    navigation.getByRole("link", { name: "Templates" }),
  ).toBeVisible();
  await navigation.getByRole("link", { name: "Templates" }).click();
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
});

test("mobile navigation closes on Escape and restores focus to the toggle", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const toggle = page.getByRole("button", { name: /navigation/i });
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await page.keyboard.press("Escape");
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(toggle).toBeFocused();
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

test("No-Code and Freelancer Resources directory filters return matching tools", async ({
  page,
}) => {
  await page.goto("/");
  const cards = page.locator(".dir-card");
  const visibleCardCount = () =>
    cards.evaluateAll(
      (items) => items.filter((item) => !item.hasAttribute("hidden")).length,
    );
  for (const label of ["No-Code", "Freelancer Resources"]) {
    await page.getByRole("button", { name: label }).click();
    await expect.poll(visibleCardCount).toBeGreaterThan(0);
  }
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

test("robots and sitemap use the configured canonical origin", async ({
  page,
}) => {
  await page.goto("/");
  const origin = new URL(page.url()).origin;
  const sitemapResponse = await page.request.get(
    new URL("/sitemap.xml", origin).toString(),
  );
  expect(sitemapResponse.ok()).toBe(true);
  const sitemap = await sitemapResponse.text();
  const sitemapOrigins = sitemap
    .split("<loc>")
    .slice(1)
    .map((entry) => new URL(entry.split("</loc>")[0]).origin);
  expect(sitemapOrigins.length).toBeGreaterThan(0);
  expect([...new Set(sitemapOrigins)]).toEqual([origin]);

  const robotsResponse = await page.request.get(
    new URL("/robots.txt", origin).toString(),
  );
  expect(robotsResponse.ok()).toBe(true);
  const robots = await robotsResponse.text();
  expect(robots).toContain(`Sitemap: ${origin}/sitemap.xml`);
  for (const path of [
    "/admin",
    "/account",
    "/checkout",
    "/api",
    "/internal",
    "/creator",
    "/seller",
  ]) {
    expect(robots).toContain(`Disallow: ${path}`);
  }
});

test("header and hero respond correctly across desktop and mobile layouts", async ({
  page,
}) => {
  const navigation = page.getByRole("navigation", {
    name: "Primary navigation",
  });
  const toggle = page.getByRole("button", { name: /navigation/i });
  const links = page.locator("#primary-navigation");
  const hero = page.locator(".hero");
  const heroVisual = page.locator(".hero-right");

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(navigation).toBeVisible();
  await expect(toggle).toBeVisible();
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(links).toBeHidden();
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  await expect(page.locator(".hero-cta .btn-fill")).toHaveText("Explore previews");
  await expect(heroVisual).toBeHidden();
  await expect(hero).toHaveCSS("grid-template-columns", /^\d+px$/);

  await page.setViewportSize({ width: 1440, height: 900 });
  await expect(toggle).toBeHidden();
  await expect(links).toBeVisible();
  await expect(links.getByRole("link", { name: "Templates" })).toBeVisible();
  await expect(heroVisual).toBeVisible();
});

test("mobile header opens, closes with Escape, and restores focus", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/");
  const toggle = page.getByRole("button", { name: "Open navigation" });
  await expect(toggle).toBeVisible();
  await toggle.click();
  const closeToggle = page.getByRole("button", { name: "Close navigation" });
  await expect(closeToggle).toHaveAttribute("aria-expanded", "true");
  await expect(page.getByRole("link", { name: "Launch Kits" })).toBeVisible();
  await page.keyboard.press("Escape");
  const openToggle = page.getByRole("button", { name: "Open navigation" });
  await expect(openToggle).toHaveAttribute("aria-expanded", "false");
  await expect(openToggle).toBeFocused();
});

test("hero preview cards remain visible on tablet and mobile", async ({
  page,
}) => {
  for (const viewport of [
    { width: 320, height: 800 },
    { width: 390, height: 844 },
    { width: 768, height: 1024 },
    { width: 1024, height: 900 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto("/");
    await expect(page.locator(".hero")).toBeVisible();
    await expect(page.locator(".hero-right .preview-card")).toHaveCount(3);
    await expect(page.locator(".hero-right .preview-card").first()).toBeVisible();
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
    );
    expect(overflow, `horizontal overflow at ${viewport.width}px`).toBe(false);
  }
});
