import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GoogleSpeechService {
  final String googleApiKey;
  final http.Client _httpClient;

  GoogleSpeechService({
    required this.googleApiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    bool returnOriginalOnFailure = true,
    bool throwOnMissingApiKey = false,
    bool nullWhenUnchanged = false,
  }) async {
    if (googleApiKey.isEmpty) {
      if (throwOnMissingApiKey) {
        throw Exception('No Google API key provided');
      }
      return returnOriginalOnFailure ? text : null;
    }

    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$googleApiKey',
    );
    final resp = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'target': targetLanguage,
        'format': 'text',
      }),
    );

    if (resp.statusCode != 200) {
      if (returnOriginalOnFailure) {
        return text;
      }
      throw Exception('Translate API returned ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final translations = data?['translations'] as List<dynamic>?;
    if (translations == null || translations.isEmpty) {
      if (returnOriginalOnFailure) {
        return text;
      }
      throw Exception('Invalid translation response: ${resp.body}');
    }

    final first = translations.first as Map<String, dynamic>;
    final translated = (first['translatedText'] as String?) ?? text;
    if (nullWhenUnchanged && translated == text) {
      return null;
    }

    return translated;
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
    String ssmlGender = 'NEUTRAL',
  }) async {
    if (googleApiKey.isEmpty) {
      return Uint8List(0);
    }

    final url = Uri.parse(
      'https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleApiKey',
    );
    final resp = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {
          'languageCode': languageCode,
          'ssmlGender': ssmlGender,
        },
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('TTS API returned ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final audioContent = body['audioContent'] as String;
    return base64Decode(audioContent);
  }

  String ttsLanguageCodeForAppLanguage(String appLang) {
    switch (appLang) {
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'zh-CN':
      case 'zh':
        return 'cmn-CN';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'pt':
        return 'pt-BR';
      case 'ru':
        return 'ru-RU';
      case 'ar':
        return 'ar-XA';
      case 'hi':
        return 'hi-IN';
      default:
        return appLang.contains('-') ? appLang : '$appLang-US';
    }
  }
}
