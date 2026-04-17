import { type Page, type Route } from "@playwright/test";

/**
 * Intercepts Flutter web app network requests to the backend and responds with
 * canned data.  This lets the E2E tests run without a live server.
 */

/** Set up route-level mocks for all backend API endpoints. */
export async function mockBackendApi(page: Page): Promise<void> {
  // Health endpoint – always healthy.
  await page.route("**/v1/health", (route: Route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ status: "ok" }),
    }),
  );

  // Firebase Auth – mock token exchange (identitytoolkit).
  await page.route("**/identitytoolkit/**", (route: Route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        idToken: "mock-id-token",
        refreshToken: "mock-refresh-token",
        expiresIn: "3600",
        localId: "mock-uid",
      }),
    }),
  );

  // Firebase Auth – mock secure token refresh.
  await page.route("**/securetoken/**", (route: Route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        id_token: "mock-id-token",
        refresh_token: "mock-refresh-token",
        expires_in: "3600",
      }),
    }),
  );

  // Firebase project config.
  await page.route("**/firebase/**", async (route: Route) => {
    const url = route.request().url();
    // Let the app load its own firebase config JS; only intercept API calls.
    if (url.includes("firebase-") || url.includes("firebase/")) {
      return route.fallback();
    }
    return route.fulfill({ status: 200, body: "{}" });
  });

  // Translation endpoint.
  await page.route("**/v1/translate", (route: Route) => {
    const postData = route.request().postDataJSON() as {
      text?: string;
      targetLanguage?: string;
    } | null;
    const text = postData?.text ?? "";
    const translatedText = fakeTranslation(text);
    return route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ translatedText }),
    });
  });

  // TTS endpoint – return a tiny valid WAV (silence).
  await page.route("**/v1/tts", (route: Route) =>
    route.fulfill({
      status: 200,
      contentType: "audio/wav",
      body: Buffer.from(silentWav()),
    }),
  );

  // Suggestions endpoint.
  await page.route("**/v1/suggest", (route: Route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        originalText: "Estoy bien, gracias.",
        translatedText: "I am fine, thanks.",
      }),
    }),
  );

  // STT recognition models list.
  await page.route("**/v1/stt/models", (route: Route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        models: [
          { id: "nova-3", name: "Nova 3" },
        ],
      }),
    }),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** A deterministic fake translation map for test assertions. */
const TRANSLATION_MAP: Record<string, string> = {
  "hola, como estás?": "Hello, how are you?",
  "hola, ¿cómo estás?": "Hello, how are you?",
  "hola como estas": "Hello, how are you?",
  "hola": "Hello",
  "buenos días": "Good morning",
};

function fakeTranslation(text: string): string {
  const normalised = text.toLowerCase().trim();
  for (const [key, value] of Object.entries(TRANSLATION_MAP)) {
    if (normalised === key.toLowerCase()) {
      return value;
    }
  }
  // Fall back to returning the input prefixed – still verifiable.
  return `[translated] ${text}`;
}

/** Generates a minimal valid WAV header for 0.1 s of silence at 16 kHz mono. */
function silentWav(): Uint8Array {
  const sampleRate = 16_000;
  const bitsPerSample = 16;
  const numChannels = 1;
  const durationSec = 0.1;
  const numSamples = Math.floor(sampleRate * durationSec);
  const dataSize = numSamples * numChannels * (bitsPerSample / 8);
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  const writeString = (offset: number, str: string) => {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  };

  writeString(0, "RIFF");
  view.setUint32(4, 36 + dataSize, true);
  writeString(8, "WAVE");
  writeString(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * numChannels * (bitsPerSample / 8), true);
  view.setUint16(32, numChannels * (bitsPerSample / 8), true);
  view.setUint16(34, bitsPerSample, true);
  writeString(36, "data");
  view.setUint32(40, dataSize, true);

  return new Uint8Array(buffer);
}
