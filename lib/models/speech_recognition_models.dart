class SpeechRecognitionWord {
  String word;
  final int? speaker;

  SpeechRecognitionWord({required this.word, required this.speaker});
}

class SpeechRecognitionResult {
  final bool isFinal;
  final bool speechFinal;
  final List<SpeechRecognitionWord> words;

  const SpeechRecognitionResult({
    required this.isFinal,
    this.speechFinal = false,
    required this.words,
  });

  String wordsToText() {
    return words.map((word) => word.word).join(' ').trim();
  }

  factory SpeechRecognitionResult.fromTranscript({
    required String? transcript,
    required bool isFinal,
    bool speechFinal = false,
    int? speaker,
  }) {
    final normalizedTranscript = (transcript ?? '').trim();
    if (normalizedTranscript.isEmpty) {
      return SpeechRecognitionResult(
        isFinal: isFinal,
        speechFinal: speechFinal,
        words: const [],
      );
    }

    final words = normalizedTranscript
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => SpeechRecognitionWord(word: token, speaker: speaker))
        .toList(growable: false);

    return SpeechRecognitionResult(
      isFinal: isFinal,
      speechFinal: speechFinal,
      words: words,
    );
  }
}
