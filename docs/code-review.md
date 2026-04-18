# OmniaLingo Code Review

**Date:** 2026-04-16
**Scope:** Full codebase review — Flutter app + Dart backend server

---

## Critical Issues

### 1. Service Account JSON Committed to Repository
`server/omnia-lingo-google-cloud-service-account.json` contains a real private key and is **not** in `.gitignore`. This is the highest-priority issue — anyone with repo access can extract credentials. Add it to `.gitignore` immediately and rotate the key.

### 2. `main.dart` is a God Widget (1356 lines)
`lib/main.dart` contains `DebouncedMessageDispatcher`, `_SuggestedResponsePanel`, ~80 state variables, initialization logic, provider settings navigation, theme management, and the entire home page build. This file should be split into at least 4-5 focused files:
- `debounced_message_dispatcher.dart` (extract the class)
- `suggested_response_panel.dart` (extract the widget)
- A settings/navigation coordinator
- The home page layout

### 3. State Duplication Between Home Page and Controllers
`_MyHomePageState` maintains parallel copies of `_sttProvider`, `_translationProvider`, `_outputProvider`, `_deepgramRecognitionModel`, `_deepgramRecognitionLanguage`, device lists, and language settings — all of which also exist in the controllers. Changes must be synchronized across multiple methods (`_setSttProvider`, `_setTranslationProvider`, etc.). Consider injecting a centralized `AppSettings` service that both the home page and controllers read from.

---

## High Priority

### 4. Silent Error Swallowing (24 instances)
The codebase has **24 occurrences** of `catch (_) {}` or empty catch blocks across the app. This makes debugging nearly impossible when things fail silently in production. At minimum, log to a diagnostic channel or use `FlutterError.onError` / a logging service:
- `lib/controllers/speech_controller.dart`: lines 334, 804, 817, 820, 874
- `lib/services/backend_api_client.dart`: lines 55, 105, 164, 224, 594, 598
- `lib/services/speech_pipeline.dart`: lines 412, 439, 449, 492
- `lib/controllers/two_way_chat_controller.dart`: lines 220, 228, 231, 345, 371

### 5. Server: No Timeout on External HTTP Calls
All `client.post()` calls in the service layer (`translation_service.dart`, `tts_service.dart`, `suggestion_service.dart`) have no explicit timeout. Hanging external APIs will block requests indefinitely. Add a 10-30 second `timeout()` to every external call.

### 6. Server: Duplicate `ApiRouter` Instantiation
`api_server.dart` constructs two independent `ApiRouter` instances sharing the same service objects. Use a single shared instance for both HTTP and WebSocket routing paths.

### 7. Server: Race-Prone `_pendingWebSocketTraceContext`
A mutable instance field is captured by closures in `buildHandler()` — concurrent WebSocket upgrades will overwrite each other's trace context. Use a per-request mechanism instead (e.g., `Completer<String?>`).

### 8. Server: Duplicate `firstOrNull` Extension
The `firstOrNull` extension is defined in both `translation_service.dart:55` and `suggestion_service.dart:212`. Extract to a shared utility file.

---

## Medium Priority

### 9. Missing Lint Rules
`analysis_options.yaml` uses only default `flutter_lints`. The server has better coverage with `package:lints/recommended.yaml` but the app does not. Consider adding to the app's `analysis_options.yaml`:
```yaml
linter:
  rules:
    prefer_single_quotes: true
    avoid_positional_boolean_parameters: true
    prefer_final_fields: true
    sort_constructors_first: true
    sort_unnamed_constructors_first: true
```

### 10. Test Coverage Gaps
- **No tests for `SpeechController`** (1247 lines) — the core state machine
- **No tests for `main.dart`** (1356 lines) — the largest file
- **No tests for `TwoWayChatController`** recognition/translation flow
- **No widget tests** for `SpeechFab`, `GroupLanguageBar`, `TwoWayChatView`
- **No integration tests** — only unit/widget tests exist

### 11. `SpeechController` is 1247 Lines
This single state machine handles audio recording, STT sessions, message queuing, final-result grouping, translation/TTS pipeline, suggested responses, and device management. Consider extracting:
- Message queuing/grouping logic into a `MessageQueue` class
- Translation/TTS orchestration into a `TranslationPipeline` service
- Device management into its own controller

### 12. Chat Message Widget is 891 Lines
`lib/widgets/chat_message.dart` handles auto-scroll, speaker chips, shimmer gradients (custom `CustomPainter`), grouped inline rendering, and hover tooltips. Extract the gradient painter and scroll logic into separate files.

### 13. ProviderSettingsDialog is 735 Lines
This single dialog manages STT provider selection, Deepgram model/language cascading, Google locale, translation/TTS providers, audio devices, and theme mode. Split into sub-widgets:
- `SttProviderSelector`
- `DeepgramModelSelector`
- `AudioDeviceSelector`
- `ThemeModeSelector`

### 14. Server: No `/metrics` Endpoint
`MetricsRegistry` accumulates counters but has no HTTP endpoint to expose them. Add a `/v1/metrics` endpoint for Cloud Run observability and monitoring dashboards.

### 15. Server: No Retry Logic
All external service calls are fire-and-forget with no retry on transient errors (503, 429). Add exponential backoff retries for Google Cloud and Deepgram API calls.

### 16. `LiveRecognitionService` Has No Implementations
The abstract interface exists in the lib/ but has no concrete implementation shipped. Either implement it or remove it to avoid confusion.

### 17. `SpeechTranslationProvider` Enum Has Only One Value
The enum pattern suggests future extensibility but currently adds indirection without benefit. Consider using a simple `String` or constant until a second provider is needed.

---

## Low Priority / Nice-to-Have

### 18. Static `_nextMessageId` Counter
A global mutable static counter in `ChatMessage` that never resets. Theoretically could overflow over extremely long sessions — use a UUID or incrementing `int` with periodic reset.

### 19. `_looksLikeJson` Heuristic is Fragile
The server's logging config checks if a message starts with `{` and ends with `}` to detect structured JSON. This fails for user messages like `"{hello}"`. Use a proper `try { jsonDecode() }` approach.

### 20. No Input Length Validation on Server
`TranslateRequest`, `TtsRequest`, and other models validate non-empty but not maximum length. Very long texts could cause API quota issues or response size problems.

### 21. `WidgetsFlutterBinding.ensureInitialized()` Called Mid-Flight
Called inside `SpeechController.startListening()` and `TwoWayChatController.startListening()`. This should only ever be called once at app startup, not inside methods that can be invoked later.

### 22. No Tests for WebSocket Auth Flow
The server has no tests for failed authentication, expired tokens, or malformed tokens in the WebSocket path.

### 23. No `.gitignore` for Server Directory
The server directory has no `.gitignore`, relying on the root one. The service account JSON file is not excluded by the root `.gitignore`. Add `server/.gitignore` with:
```
*.json
!pubspec.yaml
!pubspec.lock
```

---

## Summary by Category

| Category | Issues Found | Priority |
|----------|-------------|----------|
| Security | 2 (service account committed, no server .gitignore) | Critical |
| Architecture | 4 (god widget, state duplication, large controllers, no settings service) | High |
| Error Handling | 1 (24 silent catch blocks) | High |
| Server Reliability | 3 (no timeouts, no retries, race condition) | High |
| Code Quality | 4 (duplicate code, large files, no lint rules) | Medium |
| Testing | 1 (significant coverage gaps) | Medium |
| Observability | 2 (no metrics endpoint, no structured logging for WS) | Medium |
| Edge Cases | 4 (static counter, fragile JSON detection, no input validation, binding init) | Low |
