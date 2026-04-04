# AGENTS.md

## 1. Project Overview
OmniaLingo is a cross-platform Flutter application with a companion Dart backend that turns live speech into translated, optionally spoken responses. The client captures audio, manages group-chat and two-way-chat conversation flows, and talks only to the backend for cloud translation, text-to-speech, suggestions, and live speech streaming. The backend is designed for Cloud Run deployment, keeps Google Cloud and Deepgram credentials out of the shipped app, and protects most endpoints with Firebase Anonymous Auth.

## 2. Tech Stack
- Flutter **3.41.4** in CI (`.github/workflows/ci.yml`)
- Dart SDK **3.11.0** for both app and server (`pubspec.yaml`, `server/pubspec.yaml`, `.github/workflows/ci.yml`)
- Flutter app package: `translation_intelligence` **0.1.3+41** (`pubspec.yaml`)
- Server package: `translation_intelligence_server` **0.1.0** (`server/pubspec.yaml`)
- State management: `provider` **6.1.5+1** (`pubspec.lock`)
- Firebase client SDKs: `firebase_auth` **6.3.0**, `firebase_core` **4.6.0** (`pubspec.lock`)
- Speech and media packages: `deepgram_speech_to_text` **4.1.0**, `record` **6.2.0**, `audioplayers` **6.6.0**, `flutter_tts` **4.2.5** (`pubspec.lock`)
- Dart backend HTTP stack: `shelf` **1.4.2**, `shelf_router` **1.1.4**, `shelf_web_socket` **3.0.0** (`server/pubspec.lock`)

## 3. Folder Structure
- `lib/`: Flutter app source
  - `controllers/`: app state and orchestration (`GroupController`, `TwoWayChatController`)
  - `services/`: backend client, auth session, speech pipeline, preferences, catalogs
  - `models/`: chat, speech, playback, and suggestion models
  - `widgets/`: UI for chat, controls, dialogs, and mode-specific screens
  - `theme/`: `HyperListenTheme` and `HyperLinguistTheme`
  - `l10n/`: generated and source localization assets
- `server/`: Dart backend for auth, translation, TTS, suggestion, and live STT
  - `bin/`: server entrypoint
  - `lib/src/config/`: environment-driven configuration
  - `lib/src/http/`: routing, middleware, auth verification, logging, metrics, rate limiting
  - `lib/src/services/`: provider integrations for translation, TTS, STT, and suggestions
  - `test/`: backend tests
- `test/`: Flutter widget and service tests
- `docs/`: server API and deployment docs
- `tool/`: operational scripts for coverage, deploys, and Play uploads
- Platform folders: `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`
- Generated or config-heavy files to treat carefully: `lib/firebase_options.dart`, `android/app/google-services.json`, `google-services.json`, `.env.sample`, `.githooks/pre-commit`

## 4. Core Behaviors
- The app is backend-first: production translation, TTS, suggestions, and live STT are expected to go through `BackendApiClient`, not direct bundled cloud credentials.
- `GroupController` is the main state machine for the group-chat flow; preserve its `ChangeNotifier` pattern and listener updates when changing speech/session behavior.
- `TwoWayChatController` owns the split-screen two-way conversation flow; keep group-chat and two-way logic separate.
- The backend uses Firebase Anonymous Auth tokens for most HTTP endpoints; `/v1/stt/live` is the exception and expects auth in the first WebSocket message instead of a bearer header.
- Server responses should keep using the established middleware stack for request IDs, structured JSON logging, error mapping, CORS, and rate limiting.
- Server configuration is environment-driven. `GOOGLE_SERVICE_ACCOUNT_JSON` or `GOOGLE_SERVICE_ACCOUNT_JSON_PATH`, `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_API_KEY`, and `DEEPGRAM_API_KEY` are required for full backend startup.
- The repo includes a versioned Git pre-commit hook that auto-bumps the `+build` suffix in `pubspec.yaml`; do not be surprised if local commits modify that file.

## 5. Build & Test Commands
- App dependencies: `flutter pub get`
- Server dependencies: `cd server && dart pub get`
- Run the backend locally: `cd server && dart run bin/server.dart`
- Run the Flutter app: `flutter run`
- Analyze the Flutter app: `flutter analyze`
- Run Flutter tests: `flutter test`
- Run coverage: `dart run tool/test_with_coverage.dart`
- Run backend tests: `cd server && dart test`
- Deploy helper scripts already in-repo:
  - `dart run tool/upload_play_release.dart`
  - `./tool/deploy_server_cloud_run.sh`

## 6. Guardrails
- Never commit real credentials or replace placeholder/service-account files with live secrets.
- Never hand-edit generated Firebase client config unless the task is explicitly about regenerating platform config.
- Never bypass `BackendApiClient` by reintroducing direct client-side cloud credential usage for production flows.
- Never remove or weaken backend auth, rate limiting, structured logging, or request-context middleware without an explicit requirement.
- Never change `server/Dockerfile`, `server/cloudbuild.yaml`, or `.github/workflows/ci.yml` casually; those files directly affect deployability and CI.
- Never assume WebSocket auth matches HTTP auth; preserve the `/v1/stt/live` first-message token contract.
- Never edit `.github/agents` files.
