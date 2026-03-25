import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:logging/logging.dart';

import '../models/live_stt_models.dart';

typedef DeepgramLiveListen = Stream<dynamic> Function(
  Stream<List<int>> audioStream, {
  Map<String, dynamic>? queryParams,
});

abstract class LiveSpeechRecognitionService {
  Stream<LiveSttResult> start(LiveSttStreamInput input);
}

class DeepgramLiveSpeechRecognitionService
    implements LiveSpeechRecognitionService {
  DeepgramLiveSpeechRecognitionService({
    required String apiKey,
    DeepgramLiveListen? liveListen,
  }) : _deepgram = Deepgram(apiKey),
       _liveListen = liveListen;

  final Deepgram _deepgram;
  final DeepgramLiveListen? _liveListen;
  final Logger _logger = Logger('DeepgramLiveSpeechRecognitionService');

  @override
  Stream<LiveSttResult> start(LiveSttStreamInput input) {
    final request = input.request;
    final selectedLanguage = request.sourceLanguage == 'multi'
        ? (request.language ?? 'multi')
        : request.sourceLanguage;

    final params = <String, dynamic>{
      'detect_language': request.detectLanguage,
      'language': selectedLanguage == 'multi'
          ? 'multi'
          : _normalizeLanguage(selectedLanguage),
      'model': request.model ?? 'nova-3',
      'encoding': 'linear16',
      'sample_rate': request.sampleRate.toString(),
      'interim_results': true,
      'punctuate': request.punctuate,
      'diarize': request.diarize,
      'utterances': request.utterances,
      'smart_format': request.smartFormat,
    };

    _logger.info(
      'Starting Deepgram live stream: model=${params['model']} '
      'language=${params['language']} sampleRate=${params['sample_rate']}',
    );

    final liveListen = _liveListen ?? _deepgram.listen.live;

    return liveListen(input.audioStream, queryParams: params).map((result) {
      final words = (result.words as Iterable)
          .map<LiveSttWord>(
            (word) => LiveSttWord(
              word: word.word as String,
              speaker: word.speaker as int?,
            ),
          )
          .toList(growable: false);

      return LiveSttResult(
        isFinal: result.isFinal,
        speechFinal: _speechFinal(result),
        words: words,
      );
    });
  }

  bool _speechFinal(dynamic result) {
    if (result is Map) {
      final direct = result['speech_final'] ?? result['speechFinal'];
      if (direct is bool) {
        return direct;
      }
    }

    try {
      final dynamic value = result.speechFinal;
      if (value is bool) {
        return value;
      }
    } catch (_) {}

    try {
      final dynamic json = result.toJson();
      if (json is Map) {
        final dynamic value = json['speech_final'] ?? json['speechFinal'];
        if (value is bool) {
          return value;
        }
      }
    } catch (_) {}

    return false;
  }

  String _normalizeLanguage(String appLang) {
    switch (appLang) {
      case 'zh-CN':
        return 'zh';
      default:
        return appLang.split('-').first;
    }
  }
}
