// PHASE 10/16 item 11 — analytics privacy. AnalyticsService must never
// accept metadata that looks like it could carry SMS bodies, phone
// numbers, account/card numbers, OTPs, credentials, or raw transaction
// descriptions — mirroring the exact forbidden-fragment list already
// established for the AI context privacy tests elsewhere in this app.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/services/analytics_service.dart';

void main() {
  setUp(() => AnalyticsService.instance.clearForTesting());
  tearDown(() => AnalyticsService.instance.clearForTesting());

  group('11. Analytics privacy', () {
    test('safe metadata (counts, enum names, plan ids) is accepted and logged', () {
      AnalyticsService.instance.log(
        AnalyticsEvent.pricingSelected,
        metadata: {'planId': 'plus_annual', 'count': 3, 'tier': 'plus'},
      );
      expect(AnalyticsService.instance.debugLog.length, 1);
      expect(AnalyticsService.instance.debugLog.single.event, AnalyticsEvent.pricingSelected);
    });

    test('an event with no metadata at all is always safe', () {
      AnalyticsService.instance.log(AnalyticsEvent.dashboardOpened);
      expect(AnalyticsService.instance.debugLog.length, 1);
    });

    test('forbidden key fragments are rejected: phone/sms/otp/password/credential/account/card', () {
      const forbiddenKeys = [
        'phoneNumber', 'smsBody', 'otpCode', 'userPassword', 'apiCredential',
        'accountNumber', 'cardNumber', 'pinCode', 'biometricHash', 'secretToken',
      ];
      for (final key in forbiddenKeys) {
        expect(
          () => AnalyticsService.instance.log(AnalyticsEvent.dashboardOpened, metadata: {key: 'x'}),
          throwsA(isA<AssertionError>()),
          reason: 'metadata key "$key" should have been rejected',
        );
      }
    });

    test('a long free-text string value is rejected even under a safe-looking key', () {
      expect(
        () => AnalyticsService.instance.log(
          AnalyticsEvent.dashboardOpened,
          metadata: {'note': 'This is a suspiciously long piece of text that looks like a real transaction description.'},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('debugLog is read-only and never sent anywhere by itself', () {
      AnalyticsService.instance.log(AnalyticsEvent.onboardingStarted);
      expect(() => AnalyticsService.instance.debugLog.add(
        AnalyticsLogEntry(event: AnalyticsEvent.aiOpened, metadata: const {}, timestamp: DateTime.now()),
      ), throwsUnsupportedError);
    });

    test('every AnalyticsEvent value can be logged with empty metadata without throwing', () {
      for (final event in AnalyticsEvent.values) {
        expect(() => AnalyticsService.instance.log(event), returnsNormally);
      }
    });
  });
}
