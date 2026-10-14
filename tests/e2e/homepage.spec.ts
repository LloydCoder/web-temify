import { expect, test } from "@playwright/test";

test("homepage serves the canonical V3 experience", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("main")).toBeVisible();

  const experience = page.frameLocator('iframe[title="Web-Temify V3 marketplace experience"]');
  await expect(
    experience.getByRole("heading", { name: /your website, ready in minutes/i }),
  ).toBeVisible();
  await expect(experience.getByRole("link", { name: /browse templates/i }).first()).toBeVisible();
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

    const experience = page.frameLocator('iframe[title="Web-Temify V3 marketplace experience"]');
    await expect(experience.getByRole("heading", { level: 1 })).toBeVisible();

    const frame = page.locator('iframe[title="Web-Temify V3 marketplace experience"]');
    const hasHorizontalOverflow = await frame.evaluate((element) => {
      const document = (element as HTMLIFrameElement).contentDocument;
      return document
        ? document.documentElement.scrollWidth > document.documentElement.clientWidth
        : true;
    });
    expect(
      hasHorizontalOverflow,
      `horizontal overflow at ${viewport.width}px viewport`,
    ).toBe(false);
  }
});
