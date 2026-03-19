import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:translation_intelligence/services/deepgram_recognition_catalog.dart';
import 'package:translation_intelligence/services/live_recognition_service.dart';
import 'package:translation_intelligence/services/mlkit_translation_service.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_to_text_service.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

String _resultText(SpeechRecognitionResult result) {
  return result.words.map((word) => word.word).join(' ').trim();
}

class _FakeSpeechToTextPlatform extends SpeechToTextPlatform
    with MockPlatformInterfaceMixin {
  bool initializeResult = true;
  bool hasPermissionResult = true;
  bool listenResult = true;
  bool stopCalled = false;
  bool cancelCalled = false;
  String? lastLocaleId;

  @override
  Future<bool> hasPermission() async => hasPermissionResult;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    return initializeResult;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    lastLocaleId = localeId;
    return listenResult;
  }

  @override
  Future<List<dynamic>> locales() async => const [];

  void emitPartial(String text) {
    onTextRecognition?.call(
      '{"alternates":[{"recognizedWords":"$text","confidence":1.0}],"finalResult":false}',
    );
  }

  void emitFinal(String text) {
    onTextRecognition?.call(
      '{"alternates":[{"recognizedWords":"$text","confidence":1.0}],"finalResult":true}',
    );
  }

  void emitSoundLevel(double level) {
    onSoundLevel?.call(level);
  }

  void emitListeningStatus() {
    onStatus?.call('listening');
  }
}

class _FakeLiveRecognitionService implements LiveRecognitionService {
  bool apiKeyValid = true;
  Stream<SpeechRecognitionResult>? liveRecognitionStream;

  @override
  Future<bool> isApiKeyValid() async => apiKeyValid;

  @override
  Stream<SpeechRecognitionResult> startLiveRecognition(
    Stream<Uint8List> audioStream, {
    required String sourceLanguage,
    String? model,
    String? language,
    bool diarize = false,
    bool utterances = false,
    String sampleRate = '16000',
    bool smartFormat = true,
    bool interimResults = true,
    bool detectLanguage = true,
    bool punctuate = true,
  }) {
    return liveRecognitionStream ??
        const Stream<SpeechRecognitionResult>.empty();
  }
}

class _FakeSpeechToTextService extends SpeechToTextService {
  _FakeSpeechToTextService({this.initResult = true})
    : super(speechToText: SpeechToText.withMethodChannel());

  bool initResult;
  bool startCalled = false;
  bool stopCalled = false;
  String? lastLanguageCode;
  void Function(SpeechRecognitionResult result)? _onResult;
  void Function(double value)? _onAmplitude;

  @override
  Future<bool> initialize({String languageCode = 'en-US'}) async {
    return initResult;
  }

  @override
  Future<void> startListening({
    required String? languageCode,
    required void Function(SpeechRecognitionResult result) onResult,
    required void Function(double value) onAmplitude,
  }) async {
    startCalled = true;
    lastLanguageCode = languageCode;
    _onResult = onResult;
    _onAmplitude = onAmplitude;
  }

  @override
  Future<void> stopListening() async {
    stopCalled = true;
  }

  @override
  String? languageCodeForAppLanguage(String appLang) => 'mapped-$appLang';

  void emitSample() {
    _onAmplitude?.call(0.42);
    _onResult?.call(
      SpeechRecognitionResult.fromTranscript(
        transcript: 'from-google-stt',
        isFinal: false,
      ),
    );
  }
}

class _FakeMlKitTranslationService extends MlKitTranslationService {
  String? lastText;
  String? lastTargetLanguage;
  String? lastSourceLanguage;

  @override
  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    bool returnOriginalOnFailure = true,
    bool nullWhenUnchanged = false,
  }) async {
    lastText = text;
    lastTargetLanguage = targetLanguage;
    lastSourceLanguage = sourceLanguage;
    return 'mlkit-$text-$targetLanguage';
  }
}

class _TestableSpeechPipeline extends SpeechPipeline {
  _TestableSpeechPipeline({
    required super.deepgramApiKey,
    this.recognitionResults = const Stream<SpeechRecognitionResult>.empty(),
  });

  final Stream<SpeechRecognitionResult> recognitionResults;
  bool captureStopCalled = false;

  @override
  Future<MicrophoneCaptureSession> startMicrophoneCapture(
    AudioRecorder recorder, {
    RecordConfig config = const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      noiseSuppress: true,
    ),
    Duration amplitudeInterval = const Duration(milliseconds: 100),
  }) async {
    return MicrophoneCaptureSession(
      audioStream: Stream<Uint8List>.value(Uint8List.fromList(const [1, 2])),
      amplitudeStream: Stream<double>.value(0.66),
      stop: () async {
        captureStopCalled = true;
      },
      sampleRate: config.sampleRate,
    );
  }

  @override
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
    return recognitionResults;
  }
}

class _FakeAudioRecorder extends AudioRecorder {
  _FakeAudioRecorder({this.failStartAttempts = 0, List<Amplitude>? amplitudes})
    : _amplitudes = amplitudes ?? [Amplitude(current: -25.0, max: 0.0)];

  final int failStartAttempts;
  final List<Amplitude> _amplitudes;
  final List<int> sampleRatesTried = <int>[];
  int _startCalls = 0;
  int _amplitudeIndex = 0;
  int stopCalls = 0;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    _startCalls += 1;
    sampleRatesTried.add(config.sampleRate);
    if (_startCalls <= failStartAttempts) {
      throw StateError('start failed for ${config.sampleRate}');
    }
    return Stream<Uint8List>.value(Uint8List.fromList(const [1, 2, 3]));
  }

  @override
  Future<Amplitude> getAmplitude() async {
    final index = _amplitudeIndex < _amplitudes.length
        ? _amplitudeIndex
        : _amplitudes.length - 1;
    _amplitudeIndex += 1;
    return _amplitudes[index];
  }

  @override
  Future<String?> stop() async {
    stopCalls += 1;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async {
          if (call.method == 'create') {
            return 1;
          }
          if (call.method == 'hasPermission') {
            return true;
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  group('Provider label mappings', () {
    test('SpeechOutputProvider labels are correct', () {
      expect(SpeechOutputProvider.google.label, equals('Google'));
      expect(SpeechOutputProvider.deepgram.label, equals('Deepgram'));
    });

    test('SpeechSttProvider labels are correct', () {
      expect(SpeechSttProvider.deepgram.label, equals('Deepgram'));
      expect(SpeechSttProvider.google.label, equals('Speech to Text'));
    });
  });

  group('Deepgram recognition catalog behavior', () {
    test('supported recognition options expose defaults and choices', () {
      expect(
        DeepgramRecognitionCatalog.supportedRecognitionModels,
        contains('nova-3'),
      );
      expect(
        DeepgramRecognitionCatalog.supportedRecognitionModels,
        contains('nova-3-medical'),
      );
      expect(
        DeepgramRecognitionCatalog
            .supportedRecognitionLanguagesByModel['nova-3']?['Multi'],
        equals('multi'),
      );
      expect(
        DeepgramRecognitionCatalog
            .supportedRecognitionLanguagesByModel['nova-3-medical']?['English'],
        equals('en'),
      );
      expect(
        DeepgramRecognitionCatalog.defaultRecognitionModel,
        equals('nova-3'),
      );
      expect(
        DeepgramRecognitionCatalog.defaultRecognitionLanguage,
        equals('multi'),
      );
      expect(
        DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(
          'nova-3-medical',
        ),
        equals('en'),
      );
    });

    test('medical model default language is english', () {
      expect(
        DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(
          'nova-3-medical',
        ),
        equals('en'),
      );
    });
  });

  group('SpeechToTextService language mapping', () {
    late SpeechToTextService service;

    setUp(() {
      service = SpeechToTextService();
    });

    test('languageCodeForAppLanguage maps known values', () {
      expect(service.languageCodeForAppLanguage('multi'), equals('en-US'));
      expect(service.languageCodeForAppLanguage('ja'), equals('ja-JP'));
      expect(service.languageCodeForAppLanguage('zh'), equals('zh-CN'));
    });

    test('languageCodeForAppLanguage falls back to app language', () {
      expect(service.languageCodeForAppLanguage('en-GB'), equals('en-GB'));
    });
  });

  group('SpeechToTextService platform behavior', () {
    late SpeechToTextPlatform originalPlatform;
    late _FakeSpeechToTextPlatform fakePlatform;
    late SpeechToTextService service;

    setUp(() {
      originalPlatform = SpeechToTextPlatform.instance;
      fakePlatform = _FakeSpeechToTextPlatform();
      SpeechToTextPlatform.instance = fakePlatform;
      service = SpeechToTextService(
        speechToText: SpeechToText.withMethodChannel(),
        inactivityFinalizeDelay: const Duration(milliseconds: 100),
      );
    });

    tearDown(() {
      SpeechToTextPlatform.instance = originalPlatform;
    });

    test('initialize returns false when platform init fails', () async {
      fakePlatform.initializeResult = false;
      final ready = await service.initialize();
      expect(ready, isFalse);
    });

    test('startListening throws when platform is unavailable', () async {
      fakePlatform.initializeResult = false;

      expect(
        () => service.startListening(
          languageCode: 'en-US',
          onResult: (_) {},
          onAmplitude: (_) {},
        ),
        throwsException,
      );
    });

    test('startListening calls platform listen with locale', () async {
      await service.startListening(
        languageCode: 'en-US',
        onResult: (_) {},
        onAmplitude: (_) {},
      );

      expect(fakePlatform.lastLocaleId, equals('en-US'));
    });

    test('startListening forwards results and normalized amplitude', () async {
      final results = <SpeechRecognitionResult>[];
      final amplitudes = <double>[];

      await service.startListening(
        languageCode: 'en-US',
        onResult: results.add,
        onAmplitude: amplitudes.add,
      );

      fakePlatform.emitListeningStatus();
      fakePlatform.emitSoundLevel(4.0);
      fakePlatform.emitPartial('hello');
      fakePlatform.emitFinal('hello world');
      await Future<void>.delayed(Duration.zero);

      expect(amplitudes, isNotEmpty);
      expect(amplitudes.last, closeTo(0.5, 0.0001));
      expect(results.length, equals(2));
      expect(_resultText(results.first), equals('hello'));
      expect(results.first.isFinal, isFalse);
      expect(_resultText(results.last), equals('hello world'));
      expect(results.last.isFinal, isTrue);
    });

    test('inactivity timer emits synthetic final result', () {
      fakeAsync((async) {
        final results = <SpeechRecognitionResult>[];

        service.startListening(
          languageCode: 'en-US',
          onResult: results.add,
          onAmplitude: (_) {},
        );
        async.flushMicrotasks();

        fakePlatform.emitPartial('buffered words');
        async.flushMicrotasks();

        expect(results.length, equals(1));
        expect(results.first.isFinal, isFalse);

        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();

        expect(results.length, equals(2));
        expect(_resultText(results.last), equals('buffered words'));
        expect(results.last.isFinal, isTrue);
      });
    });

    test('stopListening calls platform stop', () async {
      await service.startListening(
        languageCode: 'en-US',
        onResult: (_) {},
        onAmplitude: (_) {},
      );

      await service.stopListening();
      expect(fakePlatform.stopCalled, isTrue);
    });
  });

  group('SpeechPipeline provider routing behavior', () {
    late SpeechPipeline pipeline;

    setUp(() {
      pipeline = SpeechPipeline(deepgramApiKey: '');
    });

    test('provider setters update selected providers', () {
      expect(pipeline.outputProvider, equals(SpeechOutputProvider.google));
      expect(pipeline.sttProvider, equals(SpeechSttProvider.deepgram));

      pipeline.setOutputProvider(SpeechOutputProvider.deepgram);
      pipeline.setSttProvider(SpeechSttProvider.google);

      expect(pipeline.outputProvider, equals(SpeechOutputProvider.deepgram));
      expect(pipeline.sttProvider, equals(SpeechSttProvider.google));
    });

    test('deepgram model and language setters track supported values', () {
      expect(
        pipeline.translationProvider,
        equals(SpeechTranslationProvider.google),
      );
      expect(
        pipeline.deepgramRecognitionModel,
        equals(DeepgramRecognitionCatalog.defaultRecognitionModel),
      );
      expect(
        pipeline.deepgramRecognitionLanguage,
        equals(DeepgramRecognitionCatalog.defaultRecognitionLanguage),
      );
      expect(pipeline.deepgramRecognitionModels, contains('nova-3-medical'));

      pipeline.setTranslationProvider(SpeechTranslationProvider.googleMlKit);
      expect(
        pipeline.translationProvider,
        equals(SpeechTranslationProvider.googleMlKit),
      );

      pipeline.setDeepgramRecognitionModel('nova-3-medical');
      expect(pipeline.deepgramRecognitionModel, equals('nova-3-medical'));
      expect(pipeline.deepgramRecognitionLanguage, equals('en'));

      pipeline.setDeepgramRecognitionLanguage('en-GB');
      expect(pipeline.deepgramRecognitionLanguage, equals('en-GB'));

      pipeline.setDeepgramRecognitionLanguage('multi');
      expect(pipeline.deepgramRecognitionLanguage, equals('en-GB'));
      expect(pipeline.deepgramRecognitionLanguages.values, contains('en-US'));
    });

    test(
      'translateText delegates to Google service and uses missing-key fallback',
      () async {
        final translated = await pipeline.translateText(
          text: 'hello',
          targetLanguage: 'es',
        );

        expect(translated, equals('hello'));
      },
    );

    test(
      'translateText delegates to ML Kit when translation provider is googleMlKit',
      () async {
        final mlKit = _FakeMlKitTranslationService();
        final routedPipeline = SpeechPipeline(
          deepgramApiKey: 'd',
          mlKitTranslationService: mlKit,
        )..setTranslationProvider(SpeechTranslationProvider.googleMlKit);

        final translated = await routedPipeline.translateText(
          text: 'hello',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
        );

        expect(translated, equals('mlkit-hello-ja'));
        expect(mlKit.lastText, equals('hello'));
        expect(mlKit.lastSourceLanguage, equals('en'));
        expect(mlKit.lastTargetLanguage, equals('ja'));
      },
    );

    test('synthesizeSpeech uses active output provider branch', () async {
      pipeline.setOutputProvider(SpeechOutputProvider.google);
      final googleBytes = await pipeline.synthesizeSpeech(text: 'hello');
      expect(googleBytes, isEmpty);

      pipeline.setOutputProvider(SpeechOutputProvider.deepgram);
      final deepgramBytes = await pipeline.synthesizeSpeech(text: 'hello');
      expect(deepgramBytes, isEmpty);
    });

    test('ttsLanguageCodeForAppLanguage changes with output provider', () {
      pipeline.setOutputProvider(SpeechOutputProvider.google);
      expect(pipeline.ttsLanguageCodeForAppLanguage('es'), equals('es-ES'));

      pipeline.setOutputProvider(SpeechOutputProvider.deepgram);
      expect(pipeline.ttsLanguageCodeForAppLanguage('ja'), equals('ja'));
    });

    test('isSpeechApiKeyValid delegates by selected STT provider', () async {
      final deepgram = _FakeLiveRecognitionService()..apiKeyValid = true;
      final speechToText = _FakeSpeechToTextService(initResult: false);
      final routedPipeline = SpeechPipeline(
        deepgramApiKey: 'd',
        recognitionService: deepgram,
        speechToTextService: speechToText,
      );

      routedPipeline.setSttProvider(SpeechSttProvider.deepgram);
      expect(await routedPipeline.isSpeechApiKeyValid(), isTrue);

      routedPipeline.setSttProvider(SpeechSttProvider.google);
      expect(await routedPipeline.isSpeechApiKeyValid(), isFalse);
    });

    test(
      'listeningDeviceRouteChanges is safe when platform channel is unavailable',
      () async {
        final stream = pipeline.listeningDeviceRouteChanges();

        expect(stream, emitsDone);
      },
    );

    test('startRecognitionSession routes to Google STT service', () async {
      final speechToText = _FakeSpeechToTextService(initResult: true);
      final routedPipeline = SpeechPipeline(
        deepgramApiKey: 'd',
        speechToTextService: speechToText,
      )..setSttProvider(SpeechSttProvider.google);

      final session = await routedPipeline.startRecognitionSession(
        AudioRecorder(),
        sourceLanguage: 'en',
      );

      final resultFuture = session.resultStream.first;
      final amplitudeFuture = session.amplitudeStream.first;
      speechToText.emitSample();
      final result = await resultFuture;
      final amplitude = await amplitudeFuture;

      expect(speechToText.startCalled, isTrue);
      expect(speechToText.lastLanguageCode, equals('mapped-en'));
      expect(_resultText(result), equals('from-google-stt'));
      expect(amplitude, equals(0.42));

      await session.stop();
      expect(speechToText.stopCalled, isTrue);
    });

    test('startRecognitionSession routes to Deepgram live stream', () async {
      final routedPipeline = _TestableSpeechPipeline(
        deepgramApiKey: 'd',
        recognitionResults: Stream<SpeechRecognitionResult>.value(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'from-deepgram',
            isFinal: true,
          ),
        ),
      )..setSttProvider(SpeechSttProvider.deepgram);

      final session = await routedPipeline.startRecognitionSession(
        AudioRecorder(),
        sourceLanguage: 'en',
      );

      final result = await session.resultStream.first;
      final amplitude = await session.amplitudeStream.first;

      expect(_resultText(result), equals('from-deepgram'));
      expect(amplitude, equals(0.66));

      await session.stop();
      expect(routedPipeline.captureStopCalled, isTrue);
    });

    test('startLiveRecognition delegates to recognition service', () async {
      final deepgram = _FakeLiveRecognitionService()
        ..liveRecognitionStream = Stream<SpeechRecognitionResult>.value(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'delegated-stream',
            isFinal: true,
          ),
        );
      final routedPipeline = SpeechPipeline(
        deepgramApiKey: 'd',
        recognitionService: deepgram,
      );

      final result = await routedPipeline
          .startLiveRecognition(
            Stream<Uint8List>.value(Uint8List.fromList(const [1])),
            sourceLanguage: 'en-US',
          )
          .first;

      expect(_resultText(result), equals('delegated-stream'));
      expect(result.isFinal, isTrue);
    });

    test(
      'startMicrophoneCapture retries sample rates and normalizes amplitude',
      () async {
        final recorder = _FakeAudioRecorder(
          failStartAttempts: 1,
          amplitudes: [Amplitude(current: -25.0, max: 0.0)],
        );

        final session = await pipeline.startMicrophoneCapture(
          recorder,
          amplitudeInterval: const Duration(milliseconds: 1),
        );

        final amplitude = await session.amplitudeStream.first.timeout(
          const Duration(milliseconds: 250),
        );

        expect(session.sampleRate, equals(32000));
        expect(recorder.sampleRatesTried, equals([48000, 32000]));
        expect(recorder.stopCalls, equals(1));
        expect(amplitude, closeTo(0.5, 0.0001));

        await session.stop();
        expect(recorder.stopCalls, equals(2));
      },
    );

    test(
      'startMicrophoneCapture normalizes positive amplitude values',
      () async {
        final recorder = _FakeAudioRecorder(
          amplitudes: [Amplitude(current: 0.75, max: 1.0)],
        );

        final session = await pipeline.startMicrophoneCapture(
          recorder,
          amplitudeInterval: const Duration(milliseconds: 1),
        );

        final amplitude = await session.amplitudeStream.first.timeout(
          const Duration(milliseconds: 250),
        );

        expect(amplitude, equals(0.75));
        await session.stop();
      },
    );

    test('startMicrophoneCapture throws when all sample rates fail', () async {
      final recorder = _FakeAudioRecorder(failStartAttempts: 4);

      await expectLater(
        pipeline.startMicrophoneCapture(recorder),
        throwsA(isA<StateError>()),
      );
      expect(recorder.sampleRatesTried, equals([48000, 32000, 24000, 16000]));
      expect(recorder.stopCalls, equals(4));
    });
  });
}
