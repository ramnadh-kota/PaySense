// Targeted tests for ForgotPasswordScreen's isConfigured branch (Task
// Group A3). The real Firebase-backed flow can't be exercised end-to-end
// (no live project — see FirebaseAuthService's class doc), so a fake
// AuthService double stands in for the "once activated" state; the
// "today" state uses the real (always-unconfigured) authServiceProvider
// default to prove behavior is genuinely unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/auth/presentation/forgot_password_screen.dart';
import 'package:paysense/shared/providers/auth_provider.dart' show AuthException;
import 'package:paysense/shared/providers/auth_service_provider.dart';
import 'package:paysense/shared/services/auth/auth_service.dart';

class _FakeConfiguredAuthService implements AuthService {
  String? lastResetEmail;
  bool shouldThrow = false;

  @override
  bool get isConfigured => true;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastResetEmail = email;
    if (shouldThrow) throw AuthException('Something went wrong. Please try again.');
  }

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  String? get currentUserEmail => null;

  @override
  bool get isEmailVerified => false;
}

Future<void> _pump(WidgetTester tester, {AuthService? authService}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (authService != null) authServiceProvider.overrideWithValue(authService),
      ],
      child: const MaterialApp(home: ForgotPasswordScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ForgotPasswordScreen — not configured (today\'s real state)', () {
    testWidgets('shows the exact unchanged honest "not available" message', (tester) async {
      await _pump(tester); // uses the real authServiceProvider default (FirebaseAuthService, unconfigured)

      expect(find.text('Password recovery isn\'t available yet'), findsOneWidget);
      expect(find.text('Back to Log In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ForgotPasswordScreen — configured (once Firebase is activated)', () {
    testWidgets('shows the real email form instead of the unavailable message', (tester) async {
      await _pump(tester, authService: _FakeConfiguredAuthService());

      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Password recovery isn\'t available yet'), findsNothing);
    });

    testWidgets('validates the email field before allowing send', (tester) async {
      await _pump(tester, authService: _FakeConfiguredAuthService());

      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('a real send shows the confirmation state, never a raw exception', (tester) async {
      final fake = _FakeConfiguredAuthService();
      await _pump(tester, authService: fake);

      await tester.enterText(find.byType(TextFormField), 'jane@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(fake.lastResetEmail, 'jane@example.com');
      expect(find.text('Check your email'), findsOneWidget);
    });

    testWidgets('a failure shows the mapped safe message, never a raw exception string', (tester) async {
      final fake = _FakeConfiguredAuthService()..shouldThrow = true;
      await _pump(tester, authService: fake);

      await tester.enterText(find.byType(TextFormField), 'jane@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });
  });
}
