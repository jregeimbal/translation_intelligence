import 'package:flutter/material.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_recognition_models.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

/// Lightweight stub of SpeechController for widget tests. Avoids plugins
/// and network calls while allowing manual control of state.
class TestSpeechController extends ChangeNotifier implements SpeechController {
  TestSpeechController({
    bool isListening = false,
    bool speechEnabled = true,
    double amplitude = 0.0,
    String targetLanguage = 'en',
  })  : _isListening = isListening,
        _speechEnabled = speechEnabled,
        _amplitude = amplitude,
        _targetLanguage = targetLanguage;

  final List<ChatMessage> _chatMessages = [];
  bool _isListening;
  final bool _speechEnabled;
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

  void addMessage(ChatMessage msg) {
    _chatMessages.add(msg);
    notifyListeners();
  }

  void setListeningState({required bool isListening, String lastWords = ''}) {
    _isListening = isListening;
    _lastWords = lastWords;
    notifyListeners();
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
  List<ChatMessage> getOptimisticMessages() {
    if (_lastWords.trim().isEmpty) return const [];
    return [ChatMessage(_lastWords.trim(), isFinal: false)];
  }

  @override
  List<ChatMessage> wordsToMessages(List<ChatMessage> oldMessages, Iterable<SpeechRecognitionWord> words, {bool isFinal = false}) {
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
}
