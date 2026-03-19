import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

const _sampleEnWavPath = '../assets/OSR_us_000_0010_8k.wav';
const _sampleEnWavContent =
    'the birch canoe slid on the smooth planks. glue the sheet to the dark blue background. it is easy to tell the depth of a well. these days a chicken leg is a rare dish. rice is often served in round bowls. the juice of lemons makes fine punch. the box was thrown beside the park truck. the hogs were fed chopped corn and garbage. four hours of steady work faced us. a large size in stockings is hard to sell.';
const _sampleFrWavPath = '../assets/OSR_fr_000_0041_8k.wav';
const _sampleFrWavContent =
    'pourrais-je avoir un verre d\'eau. la s n c f assurera un train sur trois.';
const _sampleHiWavPath = '../assets/OSR_in_000_0062_16k.wav';
const _sampleHiWavContent =
    'the birch canoe slid on the smooth planks. glue the sheet to the dark blue background.';

class _FakeFirebaseAuthVerifier implements FirebaseAuthVerifier {
  @override
  Future<AuthenticatedUser> verify(String token) async {
    if (token != 'local-firebase-token') {
      throw FirebaseAuthException('Invalid local test token');
    }

    return const AuthenticatedUser(
      uid: 'local-user',
      issuer: 'issuer',
      audience: 'audience',
    );
  }
}

class _FakeLiveSpeechRecognitionService
    implements LiveSpeechRecognitionService {
  @override
  Stream<LiveSttResult> start(LiveSttStreamInput input) async* {
    final request = input.request;
    final language = request.language ?? request.sourceLanguage;
    final transcript = switch (language) {
      'fr' || 'fr-FR' => _sampleFrWavContent,
      'hi' || 'hi-IN' => _sampleHiWavContent,
      _ => _sampleEnWavContent,
    };

    await input.audioStream.drain<void>();

    yield LiveSttResult(
      isFinal: true,
      speechFinal: true,
      words: transcript
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .map((word) => LiveSttWord(word: word, speaker: 0))
          .toList(growable: false),
    );
  }
}

class _FakeTranslationService implements TranslationService {
  @override
  Future<String> translate(TranslateRequest request) async {
    if (request.text == 'Hello, how are you?' &&
        request.targetLanguage == 'es') {
      return 'Hola, como estas?';
    }
    return '${request.text} -> ${request.targetLanguage}';
  }
}

class _FakeTtsService implements TtsService {
  @override
  Future<Uint8List> synthesize(TtsRequest request) async {
    final seed = utf8.encode(
      '${request.provider.name}:${request.languageCode}:${request.text}',
    );
    return Uint8List.fromList(
      List<int>.generate(2048, (index) => seed[index % seed.length]),
    );
  }
}

class _FakeGoogleAuthClientFactory extends GoogleAuthClientFactory {
  _FakeGoogleAuthClientFactory() : super.testing();

  @override
  Future<void> close() async {}
}

Stream<Uint8List> _generatePcmSineWaveStream({
  int sampleRate = 16000,
  double frequencyHz = 440,
  Duration totalDuration = const Duration(seconds: 2),
  Duration chunkDuration = const Duration(milliseconds: 100),
}) async* {
  final totalSamples = (sampleRate * totalDuration.inMilliseconds) ~/ 1000;
  final chunkSamples = (sampleRate * chunkDuration.inMilliseconds) ~/ 1000;
  const amplitude = 0.25;

  var sampleIndex = 0;
  while (sampleIndex < totalSamples) {
    final count = math.min(chunkSamples, totalSamples - sampleIndex);
    final bytes = Uint8List(count * 2);
    final view = ByteData.sublistView(bytes);

    for (var i = 0; i < count; i++) {
      final t = (sampleIndex + i) / sampleRate;
      final sample =
          (math.sin(2 * math.pi * frequencyHz * t) * (32767 * amplitude))
              .round()
              .clamp(-32768, 32767);
      view.setInt16(i * 2, sample, Endian.little);
    }

    sampleIndex += count;
    yield bytes;
    await Future<void>.delayed(chunkDuration);
  }
}

Uint8List _extractWavPcm(Uint8List wavBytes) {
  if (wavBytes.length < 44) {
    throw StateError('WAV file is too short to parse.');
  }

  final bytes = ByteData.sublistView(wavBytes);
  final riff = String.fromCharCodes(wavBytes.sublist(0, 4));
  final wave = String.fromCharCodes(wavBytes.sublist(8, 12));
  if (riff != 'RIFF' || wave != 'WAVE') {
    throw StateError('Invalid WAV file header.');
  }

  var offset = 12;
  while (offset + 8 <= wavBytes.length) {
    final chunkId = String.fromCharCodes(wavBytes.sublist(offset, offset + 4));
    final chunkSize = bytes.getUint32(offset + 4, Endian.little);
    final dataStart = offset + 8;
    if (chunkId == 'data') {
      final dataEnd = dataStart + chunkSize;
      if (dataEnd > wavBytes.length) {
        throw StateError('Invalid WAV data chunk length.');
      }
      return Uint8List.fromList(wavBytes.sublist(dataStart, dataEnd));
    }

    offset = dataStart + chunkSize;
    if (offset.isOdd) {
      offset += 1;
    }
  }

  throw StateError('WAV data chunk not found.');
}

Stream<Uint8List> _chunkPcmStream(
  Uint8List pcmBytes, {
  int chunkSize = 320,
  Duration interChunkDelay = const Duration(milliseconds: 20),
}) async* {
  var offset = 0;
  while (offset < pcmBytes.length) {
    final end = math.min(offset + chunkSize, pcmBytes.length);
    yield Uint8List.fromList(pcmBytes.sublist(offset, end));
    offset = end;
    await Future<void>.delayed(interChunkDelay);
  }
}

String _normalizedTranscript(Iterable<String> transcripts) {
  final combined = transcripts
      .where((text) => text.trim().isNotEmpty)
      .join(' ');
  final normalized = combined
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' .', '.')
      .trim();
  return normalized.endsWith('.') ? normalized : '$normalized.';
}

Future<bool> _isBackendHealthy(String baseUrl) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$baseUrl/v1/health'));
    final response = await request.close();
    return response.statusCode == 200;
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> _postTts({
  required String baseUrl,
  required String token,
  required String text,
  required String provider,
  required String languageCode,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$baseUrl/v1/tts'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'provider': provider,
        'text': text,
        'languageCode': languageCode,
      }),
    );
    final response = await request.close();
    final bytes = await response.fold<List<int>>(<int>[], (all, chunk) {
      all.addAll(chunk);
      return all;
    });
    if (response.statusCode != 200) {
      throw StateError('TTS request failed with ${response.statusCode}');
    }
    return Uint8List.fromList(bytes);
  } finally {
    client.close(force: true);
  }
}

Future<String> _postTranslate({
  required String baseUrl,
  required String token,
  required String text,
  required String sourceLanguage,
  required String targetLanguage,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$baseUrl/v1/translate'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'text': text,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
      }),
    );
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode != 200) {
      throw StateError(
        'Translate request failed with ${response.statusCode}: $body',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['translatedText'] as String;
  } finally {
    client.close(force: true);
  }
}

Future<List<String>> _streamStt({
  required String baseUrl,
  required String token,
  required Stream<Uint8List> audioStream,
  required int sampleRate,
  required String sourceLanguage,
  required String language,
}) async {
  final wsUri = Uri.parse(
    baseUrl.replaceFirst('http', 'ws'),
  ).resolve('/v1/stt/live');
  final channel = WebSocketChannel.connect(wsUri);
  await channel.ready;

  final ready = Completer<void>();
  final firstResult = Completer<void>();
  final done = Completer<void>();
  final results = <String>[];
  final subscription = channel.stream.listen(
    (message) {
      if (message is! String) {
        return;
      }
      final payload = jsonDecode(message) as Map<String, dynamic>;
      switch (payload['type']) {
        case 'ready':
          if (!ready.isCompleted) {
            ready.complete();
          }
          break;
        case 'recognition_result':
          final words = (payload['words'] as List<dynamic>)
              .map((word) => (word as Map<String, dynamic>)['word'] as String)
              .join(' ');
          results.add(words);
          if (!firstResult.isCompleted) {
            firstResult.complete();
          }
          break;
        case 'error':
          final error = StateError(payload['message'] as String);
          if (!ready.isCompleted) {
            ready.completeError(error);
          }
          if (!firstResult.isCompleted) {
            firstResult.completeError(error);
          }
          if (!done.isCompleted) {
            done.completeError(error);
          }
          break;
      }
    },
    onDone: () {
      if (!done.isCompleted) {
        done.complete();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!done.isCompleted) {
        done.completeError(error, stackTrace);
      }
    },
  );

  channel.sink.add(
    jsonEncode({
      'type': 'start',
      'token': token,
      'sourceLanguage': sourceLanguage,
      'sampleRate': sampleRate,
      'model': 'nova-3',
      'language': language,
      'diarize': false,
      'utterances': true,
      'punctuate': true,
      'smartFormat': true,
      'detectLanguage': false,
    }),
  );

  await ready.future;
  await for (final chunk in audioStream) {
    channel.sink.add(chunk);
  }
  channel.sink.add(jsonEncode({'type': 'stop'}));
  await firstResult.future.timeout(const Duration(seconds: 5));
  await done.future.timeout(const Duration(seconds: 5));
  await subscription.cancel();
  await channel.sink.close();
  return results;
}

void main() {
  late HttpServer httpServer;
  late ApiServer apiServer;
  late String baseUrl;
  const token = 'local-firebase-token';

  setUpAll(() async {
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
      serve: (handler, address, port) => shelf_io.serve(handler, address, port),
      googleAuthClientFactory: _FakeGoogleAuthClientFactory(),
      firebaseAuthVerifier: _FakeFirebaseAuthVerifier(),
      liveSpeechRecognitionService: _FakeLiveSpeechRecognitionService(),
      translationService: _FakeTranslationService(),
      googleTtsService: _FakeTtsService(),
      deepgramTtsService: _FakeTtsService(),
    );

    httpServer = await apiServer.start();
    baseUrl = 'http://${httpServer.address.host}:${httpServer.port}';
  });

  tearDownAll(() async {
    await apiServer.close();
    await httpServer.close(force: true);
  });

  group('Local API E2E', () {
    test('health endpoint responds ok', () async {
      expect(await _isBackendHealthy(baseUrl), isTrue);
    });

    test('translate endpoint returns translated text', () async {
      final translated = await _postTranslate(
        baseUrl: baseUrl,
        token: token,
        text: 'Hello, how are you?',
        sourceLanguage: 'en',
        targetLanguage: 'es',
      );

      expect(translated, equals('Hola, como estas?'));
    });

    test('tts endpoint returns audio bytes', () async {
      final bytes = await _postTts(
        baseUrl: baseUrl,
        token: token,
        text: 'This is a backend end to end test in English.',
        provider: 'deepgram',
        languageCode: 'en-US',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1024));
    });

    test(
      'stt websocket accepts sine-wave audio stream',
      () async {
        final results = await _streamStt(
          baseUrl: baseUrl,
          token: token,
          audioStream: _generatePcmSineWaveStream(
            totalDuration: const Duration(milliseconds: 800),
          ),
          sampleRate: 16000,
          sourceLanguage: 'en-US',
          language: 'en',
        );

        expect(results, isNotEmpty);
        expect(results.first, contains('birch canoe'));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    Future<void> expectWavRecognition({
      required String wavPath,
      required String expectedTranscript,
      required String sourceLanguage,
      required String language,
      required int sampleRate,
    }) async {
      final wavFile = File(wavPath);
      expect(
        await wavFile.exists(),
        isTrue,
        reason: 'Missing fixture $wavPath',
      );
      final pcmBytes = _extractWavPcm(await wavFile.readAsBytes());

      final results = await _streamStt(
        baseUrl: baseUrl,
        token: token,
        audioStream: _chunkPcmStream(
          pcmBytes,
          chunkSize: 4096,
          interChunkDelay: Duration.zero,
        ),
        sampleRate: sampleRate,
        sourceLanguage: sourceLanguage,
        language: language,
      );

      expect(_normalizedTranscript(results), equals(expectedTranscript));
    }

    test(
      'stt websocket transcribes english wav fixture',
      () async {
        await expectWavRecognition(
          wavPath: _sampleEnWavPath,
          expectedTranscript: _sampleEnWavContent,
          sourceLanguage: 'en-US',
          language: 'en',
          sampleRate: 8000,
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'stt websocket transcribes french wav fixture',
      () async {
        await expectWavRecognition(
          wavPath: _sampleFrWavPath,
          expectedTranscript: _sampleFrWavContent,
          sourceLanguage: 'fr-FR',
          language: 'fr',
          sampleRate: 8000,
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'stt websocket transcribes hindi wav fixture',
      () async {
        await expectWavRecognition(
          wavPath: _sampleHiWavPath,
          expectedTranscript: _sampleHiWavContent,
          sourceLanguage: 'hi-IN',
          language: 'hi',
          sampleRate: 16000,
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}
