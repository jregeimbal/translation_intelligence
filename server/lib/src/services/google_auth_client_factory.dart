import 'dart:async';

import 'package:googleapis_auth/auth_io.dart';

class GoogleAuthClientFactory {
  GoogleAuthClientFactory({required Map<String, dynamic> serviceAccountJson})
    : _credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  GoogleAuthClientFactory.testing() : _credentials = null;

  final ServiceAccountCredentials? _credentials;
  AuthClient? _client;

  Future<AuthClient> getClient(List<String> scopes) async {
    final credentials = _credentials;
    if (credentials == null) {
      throw StateError(
        'GoogleAuthClientFactory testing instance has no credentials',
      );
    }

    _client ??= await clientViaServiceAccount(credentials, scopes);
    return _client!;
  }

  Future<void> close() async {
    _client?.close();
    _client = null;
  }
}
