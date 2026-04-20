import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/playback_device.dart';
import '../services/backend_api_client.dart';
import '../services/mic_activation_sound_player.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

final _logger = Logger('SpeechSessionController');

class SpeechSessionController extends ChangeNotifier {
  SpeechSessionController({
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

  final SpeechPipeline _speechPipeline;
  final MicActivationSoundPlayer _micActivationSoundPlayer;
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<SpeechRecognitionResult>? _recognitionSub;
  StreamSubscription<double>? _ampSub;
  StreamSubscription<dynamic>? _listeningDeviceChangeSub;

  SpeechRecognitionSession? _recognitionSession;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechError = '';
  double _amplitude = 0.0;

  int? _activeSessionSampleRate;
  SpeechSttProvider? _activeSessionSttProvider;
  String? _activeSessionSourceLanguage;
  String? _activeSessionResolvedLanguageCode;
  String? _activeSessionListeningDeviceId;
  DateTime? _activeSessionStartedAt;

  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];

  final StreamController<String> _listeningDeviceUpdateController =
      StreamController<String>.broadcast();
  final StreamController<SpeechRecognitionResult> _resultStreamController =
      StreamController<SpeechRecognitionResult>.broadcast();

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

  bool get speechEnabled => _speechEnabled;
  bool get isListening => _isListening;
  String get speechError => _speechError;
  double get amplitude => _amplitude;

  int? get activeSessionSampleRate => _activeSessionSampleRate;
  SpeechSttProvider? get activeSessionSttProvider => _activeSessionSttProvider;
  String? get activeSessionSourceLanguage => _activeSessionSourceLanguage;
  String? get activeSessionResolvedLanguageCode =>
      _activeSessionResolvedLanguageCode;
  String? get activeSessionListeningDeviceId => _activeSessionListeningDeviceId;
  DateTime? get activeSessionStartedAt => _activeSessionStartedAt;

  List<InputDevice> get listeningDevices =>
      List<InputDevice>.unmodifiable(_listeningDevices);
  String? get listeningDeviceId => _speechPipeline.listeningDeviceId;
  List<PlaybackDevice> get playbackDevices =>
      List<PlaybackDevice>.unmodifiable(_playbackDevices);
  String? get playbackDeviceId => _speechPipeline.playbackDeviceId;

  Stream<String> get listeningDeviceUpdates =>
      _listeningDeviceUpdateController.stream;
  Stream<SpeechRecognitionResult> get recognitionResults =>
      _resultStreamController.stream;

  Future<void> init() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      _logger.warning('${DateTime.now().toUtc()} Microphone permission denied');
      _speechError = 'microphonePermissionDenied';
      _speechEnabled = false;
      notifyListeners();
      return;
    }

    final isValid = await _speechPipeline.isSpeechApiKeyValid();
    if (!isValid) {
      _logger.warning('${DateTime.now().toUtc()} Invalid speech API key');
      _speechError = 'invalidSpeechApiKey';
      _speechEnabled = false;
      notifyListeners();
      return;
    }

    _speechEnabled = hasPerm && isValid;
    _speechError = '';
    await refreshListeningDevices();
    await refreshPlaybackDevices();

    _listeningDeviceChangeSub ??= _speechPipeline
        .listeningDeviceRouteChanges()
        .listen(
          (event) => unawaited(_handleListeningDeviceRouteChange(event)),
          onError: (_) {},
        );

    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_speechEnabled) return;

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await WakelockPlus.enable();
    } catch (_) {}

    final SpeechRecognitionSession session;
    try {
      session = await _speechPipeline.startRecognitionSession(
        _recorder,
        sourceLanguage:
            _speechPipeline.sttProvider == SpeechSttProvider.deepgram
            ? _speechPipeline.deepgramRecognitionLanguage
            : 'multi',
        diarize: true,
        utterances: true,
      );
    } catch (_) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      rethrow;
    }

    _recognitionSession = session;
    _activeSessionSampleRate = session.sampleRate;
    _activeSessionSttProvider = session.sttProvider;
    _activeSessionSourceLanguage = session.sourceLanguage;
    _activeSessionResolvedLanguageCode = session.resolvedLanguageCode;
    _activeSessionListeningDeviceId = session.listeningDeviceId;
    _activeSessionStartedAt = session.startedAt;

    _recognitionSub?.cancel();
    _recognitionSub = session.resultStream.listen(
      (result) {
        _onRecognitionResult(result);
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleRecognitionSessionFailure(error, stackTrace));
      },
    );

    _ampSub?.cancel();
    _ampSub = session.amplitudeStream.listen((value) {
      _amplitude = value;
      notifyListeners();
    });

    _isListening = true;
    _speechError = '';
    notifyListeners();
    unawaited(_micActivationSoundPlayer.play());
  }

  Future<void> stopListening() async {
    await _stopListeningInternal(clearSpeechError: true);
  }

  Future<void> _stopListeningInternal({required bool clearSpeechError}) async {
    if (!_isListening) return;

    await _recognitionSession?.stop();
    _recognitionSession = null;
    _activeSessionSampleRate = null;
    _activeSessionSttProvider = null;
    _activeSessionSourceLanguage = null;
    _activeSessionResolvedLanguageCode = null;
    _activeSessionListeningDeviceId = null;
    _activeSessionStartedAt = null;

    final recognitionSub = _recognitionSub;
    _recognitionSub = null;
    unawaited(recognitionSub?.cancel());

    await _ampSub?.cancel();
    _ampSub = null;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    _isListening = false;
    _amplitude = 0.0;
    if (clearSpeechError) {
      _speechError = '';
    }
    notifyListeners();
  }

  Future<void> _handleRecognitionSessionFailure(
    Object error,
    StackTrace stackTrace,
  ) async {
    _logger.warning('speech recognition session failed', error, stackTrace);
    if (!_isListening) return;

    _speechError =
        'Listening stopped because the connection could not be resumed. Tap the mic to try again.';
    await _stopListeningInternal(clearSpeechError: false);
  }

  void _onRecognitionResult(SpeechRecognitionResult result) {
    if (result.words.isNotEmpty) {
      _logger.info(
        '${DateTime.now().toUtc()} RECOGNIZED: ${result.wordsToText()} - FINAL: ${result.isFinal} - SPEECH_FINAL: ${result.speechFinal}',
      );
    } else {
      _logger.finest(
        '${DateTime.now().toUtc()} RECOGNIZED RESULT WITH NO WORDS - FINAL: ${result.isFinal} - SPEECH_FINAL: ${result.speechFinal}',
      );
    }

    _resultStreamController.add(result);
    notifyListeners();
  }

  Future<void> refreshListeningDevices() async {
    try {
      _listeningDevices = await _recorder.listInputDevices();
    } catch (_) {
      _listeningDevices = const [];
    }

    final selectedId = _speechPipeline.listeningDeviceId;
    if (selectedId != null &&
        !_listeningDevices.any((device) => device.id == selectedId)) {
      _speechPipeline.setListeningDeviceId(null);
    }
    notifyListeners();
  }

  Future<void> refreshPlaybackDevices() async {
    final devices = await _speechPipeline.listPlaybackDevices();
    _playbackDevices = devices;

    final selectedId = _speechPipeline.playbackDeviceId;
    final currentRouteId = await _speechPipeline.getCurrentPlaybackDeviceId();

    if (selectedId == null) {
      _speechPipeline.setPlaybackDeviceIdLocally(currentRouteId);
    } else if (!_playbackDevices.any((device) => device.id == selectedId)) {
      _speechPipeline.setPlaybackDeviceIdLocally(currentRouteId);
    }

    notifyListeners();
  }

  Future<void> _handleListeningDeviceRouteChange(dynamic event) async {
    final eventName = event is Map
        ? (event['event']?.toString() ?? 'route_changed')
        : 'route_changed';

    final previousSignature = _listeningDevices
        .map((device) => '${device.id}|${device.label}')
        .join(';');
    final previousSelectedId = _speechPipeline.listeningDeviceId;
    final previousPlaybackSignature = _playbackDevices
        .map((device) => '${device.id}|${device.name}|${device.type}')
        .join(';');
    final previousPlaybackSelectedId = _speechPipeline.playbackDeviceId;

    await refreshListeningDevices();
    await refreshPlaybackDevices();

    final updatedSignature = _listeningDevices
        .map((device) => '${device.id}|${device.label}')
        .join(';');
    final updatedSelectedId = _speechPipeline.listeningDeviceId;
    final updatedPlaybackSignature = _playbackDevices
        .map((device) => '${device.id}|${device.name}|${device.type}')
        .join(';');
    final updatedPlaybackSelectedId = _speechPipeline.playbackDeviceId;

    if (previousSignature == updatedSignature &&
        previousSelectedId == updatedSelectedId &&
        previousPlaybackSignature == updatedPlaybackSignature &&
        previousPlaybackSelectedId == updatedPlaybackSelectedId) {
      return;
    }

    String message;
    switch (eventName) {
      case 'devices_added':
        message = 'microphoneConnected';
        break;
      case 'devices_removed':
        message = 'microphoneDisconnected';
        break;
      case 'route_changed':
        message = 'audioRouteChanged';
        break;
      default:
        message = 'listeningDeviceListUpdated';
    }

    if (updatedSelectedId != null) {
      final selected = _listeningDevices
          .where((device) => device.id == updatedSelectedId)
          .cast<InputDevice?>()
          .firstWhere((_) => true, orElse: () => null);
      if (selected != null) {
        final label = selected.label.isNotEmpty ? selected.label : selected.id;
        message = '$message: $label';
      }
    }

    if (!_listeningDeviceUpdateController.isClosed) {
      _listeningDeviceUpdateController.add(message);
    }
  }

  void setListeningDeviceId(String? deviceId) {
    if (_speechPipeline.listeningDeviceId == deviceId) return;
    _speechPipeline.setListeningDeviceId(deviceId);
    notifyListeners();
  }

  Future<bool> setPlaybackDeviceId(String? deviceId) async {
    final applied = await _speechPipeline.setPlaybackDeviceId(deviceId);
    await refreshPlaybackDevices();
    return applied;
  }

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

  @override
  void dispose() {
    unawaited(WakelockPlus.disable().catchError((_) {}));
    _recognitionSub?.cancel();
    _ampSub?.cancel();
    _listeningDeviceChangeSub?.cancel();
    unawaited(_listeningDeviceUpdateController.close());
    unawaited(_resultStreamController.close());
    unawaited(_micActivationSoundPlayer.dispose());
    _recorder.dispose();
    super.dispose();
  }
}
