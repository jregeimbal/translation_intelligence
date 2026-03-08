import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'deepgram_service.dart';
import 'google_speech_service.dart';
import 'mlkit_translation_service.dart';
import 'speech_to_text_service.dart';
import 'stts_service.dart';
import 'speech_output_provider.dart';
import 'speech_recognition_models.dart';
import 'speech_stt_provider.dart';
import 'speech_translation_provider.dart';

export 'speech_recognition_models.dart' show SpeechRecognitionResult, SpeechRecognitionWord;

class MicrophoneCaptureSession {
  final Stream<Uint8List> audioStream;
  final Stream<double> amplitudeStream;
  final Future<void> Function() stop;
  final int sampleRate;

  const MicrophoneCaptureSession({
    required this.audioStream,
    required this.amplitudeStream,
    required this.stop,
    required this.sampleRate,
  });
}

class SpeechRecognitionSession {
  final Stream<SpeechRecognitionResult> resultStream;
  final Stream<double> amplitudeStream;
  final Future<void> Function() stop;

  const SpeechRecognitionSession({
    required this.resultStream,
    required this.amplitudeStream,
    required this.stop,
  });
}

class SpeechPipeline {
  static const MethodChannel _audioRecordChannel =
      MethodChannel('com.example.translation_intelligence/audio_record');

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
  })  : _recognitionService =
            recognitionService ?? DeepgramService(apiKey: deepgramApiKey),
        _deepgramSpeechService =
            deepgramSpeechService ?? DeepgramService(apiKey: deepgramApiKey),
        _googleSpeechService =
            googleSpeechService ?? GoogleSpeechService(googleApiKey: googleApiKey),
        _speechToTextService = speechToTextService ?? SpeechToTextService(),
        _sttsService = sttsService ?? SttsService(),
        _mlKitTranslationService = mlKitTranslationService ?? MlKitTranslationService(),
        _outputProvider = initialOutputProvider,
        _sttProvider = initialSttProvider,
        _translationProvider = initialTranslationProvider;

  SpeechOutputProvider get outputProvider => _outputProvider;
  SpeechSttProvider get sttProvider => _sttProvider;
  SpeechTranslationProvider get translationProvider => _translationProvider;

  void setOutputProvider(SpeechOutputProvider provider) {
    _outputProvider = provider;
  }

  void setSttProvider(SpeechSttProvider provider) {
    _sttProvider = provider;
  }

  void setTranslationProvider(SpeechTranslationProvider provider) {
    _translationProvider = provider;
  }

  Future<bool> isSpeechApiKeyValid() {
    switch (_sttProvider) {
      case SpeechSttProvider.deepgram:
        return _recognitionService.isApiKeyValid();
      case SpeechSttProvider.google:
        return _speechToTextService.initialize();
      case SpeechSttProvider.stts:
        return _sttsService.initialize();
    }
  }

  Future<SpeechRecognitionSession> startRecognitionSession(
    AudioRecorder recorder, {
    required String sourceLanguage,
    bool diarize = false,
    bool utterances = false,
  }) async {
    switch (_sttProvider) {
      case SpeechSttProvider.deepgram:
        final capture = await startMicrophoneCapture(recorder);
        final resultStream = startLiveRecognition(
          capture.audioStream,
          sourceLanguage: sourceLanguage,
          diarize: diarize,
          utterances: utterances,
          sampleRate: capture.sampleRate.toString(),
        );

        return SpeechRecognitionSession(
          resultStream: resultStream,
          amplitudeStream: capture.amplitudeStream,
          stop: capture.stop,
        );
      case SpeechSttProvider.google:
        final resultController = StreamController<SpeechRecognitionResult>.broadcast();
        final amplitudeController = StreamController<double>.broadcast();

        await _speechToTextService.startListening(
          languageCode: _speechToTextService.languageCodeForAppLanguage(
              sourceLanguage),
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
        );
      case SpeechSttProvider.stts:
        final resultController = StreamController<SpeechRecognitionResult>.broadcast();
        final amplitudeController = StreamController<double>.broadcast();

        await _sttsService.startListening(
          languageCode: _sttsService.languageCodeForAppLanguage(sourceLanguage),
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
      developer.log('Microphone capture started (sample rate: ${rateConfig?.sampleRate})...', name: 'SpeechPipeline');
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
      device: config.device,
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
      final minBufferSize =
          await _audioRecordChannel.invokeMethod<int>('getMinBufferSize', {
        'sampleRate': sampleRate,
      });
      return (minBufferSize ?? 0) > 0;
    } catch (_) {
      return true;
    }
  }

  Stream<SpeechRecognitionResult> startLiveRecognition(
    Stream<Uint8List> audioStream, {
    required String sourceLanguage,
    bool diarize = false,
    bool utterances = false,
    String sampleRate = '16000',
  }) {
    return _recognitionService.startLiveRecognition(
      audioStream,
      sourceLanguage: sourceLanguage,
      diarize: diarize,
      utterances: utterances,
      sampleRate: sampleRate,
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
