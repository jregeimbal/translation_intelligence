import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/live_stt_models.dart';
import '../services/stt_service.dart';
import 'firebase_auth_verifier.dart';
import 'metrics_registry.dart';
import 'rate_limiter.dart';
import 'structured_logging.dart';

class LiveSttConnectionHandler {
  LiveSttConnectionHandler({
    required FirebaseAuthVerifier authVerifier,
    required LiveSpeechRecognitionService recognitionService,
    required MetricsRegistry metricsRegistry,
    required int websocketSessionRateLimitPerMinute,
  }) : _authVerifier = authVerifier,
       _recognitionService = recognitionService,
       _metricsRegistry = metricsRegistry,
       _websocketSessionRateLimitPerMinute = websocketSessionRateLimitPerMinute;

  final FirebaseAuthVerifier _authVerifier;
  final LiveSpeechRecognitionService _recognitionService;
  final MetricsRegistry _metricsRegistry;
  final int _websocketSessionRateLimitPerMinute;
  final Logger _logger = Logger('LiveSttConnection');

  void handle(
    WebSocketChannel channel, {
    String clientIp = 'unknown',
    String? traceId,
    String requestId = 'unknown',
  }) {
    unawaited(
      _handle(
        channel,
        clientIp: clientIp,
        traceId: traceId,
        requestId: requestId,
      ),
    );
  }

  Future<void> _handle(
    WebSocketChannel channel, {
    required String clientIp,
    required String? traceId,
    required String requestId,
  }) async {
    final audioController = StreamController<Uint8List>();
    StreamSubscription<dynamic>? channelSubscription;
    StreamSubscription<LiveSttResult>? recognitionSubscription;
    var sessionStarted = false;
    var sessionClosed = false;
    var audioChunkCount = 0;
    var userId = 'anonymous';

    logStructured(_logger, Level.INFO, {
      'event': 'ws_session_accepted',
      'requestId': requestId,
      'traceId': traceId,
      'clientIp': clientIp,
      'path': '/v1/stt/live',
    });

    Future<void> close([int? code, String? reason]) async {
      if (sessionClosed) {
        return;
      }
      sessionClosed = true;
      _metricsRegistry.recordWebSocketSessionCompleted();
      logStructured(_logger, Level.INFO, {
        'event': 'ws_session_closed',
        'requestId': requestId,
        'traceId': traceId,
        'clientIp': clientIp,
        'uid': userId,
        'audioChunks': audioChunkCount,
        'code': code,
        'reason': reason,
      });
      await recognitionSubscription?.cancel();
      await channelSubscription?.cancel();
      if (!audioController.isClosed) {
        await audioController.close();
      }
      try {
        await channel.sink.close(code, reason);
      } catch (_) {
        logStructured(_logger, Level.WARNING, {
          'event': 'ws_session_close_failed',
          'requestId': requestId,
          'traceId': traceId,
          'clientIp': clientIp,
          'uid': userId,
          'code': code,
          'reason': reason,
        });
      }
    }

    Future<void> sendError(String message, {bool closeSocket = true}) async {
      logStructured(_logger, Level.WARNING, {
        'event': 'ws_session_error',
        'requestId': requestId,
        'traceId': traceId,
        'clientIp': clientIp,
        'uid': userId,
        'message': message,
      });
      channel.sink.add(jsonEncode({'type': 'error', 'message': message}));
      if (closeSocket) {
        await close();
      }
    }

    Future<void> startSession(String rawMessage) async {
      final payload = jsonDecode(rawMessage) as Map<String, dynamic>;
      if ((payload['type'] as String? ?? '') != 'start') {
        throw const FormatException(
          'First websocket message must be a start payload',
        );
      }

      final request = LiveSttStartRequest.fromJson(payload);
      if (!_allowWebSocketSession(clientIp)) {
        _metricsRegistry.recordWebSocketSessionRejected();
        throw FirebaseAuthException('Rate limit exceeded');
      }

      final user = await _authVerifier.verify(request.token);
      sessionStarted = true;
      userId = user.uid;
      _metricsRegistry.recordWebSocketSessionStarted();

      logStructured(_logger, Level.INFO, {
        'event': 'ws_session_authenticated',
        'requestId': requestId,
        'traceId': traceId,
        'clientIp': clientIp,
        'uid': user.uid,
        'sourceLanguage': request.sourceLanguage,
        'sampleRate': request.sampleRate,
        'model': request.model ?? 'nova-3',
      });

      channel.sink.add(jsonEncode({'type': 'ready'}));

      recognitionSubscription = _recognitionService
          .start(
            LiveSttStreamInput(
              audioStream: audioController.stream,
              request: request,
            ),
          )
          .listen(
            (result) {
              channel.sink.add(jsonEncode(result.toJson()));
            },
            onError: (Object error, StackTrace stackTrace) async {
              logStructured(_logger, Level.WARNING, {
                'event': 'ws_deepgram_stream_error',
                'requestId': requestId,
                'traceId': traceId,
                'clientIp': clientIp,
                'uid': userId,
                'error': '$error',
              });
              await sendError('Speech recognition stream failed.');
            },
            onDone: () async {
              logStructured(_logger, Level.INFO, {
                'event': 'ws_deepgram_stream_completed',
                'requestId': requestId,
                'traceId': traceId,
                'clientIp': clientIp,
                'uid': userId,
              });
              await close();
            },
          );
    }

    channelSubscription = channel.stream.listen(
      (message) async {
        try {
          if (!sessionStarted) {
            if (message is! String) {
              throw const FormatException(
                'First websocket message must be JSON',
              );
            }
            await startSession(message);
            return;
          }

          if (message is List<int>) {
            audioChunkCount += 1;
            _metricsRegistry.recordWebSocketAudioChunk();
            if (audioChunkCount <= 3 || audioChunkCount % 50 == 0) {
              logStructured(_logger, Level.FINE, {
                'event': 'ws_audio_chunk',
                'requestId': requestId,
                'traceId': traceId,
                'clientIp': clientIp,
                'uid': userId,
                'chunkIndex': audioChunkCount,
                'bytes': message.length,
              });
            }
            audioController.add(Uint8List.fromList(message));
            return;
          }

          if (message is String) {
            final payload = jsonDecode(message) as Map<String, dynamic>;
            if ((payload['type'] as String? ?? '') == 'stop') {
              logStructured(_logger, Level.INFO, {
                'event': 'ws_client_stop',
                'requestId': requestId,
                'traceId': traceId,
                'clientIp': clientIp,
                'uid': userId,
              });
              if (!audioController.isClosed) {
                await audioController.close();
              }
              return;
            }
          }
        } on FirebaseAuthException catch (error) {
          await sendError(error.message);
        } on FormatException catch (error) {
          await sendError(error.message);
        } catch (error) {
          logStructured(_logger, Level.WARNING, {
            'event': 'ws_unexpected_message_error',
            'requestId': requestId,
            'traceId': traceId,
            'clientIp': clientIp,
            'uid': userId,
            'error': '$error',
          });
          await sendError('Invalid websocket message.');
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        logStructured(_logger, Level.WARNING, {
          'event': 'ws_channel_error',
          'requestId': requestId,
          'traceId': traceId,
          'clientIp': clientIp,
          'uid': userId,
          'error': '$error',
        });
        await close();
      },
      onDone: () async {
        logStructured(_logger, Level.INFO, {
          'event': 'ws_client_disconnected',
          'requestId': requestId,
          'traceId': traceId,
          'clientIp': clientIp,
          'uid': userId,
        });
        await close();
      },
      cancelOnError: true,
    );
  }

  bool _allowWebSocketSession(String clientIp) {
    final now = DateTime.now();
    return _sessionRateLimiter.allow(
      clientIp,
      _websocketSessionRateLimitPerMinute,
      now,
    );
  }

  final _sessionRateLimiter = RateLimiter(window: const Duration(minutes: 1));
}
