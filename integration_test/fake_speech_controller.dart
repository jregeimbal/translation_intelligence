import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/models/playback_device.dart';
import 'package:translation_intelligence/models/speech_recognition_models.dart';
import 'package:translation_intelligence/models/suggested_response.dart';
import 'package:translation_intelligence/services/deepgram_recognition_catalog.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_to_text_service.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

/// A fake [SpeechController] for Patrol e2e tests. Avoids real mic/network
/// access while allowing tests to programmatically inject speech results.
class FakeSpeechController extends ChangeNotifier implements SpeechController {
  FakeSpeechController({bool speechEnabled = true})
    : _speechEnabled = speechEnabled;

  final List<ChatMessage> _chatMessages = [];
  bool _isListening = false;
  final bool _speechEnabled;
  bool _audioPlaybackEnabled = false;
  bool _hideTranslatedOriginalText = false;
  final String _speechError = '';
  String _lastWords = '';
  final double _amplitude = 0.0;
  String _targetLanguage = 'en';
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;
  String _deepgramRecognitionModel =
      DeepgramRecognitionCatalog.defaultRecognitionModel;
  String _deepgramRecognitionLanguage =
      DeepgramRecognitionCatalog.defaultRecognitionLanguage;
  String _speechToTextRecognitionLocale =
      SpeechToTextService.defaultRecognitionLanguage;
  Map<String, String> _speechToTextRecognitionLocales = const {
    'multi': SpeechToTextService.defaultRecognitionLanguage,
    'en-US': 'en-US',
  };
  List<InputDevice> _listeningDevices = const [];
  String? _listeningDeviceId;
  List<PlaybackDevice> _playbackDevices = const [];
  String? _playbackDeviceId;
  final StreamController<String> _listeningDeviceUpdatesController =
      StreamController<String>.broadcast();
  final StreamController<SuggestedResponseEvent> _suggestedResponsesController =
      StreamController<SuggestedResponseEvent>.broadcast();

  @override
  int? preferredSpeaker;

  /// Inject a recognized [ChatMessage] into the fake controller. This will make
  /// it appear in the chat list exactly as if the backend had returned a
  /// translation result.
  void addMessage(ChatMessage msg) {
    _chatMessages.add(msg);
    notifyListeners();
  }

  void setListeningState({required bool isListening, String lastWords = ''}) {
    _isListening = isListening;
    _lastWords = lastWords;
    notifyListeners();
  }

  // ── SpeechController contract ──────────────────────────────────────────

  @override
  set finalResultGroupingWindow(Duration value) {}

  @override
  double get amplitude => _amplitude;

  @override
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  @override
  bool get isListening => _isListening;

  @override
  String get speechError => _speechError;

  @override
  bool get speechEnabled => _speechEnabled;

  @override
  bool get audioPlaybackEnabled => _audioPlaybackEnabled;

  @override
  bool get hideTranslatedOriginalText => _hideTranslatedOriginalText;

  @override
  Set<int> get speakers =>
      _chatMessages.map((m) => m.speaker).whereType<int>().toSet();

  @override
  String get targetLanguage => _targetLanguage;

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
  List<String> get deepgramRecognitionModels =>
      DeepgramRecognitionCatalog.supportedRecognitionModels;

  @override
  Map<String, String> get deepgramRecognitionLanguages =>
      DeepgramRecognitionCatalog
          .supportedRecognitionLanguagesByModel[_deepgramRecognitionModel] ??
      const <String, String>{};

  @override
  String get speechToTextRecognitionLocale => _speechToTextRecognitionLocale;

  @override
  Map<String, String> get speechToTextRecognitionLocales =>
      _speechToTextRecognitionLocales;

  @override
  List<InputDevice> get listeningDevices =>
      List<InputDevice>.unmodifiable(_listeningDevices);

  @override
  String? get listeningDeviceId => _listeningDeviceId;

  @override
  Stream<String> get listeningDeviceUpdates =>
      _listeningDeviceUpdatesController.stream;

  @override
  Stream<SuggestedResponseEvent> get suggestedResponses =>
      _suggestedResponsesController.stream;

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
  List<PlaybackDevice> get playbackDevices =>
      List<PlaybackDevice>.unmodifiable(_playbackDevices);

  @override
  String? get playbackDeviceId => _playbackDeviceId;

  @override
  List<ChatMessage> getOptimisticMessages() {
    if (_lastWords.trim().isEmpty) return const [];
    return [ChatMessage(_lastWords.trim(), isFinal: false)];
  }

  @override
  List<ChatMessage> wordsToMessages(
    List<ChatMessage> oldMessages,
    Iterable<SpeechRecognitionWord> words, {
    bool isFinal = false,
  }) {
    if (_lastWords.trim().isEmpty) return const [];
    return [ChatMessage(_lastWords.trim(), isFinal: isFinal)];
  }

  @override
  bool get hasSupportedTargetLanguage {
    return SpeechController.supportedLanguages.contains(_targetLanguage);
  }

  @override
  void clearMessages() {
    _chatMessages.clear();
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> startListening() async {
    _isListening = true;
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _lastWords = '';
    notifyListeners();
  }

  @override
  Future<void> replayTranslation(ChatMessage message) async {}

  @override
  void setPreferredSpeaker(int? speaker) {
    preferredSpeaker = speaker;
    notifyListeners();
  }

  @override
  void setTargetLanguage(String lang) {
    _targetLanguage = lang;
    notifyListeners();
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
  void setAudioPlaybackEnabled({required bool enabled}) {
    _audioPlaybackEnabled = enabled;
    notifyListeners();
  }

  @override
  void setHideTranslatedOriginalText({required bool enabled}) {
    _hideTranslatedOriginalText = enabled;
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
  Future<void> refreshSpeechToTextRecognitionLocales() async {
    _speechToTextRecognitionLocales = const {
      'multi': SpeechToTextService.defaultRecognitionLanguage,
      'en-US': 'en-US',
      'es-ES': 'es-ES',
    };
    notifyListeners();
  }

  @override
  Future<void> refreshListeningDevices() async {
    _listeningDevices = const [
      InputDevice(id: 'default', label: 'Built-in Microphone'),
    ];
    notifyListeners();
  }

  @override
  Future<void> refreshPlaybackDevices() async {
    _playbackDevices = const [
      PlaybackDevice(id: 'speaker', name: 'Built-in', type: 'Built-in Speaker'),
    ];
    notifyListeners();
  }

  @override
  void setListeningDeviceId(String? deviceId) {
    _listeningDeviceId = deviceId;
    notifyListeners();
  }

  @override
  Future<bool> setPlaybackDeviceId(String? deviceId) async {
    _playbackDeviceId = deviceId;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    _listeningDeviceUpdatesController.close();
    _suggestedResponsesController.close();
  }
}
