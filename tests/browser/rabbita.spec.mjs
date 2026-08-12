import { expect, test } from "@playwright/test";

test("loads a dynamic catalog once and reuses the installed catalog", async ({
  page,
}) => {
  let catalogRequests = 0;
  await page.route("**/i18n/zh-CN.json", async (route) => {
    catalogRequests += 1;
    await new Promise((resolve) => setTimeout(resolve, 150));
    await route.continue();
  });
  await page.goto("/");

  const app = page.getByTestId("todo-app");
  await expect(app).toHaveAttribute("data-locale", "en-US");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Todos");

  await page.locator("#locale-toggle").click();
  await expect(page.getByTestId("catalog-status")).toHaveAttribute(
    "data-state",
    "loading",
  );
  await expect(page.locator("#locale-toggle")).toBeDisabled();
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("待办事项");

  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "en-US");
  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  expect(catalogRequests).toBe(1);
});

test("keeps the old locale after an invalid catalog and supports retry", async ({
  page,
}) => {
  let catalogRequests = 0;
  await page.route("**/i18n/zh-CN.json", async (route) => {
    catalogRequests += 1;
    if (catalogRequests === 1) {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: "{not a valid catalog",
      });
    } else {
      await route.continue();
    }
  });
  await page.goto("/");

  const app = page.getByTestId("todo-app");
  await page.locator("#locale-toggle").click();
  await expect(page.getByTestId("catalog-status")).toHaveAttribute(
    "data-state",
    "error",
  );
  await expect(app).toHaveAttribute("data-locale", "en-US");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Todos");
  await expect(page.locator("#locale-toggle")).toHaveText("Retry");

  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("待办事项");
  expect(catalogRequests).toBe(2);
});

test("formats plural messages while the application state changes", async ({
  page,
}) => {
  await page.goto("/");
  await page.locator("#new-todo").fill("Ship the release candidate");
  await page.locator("#add-todo").click();
  await expect(page.locator(".panel-kicker")).toHaveText("One active");

  await page.locator("#locale-toggle").click();
  await expect(page.locator(".panel-kicker")).toHaveText("1 项待办");
  await page.locator(".status-toggle").click();
  await expect(page.locator(".panel-kicker")).toHaveText("0 项待办");
});

test("executes number, datetime, rich parts, fallback, and diagnostics in JS", async ({
  page,
}) => {
  await page.goto("/");
  const fixture = page.locator("#browser-contract");
  await expect(fixture).toHaveAttribute("data-requested-locale", "zh-CN");
  await expect(fixture).toHaveAttribute("data-used-locale", "en-US");
  expect(Number(await fixture.getAttribute("data-diagnostics"))).toBe(3);

  const number = await page.locator("#contract-number").textContent();
  expect(number).toContain("Contract number:");
  expect(number).toMatch(/1[^\d]234[^\d]567/);

  const date = await page.locator("#contract-date").textContent();
  expect(date).toContain("Updated");
  expect(date).toContain("2024");

  await expect(page.locator("#contract-rich strong")).toHaveText("Typed");
  await expect(page.locator("#contract-rich")).toContainText(
    "Typed localization",
  );
});
