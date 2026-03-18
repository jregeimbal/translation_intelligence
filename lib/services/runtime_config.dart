import 'package:flutter_dotenv/flutter_dotenv.dart';

class RuntimeConfig {
  const RuntimeConfig({required this.apiBaseUrl});

  final String apiBaseUrl;

  factory RuntimeConfig.fromDotEnv(DotEnv dotenv) {
    String require(String key) {
      final value = dotenv.get(key, fallback: '').trim();
      if (value.isEmpty) {
        throw StateError('Missing required configuration: $key');
      }
      return value;
    }

    return RuntimeConfig(apiBaseUrl: require('API_BASE_URL'));
  }
}
