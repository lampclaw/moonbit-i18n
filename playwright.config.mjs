import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/browser",
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["line"]] : [["list"]],
  use: {
    baseURL: "http://127.0.0.1:41873",
    trace: "on-first-retry",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
  ],
  webServer: {
    command: "node scripts/serve-static.mjs _build/browser/rabbita-todo 41873",
    url: "http://127.0.0.1:41873",
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
