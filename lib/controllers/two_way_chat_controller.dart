import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/two_way_message.dart';
import '../services/app_language_catalog.dart';
import '../services/backend_api_client.dart';
import '../services/mic_activation_sound_player.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

class TwoWayChatController extends ChangeNotifier {
  final SpeechPipeline _speechPipeline;
  final MicActivationSoundPlayer _micActivationSoundPlayer;
  final AudioRecorder _recorder = AudioRecorder();
  AudioPlayer? _audioPlayer;

  StreamSubscription<SpeechRecognitionResult>? _listenSub;
  StreamSubscription<double>? _ampSub;
  SpeechRecognitionSession? _recognitionSession;
  int? _activeSessionSampleRate;
  SpeechSttProvider? _activeSessionSttProvider;
  String? _activeSessionSourceLanguage;
  String? _activeSessionResolvedLanguageCode;
  String? _activeSessionListeningDeviceId;
  DateTime? _activeSessionStartedAt;
  int _listenSessionId = 0;

  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechError = '';
  String _lastWords = '';
  double _amplitude = 0.0;
  TwoWaySpeaker? _activeSpeaker;

  String _primaryLanguage = 'en';
  String _guestLanguage = 'es';

  final List<TwoWayMessage> _messages = [];
  TwoWayChatController({
    String deepgramApiKey = '',
    BackendApiClient? backendApiClient,
    SpeechPipeline? speechPipeline,
    MicActivationSoundPlayer? micActivationSoundPlayer,
  }) : _speechPipeline =
           speechPipeline ??
           SpeechPipeline(
             deepgramApiKey: deepgramApiKey,
             backendApiClient: backendApiClient,
           ),
       _micActivationSoundPlayer =
           micActivationSoundPlayer ?? DefaultMicActivationSoundPlayer();

  bool get speechEnabled => _speechEnabled;
  bool get isListening => _isListening;
  String get speechError => _speechError;
  String get lastWords => _lastWords;
  double get amplitude => _amplitude;
  TwoWaySpeaker? get activeSpeaker => _activeSpeaker;
  SpeechOutputProvider get outputProvider => _speechPipeline.outputProvider;
  SpeechSttProvider get sttProvider => _speechPipeline.sttProvider;
  SpeechTranslationProvider get translationProvider =>
      _speechPipeline.translationProvider;
  String get deepgramRecognitionModel =>
      _speechPipeline.deepgramRecognitionModel;
  String get deepgramRecognitionLanguage =>
      _speechPipeline.deepgramRecognitionLanguage;
  String get speechToTextRecognitionLocale =>
      _speechPipeline.speechToTextRecognitionLocale;
  List<String> get deepgramRecognitionModels =>
      _speechPipeline.deepgramRecognitionModels;
  Map<String, String> get deepgramRecognitionLanguages =>
      _speechPipeline.deepgramRecognitionLanguages;
  Map<String, String> get speechToTextRecognitionLocales =>
      _speechPipeline.speechToTextRecognitionLocales;
  int? get activeSessionSampleRate => _activeSessionSampleRate;
  SpeechSttProvider? get activeSessionSttProvider => _activeSessionSttProvider;
  String? get activeSessionSourceLanguage => _activeSessionSourceLanguage;
  String? get activeSessionResolvedLanguageCode =>
      _activeSessionResolvedLanguageCode;
  String? get activeSessionListeningDeviceId => _activeSessionListeningDeviceId;
  DateTime? get activeSessionStartedAt => _activeSessionStartedAt;

  String get primaryLanguage => _primaryLanguage;
  String get guestLanguage => _guestLanguage;

  List<TwoWayMessage> get messages => List.unmodifiable(_messages);

  bool get canChangeLanguages => _messages.isEmpty && !_isListening;

  void setOutputProvider(SpeechOutputProvider provider) {
    if (_speechPipeline.outputProvider == provider) return;
    _speechPipeline.setOutputProvider(provider);
    notifyListeners();
  }

  void setSttProvider(SpeechSttProvider provider) {
    if (_speechPipeline.sttProvider == provider) return;
    _speechPipeline.setSttProvider(provider);
    notifyListeners();
  }

  void setTranslationProvider(SpeechTranslationProvider provider) {
    if (_speechPipeline.translationProvider == provider) return;
    _speechPipeline.setTranslationProvider(provider);
    notifyListeners();
  }

  void setDeepgramRecognitionModel(String model) {
    if (_speechPipeline.deepgramRecognitionModel == model) return;
    _speechPipeline.setDeepgramRecognitionModel(model);
    notifyListeners();
  }

  void setDeepgramRecognitionLanguage(String language) {
    if (_speechPipeline.deepgramRecognitionLanguage == language) return;
    _speechPipeline.setDeepgramRecognitionLanguage(language);
    notifyListeners();
  }

  void setSpeechToTextRecognitionLocale(String locale) {
    if (_speechPipeline.speechToTextRecognitionLocale == locale) return;
    _speechPipeline.setSpeechToTextRecognitionLocale(locale);
    notifyListeners();
  }

  Future<void> refreshSpeechToTextRecognitionLocales() async {
    await _speechPipeline.refreshSpeechToTextRecognitionLocales();
    notifyListeners();
  }

  void setListeningDeviceId(String? deviceId) {
    if (_speechPipeline.listeningDeviceId == deviceId) return;
    _speechPipeline.setListeningDeviceId(deviceId);
    notifyListeners();
  }

  Future<bool> setPlaybackDeviceId(String? deviceId) async {
    final applied = await _speechPipeline.setPlaybackDeviceId(deviceId);
    notifyListeners();
    return applied;
  }

  static const List<String> supportedLanguages =
      AppLanguageCatalog.supportedLanguageCodes;

  Future<void> init() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      _speechError = 'microphonePermissionDenied';
      _speechEnabled = false;
      notifyListeners();
      return;
    }

    final isValid = await _speechPipeline.isSpeechApiKeyValid();
    if (!isValid) {
      _speechError = 'invalidSpeechApiKey';
      _speechEnabled = false;
      notifyListeners();
      return;
    }

    _speechEnabled = true;
    _speechError = '';
    notifyListeners();
  }

  void setPrimaryLanguage(String languageCode) {
    if (!canChangeLanguages || languageCode == _primaryLanguage) return;
    _primaryLanguage = languageCode;
    notifyListeners();
  }

  void setGuestLanguage(String languageCode) {
    if (!canChangeLanguages || languageCode == _guestLanguage) return;
    _guestLanguage = languageCode;
    notifyListeners();
  }

  Future<void> toggleListening(TwoWaySpeaker speaker) async {
    if (!_speechEnabled) return;

    if (_isListening && _activeSpeaker == speaker) {
      await stopListening();
      return;
    }

    if (_isListening && _activeSpeaker != speaker) {
      return;
    }

    await startListening(speaker);
  }

  Future<void> startListening(TwoWaySpeaker speaker) async {
    if (!_speechEnabled || _isListening) return;

    final sourceLang = speaker == TwoWaySpeaker.primary
        ? _primaryLanguage
        : _guestLanguage;
    final targetLang = speaker == TwoWaySpeaker.primary
        ? _guestLanguage
        : _primaryLanguage;

    _listenSessionId += 1;
    final currentSession = _listenSessionId;

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await WakelockPlus.enable();
    } catch (_) {}

    final session = await _speechPipeline.startRecognitionSession(
      _recorder,
      sourceLanguage: sourceLang,
    );
    _recognitionSession = session;
    _activeSessionSampleRate = session.sampleRate;
    _activeSessionSttProvider = session.sttProvider;
    _activeSessionSourceLanguage = session.sourceLanguage;
    _activeSessionResolvedLanguageCode = session.resolvedLanguageCode;
    _activeSessionListeningDeviceId = session.listeningDeviceId;
    _activeSessionStartedAt = session.startedAt;
    _ampSub?.cancel();
    _ampSub = session.amplitudeStream.listen((value) {
      _amplitude = value;
      notifyListeners();
    });

    _isListening = true;
    _activeSpeaker = speaker;
    _lastWords = '';
    notifyListeners();
    unawaited(_micActivationSoundPlayer.play());

    _listenSub = session.resultStream.listen((result) {
      unawaited(
        _onRecognitionResult(
          result: result,
          sourceSpeaker: speaker,
          targetLang: targetLang,
          sessionId: currentSession,
        ),
      );
    });
  }

  Future<void> _onRecognitionResult({
    required SpeechRecognitionResult result,
    required TwoWaySpeaker sourceSpeaker,
    required String targetLang,
    required int sessionId,
  }) async {
    if (sessionId != _listenSessionId) return;

    _lastWords = result.wordsToText();

    if (result.isFinal && _lastWords.trim().isNotEmpty) {
      final sourceText = _lastWords.trim();
      final sourceLang = sourceSpeaker == TwoWaySpeaker.primary
          ? _primaryLanguage
          : _guestLanguage;
      final translated = await _translateText(
        sourceText,
        sourceLang,
        targetLang,
      );
      if (sessionId != _listenSessionId) return;

      final primaryText = sourceSpeaker == TwoWaySpeaker.primary
          ? sourceText
          : translated;
      final guestText = sourceSpeaker == TwoWaySpeaker.guest
          ? sourceText
          : translated;

      _messages.add(
        TwoWayMessage(
          speaker: sourceSpeaker,
          primaryText: primaryText,
          guestText: guestText,
        ),
      );
      unawaited(_synthesizeAndPlayTranslated(translated, targetLang));
      _lastWords = '';
      notifyListeners();
      await stopListening();
      return;
    }

    notifyListeners();
  }

  Future<String> _translateText(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    return (await _speechPipeline.translateText(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          returnOriginalOnFailure: true,
        )) ??
        text;
  }

  Future<void> _synthesizeAndPlayTranslated(
    String translatedText,
    String targetLanguage,
  ) async {
    try {
      final audioBytes = await _speechPipeline.synthesizeSpeech(
        text: translatedText,
        languageCode: _speechPipeline.ttsLanguageCodeForAppLanguage(
          targetLanguage,
        ),
      );
      if (audioBytes.isEmpty) return;
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.play(BytesSource(audioBytes));
    } catch (_) {}
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    await _recognitionSession?.stop();
    _recognitionSession = null;
    _activeSessionSampleRate = null;
    _activeSessionSttProvider = null;
    _activeSessionSourceLanguage = null;
    _activeSessionResolvedLanguageCode = null;
    _activeSessionListeningDeviceId = null;
    _activeSessionStartedAt = null;
    await _ampSub?.cancel();
    _ampSub = null;

    await _listenSub?.cancel();
    _listenSub = null;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    _isListening = false;
    _activeSpeaker = null;
    _amplitude = 0.0;
    _lastWords = '';
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(stopListening());
    unawaited(_recognitionSession?.stop() ?? Future.value());
    unawaited(_ampSub?.cancel() ?? Future.value());
    _audioPlayer?.dispose();
    unawaited(_micActivationSoundPlayer.dispose());
    unawaited(_recorder.dispose().catchError((_) {}));
    super.dispose();
  }
}
