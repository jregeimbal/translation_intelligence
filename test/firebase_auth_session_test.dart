import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:translation_intelligence/services/firebase_auth_session.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}
class MockFirebaseOptions extends Mock implements FirebaseOptions {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockUserCredential mockCredential;
  late MockFirebaseOptions mockOptions;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockCredential = MockUserCredential();
    mockOptions = MockFirebaseOptions();
  });

  group('FirebaseAuthSession', () {
    test('initialize() signs in anonymously if no user is present', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
        firebaseAuth: mockAuth,
      );

      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.signInAnonymously())
          .thenAnswer((_) async => mockCredential);

      await session.initialize();

      verify(() => mockAuth.signInAnonymously()).called(1);
    });

    test('initialize() does nothing if user is already present', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
        firebaseAuth: mockAuth,
      );

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'fake-token');

      await session.initialize();

      verifyNever(() => mockAuth.signInAnonymously());
    });

    test('getIdToken returns token when user is already signed in', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
        firebaseAuth: mockAuth,
      );

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'valid-token');

      final token = await session.getIdToken();

      expect(token, 'valid-token');
      verify(() => mockAuth.currentUser).called(1);
      verify(() => mockUser.getIdToken()).called(1);
    });

    test('getIdToken signs in anonymously and returns token when user is not signed in', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
        firebaseAuth: mockAuth,
      );

      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.signInAnonymously()).thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'valid-token');

      final token = await session.getIdToken();

      expect(token, 'valid-token');
      verify(() => mockAuth.currentUser).called(1);
      verify(() => mockAuth.signInAnonymously()).called(1);
      verify(() => mockUser.getIdToken()).called(1);
    });

    test('getIdToken throws StateError when token is null', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
        firebaseAuth: mockAuth,
      );

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => null);

      expect(
        () => session.getIdToken(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Failed to obtain Firebase auth token')),
      );
    });

    test('getIdToken throws StateError when token is empty', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
        firebaseAuth: mockAuth,
      );

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => '');

      expect(
        () => session.getIdToken(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Failed to obtain Firebase auth token')),
      );
    });

    test('getIdToken throws StateError if not initialized and no firebaseAuth provided', () async {
      final session = FirebaseAuthSession(
        options: mockOptions,
      );

      expect(
        () => session.getIdToken(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'FirebaseAuthSession.initialize() must complete first')),
      );
    });
  });
}
