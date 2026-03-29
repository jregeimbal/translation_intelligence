import 'dart:async';
import 'dart:collection';
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
    Duration sessionResumeTimeout = const Duration(seconds: 10),
    Duration reconnectRetryDelay = const Duration(milliseconds: 500),
  }) : _baseUri = Uri.parse(baseUrl),
       _authTokenProvider = authTokenProvider,
       _httpClient = httpClient ?? http.Client(),
       _webSocketConnector = webSocketConnector ?? WebSocketChannel.connect,
       _startupTimeout = startupTimeout,
       _sessionResumeTimeout = sessionResumeTimeout,
       _reconnectRetryDelay = reconnectRetryDelay;

  final Uri _baseUri;
  final Future<String> Function() _authTokenProvider;
  final http.Client _httpClient;
  final WebSocketConnector _webSocketConnector;
  final Duration _startupTimeout;
  final Duration _sessionResumeTimeout;
  final Duration _reconnectRetryDelay;

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

    SpeechConnectionStartupException startupTimeoutException() {
      final debugInfo = _copyDebugInfo(initialDebugInfo, phase: startupPhase);
      final cause = TimeoutException(
        'Speech recognition startup exceeded ${_startupTimeout.inMilliseconds} ms.',
        _startupTimeout,
      );

      switch (startupPhase) {
        case 'connect':
          return SpeechConnectionStartupException(
            message: 'Timed out connecting to the STT websocket.',
            debugInfo: debugInfo,
            cause: cause,
          );
        case 'awaiting_ready':
          return SpeechConnectionStartupException(
            message: 'Timed out waiting for the STT stream to become ready.',
            debugInfo: debugInfo,
            cause: cause,
          );
        default:
          return SpeechConnectionStartupException(
            message: 'Timed out starting the STT websocket session.',
            debugInfo: debugInfo,
            cause: cause,
          );
      }
    }

    startupTimer = Timer(_startupTimeout, () async {
      if (startupResult.isCompleted) {
        return;
      }
      await abortStartup();
      if (startupResult.isCompleted) {
        return;
      }
      startupResult.completeError(startupTimeoutException());
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

        final resultController =
            StreamController<SpeechRecognitionResult>.broadcast();
        final outgoingAmplitude = StreamController<double>.broadcast();
        final pendingAudioChunks = Queue<Uint8List>();
        StreamSubscription<double>? amplitudeSubscription;
        StreamSubscription<Uint8List>? audioSubscription;
        StreamSubscription<dynamic>? channelSubscription;
        WebSocketChannel? activeChannel;
        var closed = false;
        var reconnecting = false;

        late Future<void> Function(
          WebSocketChannel? currentChannel, {
          bool sendStop,
        })
        closeChannel;
        late Future<void> Function({bool sendStop}) closeSession;
        late Future<void> Function(Object error, [StackTrace? stackTrace])
        failSession;
        late Future<void> Function(
          Object error,
          StackTrace stackTrace,
          WebSocketChannel failedChannel,
        )
        handleConnectedSocketInterrupted;
        late void Function() flushPendingAudio;

        Future<_ConnectedSttSocket> connectChannel({
          required Future<String> Function() tokenProvider,
          required Duration timeout,
          bool isStartup = false,
        }) async {
          final connectionToken = await tokenProvider();
          if (connectionToken.trim().isEmpty) {
            throw StateError('Missing auth token for STT websocket.');
          }

          final WebSocketChannel currentChannel;
          try {
            currentChannel = _webSocketConnector(wsUri);
            if (isStartup) {
              startupChannel = currentChannel;
            }
          } catch (error, stackTrace) {
            if (!isStartup) {
              Error.throwWithStackTrace(error, stackTrace);
            }
            Error.throwWithStackTrace(
              SpeechConnectionStartupException(
                message: 'Failed to create STT websocket connection.',
                debugInfo: _copyDebugInfo(debugInfo, phase: 'connect'),
                cause: error,
              ),
              stackTrace,
            );
          }

          try {
            if (isStartup) {
              startupPhase = 'connect';
            }
            await currentChannel.ready.timeout(timeout);
            developer.log(
              'Backend STT websocket connected uri=$wsUri',
              name: 'BackendApiClient',
            );
          } on TimeoutException catch (error, stackTrace) {
            await closeChannel(currentChannel, sendStop: false);
            if (!isStartup) {
              Error.throwWithStackTrace(error, stackTrace);
            }
            Error.throwWithStackTrace(
              SpeechConnectionStartupException(
                message: 'Timed out connecting to the STT websocket.',
                debugInfo: _copyDebugInfo(debugInfo, phase: 'connect'),
                cause: error,
              ),
              stackTrace,
            );
          } catch (error, stackTrace) {
            await closeChannel(currentChannel, sendStop: false);
            if (!isStartup) {
              Error.throwWithStackTrace(error, stackTrace);
            }
            Error.throwWithStackTrace(
              SpeechConnectionStartupException(
                message: 'Failed to connect to the STT websocket.',
                debugInfo: _copyDebugInfo(debugInfo, phase: 'connect'),
                cause: error,
              ),
              stackTrace,
            );
          }

          activeChannel = currentChannel;
          final ready = Completer<void>();
          var sessionReady = false;

          late final StreamSubscription<dynamic> currentSubscription;
          currentSubscription = currentChannel.stream.listen(
            (message) {
              if (message is! String) return;
              final payload = jsonDecode(message) as Map<String, dynamic>;
              switch (payload['type']) {
                case 'ready':
                  sessionReady = true;
                  if (!ready.isCompleted) {
                    ready.complete();
                  }
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
                  final payloadError = StateError(
                    (payload['message'] as String?) ??
                        'Speech recognition failed.',
                  );
                  developer.log(
                    'Backend STT websocket received error payload=${payload['message']}',
                    name: 'BackendApiClient',
                    error: payloadError,
                  );
                  if (!sessionReady) {
                    if (!ready.isCompleted) {
                      ready.completeError(payloadError);
                    }
                    return;
                  }
                  unawaited(failSession(payloadError));
                  return;
                default:
                  return;
              }
            },
            onError: (Object streamError, StackTrace streamStackTrace) {
              developer.log(
                'Backend STT websocket stream error',
                name: 'BackendApiClient',
                error: streamError,
                stackTrace: streamStackTrace,
              );
              if (!sessionReady) {
                if (!ready.isCompleted) {
                  ready.completeError(streamError, streamStackTrace);
                }
                return;
              }
              unawaited(
                handleConnectedSocketInterrupted(
                  streamError,
                  streamStackTrace,
                  currentChannel,
                ),
              );
            },
            onDone: () {
              developer.log(
                'Backend STT websocket closed by server',
                name: 'BackendApiClient',
              );
              if (!sessionReady) {
                if (!ready.isCompleted) {
                  ready.completeError(
                    StateError(
                      'Speech recognition websocket closed before ready.',
                    ),
                  );
                }
                return;
              }
              unawaited(
                handleConnectedSocketInterrupted(
                  StateError(
                    'Speech recognition websocket closed unexpectedly.',
                  ),
                  StackTrace.current,
                  currentChannel,
                ),
              );
            },
            cancelOnError: true,
          );

          currentChannel.sink.add(
            jsonEncode({
              'type': 'start',
              'token': connectionToken,
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
            'Backend STT websocket sent start message tokenLength=${connectionToken.length}',
            name: 'BackendApiClient',
          );

          try {
            if (isStartup) {
              startupPhase = 'awaiting_ready';
            }
            await ready.future.timeout(timeout);
          } on TimeoutException catch (error, stackTrace) {
            await currentSubscription.cancel();
            await closeChannel(currentChannel, sendStop: false);
            if (!isStartup) {
              Error.throwWithStackTrace(error, stackTrace);
            }
            Error.throwWithStackTrace(
              SpeechConnectionStartupException(
                message:
                    'Timed out waiting for the STT stream to become ready.',
                debugInfo: _copyDebugInfo(debugInfo, phase: 'awaiting_ready'),
                cause: error,
              ),
              stackTrace,
            );
          } catch (error, stackTrace) {
            await currentSubscription.cancel();
            await closeChannel(currentChannel, sendStop: false);
            if (!isStartup) {
              Error.throwWithStackTrace(error, stackTrace);
            }
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

          return _ConnectedSttSocket(
            channel: currentChannel,
            subscription: currentSubscription,
          );
        }

        closeChannel =
            (WebSocketChannel? currentChannel, {bool sendStop = false}) async {
              if (currentChannel == null) {
                return;
              }
              if (sendStop) {
                try {
                  currentChannel.sink.add(jsonEncode({'type': 'stop'}));
                } catch (_) {}
              }
              try {
                await currentChannel.sink.close();
              } catch (_) {}
            };

        closeSession = ({bool sendStop = true}) async {
          if (closed) return;
          closed = true;
          reconnecting = false;
          await audioSubscription?.cancel();
          audioSubscription = null;
          await amplitudeSubscription?.cancel();
          amplitudeSubscription = null;
          await channelSubscription?.cancel();
          channelSubscription = null;
          final currentChannel = activeChannel;
          activeChannel = null;
          await stopCaptureOnce();
          await closeChannel(currentChannel, sendStop: sendStop);
          if (!resultController.isClosed) {
            await resultController.close();
          }
          if (!outgoingAmplitude.isClosed) {
            await outgoingAmplitude.close();
          }
        };

        failSession = (Object error, [StackTrace? stackTrace]) async {
          if (closed) {
            return;
          }
          if (!resultController.isClosed) {
            resultController.addError(error, stackTrace);
          }
          await closeSession(sendStop: false);
        };

        handleConnectedSocketInterrupted =
            (
              Object error,
              StackTrace stackTrace,
              WebSocketChannel failedChannel,
            ) async {
              if (closed ||
                  reconnecting ||
                  !identical(activeChannel, failedChannel)) {
                return;
              }

              developer.log(
                'Backend STT websocket interrupted; attempting resume',
                name: 'BackendApiClient',
                error: error,
                stackTrace: stackTrace,
              );

              reconnecting = true;
              await channelSubscription?.cancel();
              channelSubscription = null;
              activeChannel = null;
              await closeChannel(failedChannel, sendStop: false);

              final deadline = DateTime.now().add(_sessionResumeTimeout);
              Object? lastError = error;
              StackTrace? lastStackTrace = stackTrace;

              while (!closed) {
                final remaining = deadline.difference(DateTime.now());
                if (remaining <= Duration.zero) {
                  break;
                }

                try {
                  final attemptTimeout = remaining < _startupTimeout
                      ? remaining
                      : _startupTimeout;
                  final connected = await connectChannel(
                    tokenProvider: _authTokenProvider,
                    timeout: attemptTimeout,
                  );
                  if (closed) {
                    await connected.subscription.cancel();
                    await closeChannel(connected.channel, sendStop: false);
                    return;
                  }
                  activeChannel = connected.channel;
                  channelSubscription = connected.subscription;
                  reconnecting = false;
                  flushPendingAudio();
                  developer.log(
                    'Backend STT websocket resumed successfully',
                    name: 'BackendApiClient',
                  );
                  return;
                } catch (retryError, retryStackTrace) {
                  lastError = retryError;
                  lastStackTrace = retryStackTrace;

                  final delay = remaining < _reconnectRetryDelay
                      ? remaining
                      : _reconnectRetryDelay;
                  if (delay <= Duration.zero) {
                    break;
                  }
                  await Future<void>.delayed(delay);
                }
              }

              reconnecting = false;
              await failSession(
                StateError('listeningConnectionLost'),
                lastStackTrace,
              );
              developer.log(
                'Backend STT websocket failed to resume within ${_sessionResumeTimeout.inMilliseconds} ms',
                name: 'BackendApiClient',
                error: lastError,
                stackTrace: lastStackTrace,
              );
            };

        flushPendingAudio = () {
          if (closed || reconnecting) {
            return;
          }
          final currentChannel = activeChannel;
          if (currentChannel == null) {
            return;
          }

          while (pendingAudioChunks.isNotEmpty) {
            final chunk = pendingAudioChunks.first;
            try {
              currentChannel.sink.add(chunk);
              pendingAudioChunks.removeFirst();
            } catch (error, stackTrace) {
              unawaited(
                handleConnectedSocketInterrupted(
                  error,
                  stackTrace,
                  currentChannel,
                ),
              );
              return;
            }
          }
        };

        startupPhase = 'awaiting_ready';
        try {
          final connected = await connectChannel(
            tokenProvider: () async => token,
            timeout: _startupTimeout,
            isStartup: true,
          );
          channelSubscription = connected.subscription;
        } catch (error, stackTrace) {
          await closeSession();
          Error.throwWithStackTrace(error, stackTrace);
        }

        amplitudeSubscription = amplitudeStream.listen((value) {
          if (!outgoingAmplitude.isClosed) {
            outgoingAmplitude.add(value);
          }
        });

        audioSubscription = audioStream.listen(
          (chunk) {
            pendingAudioChunks.add(chunk);
            flushPendingAudio();
          },
          onError: (Object audioError, StackTrace audioStackTrace) {
            unawaited(failSession(audioError, audioStackTrace));
          },
          cancelOnError: true,
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

class _ConnectedSttSocket {
  const _ConnectedSttSocket({
    required this.channel,
    required this.subscription,
  });

  final WebSocketChannel channel;
  final StreamSubscription<dynamic> subscription;
}
