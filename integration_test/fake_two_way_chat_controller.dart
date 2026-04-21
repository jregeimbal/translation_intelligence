import 'package:flutter/material.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

/// A fake [TwoWayChatController] for Patrol e2e tests. Used as the 2-way chat
/// tab controller during integration testing.
class FakeTwoWayChatController extends ChangeNotifier
    implements TwoWayChatController {
  FakeTwoWayChatController({
    bool speechEnabled = true,
    String primaryLanguage = 'en',
    String guestLanguage = 'es',
  }) : _speechEnabled = speechEnabled,
       _primaryLanguage = primaryLanguage,
       _guestLanguage = guestLanguage;

  bool _isListening = false;
  final bool _speechEnabled;
  String _primaryLanguage;
  String _guestLanguage;
  TwoWaySpeaker? _activeSpeaker;
  final List<TwoWayMessage> _messages = [];
  String _deepgramRecognitionLanguage = 'multi';
  String _speechToTextRecognitionLocale = 'en-US';
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;
  String _deepgramRecognitionModel = 'nova-2';

  @override
  bool get speechEnabled => _speechEnabled;

  @override
  bool get isListening => _isListening;

  @override
  String get speechError => '';

  @override
  String get lastWords => '';

  @override
  double get amplitude => 0.0;

  @override
  TwoWaySpeaker? get activeSpeaker => _activeSpeaker;

  @override
  String get primaryLanguage => _primaryLanguage;

  @override
  String get guestLanguage => _guestLanguage;

  @override
  List<TwoWayMessage> get messages => List.unmodifiable(_messages);

  @override
  bool get canChangeLanguages => true;

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
  int? get activeSessionSampleRate => null;

  @override
  SpeechSttProvider? get activeSessionSttProvider => null;

  @override
  String? get activeSessionSourceLanguage => null;

  @override
  String? get activeSessionResolvedLanguageCode => null;

  @override
  String? get activeSessionListeningDeviceId => null;

  @override
  DateTime? get activeSessionStartedAt => null;

  @override
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void addTestMessage(TwoWayMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  void setGuestLanguage(String language) {
    _guestLanguage = language;
    notifyListeners();
  }

  @override
  void setPrimaryLanguage(String language) {
    _primaryLanguage = language;
    notifyListeners();
  }

  @override
  Future<void> startListening(TwoWaySpeaker speaker) async {
    _isListening = true;
    _activeSpeaker = speaker;
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _activeSpeaker = null;
    notifyListeners();
  }

  @override
  Future<void> toggleListening(TwoWaySpeaker speaker) async {
    if (_isListening && _activeSpeaker == speaker) {
      await stopListening();
    } else {
      await startListening(speaker);
    }
  }

  @override
  void setOutputProvider(SpeechOutputProvider provider) {
    _outputProvider = provider;
    notifyListeners();
  }

  @override
  void setSttProvider(SpeechSttProvider provider) {
    _sttProvider = provider;
    notifyListeners();
  }

  @override
  void setTranslationProvider(SpeechTranslationProvider provider) {
    _translationProvider = provider;
    notifyListeners();
  }

  @override
  void setDeepgramRecognitionModel(String model) {
    _deepgramRecognitionModel = model;
    notifyListeners();
  }

  @override
  void setDeepgramRecognitionLanguage(String language) {
    _deepgramRecognitionLanguage = language;
    notifyListeners();
  }

  @override
  void setSpeechToTextRecognitionLocale(String locale) {
    _speechToTextRecognitionLocale = locale;
    notifyListeners();
  }

  @override
  Future<void> refreshSpeechToTextRecognitionLocales() async {}

  @override
  void setListeningDeviceId(String? deviceId) {}

  @override
  Future<bool> setPlaybackDeviceId(String? deviceId) async => true;
}
