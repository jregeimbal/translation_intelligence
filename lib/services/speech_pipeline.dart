import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../models/playback_device.dart';
import '../models/speech_recognition_models.dart';
import '../models/speech_recognition_session.dart';
import 'deepgram_service.dart';
import 'google_speech_service.dart';
import 'mlkit_translation_service.dart';
import 'speech_to_text_service.dart';
import 'stts_service.dart';
import 'speech_output_provider.dart';
import 'speech_stt_provider.dart';
import 'speech_translation_provider.dart';

export '../models/speech_recognition_models.dart'
    show SpeechRecognitionResult, SpeechRecognitionWord;
export '../models/speech_recognition_session.dart'
    show MicrophoneCaptureSession, SpeechRecognitionSession;

class SpeechPipeline {
  static const MethodChannel _audioRecordChannel = MethodChannel(
    'com.example.translation_intelligence/audio_record',
  );
  static const EventChannel _audioRouteEventChannel = EventChannel(
    'com.example.translation_intelligence/audio_route_events',
  );

  static const List<int> _sampleRateFallbackOrder = <int>[
    48000,
    32000,
    24000,
    16000,
  ];

  final DeepgramService _recognitionService;
  final DeepgramService _deepgramSpeechService;
  final GoogleSpeechService _googleSpeechService;
  final SpeechToTextService _speechToTextService;
  final SttsService _sttsService;
  final MlKitTranslationService _mlKitTranslationService;
  SpeechOutputProvider _outputProvider;
  SpeechSttProvider _sttProvider;
  SpeechTranslationProvider _translationProvider;
  String _deepgramRecognitionModel;
  String _deepgramRecognitionLanguage;
  String _speechToTextRecognitionLocale;
  Map<String, String> _speechToTextRecognitionLocales;
  String _sttsRecognitionLocale;
  Map<String, String> _sttsRecognitionLocales;
  String? _listeningDeviceId;
  String? _playbackDeviceId;

  SpeechPipeline({
    required String googleApiKey,
    required String deepgramApiKey,
    SpeechOutputProvider initialOutputProvider = SpeechOutputProvider.google,
    SpeechSttProvider initialSttProvider = SpeechSttProvider.deepgram,
    SpeechTranslationProvider initialTranslationProvider =
        SpeechTranslationProvider.google,
    DeepgramService? recognitionService,
    DeepgramService? deepgramSpeechService,
    GoogleSpeechService? googleSpeechService,
    SpeechToTextService? speechToTextService,
    SttsService? sttsService,
    MlKitTranslationService? mlKitTranslationService,
  }) : _recognitionService =
           recognitionService ?? DeepgramService(apiKey: deepgramApiKey),
       _deepgramSpeechService =
           deepgramSpeechService ?? DeepgramService(apiKey: deepgramApiKey),
       _googleSpeechService =
           googleSpeechService ??
           GoogleSpeechService(googleApiKey: googleApiKey),
       _speechToTextService = speechToTextService ?? SpeechToTextService(),
       _sttsService = sttsService ?? SttsService(),
       _mlKitTranslationService =
           mlKitTranslationService ?? MlKitTranslationService(),
       _outputProvider = initialOutputProvider,
       _sttProvider = initialSttProvider,
       _translationProvider = initialTranslationProvider,
       _deepgramRecognitionModel = DeepgramService.defaultRecognitionModel,
       _deepgramRecognitionLanguage =
           DeepgramService.defaultRecognitionLanguage,
       _speechToTextRecognitionLocale =
           SpeechToTextService.defaultRecognitionLanguage,
       _speechToTextRecognitionLocales = const {
         'Multi (Auto)': SpeechToTextService.defaultRecognitionLanguage,
       },
       _sttsRecognitionLocale = SttsService.defaultRecognitionLanguage,
       _sttsRecognitionLocales = const {
         'Multi (Auto)': SttsService.defaultRecognitionLanguage,
       };

  SpeechOutputProvider get outputProvider => _outputProvider;
  SpeechSttProvider get sttProvider => _sttProvider;
  SpeechTranslationProvider get translationProvider => _translationProvider;
  String get deepgramRecognitionModel => _deepgramRecognitionModel;
  String get deepgramRecognitionLanguage => _deepgramRecognitionLanguage;
  String get speechToTextRecognitionLocale => _speechToTextRecognitionLocale;
  String get sttsRecognitionLocale => _sttsRecognitionLocale;
  List<String> get deepgramRecognitionModels =>
      DeepgramService.supportedRecognitionModels;
  Map<String, String> get deepgramRecognitionLanguages => _recognitionService
      .supportedRecognitionLanguagesForModel(_deepgramRecognitionModel);
  Map<String, String> get speechToTextRecognitionLocales =>
      _speechToTextRecognitionLocales;
  Map<String, String> get sttsRecognitionLocales => _sttsRecognitionLocales;
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
    _recognitionService.setRecognitionModel(model);
    _deepgramRecognitionModel = _recognitionService.recognitionModel;
  }

  void setDeepgramRecognitionLanguage(String language) {
    _recognitionService.setRecognitionLanguage(language);
    _deepgramRecognitionLanguage = _recognitionService.recognitionLanguage;
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

  Future<void> refreshSttsRecognitionLocales() async {
    final locales = await _sttsService.supportedRecognitionLocales();
    _sttsRecognitionLocales = locales;
    if (!_sttsRecognitionLocales.containsValue(_sttsRecognitionLocale)) {
      _sttsRecognitionLocale = SttsService.defaultRecognitionLanguage;
    }
  }

  void setSttsRecognitionLocale(String locale) {
    if (_sttsRecognitionLocales.containsValue(locale)) {
      _sttsRecognitionLocale = locale;
      return;
    }
    _sttsRecognitionLocale = SttsService.defaultRecognitionLanguage;
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
        return _recognitionService.isApiKeyValid();
      case SpeechSttProvider.google:
        await refreshSpeechToTextRecognitionLocales();
        return _speechToTextService.initialize(
          languageCode:
              _speechToTextRecognitionLocale ==
                  SpeechToTextService.defaultRecognitionLanguage
              ? 'en-US'
              : _speechToTextRecognitionLocale,
        );
      case SpeechSttProvider.stts:
        await refreshSttsRecognitionLocales();
        return _sttsService.initialize(
          languageCode:
              _sttsRecognitionLocale == SttsService.defaultRecognitionLanguage
              ? null
              : _sttsRecognitionLocale,
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
      case SpeechSttProvider.stts:
        final resultController =
            StreamController<SpeechRecognitionResult>.broadcast();
        final amplitudeController = StreamController<double>.broadcast();

        final sttsLanguageCode = sourceLanguage == 'multi'
            ? (_sttsRecognitionLocale == SttsService.defaultRecognitionLanguage
                  ? null
                  : _sttsRecognitionLocale)
            : _sttsService.languageCodeForAppLanguage(sourceLanguage);

        await _sttsService.startListening(
          languageCode: sttsLanguageCode,
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
          await _sttsService.stopListening();
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
          sttProvider: SpeechSttProvider.stts,
          sourceLanguage: sourceLanguage,
          resolvedLanguageCode: sttsLanguageCode,
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
    return _recognitionService.startLiveRecognition(
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
    switch (_translationProvider) {
      case SpeechTranslationProvider.google:
        return _googleSpeechService.translateText(
          text: text,
          targetLanguage: targetLanguage,
          returnOriginalOnFailure: returnOriginalOnFailure,
          throwOnMissingApiKey: throwOnMissingApiKey,
          nullWhenUnchanged: nullWhenUnchanged,
        );
      case SpeechTranslationProvider.googleMlKit:
        return _mlKitTranslationService.translateText(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
          returnOriginalOnFailure: returnOriginalOnFailure,
          nullWhenUnchanged: nullWhenUnchanged,
        );
    }
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
    String ssmlGender = 'NEUTRAL',
  }) async {
    switch (_outputProvider) {
      case SpeechOutputProvider.google:
        return _googleSpeechService.synthesizeSpeech(
          text: text,
          languageCode: languageCode,
          ssmlGender: ssmlGender,
        );
      case SpeechOutputProvider.deepgram:
        return _deepgramSpeechService.synthesizeSpeech(
          text: text,
          languageCode: languageCode,
        );
      case SpeechOutputProvider.stts:
        return _sttsService.synthesizeSpeech(
          text: text,
          languageCode: languageCode,
        );
    }
  }

  String ttsLanguageCodeForAppLanguage(String appLang) {
    switch (_outputProvider) {
      case SpeechOutputProvider.google:
        return _googleSpeechService.ttsLanguageCodeForAppLanguage(appLang);
      case SpeechOutputProvider.deepgram:
        return appLang;
      case SpeechOutputProvider.stts:
        return appLang;
    }
  }
}
