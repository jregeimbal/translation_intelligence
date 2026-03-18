import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'request_context.dart';

abstract class FirebaseAuthVerifier {
  Future<AuthenticatedUser> verify(String token);
}

class FirebaseAuthException implements Exception {
  FirebaseAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseRestAuthVerifier implements FirebaseAuthVerifier {
  FirebaseRestAuthVerifier({required AppConfig config, http.Client? httpClient})
    : _config = config,
      _httpClient = httpClient ?? http.Client();

  final AppConfig _config;
  final http.Client _httpClient;

  static const _lookupBaseUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup';

  @override
  Future<AuthenticatedUser> verify(String token) async {
    final claims = _parseClaims(token);
    final issuer = claims['iss'] as String? ?? '';
    final audience = claims['aud'] as String? ?? '';
    final subject = claims['sub'] as String? ?? '';
    final expiresAt = int.tryParse('${claims['exp'] ?? ''}') ?? 0;

    if (subject.isEmpty) {
      throw FirebaseAuthException('Token subject is missing');
    }
    if (audience != _config.firebaseProjectId) {
      throw FirebaseAuthException('Token audience does not match project');
    }
    if (issuer !=
        'https://securetoken.google.com/${_config.firebaseProjectId}') {
      throw FirebaseAuthException('Token issuer does not match project');
    }
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt <= nowSeconds) {
      throw FirebaseAuthException('Token has expired');
    }

    final response = await _httpClient.post(
      Uri.parse('$_lookupBaseUrl?key=${_config.firebaseWebApiKey}'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'idToken': token}),
    );

    if (response.statusCode != 200) {
      throw FirebaseAuthException('Firebase token lookup failed');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final users = payload['users'] as List<dynamic>?;
    if (users == null || users.isEmpty) {
      throw FirebaseAuthException('Firebase token did not map to a user');
    }

    return AuthenticatedUser(uid: subject, issuer: issuer, audience: audience);
  }

  Map<String, dynamic> _parseClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw FirebaseAuthException('Malformed bearer token');
    }

    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }
}
