import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/shelf.dart';

import '../config/app_config.dart';
import '../services/google_auth_client_factory.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import 'api_router.dart';
import 'firebase_auth_verifier.dart';
import 'middleware.dart';

class ApiServer {
  ApiServer._({
    required AppConfig config,
    required Future<HttpServer> Function(Handler, Object, int) serve,
    required GoogleAuthClientFactory googleAuthClientFactory,
    FirebaseAuthVerifier? firebaseAuthVerifier,
    TranslationService? translationService,
    TtsService? googleTtsService,
    TtsService? deepgramTtsService,
  }) : _config = config,
       _serve = serve,
       _googleAuthClientFactory = googleAuthClientFactory,
       _firebaseAuthVerifier =
           firebaseAuthVerifier ?? FirebaseRestAuthVerifier(config: config),
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
    TranslationService? translationService,
    TtsService? googleTtsService,
    TtsService? deepgramTtsService,
  }) {
    return ApiServer._(
      config: config,
      serve: serve,
      googleAuthClientFactory: googleAuthClientFactory,
      firebaseAuthVerifier: firebaseAuthVerifier,
      translationService: translationService,
      googleTtsService: googleTtsService,
      deepgramTtsService: deepgramTtsService,
    );
  }

  final AppConfig _config;
  final Future<HttpServer> Function(Handler, Object address, int port) _serve;
  final GoogleAuthClientFactory _googleAuthClientFactory;
  final FirebaseAuthVerifier _firebaseAuthVerifier;
  final TranslationService _translationService;
  final TtsService _googleTtsService;
  final TtsService _deepgramTtsService;

  Handler buildHandler() {
    final router = ApiRouter(
      translationService: _translationService,
      googleTtsService: _googleTtsService,
      deepgramTtsService: _deepgramTtsService,
    );

    return const Pipeline()
        .addMiddleware(errorHandlingMiddleware())
        .addMiddleware(requestContextMiddleware())
        .addMiddleware(corsMiddleware(_config.allowedOrigins))
        .addMiddleware(bearerAuthMiddleware(_firebaseAuthVerifier))
        .addHandler(router.router.call);
  }

  Future<HttpServer> start() {
    return _serve(buildHandler(), _config.host, _config.port);
  }

  Future<void> close() async {
    await _googleAuthClientFactory.close();
  }
}
