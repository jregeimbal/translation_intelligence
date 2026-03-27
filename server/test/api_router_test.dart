import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:translation_intelligence_server/src/http/api_router.dart';
import 'package:translation_intelligence_server/src/models/translate_request.dart';
import 'package:translation_intelligence_server/src/models/suggest_response.dart';
import 'package:translation_intelligence_server/src/models/suggest_response_request.dart';
import 'package:translation_intelligence_server/src/models/tts_request.dart';
import 'package:translation_intelligence_server/src/services/suggestion_service.dart';
import 'package:translation_intelligence_server/src/services/translation_service.dart';
import 'package:translation_intelligence_server/src/services/tts_service.dart';

class _FakeTranslationService implements TranslationService {
  TranslateRequest? lastRequest;

  @override
  Future<String> translate(TranslateRequest request) async {
    lastRequest = request;
    return 'hola';
  }
}

class _FakeTtsService implements TtsService {
  _FakeTtsService(this.bytes);

  final Uint8List bytes;
  TtsRequest? lastRequest;

  @override
  Future<Uint8List> synthesize(TtsRequest request) async {
    lastRequest = request;
    return bytes;
  }
}

class _FakeSuggestionService implements SuggestionService {
  SuggestResponseRequest? lastRequest;

  @override
  bool get isAvailable => true;

  @override
  Future<SuggestResponse> suggest(SuggestResponseRequest request) async {
    lastRequest = request;
    return const SuggestResponse(
      originalText: 'claro que si',
      translatedText: 'of course',
      sourceLanguageCode: 'es',
      targetLanguageCode: 'en',
    );
  }
}

void main() {
  group('ApiRouter', () {
    late _FakeTranslationService translationService;
    late _FakeTtsService googleTtsService;
    late _FakeTtsService deepgramTtsService;
    late _FakeSuggestionService suggestionService;
    late Handler handler;

    setUp(() {
      translationService = _FakeTranslationService();
      googleTtsService = _FakeTtsService(Uint8List.fromList(const [1, 2, 3]));
      deepgramTtsService = _FakeTtsService(Uint8List.fromList(const [4, 5]));
      suggestionService = _FakeSuggestionService();
      handler = ApiRouter(
        translationService: translationService,
        googleTtsService: googleTtsService,
        deepgramTtsService: deepgramTtsService,
        suggestionService: suggestionService,
      ).router.call;
    });

    test('health responds ok', () async {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/v1/health')),
      );

      expect(response.statusCode, 200);
      expect(await response.readAsString(), contains('ok'));
    });

    test('translate delegates to translation service', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/translate'),
          body: jsonEncode({
            'text': 'hello',
            'sourceLanguage': 'en',
            'targetLanguage': 'es',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, 200);
      expect(translationService.lastRequest?.text, 'hello');
      expect(await response.readAsString(), contains('hola'));
    });

    test('tts routes to provider service', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/tts'),
          body: jsonEncode({
            'provider': 'deepgram',
            'text': 'bonjour',
            'languageCode': 'fr-FR',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, 200);
      expect(deepgramTtsService.lastRequest?.provider, TtsProvider.deepgram);
      expect(await response.read().expand((chunk) => chunk).toList(), [4, 5]);
    });

    test('suggest delegates to suggestion service', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/suggest'),
          body: jsonEncode({
            'messageText': 'hola',
            'messageTranslation': 'hello',
            'sourceLanguageCode': 'es',
            'targetLanguageCode': 'en',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, 200);
      expect(suggestionService.lastRequest?.messageText, 'hola');
      expect(await response.readAsString(), contains('of course'));
    });
  });
}
