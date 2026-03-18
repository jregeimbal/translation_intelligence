import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../config/app_config.dart';
import '../services/google_auth_client_factory.dart';
import '../services/stt_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import 'api_router.dart';
import 'firebase_auth_verifier.dart';
import 'live_stt_connection_handler.dart';
import 'metrics_registry.dart';
import 'middleware.dart';
import 'rate_limiter.dart';
import 'request_context.dart';
import 'structured_logging.dart';

class ApiServer {
  ApiServer._({
    required AppConfig config,
    required Future<HttpServer> Function(Handler, Object, int) serve,
    required GoogleAuthClientFactory googleAuthClientFactory,
    FirebaseAuthVerifier? firebaseAuthVerifier,
    LiveSpeechRecognitionService? liveSpeechRecognitionService,
    MetricsRegistry? metricsRegistry,
    TranslationService? translationService,
    TtsService? googleTtsService,
    TtsService? deepgramTtsService,
  }) : _config = config,
       _serve = serve,
       _googleAuthClientFactory = googleAuthClientFactory,
       _firebaseAuthVerifier =
           firebaseAuthVerifier ?? FirebaseRestAuthVerifier(config: config),
       _liveSpeechRecognitionService =
           liveSpeechRecognitionService ??
           DeepgramLiveSpeechRecognitionService(apiKey: config.deepgramApiKey),
       _metricsRegistry = metricsRegistry ?? MetricsRegistry(),
       _translationService =
           translationService ??
           GoogleCloudTranslationService(authFactory: googleAuthClientFactory),
       _googleTtsService =
           googleTtsService ??
           GoogleCloudTtsService(authFactory: googleAuthClientFactory),
       _deepgramTtsService =
           deepgramTtsService ??
           DeepgramTtsService(apiKey: config.deepgramApiKey);

  factory ApiServer.fromConfig(AppConfig config) {
    final authClientFactory = GoogleAuthClientFactory(
      serviceAccountJson: config.googleServiceAccount,
    );

    return ApiServer._(
      config: config,
      serve: (handler, address, port) => shelf_io.serve(handler, address, port),
      googleAuthClientFactory: authClientFactory,
    );
  }

  factory ApiServer({
    required AppConfig config,
    required Future<HttpServer> Function(Handler, Object, int) serve,
    required GoogleAuthClientFactory googleAuthClientFactory,
    FirebaseAuthVerifier? firebaseAuthVerifier,
    LiveSpeechRecognitionService? liveSpeechRecognitionService,
    MetricsRegistry? metricsRegistry,
    TranslationService? translationService,
    TtsService? googleTtsService,
    TtsService? deepgramTtsService,
  }) {
    return ApiServer._(
      config: config,
      serve: serve,
      googleAuthClientFactory: googleAuthClientFactory,
      firebaseAuthVerifier: firebaseAuthVerifier,
      liveSpeechRecognitionService: liveSpeechRecognitionService,
      metricsRegistry: metricsRegistry,
      translationService: translationService,
      googleTtsService: googleTtsService,
      deepgramTtsService: deepgramTtsService,
    );
  }

  final AppConfig _config;
  final Future<HttpServer> Function(Handler, Object address, int port) _serve;
  final GoogleAuthClientFactory _googleAuthClientFactory;
  final FirebaseAuthVerifier _firebaseAuthVerifier;
  final LiveSpeechRecognitionService _liveSpeechRecognitionService;
  final MetricsRegistry _metricsRegistry;
  final TranslationService _translationService;
  final TtsService _googleTtsService;
  final TtsService _deepgramTtsService;
  late final LiveSttConnectionHandler _liveSttConnectionHandler =
      LiveSttConnectionHandler(
        authVerifier: _firebaseAuthVerifier,
        recognitionService: _liveSpeechRecognitionService,
        metricsRegistry: _metricsRegistry,
        websocketSessionRateLimitPerMinute:
            _config.websocketSessionRateLimitPerMinute,
      );

  Handler _buildWebSocketHandler() {
    return webSocketHandler((webSocket, _) {
      final traceContext = _pendingWebSocketTraceContext;
      _liveSttConnectionHandler.handle(
        webSocket,
        clientIp: traceContext.clientIp,
        traceId: traceContext.traceId,
        requestId: traceContext.requestId,
      );
    });
  }

  Handler _buildRouterHandler() {
    final router = ApiRouter(
      translationService: _translationService,
      googleTtsService: _googleTtsService,
      deepgramTtsService: _deepgramTtsService,
    );

    return router.router.call;
  }

  Handler _buildHttpHandler() {
    final router = ApiRouter(
      translationService: _translationService,
      googleTtsService: _googleTtsService,
      deepgramTtsService: _deepgramTtsService,
    );

    final rateLimiter = RateLimiter(window: const Duration(minutes: 1));

    return Pipeline()
        .addMiddleware(errorHandlingMiddleware())
        .addMiddleware(requestContextMiddleware())
        .addMiddleware(metricsMiddleware(_metricsRegistry))
        .addMiddleware(
          rateLimitMiddleware(
            rateLimiter: rateLimiter,
            requestsPerMinute: _config.httpRateLimitPerMinute,
            metricsRegistry: _metricsRegistry,
          ),
        )
        .addMiddleware(corsMiddleware(_config.allowedOrigins))
        .addMiddleware(bearerAuthMiddleware(_firebaseAuthVerifier))
        .addHandler(router.router.call);
  }

  Handler buildHandler() {
    Logger('ApiServer').info(
      'Configured routes: /v1/health, /v1/capabilities, /v1/translate, /v1/tts, /v1/stt/live',
    );

    final webSocketHandler = _buildWebSocketHandler();
    final httpHandler = _buildHttpHandler();
    final routerHandler = _buildRouterHandler();

    return (request) {
      final isLiveSttRequest = request.url.path == 'v1/stt/live';
      final isWebSocketUpgrade =
          request.headers['upgrade']?.toLowerCase() == 'websocket';

      if (isLiveSttRequest && isWebSocketUpgrade) {
        final traceContext = RequestTraceContext(
          requestId: _randomRequestId(),
          traceId: traceIdFor(request),
          clientIp: clientIpFor(request),
        );
        _pendingWebSocketTraceContext = traceContext;
        logStructured(Logger('ApiServer'), Level.INFO, {
          'event': 'ws_route_selected',
          'requestId': traceContext.requestId,
          'traceId': traceContext.traceId,
          'clientIp': traceContext.clientIp,
          'path': request.requestedUri.path,
        });
        return webSocketHandler(request);
      }

      if (isLiveSttRequest) {
        return routerHandler(request);
      }

      return httpHandler(request);
    };
  }

  Future<HttpServer> start() {
    return _serve(buildHandler(), _config.host, _config.port);
  }

  Future<void> close() async {
    await _googleAuthClientFactory.close();
  }

  RequestTraceContext _pendingWebSocketTraceContext = const RequestTraceContext(
    requestId: 'unknown',
    traceId: null,
    clientIp: 'unknown',
  );

  String _randomRequestId() {
    final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
