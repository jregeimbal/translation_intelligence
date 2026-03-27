import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/suggested_response.dart';
import '../models/speech_connection_debug_info.dart';
import '../models/speech_recognition_models.dart';
import '../models/speech_recognition_session.dart';
import 'speech_output_provider.dart';
import 'speech_stt_provider.dart';

typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

class BackendApiClient {
  BackendApiClient({
    required String baseUrl,
    required Future<String> Function() authTokenProvider,
    http.Client? httpClient,
    WebSocketConnector? webSocketConnector,
    Duration startupTimeout = const Duration(seconds: 10),
  }) : _baseUri = Uri.parse(baseUrl),
       _authTokenProvider = authTokenProvider,
       _httpClient = httpClient ?? http.Client(),
       _webSocketConnector = webSocketConnector ?? WebSocketChannel.connect,
       _startupTimeout = startupTimeout;

  final Uri _baseUri;
  final Future<String> Function() _authTokenProvider;
  final http.Client _httpClient;
  final WebSocketConnector _webSocketConnector;
  final Duration _startupTimeout;

  Future<bool> isAvailable() async {
    final response = await _httpClient.get(_resolve('/v1/health'));
    return response.statusCode == 200;
  }

  Uri buildSttWebSocketUri() => _toWebSocketUri('/v1/stt/live');

  Future<bool> isAuthenticated() async {
    try {
      final token = await _authTokenProvider();
      return token.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    bool returnOriginalOnFailure = true,
    bool nullWhenUnchanged = false,
  }) async {
    try {
      final response = await _httpClient.post(
        _resolve('/v1/translate'),
        headers: await _authorizedJsonHeaders(),
        body: jsonEncode({
          'text': text,
          'targetLanguage': targetLanguage,
          ...?sourceLanguage == null
              ? null
              : {'sourceLanguage': sourceLanguage},
        }),
      );
      if (response.statusCode != 200) {
        if (returnOriginalOnFailure) {
          return text;
        }
        throw StateError('Backend translation failed: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final translatedText = json['translatedText'] as String?;
      if (translatedText == null || translatedText.isEmpty) {
        if (returnOriginalOnFailure) {
          return text;
        }
        throw const FormatException('Backend translation response was invalid');
      }

      if (nullWhenUnchanged &&
          translatedText.toLowerCase().trim().replaceAll(
                RegExp(r'[^\w\s]+'),
                '',
              ) ==
              text.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]+'), '')) {
        return null;
      }

      return translatedText;
    } catch (_) {
      if (returnOriginalOnFailure) {
        return text;
      }
      rethrow;
    }
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    required SpeechOutputProvider provider,
    required String languageCode,
  }) async {
    final response = await _httpClient.post(
      _resolve('/v1/tts'),
      headers: await _authorizedJsonHeaders(),
      body: jsonEncode({
        'provider': provider.name,
        'text': text,
        'languageCode': languageCode,
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Backend TTS failed: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  Future<SuggestedResponse?> suggestResponse({
    required String messageText,
    required String messageTranslation,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    try {
      final response = await _httpClient.post(
        _resolve('/v1/suggest'),
        headers: await _authorizedJsonHeaders(),
        body: jsonEncode({
          'messageText': messageText,
          'messageTranslation': messageTranslation,
          'sourceLanguageCode': sourceLanguageCode,
          'targetLanguageCode': targetLanguageCode,
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestedResponse = SuggestedResponse.fromJson(json);
      if (suggestedResponse.originalText.trim().isEmpty ||
          suggestedResponse.translatedText.trim().isEmpty) {
        return null;
      }
      return suggestedResponse;
    } catch (_) {
      return null;
    }
  }

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
    final wsUri = buildSttWebSocketUri();
    final initialDebugInfo = SpeechConnectionDebugInfo(
      transport: 'backend-websocket',
      phase: 'preconnect',
      uri: wsUri,
      sourceLanguage: sourceLanguage,
      sampleRate: sampleRate,
      model: model,
      language: language,
      diarize: diarize,
      utterances: utterances,
      punctuate: punctuate,
      smartFormat: smartFormat,
      detectLanguage: detectLanguage,
      listeningDeviceId: listeningDeviceId,
      hasAuthToken: false,
      authTokenLength: 0,
      timeout: _startupTimeout,
    );
    var startupPhase = 'preconnect';
    WebSocketChannel? startupChannel;
    var startupCleanupTriggered = false;
    var captureStopped = false;

    Future<void> stopCaptureOnce() async {
      if (captureStopped) return;
      captureStopped = true;
      await stopCapture();
    }

    Future<void> abortStartup() async {
      if (startupCleanupTriggered) return;
      startupCleanupTriggered = true;
      await stopCaptureOnce();
      final channel = startupChannel;
      if (channel == null) {
        return;
      }
      try {
        await channel.sink.close();
      } catch (_) {}
    }

    final startupResult = Completer<SpeechRecognitionSession>();
    Timer? startupTimer;

    startupTimer = Timer(_startupTimeout, () async {
      if (startupResult.isCompleted) {
        return;
      }
      await abortStartup();
      if (startupResult.isCompleted) {
        return;
      }
      startupResult.completeError(
        SpeechConnectionStartupException(
          message: 'Timed out starting the STT websocket session.',
          debugInfo: _copyDebugInfo(initialDebugInfo, phase: startupPhase),
          cause: TimeoutException(
            'Speech recognition startup exceeded ${_startupTimeout.inMilliseconds} ms.',
            _startupTimeout,
          ),
        ),
      );
    });

    Future<void> completeStartup(
      Future<SpeechRecognitionSession> Function() action,
    ) async {
      try {
        final session = await action();
        if (!startupResult.isCompleted) {
          startupResult.complete(session);
        }
      } catch (error, stackTrace) {
        if (!startupResult.isCompleted) {
          startupResult.completeError(error, stackTrace);
        }
      } finally {
        startupTimer?.cancel();
      }
    }

    unawaited(
      completeStartup(() async {
        developer.log(
          'Starting backend STT websocket uri=$wsUri sourceLanguage=$sourceLanguage sampleRate=$sampleRate model=${model ?? 'default'}',
          name: 'BackendApiClient',
        );

        startupPhase = 'auth_token';
        final String token;
        try {
          token = await _authTokenProvider();
        } catch (error) {
          await abortStartup();
          throw SpeechConnectionStartupException(
            message: 'Failed to acquire auth token for speech recognition.',
            debugInfo: initialDebugInfo,
            cause: error,
          );
        }

        final debugInfo = SpeechConnectionDebugInfo(
          transport: initialDebugInfo.transport,
          phase: initialDebugInfo.phase,
          uri: initialDebugInfo.uri,
          sourceLanguage: initialDebugInfo.sourceLanguage,
          sampleRate: initialDebugInfo.sampleRate,
          model: initialDebugInfo.model,
          language: initialDebugInfo.language,
          diarize: initialDebugInfo.diarize,
          utterances: initialDebugInfo.utterances,
          punctuate: initialDebugInfo.punctuate,
          smartFormat: initialDebugInfo.smartFormat,
          detectLanguage: initialDebugInfo.detectLanguage,
          listeningDeviceId: initialDebugInfo.listeningDeviceId,
          hasAuthToken: token.trim().isNotEmpty,
          authTokenLength: token.length,
          timeout: initialDebugInfo.timeout,
        );
        if (token.trim().isEmpty) {
          await abortStartup();
          throw SpeechConnectionStartupException(
            message: 'Missing auth token for STT websocket.',
            debugInfo: debugInfo,
          );
        }

        startupPhase = 'connect';
        final WebSocketChannel channel;
        try {
          channel = _webSocketConnector(wsUri);
          startupChannel = channel;
        } catch (error) {
          await abortStartup();
          throw SpeechConnectionStartupException(
            message: 'Failed to create STT websocket connection.',
            debugInfo: _copyDebugInfo(debugInfo, phase: 'connect'),
            cause: error,
          );
        }
        try {
          await channel.ready.timeout(_startupTimeout);
          developer.log(
            'Backend STT websocket connected uri=$wsUri',
            name: 'BackendApiClient',
          );
        } on TimeoutException catch (error, stackTrace) {
          await abortStartup();
          developer.log(
            'Backend STT websocket connection timed out uri=$wsUri timeout=${_startupTimeout.inMilliseconds}ms',
            name: 'BackendApiClient',
            error: error,
            stackTrace: stackTrace,
          );
          Error.throwWithStackTrace(
            SpeechConnectionStartupException(
              message: 'Timed out connecting to the STT websocket.',
              debugInfo: _copyDebugInfo(debugInfo, phase: 'connect'),
              cause: error,
            ),
            stackTrace,
          );
        } catch (error, stackTrace) {
          await abortStartup();
          developer.log(
            'Backend STT websocket connection failed uri=$wsUri error=$error',
            name: 'BackendApiClient',
            error: error,
            stackTrace: stackTrace,
          );
          Error.throwWithStackTrace(
            SpeechConnectionStartupException(
              message: 'Failed to connect to the STT websocket.',
              debugInfo: _copyDebugInfo(debugInfo, phase: 'connect'),
              cause: error,
            ),
            stackTrace,
          );
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
          await stopCaptureOnce();
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
                    name: 'BackendApiClient',
                  );
                  return;
                case 'recognition_result':
                  if (!resultController.isClosed) {
                    resultController.add(_mapRecognitionResult(payload));
                  }
                  return;
                case 'error':
                  final error = StateError(
                    (payload['message'] as String?) ??
                        'Speech recognition failed.',
                  );
                  developer.log(
                    'Backend STT websocket received error payload=${payload['message']}',
                    name: 'BackendApiClient',
                    error: error,
                  );
                  if (!ready.isCompleted) ready.completeError(error);
                  if (!resultController.isClosed) {
                    resultController.addError(error);
                  }
                  unawaited(closeSession());
                  return;
                default:
                  return;
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              developer.log(
                'Backend STT websocket stream error',
                name: 'BackendApiClient',
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
                name: 'BackendApiClient',
              );
              if (!ready.isCompleted) {
                ready.completeError(
                  StateError(
                    'Speech recognition websocket closed before ready.',
                  ),
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
          name: 'BackendApiClient',
        );

        startupPhase = 'awaiting_ready';
        try {
          await ready.future.timeout(_startupTimeout);
        } on TimeoutException catch (error, stackTrace) {
          await closeSession();
          Error.throwWithStackTrace(
            SpeechConnectionStartupException(
              message: 'Timed out waiting for the STT stream to become ready.',
              debugInfo: _copyDebugInfo(debugInfo, phase: 'awaiting_ready'),
              cause: error,
            ),
            stackTrace,
          );
        } catch (error, stackTrace) {
          await closeSession();
          Error.throwWithStackTrace(
            SpeechConnectionStartupException(
              message:
                  'STT stream startup failed before the session became ready.',
              debugInfo: _copyDebugInfo(debugInfo, phase: 'awaiting_ready'),
              cause: error,
            ),
            stackTrace,
          );
        }

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
      }),
    );

    return startupResult.future;
  }

  Future<Map<String, String>> _authorizedJsonHeaders() async {
    final token = await _authTokenProvider();
    if (token.trim().isEmpty) {
      throw StateError('Missing auth token for backend request');
    }

    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
  }

  Uri _resolve(String path) => _baseUri.resolve(path);

  SpeechConnectionDebugInfo _copyDebugInfo(
    SpeechConnectionDebugInfo source, {
    required String phase,
  }) {
    return SpeechConnectionDebugInfo(
      transport: source.transport,
      phase: phase,
      uri: source.uri,
      sourceLanguage: source.sourceLanguage,
      sampleRate: source.sampleRate,
      model: source.model,
      language: source.language,
      diarize: source.diarize,
      utterances: source.utterances,
      punctuate: source.punctuate,
      smartFormat: source.smartFormat,
      detectLanguage: source.detectLanguage,
      listeningDeviceId: source.listeningDeviceId,
      hasAuthToken: source.hasAuthToken,
      authTokenLength: source.authTokenLength,
      timeout: source.timeout,
    );
  }

  SpeechRecognitionResult _mapRecognitionResult(Map<String, dynamic> payload) {
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

  void close() {
    _httpClient.close();
  }
}
