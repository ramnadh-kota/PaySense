import 'package:flutter/foundation.dart';

enum LockAuthMethod { biometric, pin }

enum LockTimeout { immediately, afterOneMinute, afterFiveMinutes, afterFifteenMinutes }

extension LockTimeoutX on LockTimeout {
  /// How long the app may stay backgrounded before the next foreground
  /// triggers a lock.
  Duration get duration {
    switch (this) {
      case LockTimeout.immediately:
        return Duration.zero;
      case LockTimeout.afterOneMinute:
        return const Duration(minutes: 1);
      case LockTimeout.afterFiveMinutes:
        return const Duration(minutes: 5);
      case LockTimeout.afterFifteenMinutes:
        return const Duration(minutes: 15);
    }
  }

  String get label {
    switch (this) {
      case LockTimeout.immediately:
        return 'Immediately';
      case LockTimeout.afterOneMinute:
        return 'After 1 minute';
      case LockTimeout.afterFiveMinutes:
        return 'After 5 minutes';
      case LockTimeout.afterFifteenMinutes:
        return 'After 15 minutes';
    }
  }
}

/// App Lock preferences — NOT account authentication. Persisted via
/// [AppSettingsRepository] alongside the other app-level preferences. Never
/// holds the PIN itself, only whether one has been configured; the salted
/// hash lives separately in the repository.
@immutable
class AppLockSettings {
  const AppLockSettings({
    this.enabled = false,
    this.method = LockAuthMethod.biometric,
    this.timeout = LockTimeout.immediately,
    this.hasPinConfigured = false,
  });

  final bool enabled;
  final LockAuthMethod method;
  final LockTimeout timeout;
  final bool hasPinConfigured;

  AppLockSettings copyWith({
    bool? enabled,
    LockAuthMethod? method,
    LockTimeout? timeout,
    bool? hasPinConfigured,
  }) {
    return AppLockSettings(
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      timeout: timeout ?? this.timeout,
      hasPinConfigured: hasPinConfigured ?? this.hasPinConfigured,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppLockSettings &&
        other.enabled == enabled &&
        other.method == method &&
        other.timeout == timeout &&
        other.hasPinConfigured == hasPinConfigured;
  }

  @override
  int get hashCode => Object.hash(enabled, method, timeout, hasPinConfigured);
}
