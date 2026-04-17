class SuggestedResponse {
  const SuggestedResponse({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  factory SuggestedResponse.fromJson(Map<String, dynamic> json) {
    return SuggestedResponse(
      originalText: json['originalText'] as String? ?? '',
      translatedText: json['translatedText'] as String? ?? '',
      sourceLanguageCode: json['sourceLanguageCode'] as String? ?? '',
      targetLanguageCode: json['targetLanguageCode'] as String? ?? '',
    );
  }

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

class SuggestedResponseEvent {
  const SuggestedResponseEvent({
    required this.messageId,
    required this.response,
  });

  final String messageId;
  final SuggestedResponse response;
}
