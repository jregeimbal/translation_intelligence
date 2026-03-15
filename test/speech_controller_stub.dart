import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/models/playback_device.dart';
import 'package:translation_intelligence/models/speech_recognition_models.dart';
import 'package:translation_intelligence/services/deepgram_service.dart';
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
    double amplitude = 0.0,
    String targetLanguage = 'en',
  }) : _isListening = isListening,
       _speechEnabled = speechEnabled,
       _amplitude = amplitude,
       _targetLanguage = targetLanguage;

  final List<ChatMessage> _chatMessages = [];
  bool _isListening;
  final bool _speechEnabled;
  bool _audioPlaybackEnabled = true;
  final String _speechError = '';
  String _lastWords = '';
  final double _amplitude;
  @override
  int? preferredSpeaker;
  String _targetLanguage;
  SpeechOutputProvider _outputProvider = SpeechOutputProvider.google;
  SpeechSttProvider _sttProvider = SpeechSttProvider.deepgram;
  SpeechTranslationProvider _translationProvider =
      SpeechTranslationProvider.google;
  String _deepgramRecognitionModel = DeepgramService.defaultRecognitionModel;
  String _deepgramRecognitionLanguage =
      DeepgramService.defaultRecognitionLanguage;
  String _speechToTextRecognitionLocale =
      SpeechToTextService.defaultRecognitionLanguage;
  Map<String, String> _speechToTextRecognitionLocales = const {
    'Multi (Auto)': SpeechToTextService.defaultRecognitionLanguage,
    'English (US)': 'en-US',
  };
  List<InputDevice> _listeningDevices = const [];
  String? _listeningDeviceId;
  List<PlaybackDevice> _playbackDevices = const [];
  String? _playbackDeviceId;
  final StreamController<String> _listeningDeviceUpdatesController =
      StreamController<String>.broadcast();

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

  // SpeechController contract -------------------------------------------------
  @override
  set finalResultGroupingWindow(Duration value) => const Duration(seconds: 1);

  @override
  double get amplitude => _amplitude;

  @override
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  @override
  String get googleApiKey => '';

  @override
  bool get isListening => _isListening;

  @override
  String get speechError => _speechError;

  @override
  bool get speechEnabled => _speechEnabled;

  @override
  bool get audioPlaybackEnabled => _audioPlaybackEnabled;

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
      DeepgramService.supportedRecognitionModels;

  @override
  Map<String, String> get deepgramRecognitionLanguages =>
      DeepgramService
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
  String get targetLanguageName {
    final entry = SpeechController.supportedLanguages.entries.firstWhere(
      (e) => e.value == _targetLanguage,
      orElse: () => MapEntry(_targetLanguage, _targetLanguage),
    );
    return entry.key;
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
  void setAudioPlaybackEnabled(bool enabled) {
    _audioPlaybackEnabled = enabled;
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
      'Multi (Auto)': SpeechToTextService.defaultRecognitionLanguage,
      'English (US)': 'en-US',
      'Spanish (Spain)': 'es-ES',
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
    _listeningDeviceUpdatesController.close();
    super.dispose();
  }
}
