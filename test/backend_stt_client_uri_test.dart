import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/services/backend_stt_client.dart';

void main() {
  group('BackendSttClient.buildWebSocketUri', () {
    test('converts http base URL to ws endpoint', () {
      final client = BackendSttClient(
        baseUrl: 'http://localhost:8080',
        authTokenProvider: () async => 'token',
      );

      expect(
        client.buildWebSocketUri().toString(),
        'ws://localhost:8080/v1/stt/live',
      );
    });

    test('converts https base URL to wss endpoint', () {
      final client = BackendSttClient(
        baseUrl: 'https://api.example.com',
        authTokenProvider: () async => 'token',
      );

      expect(
        client.buildWebSocketUri().toString(),
        'wss://api.example.com/v1/stt/live',
      );
    });
  });
}
