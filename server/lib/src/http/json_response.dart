import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, Object>? headers,
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}
