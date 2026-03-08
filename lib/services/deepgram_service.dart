import 'dart:convert';
import 'dart:typed_data';

import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:http/http.dart' as http;

import 'speech_recognition_models.dart';

typedef DeepgramApiKeyValidator = Future<bool> Function();
typedef DeepgramLiveRecognizer = Stream<dynamic> Function(
  Stream<Uint8List> audioStream,
  Map<String, dynamic> queryParams,
);

class DeepgramService {
  final Deepgram _deepgram;
  final String _apiKey;
  final http.Client _httpClient;
  final DeepgramApiKeyValidator? _apiKeyValidator;
  final DeepgramLiveRecognizer? _liveRecognizer;

  DeepgramService({
    required String apiKey,
    http.Client? httpClient,
    DeepgramApiKeyValidator? apiKeyValidator,
    DeepgramLiveRecognizer? liveRecognizer,
  })
      : _apiKey = apiKey,
        _deepgram = Deepgram(apiKey),
        _httpClient = httpClient ?? http.Client(),
        _apiKeyValidator = apiKeyValidator,
        _liveRecognizer = liveRecognizer;

  Future<bool> isApiKeyValid() {
    return (_apiKeyValidator ?? _deepgram.isApiKeyValid)();
  }

  Stream<SpeechRecognitionResult> startLiveRecognition(
    Stream<Uint8List> audioStream, {
    required String sourceLanguage,
    bool diarize = false,
    bool utterances = false,
    String sampleRate = '16000',
  }) {
    final params = <String, dynamic>{
      'detect_language': false,
      'language': sourceLanguage == 'multi'
          ? 'multi'
          : normalizeLanguage(sourceLanguage),
      'model': 'nova-3',
      'encoding': 'linear16',
      'sample_rate': sampleRate,
      'interim_results': true,
      'punctuate': true,
      'diarize': diarize,
      'utterances': utterances,
    };

    Stream<dynamic> defaultLiveRecognizer(
      Stream<Uint8List> stream,
      Map<String, dynamic> queryParams,
    ) {
      return _deepgram.listen.live(stream, queryParams: queryParams);
    }

    final recognizer = _liveRecognizer ?? defaultLiveRecognizer;
    final liveStream = recognizer(audioStream, params);

    return liveStream.map((result) {
      final mappedWords = (result.words as Iterable)
          .map<SpeechRecognitionWord>(
            (word) => SpeechRecognitionWord(
              word: word.word,
              speaker: word.speaker,
            ),
          )
          .toList(growable: false);

      return SpeechRecognitionResult(
        isFinal: result.isFinal,
        words: mappedWords,
      );
    });
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en',
  }) async {
    if (_apiKey.isEmpty) {
      return Uint8List(0);
    }

    final model = ttsModelForLanguage(languageCode);
    final url = Uri.parse('https://api.deepgram.com/v1/speak?model=$model');
    final resp = await _httpClient.post(
      url,
      headers: {
        'Authorization': 'Token $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Deepgram TTS API returned ${resp.statusCode}: ${resp.body}');
    }

    return resp.bodyBytes;
  }

  String ttsModelForLanguage(String appLangOrLocale) {
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

  String normalizeLanguage(String appLang) {
    switch (appLang) {
      case 'zh-CN':
        return 'zh';
      case 'pt':
        return 'pt';
      default:
        return appLang.split('-').first;
    }
  }
}
