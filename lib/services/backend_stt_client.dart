import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/speech_recognition_models.dart';
import '../models/speech_recognition_session.dart';
import 'speech_stt_provider.dart';

typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

class BackendSttClient {
  BackendSttClient({
    required String baseUrl,
    required Future<String> Function() authTokenProvider,
    WebSocketConnector? webSocketConnector,
  }) : _baseUri = Uri.parse(baseUrl),
       _authTokenProvider = authTokenProvider,
       _webSocketConnector = webSocketConnector ?? WebSocketChannel.connect;

  final Uri _baseUri;
  final Future<String> Function() _authTokenProvider;
  final WebSocketConnector _webSocketConnector;

  Uri buildWebSocketUri() => _toWebSocketUri('/v1/stt/live');

  Future<SpeechRecognitionSession> startRecognitionSession({
    required Stream<Uint8List> audioStream,
    required Stream<double> amplitudeStream,
    required Future<void> Function() stopCapture,
    required int sampleRate,
    required String sourceLanguage,
    required String? model,
    required String? language,
    required bool diarize,
    required bool utterances,
    required bool punctuate,
    required bool smartFormat,
    required bool detectLanguage,
    String? listeningDeviceId,
  }) async {
    final wsUri = buildWebSocketUri();
    developer.log(
      'Starting backend STT websocket uri=$wsUri sourceLanguage=$sourceLanguage sampleRate=$sampleRate model=${model ?? 'default'}',
      name: 'BackendSttClient',
    );

    final token = await _authTokenProvider();
    if (token.trim().isEmpty) {
      throw StateError('Missing auth token for STT websocket');
    }

    final channel = _webSocketConnector(wsUri);
    try {
      await channel.ready;
      developer.log(
        'Backend STT websocket connected uri=$wsUri',
        name: 'BackendSttClient',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Backend STT websocket connection failed uri=$wsUri error=$error',
        name: 'BackendSttClient',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final resultController =
        StreamController<SpeechRecognitionResult>.broadcast();
    final outgoingAmplitude = StreamController<double>.broadcast();
    final subscriptions = <StreamSubscription<dynamic>>[];
    final ready = Completer<void>();
    var closed = false;

    Future<void> closeSession() async {
      if (closed) return;
      closed = true;
      await Future.wait(subscriptions.map((sub) => sub.cancel()));
      await stopCapture();
      channel.sink.add(jsonEncode({'type': 'stop'}));
      await channel.sink.close();
      if (!resultController.isClosed) await resultController.close();
      if (!outgoingAmplitude.isClosed) await outgoingAmplitude.close();
    }

    subscriptions.add(
      amplitudeStream.listen((value) {
        if (!outgoingAmplitude.isClosed) {
          outgoingAmplitude.add(value);
        }
      }),
    );

    subscriptions.add(
      channel.stream.listen(
        (message) {
          if (message is! String) return;
          final payload = jsonDecode(message) as Map<String, dynamic>;
          switch (payload['type']) {
            case 'ready':
              if (!ready.isCompleted) ready.complete();
              developer.log(
                'Backend STT websocket received ready message',
                name: 'BackendSttClient',
              );
              return;
            case 'recognition_result':
              if (!resultController.isClosed) {
                resultController.add(_mapResult(payload));
              }
              return;
            case 'error':
              final error = StateError(
                (payload['message'] as String?) ?? 'Speech recognition failed.',
              );
              developer.log(
                'Backend STT websocket received error payload=${payload['message']}',
                name: 'BackendSttClient',
                error: error,
              );
              if (!ready.isCompleted) ready.completeError(error);
              if (!resultController.isClosed) resultController.addError(error);
              unawaited(closeSession());
              return;
            default:
              return;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Backend STT websocket stream error',
            name: 'BackendSttClient',
            error: error,
            stackTrace: stackTrace,
          );
          if (!ready.isCompleted) ready.completeError(error, stackTrace);
          if (!resultController.isClosed) {
            resultController.addError(error, stackTrace);
          }
          unawaited(closeSession());
        },
        onDone: () {
          developer.log(
            'Backend STT websocket closed by server',
            name: 'BackendSttClient',
          );
          if (!ready.isCompleted) {
            ready.completeError(
              StateError('Speech recognition websocket closed before ready.'),
            );
          }
          unawaited(closeSession());
        },
        cancelOnError: true,
      ),
    );

    channel.sink.add(
      jsonEncode({
        'type': 'start',
        'token': token,
        'sourceLanguage': sourceLanguage,
        'sampleRate': sampleRate,
        ...?(model == null ? null : {'model': model}),
        ...?(language == null ? null : {'language': language}),
        'diarize': diarize,
        'utterances': utterances,
        'punctuate': punctuate,
        'smartFormat': smartFormat,
        'detectLanguage': detectLanguage,
      }),
    );
    developer.log(
      'Backend STT websocket sent start message tokenLength=${token.length}',
      name: 'BackendSttClient',
    );

    await ready.future;

    subscriptions.add(
      audioStream.listen(
        channel.sink.add,
        onError: (Object error, StackTrace stackTrace) {
          if (!resultController.isClosed) {
            resultController.addError(error, stackTrace);
          }
          unawaited(closeSession());
        },
        cancelOnError: true,
      ),
    );

    return SpeechRecognitionSession(
      resultStream: resultController.stream,
      amplitudeStream: outgoingAmplitude.stream,
      stop: closeSession,
      sampleRate: sampleRate,
      sttProvider: SpeechSttProvider.deepgram,
      sourceLanguage: sourceLanguage,
      resolvedLanguageCode: sourceLanguage,
      listeningDeviceId: listeningDeviceId,
    );
  }

  SpeechRecognitionResult _mapResult(Map<String, dynamic> payload) {
    final words = (payload['words'] as List<dynamic>? ?? const [])
        .map((item) {
          final json = item as Map<String, dynamic>;
          return SpeechRecognitionWord(
            word: json['word'] as String? ?? '',
            speaker: (json['speaker'] as num?)?.toInt(),
          );
        })
        .toList(growable: false);

    return SpeechRecognitionResult(
      isFinal: payload['isFinal'] as bool? ?? false,
      speechFinal: payload['speechFinal'] as bool? ?? false,
      words: words,
    );
  }

  Uri _toWebSocketUri(String path) {
    final resolved = _baseUri.resolve(path);
    return resolved.replace(
      scheme: resolved.scheme == 'https'
          ? 'wss'
          : resolved.scheme == 'http'
          ? 'ws'
          : resolved.scheme,
    );
  }
}
