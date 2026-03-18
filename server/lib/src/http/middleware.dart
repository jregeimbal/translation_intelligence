import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'firebase_auth_verifier.dart';
import 'json_response.dart';
import 'request_context.dart';

Middleware requestContextMiddleware() {
  return (innerHandler) {
    return (request) async {
      final requestId = _randomRequestId();
      final startedAt = DateTime.now();
      final response = await innerHandler(
        request.change(context: {...request.context, 'requestId': requestId}),
      );

      Logger('ApiServer').info(
        '${request.method} ${request.requestedUri.path} '
        '${response.statusCode} ${DateTime.now().difference(startedAt).inMilliseconds}ms '
        'requestId=$requestId',
      );

      return response.change(headers: {'x-request-id': requestId});
    };
  };
}

Middleware errorHandlingMiddleware() {
  return (innerHandler) {
    return (request) async {
      try {
        Logger('ApiServer').fine('Handling request: ${request.method} ${request.requestedUri}');
        return await innerHandler(request);
      } on FirebaseAuthException catch (error) {
        Logger('ApiServer').warning('Authentication error: ${error.message}');
        return jsonResponse({
          'error': {'code': 'unauthorized', 'message': error.message},
        }, statusCode: 401);
      } on FormatException catch (error) {
        Logger('ApiServer').warning('Format error: ${error.message}');
        return jsonResponse({
          'error': {'code': 'bad_request', 'message': error.message},
        }, statusCode: 400);
      } on StateError catch (error) {
        Logger('ApiServer').warning('State error: ${error.message}');
        return jsonResponse({
          'error': {'code': 'service_unavailable', 'message': error.message},
        }, statusCode: 503);
      } catch (error, stackTrace) {
        Logger(
          'ApiServer',
        ).severe('Unhandled request error', error, stackTrace);
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

Middleware corsMiddleware(Set<String> allowedOrigins) {
  return (innerHandler) {
    return (request) async {
      final origin = request.headers['origin'];
      final allowOrigin = origin != null && allowedOrigins.contains(origin)
          ? origin
          : null;

      if (request.method == 'OPTIONS') {
        Logger('Middleware.corsMiddleware').fine('Received preflight OPTIONS request for origin: $origin, allowOrigin: $allowOrigin');
        return Response(204, headers: _corsHeaders(allowOrigin));
      }

      final response = await innerHandler(request);
      Logger('Middleware.corsMiddleware').fine('Applying CORS headers to response for origin: $origin, allowOrigin: $allowOrigin');
      return response.change(headers: _corsHeaders(allowOrigin));
    };
  };
}

Middleware bearerAuthMiddleware(FirebaseAuthVerifier verifier) {
  return (innerHandler) {
    return (request) async {
      if (request.url.path == 'v1/health') {
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
