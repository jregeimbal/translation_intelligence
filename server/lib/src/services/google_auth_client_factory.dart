import 'dart:async';

import 'package:googleapis_auth/auth_io.dart';

class GoogleAuthClientFactory {
  GoogleAuthClientFactory({required Map<String, dynamic> serviceAccountJson})
    : _credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  final ServiceAccountCredentials _credentials;
  AuthClient? _client;

  Future<AuthClient> getClient(List<String> scopes) async {
    _client ??= await clientViaServiceAccount(_credentials, scopes);
    return _client!;
  }

  Future<void> close() async {
    _client?.close();
    _client = null;
  }
}
