import 'package:flutter/material.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

/// Lightweight stub of TwoWayChatController for widget tests. Avoids plugins
/// and network calls while allowing manual control of state.
class TestTwoWayChatController extends ChangeNotifier implements TwoWayChatController {
  TestTwoWayChatController({
    bool isListening = false,
    bool speechEnabled = true,
    double amplitude = 0.0,
    String primaryLanguage = 'en',
    String guestLanguage = 'es',
    int? activeSessionSampleRate,
    SpeechSttProvider? activeSessionSttProvider,
    String? activeSessionSourceLanguage,
    String? activeSessionResolvedLanguageCode,
    String? activeSessionListeningDeviceId,
    DateTime? activeSessionStartedAt,
    SpeechOutputProvider outputProvider = SpeechOutputProvider.google,
    SpeechSttProvider sttProvider = SpeechSttProvider.deepgram,
    SpeechTranslationProvider translationProvider = SpeechTranslationProvider.google,
    String deepgramRecognitionModel = 'nova-2',
    String deepgramRecognitionLanguage = 'en',
    String speechToTextRecognitionLocale = 'en-US',
  }) : _isListening = isListening,
       _speechEnabled = speechEnabled,
       _amplitude = amplitude,
       _primaryLanguage = primaryLanguage,
       _guestLanguage = guestLanguage,
       _activeSessionSampleRate = activeSessionSampleRate,
       _activeSessionSttProvider = activeSessionSttProvider,
       _activeSessionSourceLanguage = activeSessionSourceLanguage,
       _activeSessionResolvedLanguageCode = activeSessionResolvedLanguageCode,
       _activeSessionListeningDeviceId = activeSessionListeningDeviceId,
       _activeSessionStartedAt = activeSessionStartedAt,
       _outputProvider = outputProvider,
       _sttProvider = sttProvider,
       _translationProvider = translationProvider,
       _deepgramRecognitionModel = deepgramRecognitionModel,
       _deepgramRecognitionLanguage = deepgramRecognitionLanguage,
       _speechToTextRecognitionLocale = speechToTextRecognitionLocale;

  bool _isListening;
  final bool _speechEnabled;
  final double _amplitude;
  final String _primaryLanguage;
  final String _guestLanguage;
  int? _activeSessionSampleRate;
  SpeechSttProvider? _activeSessionSttProvider;
  String? _activeSessionSourceLanguage;
  String? _activeSessionResolvedLanguageCode;
  String? _activeSessionListeningDeviceId;
  DateTime? _activeSessionStartedAt;
  SpeechOutputProvider _outputProvider;
  SpeechSttProvider _sttProvider;
  SpeechTranslationProvider _translationProvider;
  String _deepgramRecognitionModel;
  String _deepgramRecognitionLanguage;
  String _speechToTextRecognitionLocale;

  @override
  bool get speechEnabled => _speechEnabled;

  @override
  bool get isListening => _isListening;

  @override
  String get speechError => '';

  @override
  String get lastWords => '';

  @override
  double get amplitude => _amplitude;

  @override
  TwoWaySpeaker? get activeSpeaker => null;

  @override
  SpeechOutputProvider get outputProvider => _outputProvider;

  @override
  SpeechSttProvider get sttProvider => _sttProvider;

  @override
  SpeechTranslationProvider get translationProvider => _translationProvider;

  @override
  String get deepgramRecognitionModel => _deepgramRecognitionModel;

  @override
  String get deepgramRecognitionLanguage => _deepgramRecognitionLanguage;

  @override
  String get speechToTextRecognitionLocale => _speechToTextRecognitionLocale;

  @override
  List<String> get deepgramRecognitionModels => ['nova-2', 'nova-2-general'];

  @override
  Map<String, String> get deepgramRecognitionLanguages => {'en': 'en'};

  @override
  Map<String, String> get speechToTextRecognitionLocales => {'en-US': 'en-US'};

  @override
  int? get activeSessionSampleRate => _activeSessionSampleRate;

  @override
  SpeechSttProvider? get activeSessionSttProvider => _activeSessionSttProvider;

  @override
  String? get activeSessionSourceLanguage => _activeSessionSourceLanguage;

  @override
  String? get activeSessionResolvedLanguageCode => _activeSessionResolvedLanguageCode;

  @override
  String? get activeSessionListeningDeviceId => _activeSessionListeningDeviceId;

  @override
  DateTime? get activeSessionStartedAt => _activeSessionStartedAt;

  @override
  String get primaryLanguage => _primaryLanguage;

  @override
  String get guestLanguage => _guestLanguage;

  @override
  List<TwoWayMessage> get messages => const [];

  @override
  bool get canChangeLanguages => true;

  @override
  void setOutputProvider(SpeechOutputProvider provider) {
    if (_outputProvider == provider) return;
    _outputProvider = provider;
    notifyListeners();
  }

  @override
  void setSttProvider(SpeechSttProvider provider) {
    if (_sttProvider == provider) return;
    _sttProvider = provider;
    notifyListeners();
  }

  @override
  void setTranslationProvider(SpeechTranslationProvider provider) {
    if (_translationProvider == provider) return;
    _translationProvider = provider;
    notifyListeners();
  }

  @override
  void setDeepgramRecognitionModel(String model) {
    if (_deepgramRecognitionModel == model) return;
    _deepgramRecognitionModel = model;
    notifyListeners();
  }

  @override
  void setDeepgramRecognitionLanguage(String language) {
    if (_deepgramRecognitionLanguage == language) return;
    _deepgramRecognitionLanguage = language;
    notifyListeners();
  }

  @override
  void setSpeechToTextRecognitionLocale(String locale) {
    if (_speechToTextRecognitionLocale == locale) return;
    _speechToTextRecognitionLocale = locale;
    notifyListeners();
  }

  @override
  Future<void> refreshSpeechToTextRecognitionLocales() async {}

  @override
  void setListeningDeviceId(String? deviceId) {}

  @override
  Future<bool> setPlaybackDeviceId(String? deviceId) async => true;


  void setActiveSessionData({
    int? sampleRate,
    SpeechSttProvider? sttProvider,
    String? sourceLanguage,
    String? resolvedLanguageCode,
    String? listeningDeviceId,
    DateTime? startedAt,
  }) {
    _activeSessionSampleRate = sampleRate;
    _activeSessionSttProvider = sttProvider;
    _activeSessionSourceLanguage = sourceLanguage;
    _activeSessionResolvedLanguageCode = resolvedLanguageCode;
    _activeSessionListeningDeviceId = listeningDeviceId;
    _activeSessionStartedAt = startedAt;
    notifyListeners();
  }


  void setListeningState({required bool isListening}) {
    _isListening = isListening;
    notifyListeners();
  }

  @override
  void clearMessages() {}

  @override
  Future<void> init() async {}

  @override
  void setGuestLanguage(String language) {}

  @override
  void setPrimaryLanguage(String language) {}

  @override
  Future<void> startListening(TwoWaySpeaker speaker) async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> toggleListening(TwoWaySpeaker speaker) async {}
}
