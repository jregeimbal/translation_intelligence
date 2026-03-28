import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../models/playback_device.dart';
import '../models/speech_recognition_models.dart';
import '../models/speech_recognition_session.dart';
import 'backend_api_client.dart';
import 'deepgram_recognition_catalog.dart';
import 'live_recognition_service.dart';
import 'speech_to_text_service.dart';
import 'speech_output_provider.dart';
import 'speech_stt_provider.dart';
import 'speech_translation_provider.dart';

export '../models/speech_recognition_models.dart'
    show SpeechRecognitionResult, SpeechRecognitionWord;
export '../models/speech_recognition_session.dart'
    show MicrophoneCaptureSession, SpeechRecognitionSession;

class SpeechPipeline {
  static const MethodChannel _audioRecordChannel = MethodChannel(
    'com.jax3.omnialingo/audio_record',
  );
  static const EventChannel _audioRouteEventChannel = EventChannel(
    'com.jax3.omnialingo/audio_route_events',
  );

  static const List<int> _sampleRateFallbackOrder = <int>[
    48000,
    32000,
    24000,
    16000,
  ];

  final BackendApiClient? _backendApiClient;
  final LiveRecognitionService? _recognitionService;
  final SpeechToTextService _speechToTextService;
  SpeechOutputProvider _outputProvider;
  SpeechSttProvider _sttProvider;
  SpeechTranslationProvider _translationProvider;
  String _deepgramRecognitionModel;
  String _deepgramRecognitionLanguage;
  String _speechToTextRecognitionLocale;
  Map<String, String> _speechToTextRecognitionLocales;
  String? _listeningDeviceId;
  String? _playbackDeviceId;

  SpeechPipeline({
    String deepgramApiKey = '',
    BackendApiClient? backendApiClient,
    LiveRecognitionService? recognitionService,
    SpeechOutputProvider initialOutputProvider = SpeechOutputProvider.google,
    SpeechSttProvider initialSttProvider = SpeechSttProvider.deepgram,
    SpeechTranslationProvider initialTranslationProvider =
        SpeechTranslationProvider.google,
    SpeechToTextService? speechToTextService,
  }) : _backendApiClient = backendApiClient,
       _recognitionService = recognitionService,
       _speechToTextService = speechToTextService ?? SpeechToTextService(),
       _outputProvider = initialOutputProvider,
       _sttProvider = initialSttProvider,
       _translationProvider = initialTranslationProvider,
       _deepgramRecognitionModel =
           DeepgramRecognitionCatalog.defaultRecognitionModel,
       _deepgramRecognitionLanguage =
           DeepgramRecognitionCatalog.defaultRecognitionLanguage,
       _speechToTextRecognitionLocale =
           SpeechToTextService.defaultRecognitionLanguage,
       _speechToTextRecognitionLocales = const {
         'multi': SpeechToTextService.defaultRecognitionLanguage,
       };

  SpeechOutputProvider get outputProvider => _outputProvider;
  SpeechSttProvider get sttProvider => _sttProvider;
  SpeechTranslationProvider get translationProvider => _translationProvider;
  String get deepgramRecognitionModel => _deepgramRecognitionModel;
  String get deepgramRecognitionLanguage => _deepgramRecognitionLanguage;
  String get speechToTextRecognitionLocale => _speechToTextRecognitionLocale;
  List<String> get deepgramRecognitionModels =>
      DeepgramRecognitionCatalog.supportedRecognitionModels;
  Map<String, String> get deepgramRecognitionLanguages =>
      DeepgramRecognitionCatalog.supportedRecognitionLanguagesForModel(
        _deepgramRecognitionModel,
      );
  Map<String, String> get speechToTextRecognitionLocales =>
      _speechToTextRecognitionLocales;
  String? get listeningDeviceId => _listeningDeviceId;
  String? get playbackDeviceId => _playbackDeviceId;

  void setOutputProvider(SpeechOutputProvider provider) {
    _outputProvider = provider;
  }

  void setSttProvider(SpeechSttProvider provider) {
    _sttProvider = provider;
  }

  void setTranslationProvider(SpeechTranslationProvider provider) {
    _translationProvider = provider;
  }

  void setDeepgramRecognitionModel(String model) {
    if (!DeepgramRecognitionCatalog.supportedRecognitionModels.contains(
      model,
    )) {
      return;
    }
    _deepgramRecognitionModel = model;
    if (!DeepgramRecognitionCatalog.isRecognitionLanguageSupportedForModel(
      model,
      _deepgramRecognitionLanguage,
    )) {
      _deepgramRecognitionLanguage =
          DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(model);
    }
  }

  void setDeepgramRecognitionLanguage(String language) {
    if (!DeepgramRecognitionCatalog.isRecognitionLanguageSupportedForModel(
      _deepgramRecognitionModel,
      language,
    )) {
      return;
    }
    _deepgramRecognitionLanguage = language;
  }

  Future<void> refreshSpeechToTextRecognitionLocales() async {
    final locales = await _speechToTextService.supportedRecognitionLocales();
    _speechToTextRecognitionLocales = locales;
    if (!_speechToTextRecognitionLocales.containsValue(
      _speechToTextRecognitionLocale,
    )) {
      _speechToTextRecognitionLocale =
          SpeechToTextService.defaultRecognitionLanguage;
    }
  }

  void setSpeechToTextRecognitionLocale(String locale) {
    if (_speechToTextRecognitionLocales.containsValue(locale)) {
      _speechToTextRecognitionLocale = locale;
      return;
    }
    _speechToTextRecognitionLocale =
        SpeechToTextService.defaultRecognitionLanguage;
  }

  void setListeningDeviceId(String? deviceId) {
    _listeningDeviceId = deviceId;
  }

  Future<List<PlaybackDevice>> listPlaybackDevices() async {
    if (kIsWeb) return const [];

    try {
      final rawDevices = await _audioRecordChannel.invokeMethod<List<dynamic>>(
        'getPlaybackDevices',
      );
      if (rawDevices == null) return const [];

      return rawDevices
          .whereType<Map>()
          .map((device) {
            final id = device['id']?.toString() ?? '';
            if (id.isEmpty) {
              return null;
            }
            final name = device['name']?.toString() ?? '';
            final type = device['type']?.toString() ?? '';
            return PlaybackDevice(id: id, name: name, type: type);
          })
          .whereType<PlaybackDevice>()
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<String?> getCurrentPlaybackDeviceId() async {
    if (kIsWeb) return null;

    try {
      return await _audioRecordChannel.invokeMethod<String>(
        'getCurrentPlaybackDeviceId',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> setPlaybackDeviceId(String? deviceId) async {
    if (kIsWeb) {
      _playbackDeviceId = deviceId;
      return false;
    }

    try {
      final applied = await _audioRecordChannel.invokeMethod<bool>(
        'setPlaybackDevice',
        {'deviceId': deviceId},
      );

      if (applied == true) {
        _playbackDeviceId = deviceId;
      }
      return applied ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  void setPlaybackDeviceIdLocally(String? deviceId) {
    _playbackDeviceId = deviceId;
  }

  Stream<dynamic> listeningDeviceRouteChanges() {
    if (kIsWeb) {
      return const Stream<dynamic>.empty();
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return const Stream<dynamic>.empty();
    }

    return _audioRouteEventChannel.receiveBroadcastStream().handleError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (error is MissingPluginException || error is PlatformException) {
        developer.log(
          'Audio route event channel unavailable on this platform: $error',
          name: 'SpeechPipeline',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
      throw error;
    });
  }

  Future<bool> isSpeechApiKeyValid() async {
    switch (_sttProvider) {
      case SpeechSttProvider.deepgram:
        final recognitionService = _recognitionService;
        if (recognitionService != null) {
          return recognitionService.isApiKeyValid();
        }
        final backendApiClient = _backendApiClient;
        if (backendApiClient == null) {
          return false;
        }
        return backendApiClient.isAuthenticated();
      case SpeechSttProvider.google:
        await refreshSpeechToTextRecognitionLocales();
        return _speechToTextService.initialize(
          languageCode:
              _speechToTextRecognitionLocale ==
                  SpeechToTextService.defaultRecognitionLanguage
              ? 'en-US'
              : _speechToTextRecognitionLocale,
        );
    }
  }

  Future<SpeechRecognitionSession> startRecognitionSession(
    AudioRecorder recorder, {
    required String sourceLanguage,
    bool diarize = false,
    bool utterances = false,
    bool punctuate = false,
    bool smartFormat = false,
    bool detectLanguage = false,
  }) async {
    switch (_sttProvider) {
      case SpeechSttProvider.deepgram:
        final capture = await startMicrophoneCapture(recorder);
        final backendApiClient = _backendApiClient;
        if (backendApiClient != null) {
          return backendApiClient.startRecognitionSession(
            audioStream: capture.audioStream,
            amplitudeStream: capture.amplitudeStream,
            stopCapture: capture.stop,
            sampleRate: capture.sampleRate,
            sourceLanguage: sourceLanguage,
            model: _deepgramRecognitionModel,
            language: _deepgramRecognitionLanguage,
            diarize: diarize,
            utterances: utterances,
            punctuate: punctuate,
            smartFormat: smartFormat,
            detectLanguage: detectLanguage,
            listeningDeviceId: _listeningDeviceId,
          );
        }

        final resultStream = startLiveRecognition(
          capture.audioStream,
          sourceLanguage: sourceLanguage,
          sampleRate: capture.sampleRate.toString(),
          diarize: diarize,
          utterances: utterances,
          punctuate: punctuate,
          smartFormat: smartFormat,
          detectLanguage: detectLanguage,
        );

        return SpeechRecognitionSession(
          resultStream: resultStream,
          amplitudeStream: capture.amplitudeStream,
          stop: capture.stop,
          sampleRate: capture.sampleRate,
          sttProvider: SpeechSttProvider.deepgram,
          sourceLanguage: sourceLanguage,
          resolvedLanguageCode: sourceLanguage,
          listeningDeviceId: _listeningDeviceId,
        );
      case SpeechSttProvider.google:
        final resultController =
            StreamController<SpeechRecognitionResult>.broadcast();
        final amplitudeController = StreamController<double>.broadcast();

        await _speechToTextService.startListening(
          languageCode: sourceLanguage == 'multi'
              ? (_speechToTextRecognitionLocale ==
                        SpeechToTextService.defaultRecognitionLanguage
                    ? null
                    : _speechToTextRecognitionLocale)
              : _speechToTextService.languageCodeForAppLanguage(sourceLanguage),
          onResult: (result) {
            if (!resultController.isClosed) {
              resultController.add(result);
            }
          },
          onAmplitude: (value) {
            if (!amplitudeController.isClosed) {
              amplitudeController.add(value);
            }
          },
        );

        Future<void> stop() async {
          await _speechToTextService.stopListening();
          if (!resultController.isClosed) {
            await resultController.close();
          }
          if (!amplitudeController.isClosed) {
            await amplitudeController.close();
          }
        }

        return SpeechRecognitionSession(
          resultStream: resultController.stream,
          amplitudeStream: amplitudeController.stream,
          stop: stop,
          sttProvider: SpeechSttProvider.google,
          sourceLanguage: sourceLanguage,
          resolvedLanguageCode: sourceLanguage == 'multi'
              ? (_speechToTextRecognitionLocale ==
                        SpeechToTextService.defaultRecognitionLanguage
                    ? null
                    : _speechToTextRecognitionLocale)
              : _speechToTextService.languageCodeForAppLanguage(sourceLanguage),
          listeningDeviceId: _listeningDeviceId,
        );
    }
  }

  Future<MicrophoneCaptureSession> startMicrophoneCapture(
    AudioRecorder recorder, {
    RecordConfig config = const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      noiseSuppress: true,
      audioInterruption: AudioInterruptionMode.none,
    ),
    Duration amplitudeInterval = const Duration(milliseconds: 100),
  }) async {
    Object? lastStartError;
    Stream<Uint8List>? audioStream;
    RecordConfig? rateConfig;

    developer.log('Starting microphone capture...', name: 'SpeechPipeline');

    for (final sampleRate in _sampleRateFallbackOrder) {
      final supported = await _isSampleRateSupported(sampleRate);
      if (!supported) {
        continue;
      }

      rateConfig = _configWithSampleRate(config, sampleRate);
      try {
        audioStream = await recorder.startStream(rateConfig);
        break;
      } catch (error) {
        lastStartError = error;
        try {
          await recorder.stop();
        } catch (_) {}
      }
    }

    if (audioStream == null) {
      throw StateError(
        'Unable to start microphone stream for sample rates 48000 to 16000. '
        'Last error: $lastStartError',
      );
    } else {
      developer.log(
        'Microphone capture started (sample rate: ${rateConfig?.sampleRate})...',
        name: 'SpeechPipeline',
      );
    }

    final amplitudeController = StreamController<double>.broadcast();

    final amplitudeTimer = Timer.periodic(amplitudeInterval, (_) async {
      try {
        final amp = await recorder.getAmplitude();
        final value = amp.current <= 0
            ? ((amp.current.clamp(-50.0, 0.0) + 50) / 50)
            : amp.current.clamp(0.0, 1.0);
        if (!amplitudeController.isClosed) {
          amplitudeController.add(value);
        }
      } catch (_) {}
    });

    Future<void> stop() async {
      amplitudeTimer.cancel();
      if (!amplitudeController.isClosed) {
        await amplitudeController.close();
      }
      try {
        await recorder.stop();
      } catch (_) {}
    }

    return MicrophoneCaptureSession(
      audioStream: audioStream,
      amplitudeStream: amplitudeController.stream,
      stop: stop,
      sampleRate: rateConfig?.sampleRate ?? config.sampleRate,
    );
  }

  RecordConfig _configWithSampleRate(RecordConfig config, int sampleRate) {
    return RecordConfig(
      encoder: config.encoder,
      bitRate: config.bitRate,
      sampleRate: sampleRate,
      numChannels: config.numChannels,
      device: _listeningDeviceId == null
          ? config.device
          : InputDevice(id: _listeningDeviceId!, label: ''),
      autoGain: config.autoGain,
      echoCancel: config.echoCancel,
      noiseSuppress: config.noiseSuppress,
      androidConfig: config.androidConfig,
      iosConfig: config.iosConfig,
      audioInterruption: config.audioInterruption,
      streamBufferSize: config.streamBufferSize,
    );
  }

  Future<bool> _isSampleRateSupported(int sampleRate) async {
    if (kIsWeb) {
      return true; // Platform API not available on web
    } else if (!Platform.isAndroid) {
      return true;
    }

    try {
      final minBufferSize = await _audioRecordChannel.invokeMethod<int>(
        'getMinBufferSize',
        {'sampleRate': sampleRate},
      );
      return (minBufferSize ?? 0) > 0;
    } catch (_) {
      return true;
    }
  }

  Stream<SpeechRecognitionResult> startLiveRecognition(
    Stream<Uint8List> audioStream, {
    required String sourceLanguage,
    String? model,
    String? language,
    String sampleRate = '16000',
    bool diarize = false,
    bool utterances = false,
    bool punctuate = false,
    bool smartFormat = false,
    bool detectLanguage = false,
  }) {
    final recognitionService = _recognitionService;
    if (recognitionService == null) {
      return const Stream<SpeechRecognitionResult>.empty();
    }

    return recognitionService.startLiveRecognition(
      audioStream,
      sourceLanguage: sourceLanguage,
      model: model,
      language: language,
      sampleRate: sampleRate,
      diarize: diarize,
      utterances: utterances,
      punctuate: punctuate,
      smartFormat: smartFormat,
      detectLanguage: detectLanguage,
    );
  }

  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    bool returnOriginalOnFailure = true,
    bool throwOnMissingApiKey = false,
    bool nullWhenUnchanged = false,
  }) async {
    final backendApiClient = _backendApiClient;
    if (backendApiClient == null) {
      return returnOriginalOnFailure ? text : null;
    }

    return backendApiClient.translateText(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      returnOriginalOnFailure: returnOriginalOnFailure,
      nullWhenUnchanged: nullWhenUnchanged,
    );
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
    String ssmlGender = 'NEUTRAL',
  }) async {
    final backendApiClient = _backendApiClient;
    if (backendApiClient == null) {
      return Uint8List(0);
    }

    return backendApiClient.synthesizeSpeech(
      text: text,
      provider: _outputProvider,
      languageCode: languageCode,
    );
  }

  String ttsLanguageCodeForAppLanguage(String appLang) {
    switch (_outputProvider) {
      case SpeechOutputProvider.google:
        switch (appLang) {
          case 'en':
            return 'en-US';
          case 'es':
            return 'es-ES';
          case 'fr':
            return 'fr-FR';
          case 'de':
            return 'de-DE';
          case 'zh-CN':
          case 'zh':
            return 'cmn-CN';
          case 'ja':
            return 'ja-JP';
          case 'ko':
            return 'ko-KR';
          case 'pt':
            return 'pt-BR';
          case 'ru':
            return 'ru-RU';
          case 'ar':
            return 'ar-XA';
          case 'hi':
            return 'hi-IN';
          default:
            return appLang.contains('-') ? appLang : '$appLang-US';
        }
      case SpeechOutputProvider.deepgram:
        return appLang;
    }
  }
}
