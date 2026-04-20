# OmniaLingo: AI-Powered Translator

This Flutter app captures speech locally, uses Deepgram for live recognition,
and now sends translation and text-to-speech requests through a Dart backend.
The backend keeps Google Cloud and Deepgram TTS credentials outside the app
binary and protects its endpoints with Firebase Anonymous Auth.

The app currently ships with two conversation modes:

- Group chat: diarized live transcription, translated chat bubbles, speaker
  labels, and target-language selection.
- Two-way chat: split-screen back-and-forth translation between two speakers
  with independent language selection for each side.

Server docs:

- API reference: `docs/server-api.md`
- Deployment and setup: `docs/server-deployment.md`

Deployment helpers:

- Cloud Build config: `server/cloudbuild.yaml`
- Cloud Run deploy helper: `tool/deploy_server_cloud_run.sh`
- Google Play upload helper: `dart run tool/upload_play_release.dart`

## Requirements

* Flutter SDK
* Dart SDK
* A Firebase project with Anonymous Auth enabled
* FlutterFire-generated Firebase client config for the same Firebase project
* A Google Cloud service account with Translation and Text-to-Speech access
* A Deepgram API key for speech recognition and Deepgram TTS

## Setup & Run

### 1. Configure the Flutter app

Create a `.env` file in the repository root:

```bash
API_BASE_URL=https://your-api.example.com
APP_THEME=HyperListenTheme
```

`API_BASE_URL` is required. `APP_THEME` is optional and defaults to
`HyperListenTheme`.

Generate and commit the Firebase client configuration for the same Firebase
project used by the backend:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- platform equivalents such as the iOS/macOS Firebase config files when used

### 2. Configure the backend

Minimum required environment variables:

```bash
export FIREBASE_PROJECT_ID=your_project_id
export FIREBASE_WEB_API_KEY=your_firebase_web_api_key
export DEEPGRAM_API_KEY=your_deepgram_key
export GOOGLE_SERVICE_ACCOUNT_JSON_PATH=/absolute/path/to/service-account.json
```

Optional server settings:

```bash
export ALLOWED_ORIGINS=https://your-app.example.com,http://localhost:3000
export HTTP_RATE_LIMIT_PER_MINUTE=120
export WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE=30
```

The server also supports inline Google credentials via
`GOOGLE_SERVICE_ACCOUNT_JSON` instead of
`GOOGLE_SERVICE_ACCOUNT_JSON_PATH`.

The backend must use the same Firebase project as the client app. In practice,
that means:

- `FIREBASE_PROJECT_ID` must match the client Firebase project.
- `FIREBASE_WEB_API_KEY` must be the matching Web API key for that same
  project.

If those values do not match the client app configuration, backend auth and
live STT session startup will fail.

### 3. Run the backend

```bash
cd server
dart pub get
dart run bin/server.dart
```

### 4. Run the app

```bash
flutter pub get
flutter run
```

### 5. Enable local build-number bumps on commit

This repository includes a versioned Git `pre-commit` hook in `.githooks/` that
increments the `+build` suffix in `pubspec.yaml` before each local commit and
re-stages the file automatically.

Enable it once per clone:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

To skip the bump for a one-off commit:

```bash
SKIP_PUBSPEC_BUILD_BUMP=1 git commit ...
```

See `docs/server-deployment.md` for a fuller local setup and Cloud Run
deployment guide.

### 6. Upload an Android release to Google Play

Set a Play Console service-account credential that has access to the app in the
Google Play Console:

```bash
export GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH=/absolute/path/to/google-play-service-account.json
```

Then run:

```bash
dart run tool/upload_play_release.dart
```

By default this builds the release app bundle, uploads it to the `internal`
track, and commits the edit with release status `completed`.

Useful overrides:

```bash
PLAY_TRACK=production PLAY_RELEASE_STATUS=draft dart run tool/upload_play_release.dart
dart run tool/upload_play_release.dart --skip-build --aab-path=path/to/app-release.aab
```

## Testing with coverage

Use the project runner below to always execute tests with coverage and print a
single total line-coverage percentage in the terminal:

```bash
dart run tool/test_with_coverage.dart
```

This command runs `flutter test --coverage`, then reads `coverage/lcov.info`
and prints output in this format:

```text
Total coverage: 87.42% (312/357 lines)
```

## Integration tests (Patrol)

The `integration_test/` directory contains end-to-end tests built with
[Patrol](https://patrol.leancode.co). They exercise the full app UI using
fake controllers that replace real microphone, network, and Firebase access,
so no backend or cloud credentials are needed.

### Prerequisites

Install the Patrol CLI:

```bash
flutter pub global activate patrol_cli
```

Ensure an Android emulator is running (or a physical device is connected):

```bash
flutter emulators --launch <emulator_name>
```

On Linux CI runners, enable KVM for hardware acceleration before launching the
emulator.

### Running

Run all integration tests on the connected device:

```bash
export ANDROID_HOME=~/Library/Android/sdk   # macOS default; adjust for your OS
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$HOME/.pub-cache/bin:$PATH"
patrol test
```

Target a specific device:

```bash
patrol test --device emulator-5554
```

### What the tests cover

| Scenario | Description |
|---|---|
| Record → translate | Tap mic, inject speech, verify original and translated text appear in a chat bubble |
| Toggle listening | Tap mic to start listening, tap again to stop, verify controller state transitions |
| Multiple speakers | Inject messages from different speakers and verify separate chat rows |
| First-launch walkthrough | Verify the dialog appears on first launch, page navigation (Next/Back), Skip and Close dismissals, page dot indicators, and that it is skipped when already completed |

### Project structure

| File | Purpose |
|---|---|
| `integration_test/e2e_test.dart` | Main test file with record/translate, toggle, and multi-speaker scenarios |
| `integration_test/walkthrough_test.dart` | First-launch walkthrough dialog e2e tests |
| `integration_test/e2e_test_app.dart` | Test app wrapper that injects fake controllers (record/translate tests) |
| `integration_test/e2e_test_report.dart` | Step-level pass/fail reporter with screenshot support |
| `integration_test/screenshot_helper.dart` | Screenshot capture helper (gracefully skips when unsupported) |
| `integration_test/fake_group_chat_controller.dart` | Fake `GroupChatController` for test isolation |
| `integration_test/fake_two_way_chat_controller.dart` | Fake `TwoWayChatController` for test isolation |
| `android/app/src/androidTest/` | Android instrumentation runner for Patrol |
| `test_driver/integration_test.dart` | Standard Flutter integration test driver |

### Configuration

Patrol reads its configuration from the `patrol:` block in `pubspec.yaml`:

```yaml
patrol:
  app_name: OmniaLingo
  test_directory: integration_test
  android:
    package_name: com.jax3.omnialingo
  ios:
    bundle_id: com.jax3.omnialingo
```

If backend initialization fails, the app shows a startup error instead of
shipping or asking for cloud credentials locally.

The backend is Cloud Run-hardened with structured JSON logging, request IDs,
Cloud Trace correlation from `x-cloud-trace-context`, per-instance rate limits,
and websocket session metrics for `/v1/stt/live`.

The production app now routes cloud STT, translation, and TTS through the
backend. Legacy on-device/test compatibility paths may still exist in code, but
the shipped app no longer depends on bundled Deepgram or Google cloud secrets.

## Theme selection

Set `APP_THEME` in your `.env` file to choose the app theme:

- `APP_THEME=HyperListenTheme` (default)
- `APP_THEME=HyperLinguistTheme`

If omitted, the app uses `HyperListenTheme`.

## Usage

### Group chat mode

1. Open the Group section from the bottom navigation bar.
2. Use the language bar above the transcript to choose the recognition source
  language and translation target language. Deepgram source recognition
  defaults to `multi`, and the translation target defaults to English (`en`).
3. Tap the microphone button in the footer to begin listening.
4. Speak naturally. Partial speech appears immediately, and final results are
  grouped into chat bubbles.
5. When translation is available, it appears beneath the original text and can
  be spoken through the configured TTS provider.
6. Use the controls above the footer to clear the conversation or choose which
  speaker should be right-aligned.

### Two-way chat mode

1. Open the Two-way section from the bottom navigation bar.
2. Choose the primary and guest languages from the dropdowns shown in each
  speaker panel before starting a conversation.
3. Tap a panel to listen for that speaker. Final speech is translated into the
  opposite panel's language and played back.
4. Use the center refresh button to clear the two-way conversation history.

## Notes

* The code is structured around `GroupChatController`, which manages live
  recognition, translation, and TTS flows and notifies widgets of updates.
  Recognized messages are split by speaker and labeled accordingly in the UI.
* The app also includes `TwoWayChatController`, which powers the split-panel
  two-way translation experience.
* `ChatMessage` objects now hold both the original and translated text.
* Controls for clearing the chat and speaker alignment now live in a fixed bar
  immediately above the footer, keeping the footer focused on recording.
* Provider settings allow selecting STT provider, translation provider, output
  provider, Deepgram model/language, speech-to-text locale, listening device,
  playback device, and the target translation language.
* The group chat language bar allows translating into any supported app target
  language; the default target is English (`en`).
* The production app now routes cloud STT, translation, and TTS through the
  backend.
* The backend exposes `GET /v1/health`, `GET /v1/capabilities`,
  `POST /v1/translate`, `POST /v1/tts`, and `WS /v1/stt/live`.
* The app authenticates to the backend with Firebase Anonymous Auth bearer
  tokens. See `docs/server-api.md` for request/response details.

---
