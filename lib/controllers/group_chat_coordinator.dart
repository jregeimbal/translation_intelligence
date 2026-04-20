import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../models/chat_message.dart';
import '../models/playback_device.dart';
import '../models/queued_chat_message.dart';
import '../models/suggested_response.dart';
import '../services/backend_api_client.dart';
import '../services/mic_activation_sound_player.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

import 'message_processor_controller.dart';
import 'speech_session_controller.dart';
import 'suggestion_controller.dart';
import 'translation_controller.dart';

class GroupChatCoordinator extends ChangeNotifier {

  GroupChatCoordinator({
    BackendApiClient? backendApiClient,
    Duration audioPlaybackCompletionTimeout = const Duration(seconds: 30),
    Duration finalResultGroupingWindow = const Duration(seconds: 2),
    MicActivationSoundPlayer? micActivationSoundPlayer,
    SpeechPipeline? speechPipeline,
    String deepgramApiKey = '',
  }) : _speechSessionController = SpeechSessionController(
          deepgramApiKey: deepgramApiKey,
          backendApiClient: backendApiClient,
          speechPipeline: speechPipeline,
          micActivationSoundPlayer:
              micActivationSoundPlayer ?? DefaultMicActivationSoundPlayer(),
        ),
        _messageProcessorController = MessageProcessorController(
          finalResultGroupingWindow: finalResultGroupingWindow,
        ),
        _translationController = TranslationController(
          speechPipeline: speechPipeline,
          audioPlaybackCompletionTimeout: audioPlaybackCompletionTimeout,
        ),
        _suggestionController = SuggestionController(
          backendApiClient: backendApiClient,
        ) {
    _setupSubscriptions();
  }
  final SpeechSessionController _speechSessionController;
  final MessageProcessorController _messageProcessorController;
  final TranslationController _translationController;
  final SuggestionController _suggestionController;

  void _setupSubscriptions() {
    _speechSessionController.recognitionResults.listen((result) {
      _messageProcessorController.onRecognitionResult(result);
    });
  }

  bool get speechEnabled => _speechSessionController.speechEnabled;
  bool get isListening => _speechSessionController.isListening;
  String get speechError => _speechSessionController.speechError;
  double get amplitude => _speechSessionController.amplitude;

  bool get audioPlaybackEnabled => _translationController.audioPlaybackEnabled;
  String get targetLanguage => _translationController.targetLanguage;
  bool get hasSupportedTargetLanguage =>
      _translationController.hasSupportedTargetLanguage;

  int? get preferredSpeaker => _messageProcessorController.preferredSpeaker;
  List<ChatMessage> get chatMessages =>
      List.unmodifiable(_messageProcessorController.chatMessages);
  List<QueuedChatMessage> get queuedMessages =>
      List.unmodifiable(_messageProcessorController.queuedMessages);

  SpeechOutputProvider get outputProvider =>
      _speechSessionController.outputProvider;
  SpeechSttProvider get sttProvider => _speechSessionController.sttProvider;
  SpeechTranslationProvider get translationProvider =>
      _speechSessionController.translationProvider;
  String get deepgramRecognitionModel =>
      _speechSessionController.deepgramRecognitionModel;
  String get deepgramRecognitionLanguage =>
      _speechSessionController.deepgramRecognitionLanguage;
  String get speechToTextRecognitionLocale =>
      _speechSessionController.speechToTextRecognitionLocale;
  List<String> get deepgramRecognitionModels =>
      _speechSessionController.deepgramRecognitionModels;
  Map<String, String> get deepgramRecognitionLanguages =>
      _speechSessionController.deepgramRecognitionLanguages;
  Map<String, String> get speechToTextRecognitionLocales =>
      _speechSessionController.speechToTextRecognitionLocales;

  List<InputDevice> get listeningDevices =>
      _speechSessionController.listeningDevices;
  String? get listeningDeviceId => _speechSessionController.listeningDeviceId;
  List<PlaybackDevice> get playbackDevices =>
      _speechSessionController.playbackDevices;
  String? get playbackDeviceId => _speechSessionController.playbackDeviceId;

  Stream<String> get listeningDeviceUpdates =>
      _speechSessionController.listeningDeviceUpdates;
  Stream<SuggestedResponseEvent> get suggestedResponses =>
      _suggestionController.suggestedResponses;

  int? get activeSessionSampleRate =>
      _speechSessionController.activeSessionSampleRate;
  SpeechSttProvider? get activeSessionSttProvider =>
      _speechSessionController.activeSessionSttProvider;
  String? get activeSessionSourceLanguage =>
      _speechSessionController.activeSessionSourceLanguage;
  String? get activeSessionResolvedLanguageCode =>
      _speechSessionController.activeSessionResolvedLanguageCode;
  String? get activeSessionListeningDeviceId =>
      _speechSessionController.activeSessionListeningDeviceId;
  DateTime? get activeSessionStartedAt =>
      _speechSessionController.activeSessionStartedAt;

  Future<void> init() async {
    await _speechSessionController.init();
    notifyListeners();
  }

  Future<void> startListening() async {
    await _speechSessionController.startListening();
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _speechSessionController.stopListening();
    _messageProcessorController.stopListening();
    notifyListeners();
  }

  void setPreferredSpeaker(int? speaker) {
    _messageProcessorController.setPreferredSpeaker(speaker);
    _suggestionController.setPreferredSpeaker(speaker);
    notifyListeners();
  }

  void clearMessages() {
    _messageProcessorController.clearMessages();
    notifyListeners();
  }

  void setAudioPlaybackEnabled({required bool enabled}) {
    _translationController.setAudioPlaybackEnabled(enabled: enabled);
    notifyListeners();
  }

  void setTargetLanguage(String lang) {
    _translationController.setTargetLanguage(lang);
    notifyListeners();
  }

  void setOutputProvider(SpeechOutputProvider provider) {
    _speechSessionController.setOutputProvider(provider);
    notifyListeners();
  }

  void setSttProvider(SpeechSttProvider provider) {
    _speechSessionController.setSttProvider(provider);
    notifyListeners();
  }

  void setTranslationProvider(SpeechTranslationProvider provider) {
    _speechSessionController.setTranslationProvider(provider);
    notifyListeners();
  }

  void setDeepgramRecognitionModel(String model) {
    _speechSessionController.setDeepgramRecognitionModel(model);
    notifyListeners();
  }

  void setDeepgramRecognitionLanguage(String language) {
    _speechSessionController.setDeepgramRecognitionLanguage(language);
    notifyListeners();
  }

  void setSpeechToTextRecognitionLocale(String locale) {
    _speechSessionController.setSpeechToTextRecognitionLocale(locale);
    notifyListeners();
  }

  Future<void> refreshSpeechToTextRecognitionLocales() async {
    await _speechSessionController.refreshSpeechToTextRecognitionLocales();
    notifyListeners();
  }

  Future<void> refreshListeningDevices() async {
    await _speechSessionController.refreshListeningDevices();
    notifyListeners();
  }

  Future<void> refreshPlaybackDevices() async {
    await _speechSessionController.refreshPlaybackDevices();
    notifyListeners();
  }

  void setListeningDeviceId(String? deviceId) {
    _speechSessionController.setListeningDeviceId(deviceId);
    notifyListeners();
  }

  Future<bool> setPlaybackDeviceId(String? deviceId) async {
    final applied = await _speechSessionController.setPlaybackDeviceId(deviceId);
    notifyListeners();
    return applied;
  }

  Future<void> replayTranslation(ChatMessage message) async {
    await _translationController.replayTranslation(message);
  }

  @override
  void dispose() {
    _speechSessionController.dispose();
    _messageProcessorController.dispose();
    _translationController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }
}
