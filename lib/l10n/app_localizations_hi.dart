// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'ओमनियालिंगो';

  @override
  String get themeModeSystem => 'सिस्टम';

  @override
  String get themeModeLight => 'लाइट';

  @override
  String get themeModeDark => 'डार्क';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsQuickSettingsTitle => 'मुख्य विकल्प';

  @override
  String get settingsQuickSettingsDescription => 'वह भाषा चुनें जिसे OmniaLingo सुने, वह भाषा जिसमें यह अनुवाद करे, और वह माइक्रोफ़ोन जिसका इसे उपयोग करना चाहिए।';

  @override
  String get settingsAdvancedToggle => 'उन्नत विकल्प दिखाएं';

  @override
  String get settingsAdvancedDescription => 'पहचान इंजन, अनुवाद इंजन या वॉइस आउटपुट केवल तभी बदलें जब आपको समस्या निवारण या व्यवहार को सूक्ष्म रूप से समायोजित करना हो।';

  @override
  String get sourceLanguageHint => 'यह वह भाषा है जिसे OmniaLingo सुनता है।';

  @override
  String get targetLanguageHint => 'यह वह भाषा है जिसमें OmniaLingo समूह मोड में अनुवाद करता है।';

  @override
  String get listeningDeviceHint => 'इसे Auto पर रहने दें, जब तक कि आप किसी विशेष माइक्रोफ़ोन को मजबूरन चुनना न चाहें।';

  @override
  String get deepgramModelHint => 'अलग-अलग Deepgram मॉडल अलग-अलग स्रोत भाषाओं का समर्थन करते हैं।';

  @override
  String settingsModelAdjustedLanguage(Object language) {
    return 'यह मॉडल आपकी पिछली स्रोत भाषा का समर्थन नहीं करता, इसलिए OmniaLingo ने $language पर स्विच कर दिया।';
  }

  @override
  String get tabProviders => 'वॉइस रिकग्निशन';

  @override
  String get tabAudio => 'ऑडियो डिवाइस';

  @override
  String get tabDisplay => 'दिखावट';

  @override
  String get speechToTextLabel => 'स्पीच टू टेक्स्ट';

  @override
  String get deepgramModelLabel => 'Deepgram मॉडल';

  @override
  String get deepgramLanguageLabel => 'Deepgram भाषा';

  @override
  String get googleLocaleLabel => 'Google लोकेल';

  @override
  String get translationLabel => 'अनुवाद';

  @override
  String get textToSpeechLabel => 'टेक्स्ट टू स्पीच';

  @override
  String get listeningDeviceLabel => 'सुनने का डिवाइस';

  @override
  String get audioInputSelectionHint => 'ऑडियो इनपुट चयन तब उपलब्ध है जब Speech to Text को Deepgram पर सेट किया गया हो।';

  @override
  String get noInputDevicesDetected => 'कोई इनपुट डिवाइस नहीं मिला';

  @override
  String get autoLabel => 'ऑटो';

  @override
  String currentDetails(Object details) {
    return 'वर्तमान: $details';
  }

  @override
  String autoWithDetails(Object details) {
    return 'ऑटो ($details)';
  }

  @override
  String get playbackDeviceLabel => 'प्लेबैक डिवाइस';

  @override
  String get iosPlaybackRoutesHint => 'कुछ iOS प्लेबैक रूट सिस्टम द्वारा प्रबंधित होते हैं और हमेशा प्रोग्रामेटिक रूप से बदले नहीं जा सकते।';

  @override
  String get playbackUnavailableHint => 'इस प्लेटफ़ॉर्म पर प्लेबैक डिवाइस का विवरण उपलब्ध नहीं है।';

  @override
  String get displayLabel => 'डिस्प्ले';

  @override
  String get themeModeLabel => 'थीम मोड';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get languageSearchHint => 'भाषाएँ खोजें';

  @override
  String get noMatchingLanguages => 'कोई मेल खाती भाषा नहीं मिली';

  @override
  String get save => 'सहेजें';

  @override
  String get multiAuto => 'बहुभाषी';

  @override
  String get multiAutoDetails => 'अंग्रेज़ी, स्पेनिश, फ़्रेंच, जर्मन, हिंदी, रूसी, पुर्तगाली, जापानी, इतालवी और डच';

  @override
  String get debugAudioStream => 'ऑडियो स्ट्रीम डीबग करें';

  @override
  String get debugSection => 'सेक्शन';

  @override
  String get debugSectionGroup => 'समूह';

  @override
  String get debugSectionTwoWay => '2-तरफ़ा';

  @override
  String get debugListeningActive => 'सुनना सक्रिय';

  @override
  String get yes => 'हाँ';

  @override
  String get no => 'नहीं';

  @override
  String get notAvailableShort => 'उपलब्ध नहीं';

  @override
  String get debugSttProvider => 'STT प्रदाता';

  @override
  String get debugSourceLanguage => 'स्रोत भाषा';

  @override
  String get debugResolvedLanguageCode => 'Resolved Language Code';

  @override
  String get debugActiveSampleRate => 'सक्रिय सैंपल रेट';

  @override
  String sampleRateHertz(Object sampleRate) {
    return '$sampleRate Hz';
  }

  @override
  String get debugListeningDeviceId => 'सुनने वाले डिवाइस की ID';

  @override
  String get autoDefault => 'ऑटो/डिफ़ॉल्ट';

  @override
  String get debugAmplitude => 'एम्प्लिट्यूड (0-1)';

  @override
  String get debugSessionElapsed => 'सत्र अवधि';

  @override
  String get debugSessionStartedAt => 'सत्र शुरू होने का समय';

  @override
  String get debugConfiguredSttProvider => 'कॉन्फ़िगर किया गया STT प्रदाता';

  @override
  String get debugConfiguredDeepgramLanguage => 'कॉन्फ़िगर की गई Deepgram भाषा';

  @override
  String get debugConfiguredGoogleLocale => 'कॉन्फ़िगर किया गया Google लोकेल';

  @override
  String get debugConfiguredSttLocale => 'कॉन्फ़िगर किया गया STT लोकेल';

  @override
  String get close => 'बंद करें';

  @override
  String get unableToSwitchPlaybackDevice => 'इस प्लेटफ़ॉर्म पर प्लेबैक डिवाइस बदला नहीं जा सका।';

  @override
  String get sourceLabel => 'स्रोत';

  @override
  String get swapLanguagesTooltip => 'स्रोत और लक्ष्य भाषा बदलें';

  @override
  String get swapUnavailableMultiTooltip => 'जब स्रोत या लक्ष्य बहुभाषी हो, तब अदला-बदली उपलब्ध नहीं है';

  @override
  String get swapUnavailablePairTooltip => 'चयनित भाषा जोड़ी के लिए अदला-बदली उपलब्ध नहीं है';

  @override
  String get targetLabel => 'लक्ष्य';

  @override
  String initializationFailed(Object error) {
    return 'इनिशियलाइज़ेशन विफल: $error';
  }

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get walkthroughWelcomeTitle => 'OmniaLingo में आपका स्वागत है';

  @override
  String get walkthroughWelcomeBody => 'आपकी पहली बातचीत से पहले आवश्यक बातों का यह एक छोटा परिचय है।';

  @override
  String get walkthroughDismiss => 'वॉकथ्रू बंद करें';

  @override
  String get walkthroughHelp => 'मदद';

  @override
  String get walkthroughSkip => 'छोड़ें';

  @override
  String get walkthroughBack => 'वापस';

  @override
  String get walkthroughNext => 'आगे';

  @override
  String get walkthroughGetStarted => 'शुरू करें';

  @override
  String get walkthroughModesTitle => 'सही मोड चुनें';

  @override
  String get walkthroughModesBody => 'Group का उपयोग तब करें जब कोई एक व्यक्ति या समूह साझा माइक्रोफ़ोन में बोल रहा हो और सभी को लाइव अनुवादित कैप्शन चाहिए हों। 2-way का उपयोग तब करें जब दो लोग बातचीत के दौरान डिवाइस एक-दूसरे को दे रहे हों।';

  @override
  String get walkthroughLanguagesTitle => 'स्रोत और लक्ष्य भाषाएँ';

  @override
  String get walkthroughLanguagesBody => 'स्रोत वह भाषा है जिसे OmniaLingo सुनता है। लक्ष्य वह भाषा है जिसमें यह अनुवाद करता है। 2-way मोड में, दोनों पक्ष अपनी-अपनी भाषा चुनते हैं ताकि हर व्यक्ति बातचीत को अपनी पसंदीदा भाषा में समझ सके।';

  @override
  String get walkthroughMicrophoneTitle => 'माइक्रोफ़ोन और अनुमतियाँ';

  @override
  String get walkthroughMicrophoneBody => 'सुनना शुरू या बंद करने के लिए माइक्रोफ़ोन बटन दबाएँ। पहली बार उपयोग पर, जब आपका डिवाइस पूछे, तो माइक्रोफ़ोन की अनुमति दें। यदि पहले अनुमति अस्वीकार की थी, तो डिवाइस सेटिंग्स में OmniaLingo के लिए माइक्रोफ़ोन पुनः सक्षम करें।';

  @override
  String get walkthroughPrimarySpeakerTitle => 'Primary Speaker का अर्थ';

  @override
  String get walkthroughPrimarySpeakerBody => 'Group मोड में, Primary Speaker एक व्यक्ति के संदेशों को हाइलाइट करता है और उन्हें ऐसे संरेखित करता है कि उस व्यक्ति का पक्ष समझना आसान हो जाए। जब आप चाहते हों कि किसी एक प्रतिभागी का अनुवादित टेक्स्ट अधिक स्पष्ट दिखे, तब इसे चुनें।';

  @override
  String get translationAssistant => 'रियल-टाइम वॉइस ट्रांसलेटर';

  @override
  String get groupLabel => 'समूह';

  @override
  String get twoWayLabel => '2-तरफ़ा';

  @override
  String get listeningStatus => 'सुन रहा है...';

  @override
  String get tapMicToStartListening => 'सुनना शुरू करने के लिए माइक्रोफ़ोन दबाएँ...';

  @override
  String get speechNotAvailable => 'स्पीच उपलब्ध नहीं है';

  @override
  String speakerLabel(Object number) {
    return 'स्पीकर $number';
  }

  @override
  String get hideOriginal => 'मूल छिपाएँ';

  @override
  String get showOriginal => 'मूल दिखाएँ';

  @override
  String get replayTranslation => 'अनुवाद फिर चलाएँ';

  @override
  String get jumpToLatest => 'नवीनतम पर जाएँ';

  @override
  String get suggestedResponseTitle => 'सुझाया गया जवाब';

  @override
  String suggestedResponseOriginalLabel(Object language) {
    return '$language में';
  }

  @override
  String suggestedResponseTranslatedLabel(Object language) {
    return 'आपके लिए अनुवादित ($language)';
  }

  @override
  String get guestLabel => 'अतिथि';

  @override
  String get primaryLabel => 'प्राथमिक';

  @override
  String get clearChat => 'चैट साफ़ करें';

  @override
  String speakerPanelTitle(Object title) {
    return '$title स्पीकर';
  }

  @override
  String get noMessagesYet => 'अभी तक कोई संदेश नहीं';

  @override
  String get stopListening => 'सुनना बंद करें';

  @override
  String get listen => 'सुनें';

  @override
  String get primarySpeakerLabel => 'Primary Speaker';

  @override
  String get noneLabel => 'कोई नहीं';

  @override
  String get hideTranslationOriginalText => 'अनुवाद का मूल पाठ छिपाएँ';

  @override
  String get disableAudioPlayback => 'ऑडियो प्लेबैक बंद करें';

  @override
  String get enableAudioPlayback => 'ऑडियो प्लेबैक चालू करें';

  @override
  String get primarySpeakerInline => 'Primary speaker';

  @override
  String get noAlignment => 'कोई संरेखण नहीं';

  @override
  String get speechUnavailable => 'स्पीच उपलब्ध नहीं है';

  @override
  String get microphoneConnected => 'माइक्रोफ़ोन कनेक्ट हुआ';

  @override
  String get microphoneDisconnected => 'माइक्रोफ़ोन डिस्कनेक्ट हुआ';

  @override
  String get audioRouteChanged => 'ऑडियो रूट बदला गया';

  @override
  String get listeningDeviceListUpdated => 'सुनने वाले डिवाइसों की सूची अपडेट हुई';

  @override
  String messageWithDetails(Object message, Object details) {
    return '$message: $details';
  }

  @override
  String get languageEnglish => 'अंग्रेज़ी';

  @override
  String get languageSpanish => 'स्पेनिश';

  @override
  String get languageFrench => 'फ़्रेंच';

  @override
  String get languageGerman => 'जर्मन';

  @override
  String get languageChineseSimplified => 'चीनी (सरलीकृत)';

  @override
  String get languageJapanese => 'जापानी';

  @override
  String get languageKorean => 'कोरियाई';

  @override
  String get languagePortuguese => 'पुर्तगाली';

  @override
  String get languageRussian => 'रूसी';

  @override
  String get languageArabic => 'अरबी';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get microphonePermissionDenied => 'माइक्रोफ़ोन अनुमति अस्वीकृत';

  @override
  String get invalidSpeechApiKey => 'अमान्य स्पीच API कुंजी';

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
