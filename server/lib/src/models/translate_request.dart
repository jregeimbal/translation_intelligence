import 'dart:convert';

class TranslateRequest {
  const TranslateRequest({
    required this.text,
    required this.targetLanguage,
    this.sourceLanguage,
  });

  final String text;
  final String targetLanguage;
  final String? sourceLanguage;

  factory TranslateRequest.fromJson(Map<String, dynamic> json) {
    final text = (json['text'] as String? ?? '').trim();
    final targetLanguage = (json['targetLanguage'] as String? ?? '').trim();
    final sourceLanguage = (json['sourceLanguage'] as String?)?.trim();

    if (text.isEmpty) {
      throw const FormatException('text is required');
    }
    if (targetLanguage.isEmpty) {
      throw const FormatException('targetLanguage is required');
    }

    return TranslateRequest(
      text: text,
      targetLanguage: targetLanguage,
      sourceLanguage: sourceLanguage?.isEmpty == true ? null : sourceLanguage,
    );
  }

  static Future<TranslateRequest> fromRequestBody(String body) async {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    return TranslateRequest.fromJson(payload);
  }
}
