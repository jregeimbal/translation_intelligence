import 'dart:convert';

import '../models/translate_request.dart';
import 'google_auth_client_factory.dart';

abstract class TranslationService {
  Future<String> translate(TranslateRequest request);
}

class GoogleCloudTranslationService implements TranslationService {
  GoogleCloudTranslationService({required GoogleAuthClientFactory authFactory})
    : _authFactory = authFactory;

  final GoogleAuthClientFactory _authFactory;

  static const _scopes = <String>[
    'https://www.googleapis.com/auth/cloud-platform',
  ];

  @override
  Future<String> translate(TranslateRequest request) async {
    final client = await _authFactory.getClient(_scopes);
    final response = await client.post(
      Uri.parse('https://translation.googleapis.com/language/translate/v2'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'q': request.text,
        'target': request.targetLanguage,
        if (request.sourceLanguage != null) 'source': request.sourceLanguage,
        'format': 'text',
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Google Translation request failed: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final translations = data?['translations'] as List<dynamic>?;
    final translation = translations?.firstOrNull as Map<String, dynamic>?;
    final translatedText = translation?['translatedText'] as String?;

    if (translatedText == null || translatedText.isEmpty) {
      throw StateError(
        'Google Translation response was missing translatedText',
      );
    }

    return translatedText;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
