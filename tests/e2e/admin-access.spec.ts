import { expect, test } from "@playwright/test";

test("admin operations console denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.goto("/admin");

  // Next.js may return HTTP 200 when notFound() is rendered after streaming
  // has begun. Assert the authorization outcome and rendered not-found UI,
  // not a transport status that depends on streaming timing.
  expect(response).not.toBeNull();
  await expect(page.getByText("404 — Not found")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Wrong turn." }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /admin operations/i }),
  ).toHaveCount(0);
  await expect(
    page.getByText("Catalogue records", { exact: true }),
  ).toHaveCount(0);
  await expect(
    page.getByText("Recent audit activity", { exact: true }),
  ).toHaveCount(0);
});

test("admin rights-review mutation endpoint denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.request.post(
    "/api/admin/products/89000000-0000-4000-8000-000000000089/rights-review",
    {
      data: {
        attestationId: "89100000-0000-4000-8000-000000000089",
        decision: "verified",
        notes: "Attempted unauthenticated review.",
      },
    },
  );
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});

test("admin audit and rights-review pages deny unauthenticated visitors", async ({
  page,
}) => {
  for (const route of [
    "/admin/audit",
    "/admin/reviews",
    "/admin/settlements",
    "/admin/support",
    "/admin/moderation",
    "/admin/moderation-appeals",
    "/admin/financial-controls",
  ]) {
    await page.goto(route);
    await expect(page.getByText("404 — Not found")).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Wrong turn." }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", {
        name: /audit explorer|product rights review|settlement exceptions|support case queue|financial control requests/i,
      }),
    ).toHaveCount(0);
    await expect(
      page.getByRole("navigation", {
        name: /audit pagination|settlement exception pagination/i,
      }),
    ).toHaveCount(0);
  }
});

test("settlement triage mutation denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.request.post(
    "/api/admin/settlements/89000000-0000-4000-8000-000000000089/decision",
    {
      data: {
        rowId: "payment-row-01",
        decision: "manual_review_required",
        reason: "Attempted unauthenticated settlement triage.",
        evidenceSha256: null,
      },
    },
  );
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});

test("settlement evidence upload denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.request.post("/api/admin/settlements/evidence", {
    headers: { "Content-Type": "text/csv" },
    data: "date,amount\\n2026-10-14,100",
  });
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});

test("settlement evidence download denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.request.get(
    "/api/admin/settlements/evidence/8b000000-0000-4000-8000-00000000008b",
  );
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});

test("settlement evidence linking denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.request.post(
    "/api/admin/settlements/evidence/8b000000-0000-4000-8000-00000000008b/link",
    {
      headers: { "Content-Type": "application/json" },
      data: { importId: "8d000000-0000-4000-8000-00000000008d" },
    },
  );
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});

test("admin support-case mutation denies unauthenticated visitors", async ({
  page,
}) => {
  const response = await page.request.post(
    "/api/admin/support-cases/89000000-0000-4000-8000-000000000089/transition",
    {
      data: {
        action: "triage",
        note: "Attempted unauthenticated support-case transition.",
      },
    },
  );
  expect(response.status()).toBe(404);
  await expect(response.json()).resolves.toEqual({ error: "not_found" });
});

test("financial control API denies unauthenticated queue and mutation access", async ({
  page,
}) => {
  const queue = await page.request.get("/api/admin/financial-controls");
  expect(queue.status()).toBe(404);
  await expect(queue.json()).resolves.toEqual({ error: "not_found" });

  const create = await page.request.post("/api/admin/financial-controls", {
    headers: { "Content-Type": "application/json" },
    data: {
      requestType: "manual_adjustment",
      sellerId: "a2000000-0000-4000-8000-000000000002",
      amountMinor: "2500",
      currency: "USD",
      evidenceSha256: "a".repeat(64),
      reason: "Unauthenticated request must not be created.",
      idempotencyKey: "phase5g-unauthenticated-test-0001",
    },
  });
  expect(create.status()).toBe(404);
  await expect(create.json()).resolves.toEqual({ error: "not_found" });

  const review = await page.request.post(
    "/api/admin/financial-controls/a3000000-0000-4000-8000-000000000003/review",
    {
      headers: { "Content-Type": "application/json" },
      data: { decision: "approve", note: "Unauthenticated approval attempt." },
    },
  );
  expect(review.status()).toBe(404);
  await expect(review.json()).resolves.toEqual({ error: "not_found" });
});

test("customer support-case history requires authentication", async ({
  page,
}) => {
  const response = await page.request.get("/api/support-cases");
  expect(response.status()).toBe(401);
  await expect(response.json()).resolves.toEqual({
    error: "authentication_required",
  });
});
