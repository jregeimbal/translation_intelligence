import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:translation_intelligence/services/backend_api_client.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

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
}

void main() {
  group('BackendApiClient', () {
    test('translateText sends auth and parses translated text', () async {
      late http.BaseRequest capturedRequest;
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-123',
        httpClient: _FakeHttpClient((request) async {
          capturedRequest = request;
          final streamed = request as http.Request;
          expect(jsonDecode(streamed.body), {
            'text': 'hello',
            'targetLanguage': 'es',
            'sourceLanguage': 'en',
          });
          return http.Response(
            jsonEncode({'translatedText': 'hola'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final translated = await client.translateText(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'es',
      );

      expect(translated, 'hola');
      expect(capturedRequest.headers['authorization'], 'Bearer token-123');
    });

    test('synthesizeSpeech posts provider and returns bytes', () async {
      final client = BackendApiClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token-abc',
        httpClient: _FakeHttpClient((request) async {
          final streamed = request as http.Request;
          expect(jsonDecode(streamed.body), {
            'provider': 'deepgram',
            'text': 'bonjour',
            'languageCode': 'fr-FR',
          });
          return http.Response.bytes(Uint8List.fromList(const [4, 5, 6]), 200);
        }),
      );

      final bytes = await client.synthesizeSpeech(
        text: 'bonjour',
        provider: SpeechOutputProvider.deepgram,
        languageCode: 'fr-FR',
      );

      expect(bytes, Uint8List.fromList(const [4, 5, 6]));
    });
  });
}
