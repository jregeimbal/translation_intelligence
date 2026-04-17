import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright configuration for OmniaLingo E2E tests.
 *
 * These tests run against the Flutter web build and mock backend endpoints
 * so they can execute without a live server or real microphone.
 */
export default defineConfig({
  testDir: "./tests",
  outputDir: "./test-results",
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  retries: 0,
  reporter: [
    ["list"],
    ["./reporters/screenshot-reporter.ts"],
    ["json", { outputFile: "./test-results/results.json" }],
  ],
  use: {
    /* Capture a screenshot on every test (pass or fail). */
    screenshot: "on",
    trace: "retain-on-failure",
    video: "retain-on-failure",

    /* Default browser context permissions. */
    permissions: ["microphone"],
    baseURL: "http://localhost:8080",
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: {
          args: [
            "--use-fake-ui-for-media-stream",
            "--use-fake-device-for-media-stream",
          ],
        },
      },
    },
  ],
});
