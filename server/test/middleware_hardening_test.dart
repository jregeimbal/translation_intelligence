import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:translation_intelligence_server/src/http/metrics_registry.dart';
import 'package:translation_intelligence_server/src/http/middleware.dart';
import 'package:translation_intelligence_server/src/http/rate_limiter.dart';

void main() {
  group('hardening middleware', () {
    test('rateLimitMiddleware returns 429 after per-IP limit', () async {
      final metrics = MetricsRegistry();
      final handler = const Pipeline()
          .addMiddleware(
            rateLimitMiddleware(
              rateLimiter: RateLimiter(window: const Duration(minutes: 1)),
              requestsPerMinute: 2,
              metricsRegistry: metrics,
            ),
          )
          .addHandler((request) async => Response.ok('ok'));

      Future<Response> makeRequest() {
        return Future<Response>.value(
          handler(
            Request(
              'GET',
              Uri.parse('http://localhost/v1/translate'),
              headers: {'x-forwarded-for': '203.0.113.10'},
            ),
          ),
        );
      }

      expect((await makeRequest()).statusCode, 200);
      expect((await makeRequest()).statusCode, 200);

      final limited = await makeRequest();
      final body =
          jsonDecode(await limited.readAsString()) as Map<String, dynamic>;

      expect(limited.statusCode, 429);
      expect(body['error']['code'], 'rate_limited');
      expect(metrics.httpRateLimitedTotal, 1);
    });

    test('metricsMiddleware counts HTTP requests only', () async {
      final metrics = MetricsRegistry();
      final handler = const Pipeline()
          .addMiddleware(metricsMiddleware(metrics))
          .addHandler((request) async => Response.ok('ok'));

      await handler(Request('GET', Uri.parse('http://localhost/v1/health')));
      await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/v1/stt/live'),
          headers: {'upgrade': 'websocket'},
        ),
      );

      expect(metrics.httpRequestsTotal, 1);
    });
  });
}
