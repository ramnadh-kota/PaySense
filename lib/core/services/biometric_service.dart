import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth`. Only ever asks the platform to
/// authenticate — never reads, stores, or otherwise touches biometric data
/// itself. All platform failures (no hardware, no enrolled biometrics,
/// user cancellation, lockout) are swallowed and reported as `false` so
/// callers can fall back to PIN entry gracefully.
class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether this device can currently do biometric authentication at all
  /// (hardware present, OS support, and at least one biometric enrolled).
  Future<bool> isAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (error) {
      debugPrint('BiometricService: isAvailable check failed: $error');
      return false;
    }
  }

  /// Prompts the platform biometric UI. Returns false (never throws) on
  /// cancellation, failure, or any platform error.
  Future<bool> authenticate({String reason = 'Unlock PaySense'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (error) {
      debugPrint('BiometricService: authenticate failed: $error');
      return false;
    }
  }
}
