import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseAuthSession {
  final FirebaseOptions _options;
  FirebaseAuth? _firebaseAuth;

  FirebaseAuthSession({
    required FirebaseOptions options,
    FirebaseAuth? firebaseAuth,
  }) : _options = options,
       _firebaseAuth = firebaseAuth;

  Future<void> initialize() async {
    final FirebaseApp app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: _options)
        : Firebase.app();
    _firebaseAuth ??= FirebaseAuth.instanceFor(app: app);

    final firebaseAuth = _requireFirebaseAuth();
    if (firebaseAuth.currentUser == null) {
      await firebaseAuth.signInAnonymously();
      return;
    }

    await firebaseAuth.currentUser!.getIdToken();
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
