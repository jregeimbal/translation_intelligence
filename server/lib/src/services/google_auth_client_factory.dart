import 'dart:async';

import 'package:googleapis_auth/auth_io.dart';

class GoogleAuthClientFactory {
  GoogleAuthClientFactory({Map<String, dynamic>? serviceAccountJson})
    : _credentials = serviceAccountJson != null
          ? ServiceAccountCredentials.fromJson(serviceAccountJson)
          : null;

  GoogleAuthClientFactory.testing() : _credentials = null;

  final ServiceAccountCredentials? _credentials;
  final Map<String, AuthClient> _clientsByScopeKey = <String, AuthClient>{};

  Future<AuthClient> getClient(List<String> scopes) async {
    final normalizedScopes = List<String>.from(scopes)..sort();
    final scopeKey = normalizedScopes.join(' ');
    final existingClient = _clientsByScopeKey[scopeKey];
    if (existingClient != null) {
      return existingClient;
    }

    final AuthClient client;
    final credentials = _credentials;
    if (credentials != null) {
      client = await clientViaServiceAccount(credentials, normalizedScopes);
    } else {
      // Use Application Default Credentials (e.g. Cloud Run service identity)
      client = await clientViaApplicationDefaultCredentials(
        scopes: normalizedScopes,
      );
    }
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
