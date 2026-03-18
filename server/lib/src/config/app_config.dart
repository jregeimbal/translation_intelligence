import 'dart:convert';
import 'dart:io';

class AppConfig {
  AppConfig({
    required this.host,
    required this.port,
    required this.allowedOrigins,
    required this.httpRateLimitPerMinute,
    required this.websocketSessionRateLimitPerMinute,
    required this.firebaseProjectId,
    required this.firebaseWebApiKey,
    required this.googleServiceAccountJson,
    required this.deepgramApiKey,
  });

  final String host;
  final int port;
  final Set<String> allowedOrigins;
  final int httpRateLimitPerMinute;
  final int websocketSessionRateLimitPerMinute;
  final String firebaseProjectId;
  final String firebaseWebApiKey;
  final String googleServiceAccountJson;
  final String deepgramApiKey;

  static AppConfig fromEnvironment() {
    final host = Platform.environment['SERVER_HOST'] ?? '0.0.0.0';
    final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
    final allowedOriginsRaw =
        Platform.environment['ALLOWED_ORIGINS'] ?? 'http://localhost:8000';
    final httpRateLimitPerMinute =
        int.tryParse(
          Platform.environment['HTTP_RATE_LIMIT_PER_MINUTE'] ?? '',
        ) ??
        120;
    final websocketSessionRateLimitPerMinute =
        int.tryParse(
          Platform.environment['WEBSOCKET_SESSION_RATE_LIMIT_PER_MINUTE'] ?? '',
        ) ??
        30;
    final firebaseProjectId = _requireEnv('FIREBASE_PROJECT_ID');
    final firebaseWebApiKey = _requireEnv('FIREBASE_WEB_API_KEY');
    final deepgramApiKey = _requireEnv('DEEPGRAM_API_KEY');
    final googleServiceAccountJson = _readGoogleServiceAccountJson();

    final allowedOrigins = allowedOriginsRaw
        .split(',')
        .map((origin) => origin.trim())
        .where((origin) => origin.isNotEmpty)
        .toSet();

    return AppConfig(
      host: host,
      port: port,
      allowedOrigins: allowedOrigins,
      httpRateLimitPerMinute: httpRateLimitPerMinute,
      websocketSessionRateLimitPerMinute: websocketSessionRateLimitPerMinute,
      firebaseProjectId: firebaseProjectId,
      firebaseWebApiKey: firebaseWebApiKey,
      googleServiceAccountJson: googleServiceAccountJson,
      deepgramApiKey: deepgramApiKey,
    );
  }

  Map<String, dynamic> get googleServiceAccount =>
      jsonDecode(googleServiceAccountJson) as Map<String, dynamic>;

  static String _readGoogleServiceAccountJson() {
    final inlineJson = Platform.environment['GOOGLE_SERVICE_ACCOUNT_JSON'];
    if (inlineJson != null && inlineJson.trim().isNotEmpty) {
      return inlineJson;
    }

    final jsonPath = Platform.environment['GOOGLE_SERVICE_ACCOUNT_JSON_PATH'];
    if (jsonPath != null && jsonPath.trim().isNotEmpty) {
      return File(jsonPath).readAsStringSync();
    }

    throw StateError(
      'Missing GOOGLE_SERVICE_ACCOUNT_JSON or GOOGLE_SERVICE_ACCOUNT_JSON_PATH',
    );
  }

  static String _requireEnv(String key) {
    final value = Platform.environment[key];
    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing required environment variable $key');
    }
    return value.trim();
  }
}
