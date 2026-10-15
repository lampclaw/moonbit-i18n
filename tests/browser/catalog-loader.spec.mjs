import { expect, test } from "@playwright/test";

const storageKey = "lampclaw.i18n.rabbita-todo.locale";
const commonChunk = "/i18n/zh-CN--common.json";
const todoChunk = "/i18n/zh-CN--todo_ui.json";

async function expectRecoverableFailure(page) {
  await expect(page.getByTestId("catalog-status")).toHaveAttribute("data-state", "error");
  await expect(page.getByTestId("todo-app")).toHaveAttribute("data-locale", "en-US");
  await expect(page.locator("#locale-toggle")).toHaveText("Retry");
  expect(await page.evaluate(key => localStorage.getItem(key), storageKey)).toBeNull();
}

test("aborts a request with stalled headers and allows a fresh retry", async ({ page }) => {
  await page.clock.install();
  await page.addInitScript(({ commonChunk }) => {
    const fetch = window.fetch.bind(window);
    let first = true;
    window.fetch = (url, options) => {
      if (String(url).endsWith(commonChunk) && first) {
        first = false;
        window.catalogAbortCount = 0;
        return new Promise((_, reject) => {
          options.signal.addEventListener("abort", () => {
            window.catalogAbortCount += 1;
            reject(new DOMException("Aborted", "AbortError"));
          }, { once: true });
        });
      }
      return fetch(url, options);
    };
  }, { commonChunk });
  await page.goto("/");
  await page.locator("#locale-toggle").click();
  await expect.poll(() => page.evaluate(() => window.catalogAbortCount)).toBe(0);
  await page.clock.fastForward(10_001);
  await expectRecoverableFailure(page);
  expect(await page.evaluate(() => window.catalogAbortCount)).toBe(1);
  await page.locator("#locale-toggle").click();
  await expect(page.getByTestId("todo-app")).toHaveAttribute("data-locale", "zh-CN");
});

test("times out while reading a response body and cancels its stream", async ({ page }) => {
  await page.clock.install();
  await page.addInitScript(({ commonChunk }) => {
    const fetch = window.fetch.bind(window);
    let first = true;
    window.fetch = async (url, options) => {
      if (!String(url).endsWith(commonChunk) || !first) return fetch(url, options);
      first = false;
      window.catalogStreamCancelled = false;
      return new Response(new ReadableStream({
        start(controller) { controller.enqueue(new TextEncoder().encode("{")); },
        cancel() { window.catalogStreamCancelled = true; },
      }));
    };
  }, { commonChunk });
  await page.goto("/");
  await page.locator("#locale-toggle").click();
  await expect.poll(() => page.evaluate(() => window.catalogStreamCancelled)).toBe(false);
  await page.clock.fastForward(10_001);
  await expectRecoverableFailure(page);
  await expect.poll(() => page.evaluate(() => window.catalogStreamCancelled)).toBe(true);
  await page.locator("#locale-toggle").click();
  await expect(page.getByTestId("todo-app")).toHaveAttribute("data-locale", "zh-CN");
});

test("limits actual streamed bytes despite a misleading Content-Length", async ({ page }) => {
  await page.addInitScript(({ commonChunk }) => {
    const fetch = window.fetch.bind(window);
    let first = true;
    window.fetch = async (url, options) => {
      if (!String(url).endsWith(commonChunk) || !first) return fetch(url, options);
      first = false;
      window.catalogStreamCancelled = false;
      window.catalogStreamPulls = 0;
      return new Response(new ReadableStream({
        pull(controller) {
          window.catalogStreamPulls += 1;
          controller.enqueue(new Uint8Array(65_537).fill(32));
        },
        cancel() { window.catalogStreamCancelled = true; },
      }, { highWaterMark: 0 }), { headers: { "Content-Length": "1" } });
    };
  }, { commonChunk });
  await page.goto("/");
  await page.locator("#locale-toggle").click();
  await expectRecoverableFailure(page);
  await expect.poll(() => page.evaluate(() => window.catalogStreamCancelled)).toBe(true);
  expect(await page.evaluate(() => window.catalogStreamPulls)).toBe(1);
  await page.locator("#locale-toggle").click();
  await expect(page.getByTestId("todo-app")).toHaveAttribute("data-locale", "zh-CN");
});

test("rejects invalid UTF-8 and same-length tampering before installing a catalog", async ({ page }) => {
  let requests = 0;
  await page.route(`**${commonChunk}`, async route => {
    requests += 1;
    if (requests > 2) return route.continue();
    const response = await route.fetch();
    const body = await response.body();
    if (requests === 1) {
      body[body.length - 1] = 0xff;
    } else {
      // Valid JSON with the expected byte count must still pass SHA-256.
      const message = Buffer.from("English");
      const offset = body.indexOf(message);
      expect(offset).toBeGreaterThan(0);
      Buffer.from("ENGLISH").copy(body, offset);
    }
    await route.fulfill({ response, body });
  });
  await page.goto("/");
  await page.locator("#locale-toggle").click();
  await expectRecoverableFailure(page);
  await page.locator("#locale-toggle").click();
  await expectRecoverableFailure(page);
  await expect.poll(() => requests).toBe(2);
  await page.locator("#locale-toggle").click();
  await expect(page.getByTestId("todo-app")).toHaveAttribute("data-locale", "zh-CN");
});

test("decodes UTF-8 across byte boundaries and clears a successful request's timer", async ({ page }) => {
  await page.clock.install();
  await page.addInitScript(() => {
    const fetch = window.fetch.bind(window);
    window.completedCatalogAborts = 0;
    window.fetch = async (url, options) => {
      const response = await fetch(url, options);
      if (!String(url).includes("/i18n/zh-CN--")) return response;
      options.signal.addEventListener("abort", () => { window.completedCatalogAborts += 1; });
      const bytes = new Uint8Array(await response.arrayBuffer());
      let offset = 0;
      return new Response(new ReadableStream({
        pull(controller) {
          if (offset === bytes.length) controller.close();
          else controller.enqueue(bytes.slice(offset, ++offset));
        },
      }));
    };
  });
  await page.goto("/");
  await page.locator("#locale-toggle").click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("待办事项");
  await page.clock.fastForward(20_000);
  expect(await page.evaluate(() => window.completedCatalogAborts)).toBe(0);
  await expect(page.getByTestId("catalog-status")).toHaveAttribute("data-state", "ready");
});

test("ignores a previous attempt's late failure while retrying the same locale", async ({ page }) => {
  let commonRequests = 0;
  let todoRequests = 0;
  let releaseOldTodo;
  let releaseRetryCommon;
  let oldTodoStarted;
  const oldTodoGate = new Promise(resolve => { releaseOldTodo = resolve; });
  const retryCommonGate = new Promise(resolve => { releaseRetryCommon = resolve; });
  const oldTodoReady = new Promise(resolve => { oldTodoStarted = resolve; });
  await page.route("**/i18n/zh-CN--*.json", async route => {
    if (route.request().url().endsWith(todoChunk)) {
      todoRequests += 1;
      if (todoRequests === 1) {
        oldTodoStarted();
        await oldTodoGate;
        await route.fulfill({ status: 200, headers: { "x-test-attempt": "old" }, body: "invalid old catalog" });
        return;
      }
    } else if (route.request().url().endsWith(commonChunk)) {
      commonRequests += 1;
      if (commonRequests === 1) {
        await oldTodoReady;
        await route.fulfill({ status: 503, body: "Unavailable" });
        return;
      }
      await retryCommonGate;
    }
    await route.continue();
  });
  await page.goto("/");
  await page.locator("#locale-toggle").click();
  await expectRecoverableFailure(page);
  await page.locator("#locale-toggle").click();
  await expect.poll(() => todoRequests).toBe(2);
  await expect.poll(() => commonRequests).toBe(2);
  const oldResponse = page.waitForResponse(response =>
    response.url().endsWith(todoChunk) && response.headers()["x-test-attempt"] === "old",
  );
  releaseOldTodo();
  await (await oldResponse).finished();
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await expect(page.getByTestId("catalog-status")).toHaveAttribute("data-state", "loading");
  releaseRetryCommon();
  await expect(page.getByTestId("todo-app")).toHaveAttribute("data-locale", "zh-CN");
  expect(await page.evaluate(key => localStorage.getItem(key), storageKey)).toBe("zh-CN");
});
