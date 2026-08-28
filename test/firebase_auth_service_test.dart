// FirebaseAuthService is genuinely BLOCKED/inactive in this environment
// (no real Firebase project — see the class's own doc). These tests
// verify the one thing that's honestly testable without live Firebase
// credentials: the guard that stops every method from silently
// pretending to work when Firebase.initializeApp() was never called.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/providers/auth_provider.dart' show AuthException;
import 'package:paysense/shared/services/auth/firebase_auth_service.dart';

void main() {
  group('FirebaseAuthService — inactive-by-default guard', () {
    late FirebaseAuthService service;

    setUp(() {
      service = FirebaseAuthService();
    });

    test('isConfigured is false when Firebase was never initialized', () {
      expect(service.isConfigured, isFalse);
    });

    test('currentUserEmail is null when not configured, never a stale/fabricated value', () {
      expect(service.currentUserEmail, isNull);
    });

    test('isEmailVerified is false when not configured, never a fabricated true', () {
      expect(service.isEmailVerified, isFalse);
    });

    test('signUp throws a clear AuthException rather than silently succeeding', () async {
      await expectLater(
        service.signUp(email: 'test@example.com', password: 'password123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('login throws a clear AuthException rather than silently succeeding', () async {
      await expectLater(
        service.login(email: 'test@example.com', password: 'password123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sendPasswordResetEmail throws a clear AuthException rather than silently succeeding', () async {
      await expectLater(
        service.sendPasswordResetEmail('test@example.com'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sendEmailVerification throws a clear AuthException rather than silently succeeding', () async {
      await expectLater(
        service.sendEmailVerification(),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
