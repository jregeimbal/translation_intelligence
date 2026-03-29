import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:translation_intelligence/models/suggested_response.dart';
import 'package:translation_intelligence/models/speech_connection_debug_info.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

class _TestWebSocketSink implements WebSocketSink {
  _TestWebSocketSink(this._inner);

  final StreamController<dynamic> _inner;

  @override
  void add(dynamic data) {
    if (!_inner.isClosed) {
      _inner.add(data);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream stream) => _inner.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _inner.close();

  @override
  Future<void> get done => _inner.done;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestWebSocketChannel implements WebSocketChannel {
  _TestWebSocketChannel(this._stream, this.sink, {this.readyFuture});

  final Stream<dynamic> _stream;
  final Future<void>? readyFuture;

  @override
  final WebSocketSink sink;

  @override
  Stream<dynamic> get stream => _stream;

  @override
  Future<void> get ready => readyFuture ?? Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BackendApiClient', () {
    test('translateText sends auth and parses translated text', () async {
      late http.BaseRequest capturedRequest;
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        httpClient: _FakeHttpClient((request) async {
          capturedRequest = request;
          final streamed = request as http.Request;
          expect(jsonDecode(streamed.body), {
            'text': 'hello',
            'targetLanguage': 'es',
            'sourceLanguage': 'en',
          });
          return http.Response(
            jsonEncode({'translatedText': 'hola'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final translated = await client.translateText(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'es',
      );

      expect(translated, 'hola');
      expect(capturedRequest.headers['authorization'], 'Bearer token-123');
    });

    test('synthesizeSpeech posts provider and returns bytes', () async {
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-abc',
        httpClient: _FakeHttpClient((request) async {
          final streamed = request as http.Request;
          expect(jsonDecode(streamed.body), {
            'provider': 'deepgram',
            'text': 'bonjour',
            'languageCode': 'fr-FR',
          });
          return http.Response.bytes(Uint8List.fromList(const [4, 5, 6]), 200);
        }),
      );

      final bytes = await client.synthesizeSpeech(
        text: 'bonjour',
        provider: SpeechOutputProvider.deepgram,
        languageCode: 'fr-FR',
      );

      expect(bytes, Uint8List.fromList(const [4, 5, 6]));
    });

    test('suggestResponse posts message context and parses response', () async {
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-suggest',
        httpClient: _FakeHttpClient((request) async {
          final streamed = request as http.Request;
          expect(jsonDecode(streamed.body), {
            'messageText': 'hola',
            'messageTranslation': 'hello',
            'sourceLanguageCode': 'es',
            'targetLanguageCode': 'en',
          });
          return http.Response(
            jsonEncode(
              const SuggestedResponse(
                originalText: 'claro que si',
                translatedText: 'of course',
                sourceLanguageCode: 'es',
                targetLanguageCode: 'en',
              ).toJson(),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final suggestion = await client.suggestResponse(
        messageText: 'hola',
        messageTranslation: 'hello',
        sourceLanguageCode: 'es',
        targetLanguageCode: 'en',
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.originalText, 'claro que si');
      expect(suggestion.translatedText, 'of course');
    });

    test('suggestResponse returns null on non-200 response', () async {
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-suggest',
        httpClient: _FakeHttpClient((request) async {
          return http.Response('server unavailable', 503);
        }),
      );

      final suggestion = await client.suggestResponse(
        messageText: 'hola',
        messageTranslation: 'hello',
        sourceLanguageCode: 'es',
        targetLanguageCode: 'en',
      );

      expect(suggestion, isNull);
    });

    test('suggestResponse returns null on invalid payload', () async {
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-suggest',
        httpClient: _FakeHttpClient((request) async {
          return http.Response(
            jsonEncode({
              'originalText': '   ',
              'translatedText': 'of course',
              'sourceLanguageCode': 'es',
              'targetLanguageCode': 'en',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final suggestion = await client.suggestResponse(
        messageText: 'hola',
        messageTranslation: 'hello',
        sourceLanguageCode: 'es',
        targetLanguageCode: 'en',
      );

      expect(suggestion, isNull);
    });

    test('buildSttWebSocketUri converts http base URL to ws endpoint', () {
      final client = BackendApiClient(
        baseUrl: 'http://localhost:8080',
        authTokenProvider: () async => 'token',
      );

      expect(
        client.buildSttWebSocketUri().toString(),
        'ws://localhost:8080/v1/stt/live',
      );
    });

    test('buildSttWebSocketUri converts https base URL to wss endpoint', () {
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token',
      );

      expect(
        client.buildSttWebSocketUri().toString(),
        'wss://api.example.com/v1/stt/live',
      );
    });

    test('streams audio and maps recognition results', () async {
      final sentMessages = <dynamic>[];
      final serverController = StreamController<dynamic>.broadcast();
      final sink = StreamController<dynamic>();
      sink.stream.listen(sentMessages.add);
      final audioController = StreamController<Uint8List>();
      final amplitudeController = StreamController<double>();
      var stopCaptureCalls = 0;

      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        webSocketConnector: (_) => _TestWebSocketChannel(
          serverController.stream,
          _TestWebSocketSink(sink),
        ),
      );

      final sessionFuture = client.startRecognitionSession(
        audioStream: audioController.stream,
        amplitudeStream: amplitudeController.stream,
        stopCapture: () async {
          stopCaptureCalls += 1;
        },
        sampleRate: 16000,
        sourceLanguage: 'en-US',
        model: 'nova-3',
        language: 'en-US',
        diarize: true,
        utterances: true,
        punctuate: true,
        smartFormat: false,
        detectLanguage: false,
        listeningDeviceId: 'mic-1',
      );

      await Future<void>.delayed(Duration.zero);
      serverController.add(jsonEncode({'type': 'ready'}));
      final session = await sessionFuture;

      final resultFuture = session.resultStream.first;
      final amplitudeFuture = session.amplitudeStream.first;

      amplitudeController.add(0.7);
      audioController.add(Uint8List.fromList(const [1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      serverController.add(
        jsonEncode({
          'type': 'recognition_result',
          'isFinal': true,
          'speechFinal': true,
          'words': [
            {'word': 'hello', 'speaker': 1},
            {'word': 'world', 'speaker': 1},
          ],
        }),
      );

      final result = await resultFuture;
      final amplitude = await amplitudeFuture;
      final startMessage =
          jsonDecode(sentMessages.first as String) as Map<String, dynamic>;

      expect(startMessage['type'], 'start');
      expect(startMessage['token'], 'token-123');
      expect(startMessage['sourceLanguage'], 'en-US');
      expect(sentMessages[1], Uint8List.fromList(const [1, 2, 3]));
      expect(result.wordsToText(), 'hello world');
      expect(result.isFinal, isTrue);
      expect(result.speechFinal, isTrue);
      expect(amplitude, 0.7);

      await audioController.close();
      await Future<void>.delayed(Duration.zero);
      await session.stop();

      expect(stopCaptureCalls, 1);
      expect(jsonDecode(sentMessages.last as String)['type'], 'stop');

      await amplitudeController.close();
      await serverController.close();
      await sink.close();
    });

    test('surfaces websocket connection failures', () async {
      var stopCaptureCalls = 0;
      final sentMessages = <dynamic>[];
      final sink = StreamController<dynamic>();
      sink.stream.listen(sentMessages.add);

      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        webSocketConnector: (_) => _TestWebSocketChannel(
          const Stream<dynamic>.empty(),
          _TestWebSocketSink(sink),
          readyFuture: Future<void>.microtask(
            () => throw StateError('connect failed'),
          ),
        ),
      );

      await expectLater(
        client.startRecognitionSession(
          audioStream: const Stream<Uint8List>.empty(),
          amplitudeStream: const Stream<double>.empty(),
          stopCapture: () async {
            stopCaptureCalls += 1;
          },
          sampleRate: 16000,
          sourceLanguage: 'en-US',
          model: 'nova-3',
          language: 'en-US',
          diarize: false,
          utterances: false,
          punctuate: true,
          smartFormat: false,
          detectLanguage: false,
        ),
        throwsA(
          isA<SpeechConnectionStartupException>()
              .having(
                (error) => error.debugInfo.uri.toString(),
                'uri',
                'wss://api.example.com/v1/stt/live',
              )
              .having((error) => error.debugInfo.phase, 'phase', 'connect')
              .having(
                (error) => error.debugInfo.authTokenLength,
                'auth token length',
                9,
              ),
        ),
      );
      expect(stopCaptureCalls, 1);
      await sink.close();
    });

    test('times out while connecting websocket', () async {
      var stopCaptureCalls = 0;
      final sink = StreamController<dynamic>();
      sink.stream.listen((_) {});

      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        startupTimeout: const Duration(milliseconds: 10),
        webSocketConnector: (_) => _TestWebSocketChannel(
          const Stream<dynamic>.empty(),
          _TestWebSocketSink(sink),
          readyFuture: Completer<void>().future,
        ),
      );

      await expectLater(
        client.startRecognitionSession(
          audioStream: const Stream<Uint8List>.empty(),
          amplitudeStream: const Stream<double>.empty(),
          stopCapture: () async {
            stopCaptureCalls += 1;
          },
          sampleRate: 16000,
          sourceLanguage: 'en-US',
          model: 'nova-3',
          language: 'en-US',
          diarize: false,
          utterances: false,
          punctuate: true,
          smartFormat: false,
          detectLanguage: false,
        ),
        throwsA(
          isA<SpeechConnectionStartupException>()
              .having((error) => error.debugInfo.phase, 'phase', 'connect')
              .having(
                (error) => error.message,
                'message',
                'Timed out connecting to the STT websocket.',
              )
              .having(
                (error) => error.debugInfo.timeout,
                'timeout',
                const Duration(milliseconds: 10),
              ),
        ),
      );

      expect(stopCaptureCalls, 1);
      await sink.close();
    });

    test(
      'reconnects an interrupted websocket session and resumes audio',
      () async {
        final firstSentMessages = <dynamic>[];
        final firstServerController = StreamController<dynamic>.broadcast();
        final firstSink = StreamController<dynamic>();
        firstSink.stream.listen(firstSentMessages.add);

        final secondSentMessages = <dynamic>[];
        final secondServerController = StreamController<dynamic>.broadcast();
        final secondSink = StreamController<dynamic>();
        secondSink.stream.listen(secondSentMessages.add);

        final audioController = StreamController<Uint8List>.broadcast();
        final amplitudeController = StreamController<double>.broadcast();
        var stopCaptureCalls = 0;
        var connectionCount = 0;

        final client = BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token-123',
          sessionResumeTimeout: const Duration(milliseconds: 80),
          reconnectRetryDelay: const Duration(milliseconds: 1),
          webSocketConnector: (_) {
            connectionCount += 1;
            if (connectionCount == 1) {
              return _TestWebSocketChannel(
                firstServerController.stream,
                _TestWebSocketSink(firstSink),
              );
            }
            return _TestWebSocketChannel(
              secondServerController.stream,
              _TestWebSocketSink(secondSink),
            );
          },
        );

        final sessionFuture = client.startRecognitionSession(
          audioStream: audioController.stream,
          amplitudeStream: amplitudeController.stream,
          stopCapture: () async {
            stopCaptureCalls += 1;
          },
          sampleRate: 16000,
          sourceLanguage: 'en-US',
          model: 'nova-3',
          language: 'en-US',
          diarize: false,
          utterances: false,
          punctuate: true,
          smartFormat: false,
          detectLanguage: false,
        );

        await Future<void>.delayed(Duration.zero);
        firstServerController.add(jsonEncode({'type': 'ready'}));
        final session = await sessionFuture;

        final resultFuture = session.resultStream.first;

        audioController.add(Uint8List.fromList(const [1, 2, 3]));
        await Future<void>.delayed(Duration.zero);
        expect(firstSentMessages[1], Uint8List.fromList(const [1, 2, 3]));

        await firstServerController.close();
        audioController.add(Uint8List.fromList(const [9, 8, 7]));
        await Future<void>.delayed(const Duration(milliseconds: 5));

        secondServerController.add(jsonEncode({'type': 'ready'}));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        secondServerController.add(
          jsonEncode({
            'type': 'recognition_result',
            'isFinal': true,
            'speechFinal': true,
            'words': [
              {'word': 'resumed', 'speaker': 1},
            ],
          }),
        );

        final result = await resultFuture;
        expect(result.wordsToText(), 'resumed');
        expect(secondSentMessages[1], Uint8List.fromList(const [9, 8, 7]));
        expect(stopCaptureCalls, 0);

        await session.stop();

        expect(stopCaptureCalls, 1);
        expect(jsonDecode(secondSentMessages.last as String)['type'], 'stop');

        await audioController.close();
        await amplitudeController.close();
        await secondServerController.close();
        await firstSink.close();
        await secondSink.close();
      },
    );

    test(
      'emits an error when websocket session cannot resume in time',
      () async {
        final firstServerController = StreamController<dynamic>.broadcast();
        final firstSink = StreamController<dynamic>();
        firstSink.stream.listen((_) {});

        final reconnectSink = StreamController<dynamic>();
        reconnectSink.stream.listen((_) {});

        var stopCaptureCalls = 0;
        var connectionCount = 0;

        final client = BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token-123',
          startupTimeout: const Duration(milliseconds: 5),
          sessionResumeTimeout: const Duration(milliseconds: 20),
          reconnectRetryDelay: const Duration(milliseconds: 1),
          webSocketConnector: (_) {
            connectionCount += 1;
            if (connectionCount == 1) {
              return _TestWebSocketChannel(
                firstServerController.stream,
                _TestWebSocketSink(firstSink),
              );
            }
            return _TestWebSocketChannel(
              const Stream<dynamic>.empty(),
              _TestWebSocketSink(reconnectSink),
              readyFuture: Completer<void>().future,
            );
          },
        );

        final sessionFuture = client.startRecognitionSession(
          audioStream: const Stream<Uint8List>.empty(),
          amplitudeStream: const Stream<double>.empty(),
          stopCapture: () async {
            stopCaptureCalls += 1;
          },
          sampleRate: 16000,
          sourceLanguage: 'en-US',
          model: 'nova-3',
          language: 'en-US',
          diarize: false,
          utterances: false,
          punctuate: true,
          smartFormat: false,
          detectLanguage: false,
        );

        await Future<void>.delayed(Duration.zero);
        firstServerController.add(jsonEncode({'type': 'ready'}));
        final session = await sessionFuture;

        final streamError = Completer<Object>();
        final sub = session.resultStream.listen(
          (_) {},
          onError: (Object error, StackTrace _) {
            if (!streamError.isCompleted) {
              streamError.complete(error);
            }
          },
        );

        await firstServerController.close();

        final error = await streamError.future;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(error, isA<StateError>());
        expect(error.toString(), contains('listeningConnectionLost'));
        expect(stopCaptureCalls, 1);

        await sub.cancel();
        await firstSink.close();
        await reconnectSink.close();
      },
    );

    test('surfaces backend error payload before ready', () async {
      final sentMessages = <dynamic>[];
      final serverController = StreamController<dynamic>.broadcast();
      final sink = StreamController<dynamic>();
      sink.stream.listen(sentMessages.add);

      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        webSocketConnector: (_) => _TestWebSocketChannel(
          serverController.stream,
          _TestWebSocketSink(sink),
        ),
      );

      final sessionFuture = client.startRecognitionSession(
        audioStream: const Stream<Uint8List>.empty(),
        amplitudeStream: const Stream<double>.empty(),
        stopCapture: () async {},
        sampleRate: 16000,
        sourceLanguage: 'en-US',
        model: 'nova-3',
        language: 'en-US',
        diarize: false,
        utterances: false,
        punctuate: true,
        smartFormat: false,
        detectLanguage: false,
      );

      await Future<void>.delayed(Duration.zero);
      serverController.add(
        jsonEncode({'type': 'error', 'message': 'auth failed'}),
      );

      await expectLater(
        sessionFuture,
        throwsA(
          isA<SpeechConnectionStartupException>()
              .having(
                (error) => error.debugInfo.phase,
                'phase',
                'awaiting_ready',
              )
              .having(
                (error) => error.cause.toString(),
                'cause',
                contains('auth failed'),
              ),
        ),
      );
      expect(sentMessages, isNotEmpty);

      await serverController.close();
      await sink.close();
    });

    test(
      'times out while waiting for ready and includes debug details',
      () async {
        final serverController = StreamController<dynamic>.broadcast();
        final sink = StreamController<dynamic>();
        final sentMessages = <dynamic>[];
        sink.stream.listen(sentMessages.add);
        var stopCaptureCalls = 0;

        final client = BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token-123',
          startupTimeout: const Duration(milliseconds: 10),
          webSocketConnector: (_) => _TestWebSocketChannel(
            serverController.stream,
            _TestWebSocketSink(sink),
          ),
        );

        await expectLater(
          client.startRecognitionSession(
            audioStream: const Stream<Uint8List>.empty(),
            amplitudeStream: const Stream<double>.empty(),
            stopCapture: () async {
              stopCaptureCalls += 1;
            },
            sampleRate: 16000,
            sourceLanguage: 'en-US',
            model: 'nova-3',
            language: 'en-US',
            diarize: true,
            utterances: true,
            punctuate: true,
            smartFormat: false,
            detectLanguage: false,
            listeningDeviceId: 'mic-9',
          ),
          throwsA(
            isA<SpeechConnectionStartupException>()
                .having(
                  (error) => error.debugInfo.phase,
                  'phase',
                  'awaiting_ready',
                )
                .having(
                  (error) => error.debugInfo.listeningDeviceId,
                  'listening device',
                  'mic-9',
                )
                .having(
                  (error) => error.debugInfo.timeout,
                  'timeout',
                  const Duration(milliseconds: 10),
                ),
          ),
        );

        expect(stopCaptureCalls, 1);
        expect(sentMessages, isNotEmpty);

        await serverController.close();
        await sink.close();
      },
    );
  });
}
