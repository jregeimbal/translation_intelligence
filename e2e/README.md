# E2E Tests – OmniaLingo

End-to-end tests for the OmniaLingo Flutter web app using [Playwright](https://playwright.dev/).

## Prerequisites

| Tool | Version |
|------|---------|
| Node.js | ≥ 18 |
| Flutter | 3.41+ |

Install dependencies from the repository root:

```bash
npm install
npx playwright install chromium
```

## Running the tests

### 1. Build the Flutter web app

The tests run against a local HTTP server that serves the Flutter web build.

```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

### 2. Serve the web build

Use any static file server. For example:

```bash
npx serve build/web -l 8080
# Or: python3 -m http.server 8080 --directory build/web
```

### 3. Run the E2E tests

```bash
npm run e2e            # headless
npm run e2e:headed     # with visible browser window
```

## What the tests do

| Test | Description |
|------|-------------|
| **User records speech and sees original text and translation** | Clicks the record button, mock STT emits "hola, como estás?", the mock translate endpoint returns "Hello, how are you?". Asserts both texts appear in the chat. |
| **Multiple utterances are displayed in order** | Scripts two utterances from different speakers and verifies both appear. |
| **App loads without errors** | Verifies the app loads to a usable state without critical JS errors. |

## Architecture

- **`fixtures/backend-mock.ts`** – Route-level mocks for all backend HTTP endpoints (translate, TTS, health, auth).
- **`fixtures/mock-stt-server.ts`** – A tiny WebSocket server that speaks the `/v1/stt/live` protocol and emits scripted recognition results.
- **`reporters/screenshot-reporter.ts`** – Custom Playwright reporter that prints a pass/fail summary with links to every captured screenshot.
- **`tests/speech-translation.spec.ts`** – The test scenarios.

## Test output

After a run the following artifacts are produced:

| Path | Description |
|------|-------------|
| `e2e/test-results/*.png` | Screenshots captured at key points |
| `e2e/test-results/results.json` | Machine-readable Playwright JSON results |
| `e2e/test-results/e2e-summary.json` | Simplified summary with pass/fail, failures list, and screenshot paths |

The summary is also printed to stdout by the custom reporter.

## Customisation

Edit `e2e/playwright.config.ts` to:

- Change the `baseURL` if your dev server runs on a different port.
- Add more browser projects (Firefox, WebKit).
- Adjust timeouts, retries, or screenshot/video capture modes.
