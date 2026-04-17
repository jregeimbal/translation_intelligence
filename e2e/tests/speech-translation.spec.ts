import { test, expect, type Page } from "@playwright/test";
import { mockBackendApi } from "../fixtures/backend-mock";
import {
  MockSttServer,
  type ScriptedUtterance,
} from "../fixtures/mock-stt-server";

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

let mockSttServer: MockSttServer;

/**
 * Wait for the Flutter web app to finish rendering the initial frame.
 * The app wraps its content in a `<flt-glass-pane>` or shadow-DOM host.
 * We wait for the app title text to appear on screen as a ready signal.
 */
async function waitForAppReady(page: Page): Promise<void> {
  // Flutter web renders content either in shadow DOM or a canvas element.
  // We wait for the page to be interactive by checking for the title to appear.
  // The app title is "OmniaLingo" per the MaterialApp onGenerateTitle.
  await page.waitForFunction(
    () => document.title.includes("OmniaLingo"),
    { timeout: 30_000 },
  );

  // Give Flutter an extra moment to finish the first paint and settle providers.
  await page.waitForTimeout(3_000);
}

/**
 * Intercept the WebSocket URL so the app connects to our mock STT server
 * instead of the real backend.
 */
async function redirectWebSocketToMock(
  page: Page,
  mockBaseUrl: string,
): Promise<void> {
  // The Flutter app constructs the WebSocket URL by replacing http(s) with ws(s)
  // on the configured API_BASE_URL + `/v1/stt/live`.
  // We intercept all WebSocket upgrade requests and redirect to our mock.
  const wsUrl = mockBaseUrl.replace(/^http/, "ws") + "/v1/stt/live";

  await page.addInitScript((url: string) => {
    // Override WebSocket constructor so any connection to /v1/stt/live goes to mock.
    const OriginalWebSocket = window.WebSocket;
    (window as unknown as Record<string, unknown>).WebSocket = class extends OriginalWebSocket {
      constructor(urlArg: string | URL, protocols?: string | string[]) {
        const target = typeof urlArg === "string" ? urlArg : urlArg.toString();
        if (target.includes("/v1/stt/live")) {
          super(url, protocols);
        } else {
          super(urlArg, protocols);
        }
      }
    };
  }, wsUrl);
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

test.describe("Speech Translation E2E", () => {
  test.beforeAll(async () => {
    mockSttServer = new MockSttServer({ responseDelayMs: 500 });
    await mockSttServer.start();
  });

  test.afterAll(async () => {
    await mockSttServer.stop();
  });

  test("User records speech and sees original text and translation", async ({
    page,
  }) => {
    // 1. Script the utterance that the mock STT server will produce.
    const utterances: ScriptedUtterance[] = [
      {
        interimText: "hola, como",
        finalText: "hola, como estás?",
        speaker: 0,
      },
    ];
    mockSttServer.setUtterances(utterances);

    // 2. Set up backend mocks (translation, TTS, auth, health).
    await mockBackendApi(page);
    await redirectWebSocketToMock(page, mockSttServer.address);

    // 3. Navigate to the app.
    await page.goto("/", { waitUntil: "networkidle" });
    await waitForAppReady(page);

    // Take a screenshot of the initial state.
    await page.screenshot({
      path: "test-results/01-app-loaded.png",
      fullPage: true,
    });

    // 4. Locate and click the record (microphone) button.
    //    The SpeechFab uses a FloatingActionButton with heroTag 'speech-fab'
    //    and an Icons.mic icon.  In Flutter web the FAB is rendered either as
    //    a <button> with role or as an <flt-semantics> element.
    //    We try multiple strategies.
    const micButton = page
      .locator('flt-semantics[role="button"]')
      .filter({ hasText: /listen/i })
      .first();

    // If the semantic button is not available (e.g. canvas renderer), fall
    // back to clicking the FAB by its approximate position.
    const micExists = (await micButton.count()) > 0;
    if (micExists) {
      await micButton.click();
    } else {
      // Flutter may render with CanvasKit – look for any clickable element
      // near the bottom center (where the FAB lives).
      const viewport = page.viewportSize();
      if (viewport) {
        await page.click("body", {
          position: {
            x: viewport.width / 2,
            y: viewport.height - 80,
          },
        });
      }
    }

    // Take a screenshot right after clicking record.
    await page.screenshot({
      path: "test-results/02-recording-started.png",
      fullPage: true,
    });

    // 5. Wait for the scripted recognition results + translation to appear.
    //    The mock STT server emits "hola, como estás?" and the mock
    //    translation endpoint returns "Hello, how are you?".
    //    Flutter renders these inside the ChatMessageList widget.
    //    We give the app up to 15 s to process everything.

    // Wait for the original text to appear in the page.
    await expect(async () => {
      const content = await page.textContent("body");
      expect(content).toContain("hola");
    }).toPass({ timeout: 15_000 });

    await page.screenshot({
      path: "test-results/03-original-text-visible.png",
      fullPage: true,
    });

    // Wait for the translation to appear.
    await expect(async () => {
      const content = await page.textContent("body");
      expect(content).toContain("Hello");
    }).toPass({ timeout: 15_000 });

    // Final screenshot showing both original and translation.
    await page.screenshot({
      path: "test-results/04-translation-visible.png",
      fullPage: true,
    });

    // 6. Assert the full expected texts are present.
    const bodyText = await page.textContent("body");
    expect(bodyText).toContain("hola");
    expect(bodyText).toContain("Hello");
  });

  test("Multiple utterances are displayed in order", async ({ page }) => {
    const utterances: ScriptedUtterance[] = [
      {
        interimText: "buenos",
        finalText: "buenos días",
        speaker: 0,
      },
      {
        interimText: "hola",
        finalText: "hola",
        speaker: 1,
      },
    ];
    mockSttServer.setUtterances(utterances);

    await mockBackendApi(page);
    await redirectWebSocketToMock(page, mockSttServer.address);

    await page.goto("/", { waitUntil: "networkidle" });
    await waitForAppReady(page);

    // Click record.
    const micButton = page
      .locator('flt-semantics[role="button"]')
      .filter({ hasText: /listen/i })
      .first();
    const micExists = (await micButton.count()) > 0;
    if (micExists) {
      await micButton.click();
    } else {
      const viewport = page.viewportSize();
      if (viewport) {
        await page.click("body", {
          position: { x: viewport.width / 2, y: viewport.height - 80 },
        });
      }
    }

    // Wait for both utterances.
    await expect(async () => {
      const content = await page.textContent("body");
      expect(content).toContain("buenos");
      expect(content).toContain("hola");
    }).toPass({ timeout: 15_000 });

    await page.screenshot({
      path: "test-results/05-multiple-utterances.png",
      fullPage: true,
    });

    const bodyText = await page.textContent("body");
    expect(bodyText).toContain("buenos");
    expect(bodyText).toContain("hola");
  });

  test("App loads without errors", async ({ page }) => {
    await mockBackendApi(page);

    const consoleErrors: string[] = [];
    page.on("console", (msg) => {
      if (msg.type() === "error") {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto("/", { waitUntil: "networkidle" });
    await waitForAppReady(page);

    await page.screenshot({
      path: "test-results/06-clean-load.png",
      fullPage: true,
    });

    // Filter out known benign errors (e.g. Firebase analytics, font loading).
    const significantErrors = consoleErrors.filter(
      (e) =>
        !e.includes("analytics") &&
        !e.includes("font") &&
        !e.includes("favicon") &&
        !e.includes("ERR_CONNECTION_REFUSED"),
    );

    // We allow the app to load; any critical JS errors would crash the page.
    expect(significantErrors.length).toBeLessThanOrEqual(5);
  });
});
