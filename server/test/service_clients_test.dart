import 'dart:async';
import 'dart:convert';
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/base_client.dart';
import 'package:test/test.dart';
import 'package:translation_intelligence_server/src/models/live_stt_models.dart';
import 'package:translation_intelligence_server/src/models/translate_request.dart';
import 'package:translation_intelligence_server/src/models/tts_request.dart';
import 'package:translation_intelligence_server/src/services/google_auth_client_factory.dart';
import 'package:translation_intelligence_server/src/services/stt_service.dart';
import 'package:translation_intelligence_server/src/services/translation_service.dart';
import 'package:translation_intelligence_server/src/services/tts_service.dart';

class _FakeAuthClient with BaseClient implements AuthClient {
  _FakeAuthClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  AccessCredentials get credentials => AccessCredentials(
    AccessToken(
      'Bearer',
      'test-token',
      DateTime.now().add(const Duration(hours: 1)),
    ),
    null,
    const <String>[],
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return _handler(request);
  }
}

class _FakeGoogleAuthClientFactory extends GoogleAuthClientFactory {
  _FakeGoogleAuthClientFactory(this.client) : super.testing();

  final AuthClient client;
  List<String>? lastScopes;
  int getClientCallCount = 0;

  @override
  Future<AuthClient> getClient(List<String> scopes) async {
    getClientCallCount += 1;
    lastScopes = List<String>.from(scopes);
    return client;
  }
}

class _FakeHttpClient with BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return _handler(request);
  }
}

class _SpeechFinalFieldResult {
  _SpeechFinalFieldResult(this.speechFinal);

  final bool speechFinal;
}

class _SpeechFinalJsonResult {
  _SpeechFinalJsonResult(this.value);

  final bool value;

  Map<String, dynamic> toJson() => <String, dynamic>{'speech_final': value};
}

class _FakeDeepgramWord {
  _FakeDeepgramWord({required this.word, required this.speaker});

  final String word;
  final int? speaker;
}

class _FakeDeepgramLiveResult {
  _FakeDeepgramLiveResult({
    required this.isFinal,
    required this.words,
    this.speechFinal,
    this.jsonSpeechFinal,
  });

  final bool isFinal;
  final List<_FakeDeepgramWord> words;
  final bool? speechFinal;
  final bool? jsonSpeechFinal;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (jsonSpeechFinal != null) 'speech_final': jsonSpeechFinal,
  };
}

dynamic _invokePrivate(
  Object target,
  String memberName,
  List<dynamic> positionalArguments,
) {
  final classMirror = reflect(target).type;
  final libraryMirror = classMirror.owner as LibraryMirror;
  final symbol = MirrorSystem.getSymbol(memberName, libraryMirror);
  return reflect(target).invoke(symbol, positionalArguments).reflectee;
}

http.StreamedResponse _jsonResponse(
  int statusCode,
  Map<String, dynamic> json,
) {
  final bytes = utf8.encode(jsonEncode(json));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

http.StreamedResponse _textResponse(int statusCode, String body) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
    headers: const <String, String>{'content-type': 'text/plain'},
  );
}

void main() {
  group('GoogleCloudTranslationService', () {
    test('posts translated text request and returns translatedText', () async {
      late Map<String, dynamic> payload;
      final client = _FakeAuthClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://translation.googleapis.com/language/translate/v2',
        );
        expect(request.headers['content-type'], 'application/json');

        payload = jsonDecode((request as http.Request).body)
            as Map<String, dynamic>;

        return _jsonResponse(200, <String, dynamic>{
          'data': <String, dynamic>{
            'translations': <Map<String, dynamic>>[
              <String, dynamic>{'translatedText': 'hola'},
            ],
          },
        });
      });
      final authFactory = _FakeGoogleAuthClientFactory(client);
      final service = GoogleCloudTranslationService(authFactory: authFactory);

      final result = await service.translate(
        const TranslateRequest(
          text: 'hello',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        ),
      );

      expect(result, 'hola');
      expect(payload, <String, dynamic>{
        'q': 'hello',
        'target': 'es',
        'source': 'en',
        'format': 'text',
      });
      expect(authFactory.getClientCallCount, 1);
      expect(
        authFactory.lastScopes,
        contains('https://www.googleapis.com/auth/cloud-platform'),
      );
    });

    test('omits source when request sourceLanguage is null', () async {
      late Map<String, dynamic> payload;
      final client = _FakeAuthClient((request) async {
        payload = jsonDecode((request as http.Request).body)
            as Map<String, dynamic>;
        return _jsonResponse(200, <String, dynamic>{
          'data': <String, dynamic>{
            'translations': <Map<String, dynamic>>[
              <String, dynamic>{'translatedText': 'bonjour'},
            ],
          },
        });
      });
      final service = GoogleCloudTranslationService(
        authFactory: _FakeGoogleAuthClientFactory(client),
      );

      await service.translate(
        const TranslateRequest(text: 'hello', targetLanguage: 'fr'),
      );

      expect(payload.containsKey('source'), isFalse);
    });

    test('throws when Google Translation returns non-200', () async {
      final client = _FakeAuthClient(
        (_) async => _textResponse(503, 'backend unavailable'),
      );
      final service = GoogleCloudTranslationService(
        authFactory: _FakeGoogleAuthClientFactory(client),
      );

      expect(
        () => service.translate(
          const TranslateRequest(text: 'hello', targetLanguage: 'fr'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('503 backend unavailable'),
          ),
        ),
      );
    });

    test('throws when translatedText is missing from response', () async {
      final client = _FakeAuthClient(
        (_) async => _jsonResponse(200, <String, dynamic>{
          'data': <String, dynamic>{
            'translations': <Map<String, dynamic>>[
              <String, dynamic>{'detectedSourceLanguage': 'en'}
            ],
          },
        }),
      );
      final service = GoogleCloudTranslationService(
        authFactory: _FakeGoogleAuthClientFactory(client),
      );

      expect(
        () => service.translate(
          const TranslateRequest(text: 'hello', targetLanguage: 'fr'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('missing translatedText'),
          ),
        ),
      );
    });
  });

  group('GoogleCloudTtsService', () {
    test('posts synthesis request and decodes audio content', () async {
      late Map<String, dynamic> payload;
      final client = _FakeAuthClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://texttospeech.googleapis.com/v1/text:synthesize',
        );

        payload = jsonDecode((request as http.Request).body)
            as Map<String, dynamic>;

        return _jsonResponse(200, <String, dynamic>{
          'audioContent': base64Encode(const <int>[1, 2, 3, 4]),
        });
      });
      final service = GoogleCloudTtsService(
        authFactory: _FakeGoogleAuthClientFactory(client),
      );

      final bytes = await service.synthesize(
        const TtsRequest(
          provider: TtsProvider.google,
          text: 'hello world',
          languageCode: 'en-US',
        ),
      );

      expect(bytes, Uint8List.fromList(const <int>[1, 2, 3, 4]));
      expect(payload, <String, dynamic>{
        'input': <String, dynamic>{'text': 'hello world'},
        'voice': <String, dynamic>{
          'languageCode': 'en-US',
          'ssmlGender': 'NEUTRAL',
        },
        'audioConfig': <String, dynamic>{'audioEncoding': 'MP3'},
      });
    });

    test('throws when Google TTS returns non-200', () async {
      final client = _FakeAuthClient((_) async => _textResponse(500, 'error'));
      final service = GoogleCloudTtsService(
        authFactory: _FakeGoogleAuthClientFactory(client),
      );

      expect(
        () => service.synthesize(
          const TtsRequest(
            provider: TtsProvider.google,
            text: 'hello world',
            languageCode: 'en-US',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Text-to-Speech request failed'),
          ),
        ),
      );
    });

    test('throws when audioContent is missing from response', () async {
      final client = _FakeAuthClient(
        (_) async => _jsonResponse(200, <String, dynamic>{}),
      );
      final service = GoogleCloudTtsService(
        authFactory: _FakeGoogleAuthClientFactory(client),
      );

      expect(
        () => service.synthesize(
          const TtsRequest(
            provider: TtsProvider.google,
            text: 'hello world',
            languageCode: 'en-US',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('missing audioContent'),
          ),
        ),
      );
    });
  });

  group('DeepgramTtsService', () {
    test('uses language-specific models and returns body bytes', () async {
      final recordedModels = <String>[];
      final client = _FakeHttpClient((request) async {
        recordedModels.add(request.url.queryParameters['model'] ?? '');
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Token deepgram-key');
        expect(request.headers['content-type'], 'application/json');

        final payload = jsonDecode((request as http.Request).body)
            as Map<String, dynamic>;
        expect(payload['text'], isNotEmpty);

        return http.StreamedResponse(
          Stream<List<int>>.value(const <int>[9, 8, 7]),
          200,
        );
      });
      final service = DeepgramTtsService(
        apiKey: 'deepgram-key',
        httpClient: client,
      );

      final spanish = await service.synthesize(
        const TtsRequest(
          provider: TtsProvider.deepgram,
          text: 'hola',
          languageCode: 'es-ES',
        ),
      );
      await service.synthesize(
        const TtsRequest(
          provider: TtsProvider.deepgram,
          text: 'bonjour',
          languageCode: 'fr-FR',
        ),
      );
      await service.synthesize(
        const TtsRequest(
          provider: TtsProvider.deepgram,
          text: 'guten tag',
          languageCode: 'de-DE',
        ),
      );
      await service.synthesize(
        const TtsRequest(
          provider: TtsProvider.deepgram,
          text: 'hello',
          languageCode: 'en-US',
        ),
      );

      expect(spanish, Uint8List.fromList(const <int>[9, 8, 7]));
      expect(recordedModels, <String>[
        'aura-2-carina-es',
        'aura-2-agathe-fr',
        'aura-2-julius-de',
        'aura-2-odysseus-en',
      ]);
    });

    test('throws when Deepgram TTS returns non-200', () async {
      final service = DeepgramTtsService(
        apiKey: 'deepgram-key',
        httpClient: _FakeHttpClient(
          (_) async => _textResponse(429, 'rate limited'),
        ),
      );

      expect(
        () => service.synthesize(
          const TtsRequest(
            provider: TtsProvider.deepgram,
            text: 'hello',
            languageCode: 'en-US',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Deepgram Text-to-Speech request failed'),
          ),
        ),
      );
    });
  });

  group('DeepgramLiveSpeechRecognitionService private helpers', () {
    late DeepgramLiveSpeechRecognitionService service;

    setUp(() {
      service = DeepgramLiveSpeechRecognitionService(apiKey: 'test-key');
    });

    test('normalizes app language codes for Deepgram', () {
      expect(_invokePrivate(service, '_normalizeLanguage', <dynamic>['zh-CN']), 'zh');
      expect(_invokePrivate(service, '_normalizeLanguage', <dynamic>['en-US']), 'en');
      expect(_invokePrivate(service, '_normalizeLanguage', <dynamic>['fr']), 'fr');
    });

    test('reads speechFinal directly from map payloads', () {
      expect(
        _invokePrivate(
          service,
          '_speechFinal',
          <dynamic>[<String, dynamic>{'speech_final': true}],
        ),
        isTrue,
      );
      expect(
        _invokePrivate(
          service,
          '_speechFinal',
          <dynamic>[<String, dynamic>{'speechFinal': true}],
        ),
        isTrue,
      );
    });

    test('reads speechFinal from object properties and toJson fallback', () {
      expect(
        _invokePrivate(
          service,
          '_speechFinal',
          <dynamic>[_SpeechFinalFieldResult(true)],
        ),
        isTrue,
      );
      expect(
        _invokePrivate(
          service,
          '_speechFinal',
          <dynamic>[_SpeechFinalJsonResult(true)],
        ),
        isTrue,
      );
      expect(
        _invokePrivate(service, '_speechFinal', <dynamic>[Object()]),
        isFalse,
      );
    });
  });

  group('DeepgramLiveSpeechRecognitionService', () {
    test('builds normalized query params and maps live results', () async {
      late Map<String, dynamic> recordedParams;
      final capturedAudio = <List<int>>[];
      final service = DeepgramLiveSpeechRecognitionService(
        apiKey: 'test-key',
        liveListen: (audioStream, {queryParams}) async* {
          recordedParams = Map<String, dynamic>.from(queryParams!);
          await for (final chunk in audioStream) {
            capturedAudio.add(List<int>.from(chunk));
          }

          yield _FakeDeepgramLiveResult(
            isFinal: true,
            speechFinal: true,
            words: <_FakeDeepgramWord>[
              _FakeDeepgramWord(word: 'hello', speaker: 2),
              _FakeDeepgramWord(word: 'world', speaker: null),
            ],
          );
        },
      );

      final result = await service
          .start(
            LiveSttStreamInput(
              audioStream: Stream<Uint8List>.fromIterable(
                <Uint8List>[
                  Uint8List.fromList(<int>[1, 2, 3]),
                  Uint8List.fromList(<int>[4, 5]),
                ],
              ),
              request: const LiveSttStartRequest(
                token: 'token',
                sourceLanguage: 'en-US',
                sampleRate: 16000,
                detectLanguage: true,
                diarize: true,
                utterances: true,
                punctuate: true,
                smartFormat: true,
              ),
            ),
          )
          .single;

      expect(capturedAudio, <List<int>>[
        <int>[1, 2, 3],
        <int>[4, 5],
      ]);
      expect(recordedParams, <String, dynamic>{
        'detect_language': true,
        'language': 'en',
        'model': 'nova-3',
        'encoding': 'linear16',
        'sample_rate': '16000',
        'interim_results': true,
        'punctuate': true,
        'diarize': true,
        'utterances': true,
        'smart_format': true,
      });
      expect(result.isFinal, isTrue);
      expect(result.speechFinal, isTrue);
      expect(
        result.words.map((word) => word.toJson()).toList(growable: false),
        <Map<String, dynamic>>[
          <String, dynamic>{'word': 'hello', 'speaker': 2},
          <String, dynamic>{'word': 'world'},
        ],
      );
    });

    test('uses explicit language when source language is multi', () async {
      late Map<String, dynamic> recordedParams;
      final service = DeepgramLiveSpeechRecognitionService(
        apiKey: 'test-key',
        liveListen: (audioStream, {queryParams}) async* {
          recordedParams = Map<String, dynamic>.from(queryParams!);
          await audioStream.drain<void>();

          yield _FakeDeepgramLiveResult(
            isFinal: false,
            jsonSpeechFinal: true,
            words: <_FakeDeepgramWord>[],
          );
        },
      );

      final result = await service
          .start(
            LiveSttStreamInput(
              audioStream: Stream<Uint8List>.value(Uint8List(0)),
              request: const LiveSttStartRequest(
                token: 'token',
                sourceLanguage: 'multi',
                language: 'fr-FR',
                sampleRate: 8000,
                model: 'nova-2',
              ),
            ),
          )
          .single;

      expect(recordedParams['language'], 'fr');
      expect(recordedParams['model'], 'nova-2');
      expect(recordedParams['sample_rate'], '8000');
      expect(result.speechFinal, isTrue);
    });

    test('leaves multi language unchanged when no language override exists', () async {
      late Map<String, dynamic> recordedParams;
      final service = DeepgramLiveSpeechRecognitionService(
        apiKey: 'test-key',
        liveListen: (audioStream, {queryParams}) async* {
          recordedParams = Map<String, dynamic>.from(queryParams!);
          await audioStream.drain<void>();

          yield _FakeDeepgramLiveResult(
            isFinal: false,
            words: <_FakeDeepgramWord>[],
          );
        },
      );

      await service
          .start(
            LiveSttStreamInput(
              audioStream: Stream<Uint8List>.value(Uint8List(0)),
              request: const LiveSttStartRequest(
                token: 'token',
                sourceLanguage: 'multi',
                sampleRate: 16000,
              ),
            ),
          )
          .single;

      expect(recordedParams['language'], 'multi');
    });
  });
}