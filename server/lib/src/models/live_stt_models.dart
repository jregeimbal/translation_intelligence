import 'dart:typed_data';

class LiveSttStartRequest {
  const LiveSttStartRequest({
    required this.token,
    required this.sourceLanguage,
    required this.sampleRate,
    this.model,
    this.language,
    this.diarize = false,
    this.utterances = false,
    this.punctuate = false,
    this.smartFormat = false,
    this.detectLanguage = false,
  });

  final String token;
  final String sourceLanguage;
  final int sampleRate;
  final String? model;
  final String? language;
  final bool diarize;
  final bool utterances;
  final bool punctuate;
  final bool smartFormat;
  final bool detectLanguage;

  factory LiveSttStartRequest.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] as String? ?? '').trim();
    final sourceLanguage = (json['sourceLanguage'] as String? ?? '').trim();
    final sampleRate = (json['sampleRate'] as num?)?.toInt() ?? 0;

    if (token.isEmpty) {
      throw const FormatException('token is required');
    }
    if (sourceLanguage.isEmpty) {
      throw const FormatException('sourceLanguage is required');
    }
    if (sampleRate <= 0) {
      throw const FormatException('sampleRate must be positive');
    }

    return LiveSttStartRequest(
      token: token,
      sourceLanguage: sourceLanguage,
      sampleRate: sampleRate,
      model: (json['model'] as String?)?.trim(),
      language: (json['language'] as String?)?.trim(),
      diarize: json['diarize'] as bool? ?? false,
      utterances: json['utterances'] as bool? ?? false,
      punctuate: json['punctuate'] as bool? ?? false,
      smartFormat: json['smartFormat'] as bool? ?? false,
      detectLanguage: json['detectLanguage'] as bool? ?? false,
    );
  }
}

class LiveSttWord {
  const LiveSttWord({required this.word, required this.speaker});

  final String word;
  final int? speaker;

  Map<String, dynamic> toJson() {
    return {'word': word, if (speaker != null) 'speaker': speaker};
  }
}

class LiveSttResult {
  const LiveSttResult({
    required this.isFinal,
    required this.speechFinal,
    required this.words,
  });

  final bool isFinal;
  final bool speechFinal;
  final List<LiveSttWord> words;

  Map<String, dynamic> toJson() {
    return {
      'type': 'recognition_result',
      'isFinal': isFinal,
      'speechFinal': speechFinal,
      'words': words.map((word) => word.toJson()).toList(growable: false),
    };
  }
}

class LiveSttStreamInput {
  const LiveSttStreamInput({required this.audioStream, required this.request});

  final Stream<Uint8List> audioStream;
  final LiveSttStartRequest request;
}
