import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'request_context.dart';

void logStructured(Logger logger, Level level, Map<String, Object?> payload) {
  logger.log(level, jsonEncode(payload));
}

RequestTraceContext requestTraceContextFor(Request request) {
  final existing = request.context[requestTraceContextKey];
  if (existing is RequestTraceContext) {
    return existing;
  }
  return const RequestTraceContext(
    requestId: 'unknown',
    traceId: null,
    clientIp: 'unknown',
  );
}

String clientIpFor(Request request) {
  final forwardedFor = request.headers['x-forwarded-for'];
  if (forwardedFor != null && forwardedFor.trim().isNotEmpty) {
    return forwardedFor.split(',').first.trim();
  }

  final realIp = request.headers['x-real-ip'];
  if (realIp != null && realIp.trim().isNotEmpty) {
    return realIp.trim();
  }

  return 'unknown';
}

String? traceIdFor(Request request) {
  final traceHeader = request.headers['x-cloud-trace-context'];
  if (traceHeader == null || traceHeader.trim().isEmpty) {
    return null;
  }

  final traceId = traceHeader.split('/').first.trim();
  return traceId.isEmpty ? null : traceId;
}
