import 'dart:async';

import 'package:googleapis_auth/auth_io.dart';

class GoogleAuthClientFactory {
  GoogleAuthClientFactory({required Map<String, dynamic> serviceAccountJson})
    : _credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  GoogleAuthClientFactory.testing() : _credentials = null;

  final ServiceAccountCredentials? _credentials;
  final Map<String, AuthClient> _clientsByScopeKey = <String, AuthClient>{};

  Future<AuthClient> getClient(List<String> scopes) async {
    final credentials = _credentials;
    if (credentials == null) {
      throw StateError(
        'GoogleAuthClientFactory testing instance has no credentials',
      );
    }

    final normalizedScopes = List<String>.from(scopes)..sort();
    final scopeKey = normalizedScopes.join(' ');
    final existingClient = _clientsByScopeKey[scopeKey];
    if (existingClient != null) {
      return existingClient;
    }

    final client = await clientViaServiceAccount(credentials, normalizedScopes);
    _clientsByScopeKey[scopeKey] = client;
    return client;
  }

  Future<void> close() async {
    for (final client in _clientsByScopeKey.values) {
      client.close();
    }
    _clientsByScopeKey.clear();
  }
}
