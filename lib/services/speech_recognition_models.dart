class SpeechRecognitionWord {
  String word;
  final int? speaker;

  SpeechRecognitionWord({required this.word, required this.speaker});
}

class SpeechRecognitionResult {
  final bool isFinal;
  final List<SpeechRecognitionWord> words;

  const SpeechRecognitionResult({
    required this.isFinal,
    required this.words,
  });

  String wordsToText() {
    return words.map((word) => word.word).join(' ').trim();
  }

  factory SpeechRecognitionResult.fromTranscript({
    required String? transcript,
    required bool isFinal,
    int? speaker,
  }) {
    final normalizedTranscript = (transcript ?? '').trim();
    if (normalizedTranscript.isEmpty) {
      return SpeechRecognitionResult(isFinal: isFinal, words: const []);
    }

    final words = normalizedTranscript
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map(
          (token) => SpeechRecognitionWord(
            word: token,
            speaker: speaker,
          ),
        )
        .toList(growable: false);

    return SpeechRecognitionResult(isFinal: isFinal, words: words);
  }
}
