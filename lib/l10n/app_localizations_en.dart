// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OmniaLingo';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsQuickSettingsTitle => 'Essentials';

  @override
  String get settingsQuickSettingsDescription => 'Choose the language OmniaLingo listens for, the language it translates into, and the microphone it should use.';

  @override
  String get settingsAdvancedToggle => 'Show advanced options';

  @override
  String get settingsAdvancedDescription => 'Only change recognition engines, translation engines, or voice output if you need to troubleshoot or fine-tune behavior.';

  @override
  String get sourceLanguageHint => 'This is the language OmniaLingo listens for.';

  @override
  String get targetLanguageHint => 'This is the language OmniaLingo translates into in Group mode.';

  @override
  String get listeningDeviceHint => 'Leave this on Auto unless you want to force a specific microphone.';

  @override
  String get deepgramModelHint => 'Different Deepgram models support different source languages.';

  @override
  String settingsModelAdjustedLanguage(Object language) {
    return 'This model does not support your previous source language, so OmniaLingo switched to $language.';
  }

  @override
  String get tabProviders => 'Voice Recognition';

  @override
  String get tabAudio => 'Audio Devices';

  @override
  String get tabDisplay => 'Appearance';

  @override
  String get speechToTextLabel => 'Speech to Text';

  @override
  String get deepgramModelLabel => 'Deepgram Model';

  @override
  String get deepgramLanguageLabel => 'Deepgram Language';

  @override
  String get googleLocaleLabel => 'Google Locale';

  @override
  String get translationLabel => 'Translation';

  @override
  String get textToSpeechLabel => 'Text to Speech';

  @override
  String get listeningDeviceLabel => 'Listening Device';

  @override
  String get audioInputSelectionHint => 'Audio input selection is available when Speech to Text is set to Deepgram.';

  @override
  String get noInputDevicesDetected => 'No input devices detected';

  @override
  String get autoLabel => 'Auto';

  @override
  String currentDetails(Object details) {
    return 'Current: $details';
  }

  @override
  String autoWithDetails(Object details) {
    return 'Auto ($details)';
  }

  @override
  String get playbackDeviceLabel => 'Playback Device';

  @override
  String get iosPlaybackRoutesHint => 'Some iOS playback routes are managed by the system and may not always switch programmatically.';

  @override
  String get playbackUnavailableHint => 'Playback device details unavailable on this platform.';

  @override
  String get displayLabel => 'Display';

  @override
  String get themeModeLabel => 'Theme Mode';

  @override
  String get cancel => 'Cancel';

  @override
  String get languageSearchHint => 'Search languages';

  @override
  String get noMatchingLanguages => 'No matching languages';

  @override
  String get save => 'Save';

  @override
  String get multiAuto => 'Multilingual';

  @override
  String get multiAutoDetails => 'English, Spanish, French, German, Hindi, Russian, Portuguese, Japanese, Italian, and Dutch';

  @override
  String get debugAudioStream => 'Debug Audio Stream';

  @override
  String get debugSection => 'Section';

  @override
  String get debugSectionGroup => 'Group';

  @override
  String get debugSectionTwoWay => '2-way';

  @override
  String get debugListeningActive => 'Listening Active';

  @override
  String get yes => 'yes';

  @override
  String get no => 'no';

  @override
  String get notAvailableShort => 'n/a';

  @override
  String get debugSttProvider => 'STT Provider';

  @override
  String get debugSourceLanguage => 'Source Language';

  @override
  String get debugResolvedLanguageCode => 'Resolved Language Code';

  @override
  String get debugActiveSampleRate => 'Active Sample Rate';

  @override
  String sampleRateHertz(Object sampleRate) {
    return '$sampleRate Hz';
  }

  @override
  String get debugListeningDeviceId => 'Listening Device Id';

  @override
  String get autoDefault => 'auto/default';

  @override
  String get debugAmplitude => 'Amplitude (0-1)';

  @override
  String get debugSessionElapsed => 'Session Elapsed';

  @override
  String get debugSessionStartedAt => 'Session Started At';

  @override
  String get debugConfiguredSttProvider => 'Configured STT Provider';

  @override
  String get debugConfiguredDeepgramLanguage => 'Configured Deepgram Language';

  @override
  String get debugConfiguredGoogleLocale => 'Configured Google Locale';

  @override
  String get debugConfiguredSttLocale => 'Configured STT Locale';

  @override
  String get close => 'Close';

  @override
  String get unableToSwitchPlaybackDevice => 'Unable to switch playback device on this platform.';

  @override
  String get sourceLabel => 'Source';

  @override
  String get swapLanguagesTooltip => 'Swap source and target language';

  @override
  String get swapUnavailableMultiTooltip => 'Swap unavailable when source or target is multi';

  @override
  String get swapUnavailablePairTooltip => 'Swap unavailable for selected language pair';

  @override
  String get targetLabel => 'Target';

  @override
  String initializationFailed(Object error) {
    return 'Initialization failed: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get walkthroughWelcomeTitle => 'Welcome to OmniaLingo';

  @override
  String get walkthroughWelcomeBody => 'Here is a quick walkthrough of the essentials before your first conversation.';

  @override
  String get walkthroughDismiss => 'Dismiss walkthrough';

  @override
  String get walkthroughHelp => 'Help';

  @override
  String get walkthroughSkip => 'Skip';

  @override
  String get walkthroughBack => 'Back';

  @override
  String get walkthroughNext => 'Next';

  @override
  String get walkthroughGetStarted => 'Get Started';

  @override
  String get walkthroughModesTitle => 'Choose the right mode';

  @override
  String get walkthroughModesBody => 'Use Group when one speaker or a group is talking into a shared microphone and everyone wants live translated captions. Use 2-way when two people are handing the device back and forth for a conversation.';

  @override
  String get walkthroughLanguagesTitle => 'Source and target languages';

  @override
  String get walkthroughLanguagesBody => 'Source is the language OmniaLingo listens for. Target is the language it translates into. In 2-way mode, each side chooses its own language so each person can follow the conversation in the language they prefer.';

  @override
  String get walkthroughMicrophoneTitle => 'Microphone and permissions';

  @override
  String get walkthroughMicrophoneBody => 'Tap the microphone button to start or stop listening. The first time you use it, allow microphone access when your device asks. If access was denied earlier, re-enable the microphone for OmniaLingo in your device settings.';

  @override
  String get walkthroughPrimarySpeakerTitle => 'What Primary Speaker means';

  @override
  String get walkthroughPrimarySpeakerBody => 'In Group mode, Primary Speaker highlights one speaker\'s messages and aligns them so that person\'s side is easier to follow. Choose it when you want one participant\'s translated text to stand out.';

  @override
  String get translationAssistant => 'AI-Powered Translator';

  @override
  String get groupLabel => 'Group';

  @override
  String get twoWayLabel => '2-way';

  @override
  String get listeningStatus => 'Listening...';

  @override
  String get tapMicToStartListening => 'Tap the mic to start listening...';

  @override
  String get speechNotAvailable => 'Speech not available';

  @override
  String speakerLabel(Object number) {
    return 'Speaker $number';
  }

  @override
  String get hideOriginal => 'Hide original';

  @override
  String get showOriginal => 'Show original';

  @override
  String get replayTranslation => 'Replay translation';

  @override
  String get jumpToLatest => 'Jump to latest';

  @override
  String get suggestedResponseTitle => 'Suggested response';

  @override
  String suggestedResponseOriginalLabel(Object language) {
    return 'In $language';
  }

  @override
  String suggestedResponseTranslatedLabel(Object language) {
    return 'Translated for you ($language)';
  }

  @override
  String get guestLabel => 'Guest';

  @override
  String get primaryLabel => 'Primary';

  @override
  String get clearChat => 'Clear chat';

  @override
  String speakerPanelTitle(Object title) {
    return '$title Speaker';
  }

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get listen => 'Listen';

  @override
  String get primarySpeakerLabel => 'Primary Speaker';

  @override
  String get noneLabel => 'None';

  @override
  String get hideTranslationOriginalText => 'Hide translation original text';

  @override
  String get disableAudioPlayback => 'Disable audio playback';

  @override
  String get enableAudioPlayback => 'Enable audio playback';

  @override
  String get audioPlaybackBluetoothNotice => 'For the best experience, use audio playback with a bluetooth device.';

  @override
  String get primarySpeakerInline => 'Primary speaker';

  @override
  String get noAlignment => 'No alignment';

  @override
  String get speechUnavailable => 'Speech unavailable';

  @override
  String get microphoneConnected => 'Microphone connected';

  @override
  String get microphoneDisconnected => 'Microphone disconnected';

  @override
  String get audioRouteChanged => 'Audio route changed';

  @override
  String get listeningDeviceListUpdated => 'Listening device list updated';

  @override
  String messageWithDetails(Object message, Object details) {
    return '$message: $details';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageFrench => 'French';

  @override
  String get languageGerman => 'German';

  @override
  String get languageChineseSimplified => 'Chinese (Simplified)';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get microphonePermissionDenied => 'Microphone permission denied';

  @override
  String get invalidSpeechApiKey => 'Invalid speech API key';

  @override
  String get sttProviderDeepgram => 'Deepgram';

  @override
  String get sttProviderGoogle => 'Speech to Text';

  @override
  String get translationProviderGoogle => 'Google Cloud (Backend)';

  @override
  String get outputProviderGoogle => 'Google';

  @override
  String get outputProviderDeepgram => 'Deepgram';
}
