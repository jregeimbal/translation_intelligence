import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'speech_output_provider.dart';

class BackendApiClient {
  BackendApiClient({
    required String baseUrl,
    required Future<String> Function() authTokenProvider,
    http.Client? httpClient,
  }) : _baseUri = Uri.parse(baseUrl),
       _authTokenProvider = authTokenProvider,
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final Future<String> Function() _authTokenProvider;
  final http.Client _httpClient;

  Future<bool> isAvailable() async {
    final response = await _httpClient.get(_resolve('/v1/health'));
    return response.statusCode == 200;
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

      if (nullWhenUnchanged && translatedText == text) {
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

  void close() {
    _httpClient.close();
  }
}
