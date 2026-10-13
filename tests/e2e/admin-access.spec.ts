import { expect, test } from "@playwright/test";

test("admin operations console denies unauthenticated visitors", async ({ page }) => {
  const response = await page.goto("/admin");

  // Next.js may return HTTP 200 when notFound() is rendered after streaming
  // has begun. Assert the authorization outcome and rendered not-found UI,
  // not a transport status that depends on streaming timing.
  expect(response).not.toBeNull();
  await expect(page.getByText("404 — Not found")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Wrong turn." })).toBeVisible();
  await expect(page.getByRole("heading", { name: /admin operations/i })).toHaveCount(0);
  await expect(page.getByText("Catalogue records", { exact: true })).toHaveCount(0);
  await expect(page.getByText("Recent audit activity", { exact: true })).toHaveCount(0);
});


test("admin rights-review mutation endpoint denies unauthenticated visitors", async ({ page }) => {
  const response = await page.request.post("/api/admin/products/89000000-0000-4000-8000-000000000089/rights-review", {
    data: {
      attestationId: "89100000-0000-4000-8000-000000000089",
      decision: "verified",
      notes: "Attempted unauthenticated review."
    }
  });
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});
