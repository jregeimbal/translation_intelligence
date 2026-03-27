class SuggestResponse {
  const SuggestResponse({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  final String originalText;
  final String translatedText;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  Map<String, dynamic> toJson() {
    return {
      'originalText': originalText,
      'translatedText': translatedText,
      'sourceLanguageCode': sourceLanguageCode,
      'targetLanguageCode': targetLanguageCode,
    };
  }
}