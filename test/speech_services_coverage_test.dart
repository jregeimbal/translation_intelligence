import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:translation_intelligence/services/deepgram_service.dart';
import 'package:translation_intelligence/services/google_speech_service.dart';
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

class _FakeDeepgramService extends DeepgramService {
  _FakeDeepgramService() : super(apiKey: 'fake-key');

  bool apiKeyValid = true;
  List<int> synthBytes = const [9, 8, 7];
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

  @override
  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en',
  }) async {
    return Uint8List.fromList(synthBytes);
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
    required super.googleApiKey,
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

class _FakeDeepgramWord {
  const _FakeDeepgramWord({required this.word, required this.speaker});

  final String word;
  final int speaker;
}

class _FakeDeepgramRecognition {
  const _FakeDeepgramRecognition({
    required this.transcript,
    required this.isFinal,
    required this.words,
  });

  final String transcript;
  final bool isFinal;
  final List<_FakeDeepgramWord> words;
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

  group('GoogleSpeechService non-network behavior', () {
    late GoogleSpeechService service;

    setUp(() {
      service = GoogleSpeechService(googleApiKey: '');
    });

    test(
      'translateText returns original text when key is missing by default',
      () async {
        final translated = await service.translateText(
          text: 'hello',
          targetLanguage: 'es',
        );

        expect(translated, equals('hello'));
      },
    );

    test(
      'translateText returns null when key is missing and fallback is disabled',
      () async {
        final translated = await service.translateText(
          text: 'hello',
          targetLanguage: 'es',
          returnOriginalOnFailure: false,
        );

        expect(translated, isNull);
      },
    );

    test(
      'translateText throws when missing key and throwOnMissingApiKey is true',
      () async {
        expect(
          () => service.translateText(
            text: 'hello',
            targetLanguage: 'es',
            throwOnMissingApiKey: true,
          ),
          throwsException,
        );
      },
    );

    test('synthesizeSpeech returns empty bytes when key is missing', () async {
      final bytes = await service.synthesizeSpeech(text: 'hello');
      expect(bytes, isEmpty);
    });

    test(
      'ttsLanguageCodeForAppLanguage maps known values and fallback rules',
      () {
        expect(service.ttsLanguageCodeForAppLanguage('es'), equals('es-ES'));
        expect(service.ttsLanguageCodeForAppLanguage('zh'), equals('cmn-CN'));
        expect(service.ttsLanguageCodeForAppLanguage('xx'), equals('xx-US'));
        expect(service.ttsLanguageCodeForAppLanguage('en-GB'), equals('en-GB'));
      },
    );

    test(
      'translateText returns translated value on successful API response',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': {
                'translations': [
                  {'translatedText': 'hola'},
                ],
              },
            }),
            200,
          );
        });
        final apiService = GoogleSpeechService(
          googleApiKey: 'key',
          httpClient: client,
        );

        final translated = await apiService.translateText(
          text: 'hello',
          targetLanguage: 'es',
        );

        expect(translated, equals('hola'));
      },
    );

    test(
      'translateText throws when API status is non-200 and fallback disabled',
      () async {
        final client = MockClient((request) async => http.Response('bad', 500));
        final apiService = GoogleSpeechService(
          googleApiKey: 'key',
          httpClient: client,
        );

        expect(
          () => apiService.translateText(
            text: 'hello',
            targetLanguage: 'es',
            returnOriginalOnFailure: false,
          ),
          throwsException,
        );
      },
    );

    test(
      'translateText throws on invalid response shape when fallback disabled',
      () async {
        final client = MockClient((request) async => http.Response('{}', 200));
        final apiService = GoogleSpeechService(
          googleApiKey: 'key',
          httpClient: client,
        );

        expect(
          () => apiService.translateText(
            text: 'hello',
            targetLanguage: 'es',
            returnOriginalOnFailure: false,
          ),
          throwsException,
        );
      },
    );

    test(
      'translateText returns null when unchanged and nullWhenUnchanged is true',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': {
                'translations': [
                  {'translatedText': 'hello'},
                ],
              },
            }),
            200,
          );
        });
        final apiService = GoogleSpeechService(
          googleApiKey: 'key',
          httpClient: client,
        );

        final translated = await apiService.translateText(
          text: 'hello',
          targetLanguage: 'en',
          nullWhenUnchanged: true,
        );

        expect(translated, isNull);
      },
    );

    test('synthesizeSpeech decodes audioContent when API succeeds', () async {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'audioContent': base64Encode(bytes)}),
          200,
        );
      });
      final apiService = GoogleSpeechService(
        googleApiKey: 'key',
        httpClient: client,
      );

      final result = await apiService.synthesizeSpeech(text: 'hello');
      expect(result, equals(bytes));
    });

    test('synthesizeSpeech throws on API error', () async {
      final client = MockClient((request) async => http.Response('oops', 500));
      final apiService = GoogleSpeechService(
        googleApiKey: 'key',
        httpClient: client,
      );

      expect(() => apiService.synthesizeSpeech(text: 'hello'), throwsException);
    });
  });

  group('DeepgramService non-network behavior', () {
    late DeepgramService service;

    setUp(() {
      service = DeepgramService(apiKey: '');
    });

    test('synthesizeSpeech returns empty bytes when key is missing', () async {
      final bytes = await service.synthesizeSpeech(
        text: 'hello',
        languageCode: 'en-US',
      );
      expect(bytes, isEmpty);
    });

    test('ttsModelForLanguage maps to expected voices', () {
      expect(service.ttsModelForLanguage('es-ES'), equals('aura-2-carina-es'));
      expect(service.ttsModelForLanguage('fr-FR'), equals('aura-2-agathe-fr'));
      expect(service.ttsModelForLanguage('de-DE'), equals('aura-2-julius-de'));
      expect(
        service.ttsModelForLanguage('en-US'),
        equals('aura-2-odysseus-en'),
      );
    });

    test('normalizeLanguage handles locale variants', () {
      expect(service.normalizeLanguage('zh-CN'), equals('zh'));
      expect(service.normalizeLanguage('pt'), equals('pt'));
      expect(service.normalizeLanguage('en-US'), equals('en'));
    });

    test('supported recognition options expose defaults and choices', () {
      expect(DeepgramService.supportedRecognitionModels, contains('nova-3'));
      expect(
        DeepgramService.supportedRecognitionModels,
        contains('nova-3-medical'),
      );
      expect(
        DeepgramService
            .supportedRecognitionLanguagesByModel['nova-3']?['Multi'],
        equals('multi'),
      );
      expect(
        DeepgramService
            .supportedRecognitionLanguagesByModel['nova-3-medical']?['English'],
        equals('en'),
      );
      expect(DeepgramService.defaultRecognitionModel, equals('nova-3'));
      expect(DeepgramService.defaultRecognitionLanguage, equals('multi'));
      expect(
        DeepgramService.defaultRecognitionLanguageForModel('nova-3-medical'),
        equals('en'),
      );
    });

    test(
      'synthesizeSpeech returns response bytes on successful API call',
      () async {
        final client = MockClient((request) async {
          expect(request.headers['Authorization'], equals('Token key'));
          return http.Response.bytes(const [7, 8, 9], 200);
        });
        final apiService = DeepgramService(apiKey: 'key', httpClient: client);

        final bytes = await apiService.synthesizeSpeech(
          text: 'hello',
          languageCode: 'en-US',
        );
        expect(bytes, equals(Uint8List.fromList(const [7, 8, 9])));
      },
    );

    test('synthesizeSpeech throws on API error status', () async {
      final client = MockClient((request) async => http.Response('fail', 500));
      final apiService = DeepgramService(apiKey: 'key', httpClient: client);

      expect(
        () => apiService.synthesizeSpeech(text: 'hello', languageCode: 'en-US'),
        throwsException,
      );
    });

    test('isApiKeyValid uses injected validator when provided', () async {
      final apiService = DeepgramService(
        apiKey: 'key',
        apiKeyValidator: () async => true,
      );

      expect(await apiService.isApiKeyValid(), isTrue);
    });

    test(
      'startLiveRecognition maps transcript, final flag, and speaker words',
      () async {
        Map<String, dynamic>? capturedParams;
        final apiService = DeepgramService(
          apiKey: 'key',
          liveRecognizer: (audioStream, queryParams) {
            capturedParams = queryParams;
            return Stream<dynamic>.value(
              const _FakeDeepgramRecognition(
                transcript: 'hello mapped',
                isFinal: true,
                words: [
                  _FakeDeepgramWord(word: 'hello', speaker: 0),
                  _FakeDeepgramWord(word: 'mapped', speaker: 1),
                ],
              ),
            );
          },
        );

        final result = await apiService
            .startLiveRecognition(
              Stream<Uint8List>.value(Uint8List.fromList(const [1, 2])),
              sourceLanguage: 'en-US',
              diarize: true,
              utterances: true,
            )
            .first;

        expect(capturedParams?['language'], equals('en'));
        expect(capturedParams?['diarize'], isTrue);
        expect(capturedParams?['utterances'], isTrue);
        expect(_resultText(result), equals('hello mapped'));
        expect(result.isFinal, isTrue);
        expect(result.words.length, equals(2));
        expect(result.words.first.word, equals('hello'));
        expect(result.words.first.speaker, equals(0));
        expect(result.words.last.word, equals('mapped'));
        expect(result.words.last.speaker, equals(1));
      },
    );

    test('startLiveRecognition preserves multi language flag', () async {
      Map<String, dynamic>? capturedParams;
      final apiService = DeepgramService(
        apiKey: 'key',
        liveRecognizer: (audioStream, queryParams) {
          capturedParams = queryParams;
          return const Stream<dynamic>.empty();
        },
      );

      await apiService
          .startLiveRecognition(
            const Stream<Uint8List>.empty(),
            sourceLanguage: 'multi',
          )
          .drain<void>();

      expect(capturedParams?['language'], equals('multi'));
    });

    test(
      'startLiveRecognition ignores unsupported model and uses current model params',
      () async {
        Map<String, dynamic>? capturedParams;
        final apiService = DeepgramService(
          apiKey: 'key',
          liveRecognizer: (audioStream, queryParams) {
            capturedParams = queryParams;
            return const Stream<dynamic>.empty();
          },
        );

        apiService.setRecognitionModel('unsupported-model');
        apiService.setRecognitionLanguage('es');

        await apiService
            .startLiveRecognition(
              const Stream<Uint8List>.empty(),
              sourceLanguage: 'multi',
              diarize: true,
              utterances: true,
            )
            .drain<void>();

        expect(capturedParams?['model'], equals('nova-3'));
        expect(capturedParams?['language'], equals('es'));
        expect(capturedParams?['detect_language'], isFalse);
        expect(capturedParams?['diarize'], isTrue);
        expect(capturedParams?['utterances'], isTrue);
        expect(capturedParams?['interim_results'], isTrue);
        expect(capturedParams?['punctuate'], isTrue);
      },
    );

    test('setRecognitionModel ignores unsupported model', () async {
      final apiService = DeepgramService(apiKey: 'key');
      apiService.setRecognitionLanguage('multi');

      apiService.setRecognitionModel('unsupported-model');

      expect(apiService.recognitionModel, equals('nova-3'));
      expect(apiService.recognitionLanguage, equals('multi'));
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
      pipeline = SpeechPipeline(googleApiKey: '', deepgramApiKey: '');
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
        equals(DeepgramService.defaultRecognitionModel),
      );
      expect(
        pipeline.deepgramRecognitionLanguage,
        equals(DeepgramService.defaultRecognitionLanguage),
      );
      expect(pipeline.deepgramRecognitionModels, contains('nova-3-medical'));

      pipeline.setTranslationProvider(SpeechTranslationProvider.googleMlKit);
      expect(
        pipeline.translationProvider,
        equals(SpeechTranslationProvider.googleMlKit),
      );

      pipeline.setDeepgramRecognitionModel('nova-3-medical');
      expect(pipeline.deepgramRecognitionModel, equals('nova-3-medical'));
      expect(pipeline.deepgramRecognitionLanguage, equals('multi'));

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
          googleApiKey: 'g',
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
      final deepgram = _FakeDeepgramService()..apiKeyValid = true;
      final speechToText = _FakeSpeechToTextService(initResult: false);
      final routedPipeline = SpeechPipeline(
        googleApiKey: 'g',
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
        googleApiKey: 'g',
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
        googleApiKey: 'g',
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
      final deepgram = _FakeDeepgramService()
        ..liveRecognitionStream = Stream<SpeechRecognitionResult>.value(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'delegated-stream',
            isFinal: true,
          ),
        );
      final routedPipeline = SpeechPipeline(
        googleApiKey: 'g',
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
