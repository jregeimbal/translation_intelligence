import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseAuthSession {

  FirebaseAuthSession({
    required FirebaseOptions options,
    FirebaseAuth? firebaseAuth,
  }) : _options = options,
       _firebaseAuth = firebaseAuth;
  final FirebaseOptions _options;
  FirebaseAuth? _firebaseAuth;

  Future<void> initialize() async {
    if (_firebaseAuth == null) {
      final FirebaseApp app = await _getFirebaseApp();
      _firebaseAuth = _getFirebaseAuthForApp(app);
    }

    final firebaseAuth = _requireFirebaseAuth();
    if (firebaseAuth.currentUser == null) {
      await firebaseAuth.signInAnonymously();
      return;
    }

    await firebaseAuth.currentUser!.getIdToken();
  }

  Future<FirebaseApp> _getFirebaseApp() {
    return Firebase.apps.isEmpty
        ? Firebase.initializeApp(options: _options)
        : Future.value(Firebase.app());
  }

  FirebaseAuth _getFirebaseAuthForApp(FirebaseApp app) {
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<String> getIdToken() async {
    final firebaseAuth = _requireFirebaseAuth();
    var user = firebaseAuth.currentUser;
    if (user == null) {
      final credentials = await firebaseAuth.signInAnonymously();
      user = credentials.user;
    }

    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Failed to obtain Firebase auth token');
    }

    return token;
  }

  FirebaseAuth _requireFirebaseAuth() {
    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth == null) {
      throw StateError('FirebaseAuthSession.initialize() must complete first');
    }
    return firebaseAuth;
  }
}
