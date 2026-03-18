# Translation Intelligence

This Flutter app captures speech locally, uses Deepgram for live recognition,
and now sends translation and text-to-speech requests through a Dart backend.
The backend keeps Google Cloud and Deepgram TTS credentials outside the app
binary and protects its endpoints with Firebase Anonymous Auth.

## Requirements

* Flutter SDK
* Flutter SDK
* Dart SDK
* A Firebase project with Anonymous Auth enabled
* A Google Cloud service account with Translation and Text-to-Speech access
* A Deepgram API key for speech recognition and Deepgram TTS

## Setup & Run

Configure the Flutter app with a `.env` file:

```bash
API_BASE_URL=https://your-api.example.com
```

Run the app:

```bash
flutter pub get
flutter run
```

Firebase client configuration should be generated with FlutterFire and committed
via files like `lib/firebase_options.dart` and `android/app/google-services.json`.

Configure the backend with environment variables:

```bash
export FIREBASE_PROJECT_ID=your_project_id
export FIREBASE_WEB_API_KEY=your_firebase_web_api_key
export DEEPGRAM_API_KEY=your_deepgram_key
export GOOGLE_SERVICE_ACCOUNT_JSON_PATH=/absolute/path/to/service-account.json
export ALLOWED_ORIGINS=https://your-app.example.com,http://localhost:3000
export HTTP_RATE_LIMIT_PER_MINUTE=120
export WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE=30
```

Run the backend:

```bash
cd server
dart pub get
dart run bin/server.dart
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

1. Tap the microphone floating button to begin listening (the locale is
   fixed to `es-ES`).
2. Speak a phrase in Spanish; once the speech result is final you'll see an
   entry appear in the chat log.
3. A few moments later the English translation will appear beneath the
   original text and will be read back to you.
4. Use the controls in the bar above the footer (but fixed in place) to clear the conversation history or choose a speaker to right-align.
5. Tap the language icon in the app bar to pick a translation target; English is used by default.

## Notes

* The code is structured around `SpeechController`, which manages a
  Deepgram live stream, handles multi-speaker transcription, translation/tts
  network calls, and notifies widgets of updates.  Recognized messages are
  split by speaker and labeled accordingly in the UI.
* `ChatMessage` objects now hold both the original and translated text.
* Controls for clearing the chat and speaker alignment now live in a fixed bar
  immediately above the footer, keeping the footer focused on recording.
* A language selector in the app bar allows translating into any supported Nova‑3
  language; the default target is English (`en`).
* Phase 1 moves Google Translation, Google TTS, and Deepgram TTS behind the
  backend. Live Deepgram STT still runs directly from the app for now.
* The backend exposes `GET /v1/health`, `GET /v1/capabilities`,
  `POST /v1/translate`, and `POST /v1/tts`.
* The app authenticates to the backend with Firebase Anonymous Auth bearer
  tokens.

---
