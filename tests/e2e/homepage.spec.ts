import { expect, test } from "@playwright/test";

test("homepage serves the canonical V3 experience", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("main")).toBeVisible();

  const experience = page.frameLocator(
    'iframe[title="Web-Temify V3 marketplace experience"]',
  );
  await expect(
    experience.getByRole("heading", {
      name: /your website, ready in minutes/i,
    }),
  ).toBeVisible();
  await expect(
    experience.getByText(/no products are available for purchase/i),
  ).toBeVisible();
  await expect(
    experience.getByRole("link", { name: /browse catalogue/i }).first(),
  ).toBeVisible();
  await expect(experience.locator('a[href="#"]')).toHaveCount(0);
  await expect(
    experience.getByText(
      /2,400\+ businesses|1,200\+ curated tools|[0-9,]+ sales/i,
    ),
  ).toHaveCount(0);

  const frame = page.locator(
    'iframe[title="Web-Temify V3 marketplace experience"]',
  );
  const unresolvedAnchorTargets = await frame.evaluate((element) => {
    const document = (element as HTMLIFrameElement).contentDocument;
    if (!document) return ["iframe document unavailable"];
    return Array.from(document.querySelectorAll('a[href^="#"]'))
      .map((anchor) => anchor.getAttribute("href")?.slice(1) ?? "")
      .filter((target) => target && !document.getElementById(target));
  });
  expect(unresolvedAnchorTargets).toEqual([]);
});

test("homepage has semantic landmarks and no horizontal overflow on mobile or desktop", async ({
  page,
}) => {
  for (const viewport of [
    { width: 320, height: 800 },
    { width: 1440, height: 900 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto("/");
    await expect(page.getByRole("main")).toBeVisible();

    const experience = page.frameLocator(
      'iframe[title="Web-Temify V3 marketplace experience"]',
    );
    await expect(experience.getByRole("heading", { level: 1 })).toBeVisible();

    const frame = page.locator(
      'iframe[title="Web-Temify V3 marketplace experience"]',
    );
    const hasHorizontalOverflow = await frame.evaluate((element) => {
      const document = (element as HTMLIFrameElement).contentDocument;
      return document
        ? document.documentElement.scrollWidth >
            document.documentElement.clientWidth
        : true;
    });
    expect(
      hasHorizontalOverflow,
      `horizontal overflow at ${viewport.width}px viewport`,
    ).toBe(false);
  }
});
