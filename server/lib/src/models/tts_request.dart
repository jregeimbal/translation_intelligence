import 'dart:convert';

enum TtsProvider { google, deepgram }

class TtsRequest {
  const TtsRequest({
    required this.provider,
    required this.text,
    required this.languageCode,
  });

  final TtsProvider provider;
  final String text;
  final String languageCode;

  factory TtsRequest.fromJson(Map<String, dynamic> json) {
    final providerName = (json['provider'] as String? ?? '').trim();
    final text = (json['text'] as String? ?? '').trim();
    final languageCode = (json['languageCode'] as String? ?? '').trim();

    if (providerName.isEmpty) {
      throw const FormatException('provider is required');
    }
    if (text.isEmpty) {
      throw const FormatException('text is required');
    }
    if (languageCode.isEmpty) {
      throw const FormatException('languageCode is required');
    }

    return TtsRequest(
      provider: TtsProvider.values.byName(providerName),
      text: text,
      languageCode: languageCode,
    );
  }

  static Future<TtsRequest> fromRequestBody(String body) async {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    return TtsRequest.fromJson(payload);
  }
}
