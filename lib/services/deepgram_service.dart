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
  static const String defaultRecognitionModel = 'nova-3';
  static const String defaultRecognitionLanguage = 'multi';

  static const List<String> supportedRecognitionModels = [
    'nova-3',
    'flux-general-en',
  ];

  static const Map<String, Map<String, String>> supportedRecognitionLanguagesByModel = {
    'nova-3': {
      'Multi': 'multi',
      'English': 'en',
      'Spanish': 'es',
      'French': 'fr',
      'German': 'de',
      'Portuguese': 'pt',
      'Russian': 'ru',
      'Japanese': 'ja',
      'Italian': 'it',
      'Dutch': 'nl',
      'Hindi': 'hi',
      'Arabic': 'ar',
    },
    'flux-general-en': {
      'English': 'en',
    },
  };

  final Deepgram _deepgram;
  final String _apiKey;
  final http.Client _httpClient;
  final DeepgramApiKeyValidator? _apiKeyValidator;
  final DeepgramLiveRecognizer? _liveRecognizer;
  String _recognitionModel;
  String _recognitionLanguage;

  DeepgramService({
    required String apiKey,
    http.Client? httpClient,
    DeepgramApiKeyValidator? apiKeyValidator,
    DeepgramLiveRecognizer? liveRecognizer,
    String initialRecognitionModel = defaultRecognitionModel,
    String initialRecognitionLanguage = defaultRecognitionLanguage,
  })
      : _apiKey = apiKey,
        _deepgram = Deepgram(apiKey),
        _httpClient = httpClient ?? http.Client(),
        _apiKeyValidator = apiKeyValidator,
        _liveRecognizer = liveRecognizer,
        _recognitionModel = initialRecognitionModel,
        _recognitionLanguage = initialRecognitionLanguage;

  String get recognitionModel => _recognitionModel;
  String get recognitionLanguage => _recognitionLanguage;

  Map<String, String> supportedRecognitionLanguagesForModel(String model) {
    return supportedRecognitionLanguagesByModel[model] ??
        supportedRecognitionLanguagesByModel[defaultRecognitionModel]!;
  }

  bool isRecognitionLanguageSupportedForModel(
    String model,
    String language,
  ) {
    return supportedRecognitionLanguagesForModel(model).containsValue(language);
  }

  static String defaultRecognitionLanguageForModel(String model) {
    if (model == 'flux-general-en') {
      return 'en';
    }
    return defaultRecognitionLanguage;
  }

  void setRecognitionModel(String model) {
    if (!supportedRecognitionModels.contains(model)) {
      return;
    }
    _recognitionModel = model;
    if (!isRecognitionLanguageSupportedForModel(model, _recognitionLanguage)) {
      _recognitionLanguage = defaultRecognitionLanguageForModel(model);
    }
  }

  void setRecognitionLanguage(String language) {
    if (!isRecognitionLanguageSupportedForModel(_recognitionModel, language)) {
      return;
    }
    _recognitionLanguage = language;
  }

  Future<bool> isApiKeyValid() {
    return (_apiKeyValidator ?? _deepgram.isApiKeyValid)();
  }

  Stream<SpeechRecognitionResult> startLiveRecognition(
    Stream<Uint8List> audioStream, {
    required String sourceLanguage,
    String? model,
    String? language,
    bool diarize = false,
    bool utterances = false,
    String sampleRate = '16000',
  }) {
    final selectedModel = model ?? _recognitionModel;
    final selectedLanguage =
        sourceLanguage == 'multi' ? (language ?? _recognitionLanguage) : sourceLanguage;

    final params = <String, dynamic>{
      'detect_language': false,
      'language': selectedLanguage == 'multi'
          ? 'multi'
          : normalizeLanguage(selectedLanguage),
      'model': selectedModel,
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
