import { expect, test } from "@playwright/test";

const destinations = [
  {
    path: "/hosting",
    title: "Web Hosting & Deployment",
    status: /provisioning not operational/i,
  },
  {
    path: "/ai-site-builder",
    title: "AI Site Builder",
    status: /generation disabled/i,
  },
  {
    path: "/directory",
    title: "Tech Directory Hub",
    status: /submissions and paid placements not live/i,
  },
  {
    path: "/automations",
    title: "Verified Automation Marketplace",
    status: /transactions disabled/i,
  },
  {
    path: "/specialists",
    title: "Specialist Supplier Directory",
    status: /onboarding not available/i,
  },
  {
    path: "/implementation",
    title: "Outcome-Based AI Implementation",
    status: /contracts and milestone payments disabled/i,
  },
  {
    path: "/platform",
    title: "Shared Enterprise Platform",
    status: /feature availability varies/i,
  },
  {
    path: "/tech-hub",
    title: "Tech Hub & Advertising Engine",
    status: /publishing and monetization not enabled/i,
  },
];

for (const destination of destinations) {
  test(`destination ${destination.path} states its actual availability`, async ({
    page,
  }) => {
    await page.goto(destination.path);
    await expect(
      page.getByRole("heading", { level: 1, name: destination.title }),
    ).toBeVisible();
    await expect(page.getByText(destination.status)).toBeVisible();
    await expect(
      page.getByRole("link", { name: /browse catalogue/i }),
    ).toHaveAttribute("href", "/catalog");
    await expect(
      page.getByRole("link", { name: /all ecosystem areas/i }),
    ).toHaveAttribute("href", "/#ecosystem");
    await expect(page.locator('a[href="#"]')).toHaveCount(0);
  });
}

test("ecosystem destination pages avoid horizontal overflow on mobile and desktop", async ({
  page,
}) => {
  for (const viewport of [
    { width: 320, height: 800 },
    { width: 390, height: 844 },
    { width: 1440, height: 900 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto("/implementation");
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
