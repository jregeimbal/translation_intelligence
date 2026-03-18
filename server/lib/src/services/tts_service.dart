import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/tts_request.dart';
import 'google_auth_client_factory.dart';

abstract class TtsService {
  Future<Uint8List> synthesize(TtsRequest request);
}

class GoogleCloudTtsService implements TtsService {
  GoogleCloudTtsService({required GoogleAuthClientFactory authFactory})
    : _authFactory = authFactory;

  final GoogleAuthClientFactory _authFactory;

  static const _scopes = <String>[
    'https://www.googleapis.com/auth/cloud-platform',
  ];

  @override
  Future<Uint8List> synthesize(TtsRequest request) async {
    final client = await _authFactory.getClient(_scopes);
    final response = await client.post(
      Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'input': {'text': request.text},
        'voice': {
          'languageCode': request.languageCode,
          'ssmlGender': 'NEUTRAL',
        },
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Google Text-to-Speech request failed');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final audioContent = json['audioContent'] as String?;
    if (audioContent == null || audioContent.isEmpty) {
      throw StateError(
        'Google Text-to-Speech response was missing audioContent',
      );
    }

    return base64Decode(audioContent);
  }
}

class DeepgramTtsService implements TtsService {
  DeepgramTtsService({required String apiKey, http.Client? httpClient})
    : _apiKey = apiKey,
      _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _httpClient;

  @override
  Future<Uint8List> synthesize(TtsRequest request) async {
    final response = await _httpClient.post(
      Uri.parse(
        'https://api.deepgram.com/v1/speak?model=${_modelForLanguage(request.languageCode)}',
      ),
      headers: {
        'authorization': 'Token $_apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({'text': request.text}),
    );

    if (response.statusCode != 200) {
      throw StateError('Deepgram Text-to-Speech request failed');
    }

    return response.bodyBytes;
  }

  String _modelForLanguage(String appLangOrLocale) {
    final lang = appLangOrLocale.split('-').first.toLowerCase();
    switch (lang) {
      case 'es':
        return 'aura-2-carina-es';
      case 'fr':
        return 'aura-2-agathe-fr';
      case 'de':
        return 'aura-2-julius-de';
      default:
        return 'aura-2-odysseus-en';
    }
  }
}
