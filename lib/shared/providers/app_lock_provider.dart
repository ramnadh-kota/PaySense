import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/biometric_service.dart';
import '../models/app_lock_settings.dart';
import 'settings_provider.dart' show appSettingsRepositoryProvider;

/// Whether this device currently supports biometric authentication at all
/// (hardware + enrollment). Cached for the life of the provider container.
final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return BiometricService.instance.isAvailable();
});

/// Thrown for user-facing PIN setup failures (bad length, mismatch) so the
/// UI can show a message without treating it as an unexpected error.
class AppLockException implements Exception {
  AppLockException(this.message);

  final String message;

  @override
  String toString() => message;
}

final appLockSettingsProvider =
    AsyncNotifierProvider<AppLockSettingsNotifier, AppLockSettings>(
      AppLockSettingsNotifier.new,
    );

/// Whether the app is CURRENTLY locked (runtime-only, never persisted).
/// Flipped by the lifecycle gate on resume and cleared on successful
/// unlock. Never touches the account session in [authProvider].
final appLockStateProvider = StateProvider<bool>((ref) => false);

class AppLockSettingsNotifier extends AsyncNotifier<AppLockSettings> {
  @override
  Future<AppLockSettings> build() async {
    return ref.read(appSettingsRepositoryProvider).getAppLockSettings();
  }

  Future<void> setEnabled(bool enabled) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setAppLockEnabled(enabled);
    state = AsyncValue.data(
      (state.value ?? const AppLockSettings()).copyWith(enabled: enabled),
    );
  }

  Future<void> setMethod(LockAuthMethod method) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setAppLockMethod(method);
    state = AsyncValue.data(
      (state.value ?? const AppLockSettings()).copyWith(method: method),
    );
  }

  Future<void> setTimeout(LockTimeout timeout) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setAppLockTimeout(timeout);
    state = AsyncValue.data(
      (state.value ?? const AppLockSettings()).copyWith(timeout: timeout),
    );
  }

  /// Validates and stores a new PIN. Requirements: 4-6 digits, confirmation
  /// must match. Never stores the plaintext value.
  Future<void> setupPin({required String pin, required String confirmPin}) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw AppLockException('PIN must be 4-6 digits.');
    }
    if (pin != confirmPin) {
      throw AppLockException('PINs do not match.');
    }

    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setPin(pin);
    state = AsyncValue.data(
      (state.value ?? const AppLockSettings()).copyWith(hasPinConfigured: true),
    );
  }

  bool verifyPin(String pin) {
    return ref.read(appSettingsRepositoryProvider).verifyPin(pin);
  }

  Future<void> clearPin() async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.clearPin();
    state = AsyncValue.data(
      (state.value ?? const AppLockSettings()).copyWith(hasPinConfigured: false),
    );
  }
}
