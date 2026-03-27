import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OmniaLingo'**
  String get appTitle;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsQuickSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Essentials'**
  String get settingsQuickSettingsTitle;

  /// No description provided for @settingsQuickSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language OmniaLingo listens for, the language it translates into, and the microphone it should use.'**
  String get settingsQuickSettingsDescription;

  /// No description provided for @settingsAdvancedToggle.
  ///
  /// In en, this message translates to:
  /// **'Show advanced options'**
  String get settingsAdvancedToggle;

  /// No description provided for @settingsAdvancedDescription.
  ///
  /// In en, this message translates to:
  /// **'Only change recognition engines, translation engines, or voice output if you need to troubleshoot or fine-tune behavior.'**
  String get settingsAdvancedDescription;

  /// No description provided for @sourceLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'This is the language OmniaLingo listens for.'**
  String get sourceLanguageHint;

  /// No description provided for @targetLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'This is the language OmniaLingo translates into in Group mode.'**
  String get targetLanguageHint;

  /// No description provided for @listeningDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Leave this on Auto unless you want to force a specific microphone.'**
  String get listeningDeviceHint;

  /// No description provided for @deepgramModelHint.
  ///
  /// In en, this message translates to:
  /// **'Different Deepgram models support different source languages.'**
  String get deepgramModelHint;

  /// No description provided for @settingsModelAdjustedLanguage.
  ///
  /// In en, this message translates to:
  /// **'This model does not support your previous source language, so OmniaLingo switched to {language}.'**
  String settingsModelAdjustedLanguage(Object language);

  /// No description provided for @tabProviders.
  ///
  /// In en, this message translates to:
  /// **'Voice Recognition'**
  String get tabProviders;

  /// No description provided for @tabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio Devices'**
  String get tabAudio;

  /// No description provided for @tabDisplay.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get tabDisplay;

  /// No description provided for @speechToTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech to Text'**
  String get speechToTextLabel;

  /// No description provided for @deepgramModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Deepgram Model'**
  String get deepgramModelLabel;

  /// No description provided for @deepgramLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Deepgram Language'**
  String get deepgramLanguageLabel;

  /// No description provided for @googleLocaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Locale'**
  String get googleLocaleLabel;

  /// No description provided for @translationLabel.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translationLabel;

  /// No description provided for @textToSpeechLabel.
  ///
  /// In en, this message translates to:
  /// **'Text to Speech'**
  String get textToSpeechLabel;

  /// No description provided for @listeningDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Listening Device'**
  String get listeningDeviceLabel;

  /// No description provided for @audioInputSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Audio input selection is available when Speech to Text is set to Deepgram.'**
  String get audioInputSelectionHint;

  /// No description provided for @noInputDevicesDetected.
  ///
  /// In en, this message translates to:
  /// **'No input devices detected'**
  String get noInputDevicesDetected;

  /// No description provided for @autoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoLabel;

  /// No description provided for @currentDetails.
  ///
  /// In en, this message translates to:
  /// **'Current: {details}'**
  String currentDetails(Object details);

  /// No description provided for @autoWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Auto ({details})'**
  String autoWithDetails(Object details);

  /// No description provided for @playbackDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Playback Device'**
  String get playbackDeviceLabel;

  /// No description provided for @iosPlaybackRoutesHint.
  ///
  /// In en, this message translates to:
  /// **'Some iOS playback routes are managed by the system and may not always switch programmatically.'**
  String get iosPlaybackRoutesHint;

  /// No description provided for @playbackUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'Playback device details unavailable on this platform.'**
  String get playbackUnavailableHint;

  /// No description provided for @displayLabel.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displayLabel;

  /// No description provided for @themeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeModeLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @languageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get languageSearchHint;

  /// No description provided for @noMatchingLanguages.
  ///
  /// In en, this message translates to:
  /// **'No matching languages'**
  String get noMatchingLanguages;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @multiAuto.
  ///
  /// In en, this message translates to:
  /// **'Multilingual'**
  String get multiAuto;

  /// No description provided for @multiAutoDetails.
  ///
  /// In en, this message translates to:
  /// **'English, Spanish, French, German, Hindi, Russian, Portuguese, Japanese, Italian, and Dutch'**
  String get multiAutoDetails;

  /// No description provided for @debugAudioStream.
  ///
  /// In en, this message translates to:
  /// **'Debug Audio Stream'**
  String get debugAudioStream;

  /// No description provided for @debugSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get debugSection;

  /// No description provided for @debugSectionGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get debugSectionGroup;

  /// No description provided for @debugSectionTwoWay.
  ///
  /// In en, this message translates to:
  /// **'2-way'**
  String get debugSectionTwoWay;

  /// No description provided for @debugListeningActive.
  ///
  /// In en, this message translates to:
  /// **'Listening Active'**
  String get debugListeningActive;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @notAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get notAvailableShort;

  /// No description provided for @debugSttProvider.
  ///
  /// In en, this message translates to:
  /// **'STT Provider'**
  String get debugSttProvider;

  /// No description provided for @debugSourceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Source Language'**
  String get debugSourceLanguage;

  /// No description provided for @debugResolvedLanguageCode.
  ///
  /// In en, this message translates to:
  /// **'Resolved Language Code'**
  String get debugResolvedLanguageCode;

  /// No description provided for @debugActiveSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Active Sample Rate'**
  String get debugActiveSampleRate;

  /// No description provided for @sampleRateHertz.
  ///
  /// In en, this message translates to:
  /// **'{sampleRate} Hz'**
  String sampleRateHertz(Object sampleRate);

  /// No description provided for @debugListeningDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Listening Device Id'**
  String get debugListeningDeviceId;

  /// No description provided for @autoDefault.
  ///
  /// In en, this message translates to:
  /// **'auto/default'**
  String get autoDefault;

  /// No description provided for @debugAmplitude.
  ///
  /// In en, this message translates to:
  /// **'Amplitude (0-1)'**
  String get debugAmplitude;

  /// No description provided for @debugSessionElapsed.
  ///
  /// In en, this message translates to:
  /// **'Session Elapsed'**
  String get debugSessionElapsed;

  /// No description provided for @debugSessionStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Session Started At'**
  String get debugSessionStartedAt;

  /// No description provided for @debugConfiguredSttProvider.
  ///
  /// In en, this message translates to:
  /// **'Configured STT Provider'**
  String get debugConfiguredSttProvider;

  /// No description provided for @debugConfiguredDeepgramLanguage.
  ///
  /// In en, this message translates to:
  /// **'Configured Deepgram Language'**
  String get debugConfiguredDeepgramLanguage;

  /// No description provided for @debugConfiguredGoogleLocale.
  ///
  /// In en, this message translates to:
  /// **'Configured Google Locale'**
  String get debugConfiguredGoogleLocale;

  /// No description provided for @debugConfiguredSttLocale.
  ///
  /// In en, this message translates to:
  /// **'Configured STT Locale'**
  String get debugConfiguredSttLocale;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unableToSwitchPlaybackDevice.
  ///
  /// In en, this message translates to:
  /// **'Unable to switch playback device on this platform.'**
  String get unableToSwitchPlaybackDevice;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @swapLanguagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap source and target language'**
  String get swapLanguagesTooltip;

  /// No description provided for @swapUnavailableMultiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap unavailable when source or target is multi'**
  String get swapUnavailableMultiTooltip;

  /// No description provided for @swapUnavailablePairTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap unavailable for selected language pair'**
  String get swapUnavailablePairTooltip;

  /// No description provided for @targetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get targetLabel;

  /// No description provided for @initializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed: {error}'**
  String initializationFailed(Object error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @walkthroughWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to OmniaLingo'**
  String get walkthroughWelcomeTitle;

  /// No description provided for @walkthroughWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Here is a quick walkthrough of the essentials before your first conversation.'**
  String get walkthroughWelcomeBody;

  /// No description provided for @walkthroughDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss walkthrough'**
  String get walkthroughDismiss;

  /// No description provided for @walkthroughHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get walkthroughHelp;

  /// No description provided for @walkthroughSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get walkthroughSkip;

  /// No description provided for @walkthroughBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get walkthroughBack;

  /// No description provided for @walkthroughNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get walkthroughNext;

  /// No description provided for @walkthroughGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get walkthroughGetStarted;

  /// No description provided for @walkthroughModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the right mode'**
  String get walkthroughModesTitle;

  /// No description provided for @walkthroughModesBody.
  ///
  /// In en, this message translates to:
  /// **'Use Group when one speaker or a group is talking into a shared microphone and everyone wants live translated captions. Use 2-way when two people are handing the device back and forth for a conversation.'**
  String get walkthroughModesBody;

  /// No description provided for @walkthroughLanguagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Source and target languages'**
  String get walkthroughLanguagesTitle;

  /// No description provided for @walkthroughLanguagesBody.
  ///
  /// In en, this message translates to:
  /// **'Source is the language OmniaLingo listens for. Target is the language it translates into. In 2-way mode, each side chooses its own language so each person can follow the conversation in the language they prefer.'**
  String get walkthroughLanguagesBody;

  /// No description provided for @walkthroughMicrophoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone and permissions'**
  String get walkthroughMicrophoneTitle;

  /// No description provided for @walkthroughMicrophoneBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone button to start or stop listening. The first time you use it, allow microphone access when your device asks. If access was denied earlier, re-enable the microphone for OmniaLingo in your device settings.'**
  String get walkthroughMicrophoneBody;

  /// No description provided for @walkthroughPrimarySpeakerTitle.
  ///
  /// In en, this message translates to:
  /// **'What Primary Speaker means'**
  String get walkthroughPrimarySpeakerTitle;

  /// No description provided for @walkthroughPrimarySpeakerBody.
  ///
  /// In en, this message translates to:
  /// **'In Group mode, Primary Speaker highlights one speaker\'s messages and aligns them so that person\'s side is easier to follow. Choose it when you want one participant\'s translated text to stand out.'**
  String get walkthroughPrimarySpeakerBody;

  /// No description provided for @translationAssistant.
  ///
  /// In en, this message translates to:
  /// **'Real-Time Voice Translator'**
  String get translationAssistant;

  /// No description provided for @groupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupLabel;

  /// No description provided for @twoWayLabel.
  ///
  /// In en, this message translates to:
  /// **'2-way'**
  String get twoWayLabel;

  /// No description provided for @listeningStatus.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listeningStatus;

  /// No description provided for @tapMicToStartListening.
  ///
  /// In en, this message translates to:
  /// **'Tap the mic to start listening...'**
  String get tapMicToStartListening;

  /// No description provided for @speechNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Speech not available'**
  String get speechNotAvailable;

  /// No description provided for @speakerLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaker {number}'**
  String speakerLabel(Object number);

  /// No description provided for @hideOriginal.
  ///
  /// In en, this message translates to:
  /// **'Hide original'**
  String get hideOriginal;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

  /// No description provided for @replayTranslation.
  ///
  /// In en, this message translates to:
  /// **'Replay translation'**
  String get replayTranslation;

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get jumpToLatest;

  /// No description provided for @guestLabel.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestLabel;

  /// No description provided for @primaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryLabel;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get clearChat;

  /// No description provided for @speakerPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} Speaker'**
  String speakerPanelTitle(Object title);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListening;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @primarySpeakerLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary Speaker'**
  String get primarySpeakerLabel;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @hideTranslationOriginalText.
  ///
  /// In en, this message translates to:
  /// **'Hide translation original text'**
  String get hideTranslationOriginalText;

  /// No description provided for @disableAudioPlayback.
  ///
  /// In en, this message translates to:
  /// **'Disable audio playback'**
  String get disableAudioPlayback;

  /// No description provided for @enableAudioPlayback.
  ///
  /// In en, this message translates to:
  /// **'Enable audio playback'**
  String get enableAudioPlayback;

  /// No description provided for @primarySpeakerInline.
  ///
  /// In en, this message translates to:
  /// **'Primary speaker'**
  String get primarySpeakerInline;

  /// No description provided for @noAlignment.
  ///
  /// In en, this message translates to:
  /// **'No alignment'**
  String get noAlignment;

  /// No description provided for @speechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech unavailable'**
  String get speechUnavailable;

  /// No description provided for @microphoneConnected.
  ///
  /// In en, this message translates to:
  /// **'Microphone connected'**
  String get microphoneConnected;

  /// No description provided for @microphoneDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Microphone disconnected'**
  String get microphoneDisconnected;

  /// No description provided for @audioRouteChanged.
  ///
  /// In en, this message translates to:
  /// **'Audio route changed'**
  String get audioRouteChanged;

  /// No description provided for @listeningDeviceListUpdated.
  ///
  /// In en, this message translates to:
  /// **'Listening device list updated'**
  String get listeningDeviceListUpdated;

  /// No description provided for @messageWithDetails.
  ///
  /// In en, this message translates to:
  /// **'{message}: {details}'**
  String messageWithDetails(Object message, Object details);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get languageChineseSimplified;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get microphonePermissionDenied;

  /// No description provided for @invalidSpeechApiKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid speech API key'**
  String get invalidSpeechApiKey;

  /// No description provided for @sttProviderDeepgram.
  ///
  /// In en, this message translates to:
  /// **'Deepgram'**
  String get sttProviderDeepgram;

  /// No description provided for @sttProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Speech to Text'**
  String get sttProviderGoogle;

  /// No description provided for @translationProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Cloud (Backend)'**
  String get translationProviderGoogle;

  /// No description provided for @translationProviderGoogleMlKit.
  ///
  /// In en, this message translates to:
  /// **'Google ML Kit (Legacy)'**
  String get translationProviderGoogleMlKit;

  /// No description provided for @outputProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get outputProviderGoogle;

  /// No description provided for @outputProviderDeepgram.
  ///
  /// In en, this message translates to:
  /// **'Deepgram'**
  String get outputProviderDeepgram;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'fr', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'hi': return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
