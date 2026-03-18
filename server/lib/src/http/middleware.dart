import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'firebase_auth_verifier.dart';
import 'json_response.dart';
import 'metrics_registry.dart';
import 'rate_limiter.dart';
import 'request_context.dart';
import 'structured_logging.dart';

Middleware requestContextMiddleware() {
  return (innerHandler) {
    return (request) async {
      final isWebSocketUpgrade =
          request.headers['upgrade']?.toLowerCase() == 'websocket';
      final requestId = _randomRequestId();
      final traceContext = RequestTraceContext(
        requestId: requestId,
        traceId: traceIdFor(request),
        clientIp: clientIpFor(request),
      );
      final startedAt = DateTime.now();
      final response = await innerHandler(
        request.change(
          context: {
            ...request.context,
            'requestId': requestId,
            requestTraceContextKey: traceContext,
          },
        ),
      );

      logStructured(Logger('ApiServer'), Level.INFO, {
        'event': 'http_request_completed',
        'requestId': traceContext.requestId,
        'traceId': traceContext.traceId,
        'clientIp': traceContext.clientIp,
        'method': request.method,
        'path': request.requestedUri.path,
        'statusCode': response.statusCode,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      });

      if (isWebSocketUpgrade || request.url.path == 'v1/stt/live') {
        return response;
      }

      return response.change(headers: {'x-request-id': requestId});
    };
  };
}

Middleware errorHandlingMiddleware() {
  return (innerHandler) {
    return (request) async {
      final traceContext = requestTraceContextFor(request);
      try {
        return await innerHandler(request);
      } on HijackException {
        rethrow;
      } on FirebaseAuthException catch (error) {
        logStructured(Logger('ApiServer'), Level.WARNING, {
          'event': 'http_auth_error',
          'requestId': traceContext.requestId,
          'traceId': traceContext.traceId,
          'clientIp': traceContext.clientIp,
          'path': request.requestedUri.path,
          'message': error.message,
        });
        return jsonResponse({
          'error': {'code': 'unauthorized', 'message': error.message},
        }, statusCode: 401);
      } on FormatException catch (error) {
        logStructured(Logger('ApiServer'), Level.WARNING, {
          'event': 'http_format_error',
          'requestId': traceContext.requestId,
          'traceId': traceContext.traceId,
          'clientIp': traceContext.clientIp,
          'path': request.requestedUri.path,
          'message': error.message,
        });
        return jsonResponse({
          'error': {'code': 'bad_request', 'message': error.message},
        }, statusCode: 400);
      } on StateError catch (error) {
        logStructured(Logger('ApiServer'), Level.WARNING, {
          'event': 'http_state_error',
          'requestId': traceContext.requestId,
          'traceId': traceContext.traceId,
          'clientIp': traceContext.clientIp,
          'path': request.requestedUri.path,
          'message': error.message,
        });
        return jsonResponse({
          'error': {'code': 'service_unavailable', 'message': error.message},
        }, statusCode: 503);
      } catch (error) {
        logStructured(Logger('ApiServer'), Level.SEVERE, {
          'event': 'http_unhandled_error',
          'requestId': traceContext.requestId,
          'traceId': traceContext.traceId,
          'clientIp': traceContext.clientIp,
          'path': request.requestedUri.path,
          'error': '$error',
        });
        return jsonResponse({
          'error': {
            'code': 'internal_error',
            'message': 'An unexpected error occurred.',
          },
        }, statusCode: 500);
      }
    };
  };
}

Middleware metricsMiddleware(MetricsRegistry metricsRegistry) {
  return (innerHandler) {
    return (request) async {
      final isWebSocketUpgrade =
          request.headers['upgrade']?.toLowerCase() == 'websocket';
      if (!isWebSocketUpgrade) {
        metricsRegistry.recordHttpRequest();
      }
      return innerHandler(request);
    };
  };
}

Middleware rateLimitMiddleware({
  required RateLimiter rateLimiter,
  required int requestsPerMinute,
  required MetricsRegistry metricsRegistry,
}) {
  return (innerHandler) {
    return (request) async {
      final isWebSocketUpgrade =
          request.headers['upgrade']?.toLowerCase() == 'websocket';
      if (isWebSocketUpgrade || request.url.path == 'v1/health') {
        return innerHandler(request);
      }

      final clientIp = clientIpFor(request);
      final allowed = rateLimiter.allow(
        clientIp,
        requestsPerMinute,
        DateTime.now(),
      );
      if (allowed) {
        return innerHandler(request);
      }

      metricsRegistry.recordHttpRateLimited();
      final traceContext = requestTraceContextFor(request);
      logStructured(Logger('ApiServer'), Level.WARNING, {
        'event': 'http_rate_limited',
        'requestId': traceContext.requestId,
        'traceId': traceContext.traceId,
        'clientIp': clientIp,
        'path': request.requestedUri.path,
        'limitPerMinute': requestsPerMinute,
      });
      return jsonResponse({
        'error': {
          'code': 'rate_limited',
          'message': 'Too many requests. Please retry later.',
        },
      }, statusCode: 429);
    };
  };
}

Middleware corsMiddleware(Set<String> allowedOrigins) {
  return (innerHandler) {
    return (request) async {
      final isWebSocketUpgrade =
          request.headers['upgrade']?.toLowerCase() == 'websocket';
      final origin = request.headers['origin'];
      final allowOrigin = origin != null && allowedOrigins.contains(origin)
          ? origin
          : null;

      if (request.method == 'OPTIONS') {
        Logger('Middleware.corsMiddleware').fine(
          'Received preflight OPTIONS request for origin: $origin, allowOrigin: $allowOrigin',
        );
        return Response(204, headers: _corsHeaders(allowOrigin));
      }

      final response = await innerHandler(request);

      if (isWebSocketUpgrade || request.url.path == 'v1/stt/live') {
        return response;
      }

      Logger('Middleware.corsMiddleware').fine(
        'Applying CORS headers to response for origin: $origin, allowOrigin: $allowOrigin',
      );
      return response.change(headers: _corsHeaders(allowOrigin));
    };
  };
}

Middleware bearerAuthMiddleware(FirebaseAuthVerifier verifier) {
  return (innerHandler) {
    return (request) async {
      final isWebSocketUpgrade =
          request.headers['upgrade']?.toLowerCase() == 'websocket';

      if (request.url.path == 'v1/health' ||
          request.url.path == 'v1/stt/live' ||
          isWebSocketUpgrade) {
        return innerHandler(request);
      }

      final header = request.headers['authorization'];
      if (header == null || !header.startsWith('Bearer ')) {
        throw FirebaseAuthException('Missing bearer token');
      }

      final token = header.substring('Bearer '.length).trim();
      if (token.isEmpty) {
        throw FirebaseAuthException('Missing bearer token');
      }

      final user = await verifier.verify(token);
      return innerHandler(
        request.change(
          context: {...request.context, authenticatedUserContextKey: user},
        ),
      );
    };
  };
}

Map<String, String> _corsHeaders(String? allowOrigin) {
  return {
    ...?allowOrigin == null
        ? null
        : {'access-control-allow-origin': allowOrigin, 'vary': 'Origin'},
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'Authorization,Content-Type',
  };
}

String _randomRequestId() {
  final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
