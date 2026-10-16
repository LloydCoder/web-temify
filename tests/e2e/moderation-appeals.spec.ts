import { expect, test } from "@playwright/test";

test("creator appeal center reveals no case data before sign-in", async ({
  page,
}) => {
  await page.goto("/creator/moderation-appeals");
  await expect(
    page.getByRole("heading", { name: "Creator takedown appeals" }),
  ).toBeVisible();
  await expect(
    page.getByText(
      "Sign in with the account that owns the affected listing to review or submit an appeal.",
    ),
  ).toBeVisible();
  await expect(page.getByText("Case:", { exact: true })).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: /submit appeal/i }),
  ).toHaveCount(0);
});

test(
  "creator appeal intake requires authentication after same-origin validation",
  async ({ page }) => {
  const response = await page.request.post("/api/moderation/appeals", {
    headers: {
      Origin: "http://127.0.0.1:3000",
      "Content-Type": "application/json",
    },
    data: {
      enforcementId: "b5000000-0000-4000-8000-000000000005",
      statement:
        "I am requesting a review of the takedown and can provide ownership evidence.",
      evidenceReference: null,
      idempotencyKey: "phase5e2-e2e-auth-check-0001",
    },
  });
    expect(response.status()).toBe(401);
    await expect(response.json()).resolves.toEqual({
      error: "authentication_required",
    });
  },
);

test(
  "moderation and appeal administration pages deny unauthenticated visitors",
  async ({ page }) => {
  for (const route of ["/admin/moderation", "/admin/moderation-appeals"]) {
    await page.goto(route);
        await expect(page.getByText("404 — Not found")).toBeVisible();
      await expect(
        page.getByRole("heading", { name: "Wrong turn." }),
      ).toBeVisible();
      await expect(
        page.getByRole("heading", {
          name: /listing moderation|creator takedown appeals/i,
        }),
      ).toHaveCount(0);
    }
  },
);

test(
  "moderation takedown, appeal transition, and policy mutations deny unauthenticated visitors",
  async ({ page }) => {
  const requests = [
    {
      url: "/api/admin/moderation-cases/b5000000-0000-4000-8000-000000000005/takedown",
      data: {
        reasonCode: "rights_review_required",
        note: "Unauthenticated E2E request.",
      },
    },
    {
      url: "/api/admin/moderation-appeals/b6000000-0000-4000-8000-000000000006/transition",
      data: {
        action: "uphold",
        note: "Unauthenticated E2E request.",
      },
    },
    {
      url: "/api/admin/moderation-appeal-policy",
      data: {
        responseTargetHours: 336,
        policyVersion: "unauthorized-e2e-attempt",
        approvalNote: "Unauthenticated E2E request.",
        legalReviewReference: "test-only",
      },
    },
  ];

  for (const request of requests) {
    const response = await page.request.post(request.url, {
      data: request.data,
    });
      expect(response.status()).toBe(404);
      await expect(response.json()).resolves.toEqual({ error: "not_found" });
    }
  },
);
