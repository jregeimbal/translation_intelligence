# Translation Intelligence

This Flutter demo streams Spanish speech to Deepgram for recognition,
displays the transcript, translates each message to English using the Google
Cloud Translation API, and plays back the English translation with the Google
Cloud Text‑to‑Speech API.  Translations are rendered under the original chat
message and also spoken aloud for the user.

## Requirements

* Flutter SDK
* A Google Cloud API key with the **Translation API** and **Text‑to‑Speech API**
enabled
* A Deepgram API key (set `DEEPGRAM_API_KEY`) for speech recognition

## Setup & Run

Provide the API keys when launching the app (dart-define is used
here):

```bash
flutter pub get
flutter run \
  --dart-define=GOOGLE_API_KEY=your_key_here \
  --dart-define=DEEPGRAM_API_KEY=your_key_here
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

If the key is missing or invalid the app continues to recognize speech but
skips the translation/tts steps.

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
* API interactions are implemented with plain HTTP calls for simplicity;
  you may substitute the official Google Cloud client libraries if desired.

---
