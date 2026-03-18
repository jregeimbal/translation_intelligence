import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/services/backend_stt_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  group('BackendSttClient', () {
    test('streams audio and maps recognition results', () async {
      final sentMessages = <dynamic>[];
      final serverController = StreamController<dynamic>.broadcast();
      final sink = StreamController<dynamic>();
      sink.stream.listen(sentMessages.add);
      final audioController = StreamController<Uint8List>();
      final amplitudeController = StreamController<double>();
      var stopCaptureCalls = 0;

      final client = BackendSttClient(
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
      final client = BackendSttClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        webSocketConnector: (_) => _TestWebSocketChannel(
          const Stream<dynamic>.empty(),
          _TestWebSocketSink(StreamController<dynamic>()),
          readyFuture: Future<void>.error(StateError('connect failed')),
        ),
      );

      expect(
        () => client.startRecognitionSession(
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
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('surfaces backend error payload before ready', () async {
      final sentMessages = <dynamic>[];
      final serverController = StreamController<dynamic>.broadcast();
      final sink = StreamController<dynamic>();
      sink.stream.listen(sentMessages.add);

      final client = BackendSttClient(
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

      await expectLater(sessionFuture, throwsA(isA<StateError>()));
      expect(sentMessages, isNotEmpty);

      await serverController.close();
      await sink.close();
    });
  });
}
