import 'package:flutter_dotenv/flutter_dotenv.dart';

class RuntimeConfig {
  const RuntimeConfig({required this.apiBaseUrl, required this.deepgramApiKey});

  final String apiBaseUrl;
  final String deepgramApiKey;

  factory RuntimeConfig.fromDotEnv(DotEnv dotenv) {
    String require(String key) {
      final value = dotenv.get(key, fallback: '').trim();
      if (value.isEmpty) {
        throw StateError('Missing required configuration: $key');
      }
      return value;
    }

    return RuntimeConfig(
      apiBaseUrl: require('API_BASE_URL'),
      deepgramApiKey: require('DEEPGRAM_API_KEY'),
    );
  }
}
