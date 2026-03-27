class SuggestResponseRequest {
  const SuggestResponseRequest({
    required this.messageText,
    required this.messageTranslation,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  final String messageText;
  final String messageTranslation;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  factory SuggestResponseRequest.fromJson(Map<String, dynamic> json) {
    return SuggestResponseRequest(
      messageText: json['messageText'] as String? ?? '',
      messageTranslation: json['messageTranslation'] as String? ?? '',
      sourceLanguageCode: json['sourceLanguageCode'] as String? ?? '',
      targetLanguageCode: json['targetLanguageCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageText': messageText,
      'messageTranslation': messageTranslation,
      'sourceLanguageCode': sourceLanguageCode,
      'targetLanguageCode': targetLanguageCode,
    };
  }
}