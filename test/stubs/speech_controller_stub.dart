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

/// Lightweight stub of SpeechController for widget tests. Avoids plugins
/// and network calls while allowing manual control of state.
class TestSpeechController extends ChangeNotifier implements SpeechController {
  TestSpeechController({
    bool isListening = false,
    bool speechEnabled = true,
    bool audioPlaybackEnabled = false,
    double amplitude = 0.0,
    String targetLanguage = 'en',
    int? activeSessionSampleRate,
    SpeechSttProvider? activeSessionSttProvider,
    String? activeSessionSourceLanguage,
    String? activeSessionResolvedLanguageCode,
    String? activeSessionListeningDeviceId,
    DateTime? activeSessionStartedAt,
  }) : _isListening = isListening,
       _speechEnabled = speechEnabled,
       _audioPlaybackEnabled = audioPlaybackEnabled,
       _amplitude = amplitude,
       _targetLanguage = targetLanguage,
       _activeSessionSampleRate = activeSessionSampleRate,
       _activeSessionSttProvider = activeSessionSttProvider,
       _activeSessionSourceLanguage = activeSessionSourceLanguage,
       _activeSessionResolvedLanguageCode = activeSessionResolvedLanguageCode,
       _activeSessionListeningDeviceId = activeSessionListeningDeviceId,
       _activeSessionStartedAt = activeSessionStartedAt;

  final List<ChatMessage> _chatMessages = [];
  bool _isListening;
  final bool _speechEnabled;
  bool _audioPlaybackEnabled;
  bool _hideTranslatedOriginalText = true;
  final String _speechError = '';
  String _lastWords = '';
  final double _amplitude;
  int? _activeSessionSampleRate;
  SpeechSttProvider? _activeSessionSttProvider;
  String? _activeSessionSourceLanguage;
  String? _activeSessionResolvedLanguageCode;
  String? _activeSessionListeningDeviceId;
  DateTime? _activeSessionStartedAt;
  @override
  int? preferredSpeaker;
  String _targetLanguage;
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
  int startListeningCallCount = 0;
  int stopListeningCallCount = 0;
  int replayTranslationCallCount = 0;
  String? lastReplayedTranslation;
  final StreamController<String> _listeningDeviceUpdatesController =
      StreamController<String>.broadcast();
  final StreamController<SuggestedResponseEvent> _suggestedResponsesController =
      StreamController<SuggestedResponseEvent>.broadcast();

  void addMessage(ChatMessage msg) {
    _chatMessages.add(msg);
    notifyListeners();
  }

  void setListeningState({required bool isListening, String lastWords = ''}) {
    _isListening = isListening;
    _lastWords = lastWords;
    notifyListeners();
  }

  void emitListeningDeviceUpdate(String message) {
    if (!_listeningDeviceUpdatesController.isClosed) {
      _listeningDeviceUpdatesController.add(message);
    }
  }

  void emitSuggestedResponse(SuggestedResponseEvent event) {
    if (!_suggestedResponsesController.isClosed) {
      _suggestedResponsesController.add(event);
    }
  }

  // SpeechController contract -------------------------------------------------
  @override
  set finalResultGroupingWindow(Duration value) => const Duration(seconds: 1);

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
  int? get activeSessionSampleRate => _activeSessionSampleRate;

  @override
  SpeechSttProvider? get activeSessionSttProvider => _activeSessionSttProvider;

  @override
  String? get activeSessionSourceLanguage => _activeSessionSourceLanguage;

  @override
  String? get activeSessionResolvedLanguageCode =>
      _activeSessionResolvedLanguageCode;

  @override
  String? get activeSessionListeningDeviceId => _activeSessionListeningDeviceId;

  @override
  DateTime? get activeSessionStartedAt => _activeSessionStartedAt;

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
    startListeningCallCount += 1;
    _isListening = true;
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount += 1;
    _isListening = false;
    _lastWords = '';
    notifyListeners();
  }

  @override
  Future<void> replayTranslation(ChatMessage message) async {
    replayTranslationCallCount += 1;
    lastReplayedTranslation = message.translation?.trim().isNotEmpty == true
        ? message.translation!.trim()
        : message.groups
              .map((group) => group.translation?.trim())
              .whereType<String>()
              .where((translation) => translation.isNotEmpty)
              .join(' ')
              .trim();
  }

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

  @override
  void dispose() {
    super.dispose();
    _listeningDeviceUpdatesController.close();
    _suggestedResponsesController.close();
  }
}
