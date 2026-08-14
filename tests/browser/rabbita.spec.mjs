import { expect, test } from "@playwright/test";

const LOCALE_STORAGE_KEY = "lampclaw.i18n.rabbita-todo.locale";

test("loads a dynamic catalog once and reuses the installed catalog", async ({
  page,
}) => {
  let catalogRequests = 0;
  await page.route("**/i18n/zh-CN--*.json", async (route) => {
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
  expect(catalogRequests).toBe(2);
});

test("keeps the old locale after an invalid catalog and supports retry", async ({
  page,
}) => {
  let catalogRequests = 0;
  let failedCommon = false;
  await page.route("**/i18n/zh-CN--*.json", async (route) => {
    catalogRequests += 1;
    if (
      !failedCommon &&
      route.request().url().endsWith("/i18n/zh-CN--common.json")
    ) {
      failedCommon = true;
      await new Promise((resolve) => setTimeout(resolve, 150));
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
  expect(
    await page.evaluate((key) => localStorage.getItem(key), LOCALE_STORAGE_KEY),
  ).toBeNull();

  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("待办事项");
  expect(
    await page.evaluate((key) => localStorage.getItem(key), LOCALE_STORAGE_KEY),
  ).toBe("zh-CN");
  expect(catalogRequests).toBe(3);
});

test("persists an explicit locale and restores it after reload", async ({
  page,
}) => {
  let catalogRequests = 0;
  let releaseReloadCatalog;
  const reloadCatalogGate = new Promise((resolve) => {
    releaseReloadCatalog = resolve;
  });
  let observeReloadRequest;
  const reloadRequest = new Promise((resolve) => {
    observeReloadRequest = resolve;
  });
  await page.route("**/i18n/zh-CN--*.json", async (route) => {
    catalogRequests += 1;
    if (catalogRequests === 3) {
      observeReloadRequest();
      await reloadCatalogGate;
    }
    await route.continue();
  });
  await page.goto("/");

  const app = page.getByTestId("todo-app");
  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  expect(
    await page.evaluate((key) => localStorage.getItem(key), LOCALE_STORAGE_KEY),
  ).toBe("zh-CN");

  const reload = page.reload();
  await reloadRequest;
  await expect(app).toHaveAttribute("data-locale", "en-US");
  await expect(page.getByTestId("catalog-status")).toHaveAttribute(
    "data-state",
    "loading",
  );
  releaseReloadCatalog();
  await reload;
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("待办事项");

  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "en-US");
  expect(
    await page.evaluate((key) => localStorage.getItem(key), LOCALE_STORAGE_KEY),
  ).toBe("en-US");
  await page.reload();
  await expect(app).toHaveAttribute("data-locale", "en-US");
  await expect(page.getByTestId("catalog-status")).toHaveAttribute(
    "data-state",
    "ready",
  );
  expect(catalogRequests).toBe(4);
});

test("keeps locale switching usable when browser storage throws", async ({
  page,
}) => {
  await page.addInitScript(() => {
    Object.defineProperty(Storage.prototype, "getItem", {
      configurable: true,
      value() {
        throw new DOMException("storage blocked", "SecurityError");
      },
    });
    Object.defineProperty(Storage.prototype, "setItem", {
      configurable: true,
      value() {
        throw new DOMException("storage blocked", "SecurityError");
      },
    });
  });
  await page.goto("/");

  const app = page.getByTestId("todo-app");
  await expect(app).toHaveAttribute("data-locale", "en-US");
  await page.locator("#locale-toggle").click();
  await expect(app).toHaveAttribute("data-locale", "zh-CN");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("待办事项");
});

test("formats plural messages while the application state changes", async ({
  page,
}) => {
  await page.goto("/");
  await page.locator("#new-todo").fill("Ship the release candidate");
  await page.locator("#add-todo").click();
  await expect(page.locator(".panel-kicker")).toHaveText("One active");

  await page.locator("#locale-toggle").click();
  await expect(page.locator(".panel-kicker")).toHaveText("\u20681\u2069 项待办");
  await page.locator(".status-toggle").click();
  await expect(page.locator(".panel-kicker")).toHaveText("\u20680\u2069 项待办");
});

test("executes number, datetime, rich parts, fallback, and diagnostics in JS", async ({
  page,
}) => {
  await page.goto("/");
  const fixture = page.locator("#browser-contract");
  await expect(fixture).toHaveAttribute("data-negotiated-locale", "zh-CN");
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
