import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:translation_intelligence_server/src/config/app_config.dart';
import 'package:translation_intelligence_server/src/http/api_server.dart';
import 'package:translation_intelligence_server/src/http/firebase_auth_verifier.dart';
import 'package:translation_intelligence_server/src/http/request_context.dart';
import 'package:translation_intelligence_server/src/models/live_stt_models.dart';
import 'package:translation_intelligence_server/src/models/translate_request.dart';
import 'package:translation_intelligence_server/src/models/tts_request.dart';
import 'package:translation_intelligence_server/src/services/google_auth_client_factory.dart';
import 'package:translation_intelligence_server/src/services/stt_service.dart';
import 'package:translation_intelligence_server/src/services/translation_service.dart';
import 'package:translation_intelligence_server/src/services/tts_service.dart';

class _FakeFirebaseAuthVerifier implements FirebaseAuthVerifier {
  @override
  Future<AuthenticatedUser> verify(String token) async {
    return const AuthenticatedUser(
      uid: 'user-1',
      issuer: 'issuer',
      audience: 'audience',
    );
  }
}

class _FakeLiveSpeechRecognitionService
    implements LiveSpeechRecognitionService {
  LiveSttStreamInput? lastInput;

  @override
  Stream<LiveSttResult> start(LiveSttStreamInput input) async* {
    lastInput = input;
    await Future<void>.delayed(Duration.zero);
    yield const LiveSttResult(
      isFinal: true,
      speechFinal: true,
      words: [LiveSttWord(word: 'hello', speaker: 1)],
    );
  }
}

class _FakeTranslationService implements TranslationService {
  @override
  Future<String> translate(TranslateRequest request) async => 'hola';
}

class _FakeTtsService implements TtsService {
  @override
  Future<Uint8List> synthesize(TtsRequest request) async =>
      Uint8List.fromList(const [1, 2, 3]);
}

class _FakeGoogleAuthClientFactory extends GoogleAuthClientFactory {
  _FakeGoogleAuthClientFactory() : super.testing();

  @override
  Future<void> close() async {}
}

void main() {
  group('ApiServer websocket routing', () {
    late HttpServer httpServer;
    late ApiServer apiServer;
    late _FakeLiveSpeechRecognitionService liveSpeechRecognitionService;

    setUp(() async {
      liveSpeechRecognitionService = _FakeLiveSpeechRecognitionService();
      final config = AppConfig(
        host: '127.0.0.1',
        port: 0,
        allowedOrigins: {'http://localhost:3000'},
        httpRateLimitPerMinute: 120,
        websocketSessionRateLimitPerMinute: 30,
        firebaseProjectId: 'project-id',
        firebaseWebApiKey: 'web-api-key',
        googleServiceAccountJson: jsonEncode({
          'type': 'service_account',
          'project_id': 'project-id',
          'private_key_id': 'key-id',
          'private_key':
              '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
          'client_email': 'test@example.com',
          'client_id': 'client-id',
          'token_uri': 'https://oauth2.googleapis.com/token',
        }),
        deepgramApiKey: 'deepgram-key',
      );

      apiServer = ApiServer(
        config: config,
        serve: (handler, address, port) =>
            shelf_io.serve(handler, address, port),
        googleAuthClientFactory: _FakeGoogleAuthClientFactory(),
        firebaseAuthVerifier: _FakeFirebaseAuthVerifier(),
        liveSpeechRecognitionService: liveSpeechRecognitionService,
        translationService: _FakeTranslationService(),
        googleTtsService: _FakeTtsService(),
        deepgramTtsService: _FakeTtsService(),
      );

      httpServer = await apiServer.start();
    });

    tearDown(() async {
      await apiServer.close();
      await httpServer.close(force: true);
    });

    test(
      'routes websocket upgrades to live STT handler before HTTP middleware',
      () async {
        final uri = Uri.parse(
          'ws://${httpServer.address.host}:${httpServer.port}/v1/stt/live',
        );
        final socket = await WebSocket.connect(uri.toString());
        final incomingMessages = socket.cast<String>().asBroadcastStream();

        socket.add(
          jsonEncode({
            'type': 'start',
            'token': 'firebase-token',
            'sourceLanguage': 'en-US',
            'sampleRate': 16000,
            'model': 'nova-3',
            'language': 'en-US',
            'diarize': true,
            'utterances': true,
            'punctuate': true,
            'smartFormat': false,
            'detectLanguage': false,
          }),
        );

        final firstMessage =
            jsonDecode(await incomingMessages.first) as Map<String, dynamic>;
        expect(firstMessage['type'], 'ready');

        socket.add(Uint8List.fromList(const [1, 2, 3, 4]));
        final resultMessage =
            jsonDecode(await incomingMessages.first) as Map<String, dynamic>;
        expect(resultMessage['type'], 'recognition_result');
        expect(resultMessage['words'][0]['word'], 'hello');

        expect(liveSpeechRecognitionService.lastInput, isNotNull);
        expect(
          liveSpeechRecognitionService.lastInput!.request.token,
          'firebase-token',
        );

        await socket.close();
      },
    );

    test('health endpoint still uses HTTP pipeline', () async {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'http://${httpServer.address.host}:${httpServer.port}/v1/health',
        ),
      );
      final response = await request.close();
      final body = await utf8.decodeStream(response);

      expect(response.statusCode, 200);
      expect(response.headers.value('x-request-id'), isNotNull);
      expect(body, contains('ok'));
      client.close(force: true);
    });
  });
}
