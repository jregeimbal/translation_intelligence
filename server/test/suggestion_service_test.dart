import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:translation_intelligence_server/src/models/suggest_response_request.dart';
import 'package:translation_intelligence_server/src/models/translate_request.dart';
import 'package:translation_intelligence_server/src/services/google_auth_client_factory.dart';
import 'package:translation_intelligence_server/src/services/suggestion_service.dart';
import 'package:translation_intelligence_server/src/services/translation_service.dart';

class _FakeTranslationService implements TranslationService {
  TranslateRequest? lastRequest;
  String translatedText;

  _FakeTranslationService({this.translatedText = 'of course'});

  @override
  Future<String> translate(TranslateRequest request) async {
    lastRequest = request;
    return translatedText;
  }
}

class _FakeAuthClient extends http.BaseClient implements AuthClient {
  _FakeAuthClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleAuthClientFactory extends GoogleAuthClientFactory {
  _FakeGoogleAuthClientFactory(this.client) : super.testing();

  final AuthClient client;
  List<String>? lastScopes;

  @override
  Future<AuthClient> getClient(List<String> scopes) async {
    lastScopes = List<String>.from(scopes);
    return client;
  }
}

void main() {
  group('SuggestionService', () {
    test('unavailable suggestion service reports unavailable and throws', () {
      const service = UnavailableSuggestionService();

      expect(service.isAvailable, isFalse);
      expect(
        () => service.suggest(
          const SuggestResponseRequest(
            messageText: 'hola',
            messageTranslation: 'hello',
            sourceLanguageCode: 'es',
            targetLanguageCode: 'en',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'gemini suggestion service generates reply and translates it',
      () async {
        late http.BaseRequest capturedRequest;
        final authClient = _FakeAuthClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"suggestedReply":"claro que si"}'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final authFactory = _FakeGoogleAuthClientFactory(authClient);
        final translationService = _FakeTranslationService();
        final service = GeminiSuggestionService(
          authFactory: authFactory,
          projectId: 'demo-project',
          model: 'gemini-2.5-flash',
          translationService: translationService,
        );

        final response = await service.suggest(
          const SuggestResponseRequest(
            messageText: 'hola',
            messageTranslation: 'hello',
            sourceLanguageCode: 'es',
            targetLanguageCode: 'en',
          ),
        );

        expect(service.isAvailable, isTrue);
        expect(
          authFactory.lastScopes,
          containsAll(<String>[
            'https://www.googleapis.com/auth/cloud-platform',
            'https://www.googleapis.com/auth/generative-language.retriever',
          ]),
        );
        expect(capturedRequest.url.toString(), contains(':generateContent'));
        expect(capturedRequest.headers['x-goog-user-project'], 'demo-project');

        final requestBody =
            jsonDecode((capturedRequest as http.Request).body)
                as Map<String, dynamic>;
        final prompt =
            (((requestBody['contents'] as List<dynamic>).first
                            as Map<String, dynamic>)['parts']
                        as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        expect(
          prompt['text'] as String,
          contains('Write the reply in the source language.'),
        );
        expect(
          prompt['text'] as String,
          contains('Incoming message in source language (es): hola'),
        );

        expect(translationService.lastRequest?.text, 'claro que si');
        expect(translationService.lastRequest?.sourceLanguage, 'es');
        expect(translationService.lastRequest?.targetLanguage, 'en');
        expect(response.originalText, 'claro que si');
        expect(response.translatedText, 'of course');
        expect(response.sourceLanguageCode, 'es');
        expect(response.targetLanguageCode, 'en');
      },
    );

    test(
      'gemini suggestion service falls back for multi-language requests',
      () async {
        final authClient = _FakeAuthClient((request) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"suggestedReply":"sounds good"}'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final translationService = _FakeTranslationService(
          translatedText: 'suena bien',
        );
        final service = GeminiSuggestionService(
          authFactory: _FakeGoogleAuthClientFactory(authClient),
          projectId: 'demo-project',
          model: 'gemini-2.5-flash',
          translationService: translationService,
        );

        final response = await service.suggest(
          const SuggestResponseRequest(
            messageText: 'hello there',
            messageTranslation: 'hola',
            sourceLanguageCode: 'multi',
            targetLanguageCode: 'multi',
          ),
        );

        expect(translationService.lastRequest?.text, 'sounds good');
        expect(translationService.lastRequest?.sourceLanguage, isNull);
        expect(translationService.lastRequest?.targetLanguage, 'en');
        expect(response.sourceLanguageCode, 'multi');
        expect(response.targetLanguageCode, 'en');
        expect(response.translatedText, 'suena bien');
      },
    );

    test(
      'gemini suggestion service throws on invalid candidate payload',
      () async {
        final authClient = _FakeAuthClient((request) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'not valid json'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final service = GeminiSuggestionService(
          authFactory: _FakeGoogleAuthClientFactory(authClient),
          projectId: 'demo-project',
          model: 'gemini-2.5-flash',
          translationService: _FakeTranslationService(),
        );

        expect(
          () => service.suggest(
            const SuggestResponseRequest(
              messageText: 'hola',
              messageTranslation: 'hello',
              sourceLanguageCode: 'es',
              targetLanguageCode: 'en',
            ),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
