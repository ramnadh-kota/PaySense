import 'package:flutter/foundation.dart';

enum AppThemeMode { system, light, dark }

/// Plain (non-Hive) value object for app-level preferences. Persisted via
/// [AppSettingsRepository] in the existing untyped 'app_settings' box —
/// individual keys, not a typed record, matching how [isFirstLaunch] is
/// already stored.
///
/// Currency and country are deliberately NOT here — they already live on
/// [UserProfile] and are edited through it, so this model doesn't duplicate
/// that data.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.billReminders = true,
    this.recurringReminders = true,
    this.loanReminders = true,
    this.smsAutomationEnabled = false,
  });

  final AppThemeMode themeMode;
  final bool billReminders;
  final bool recurringReminders;
  final bool loanReminders;

  /// Whether PaySense should automatically detect bank/UPI transactions
  /// from incoming SMS. Off by default — SMS permissions are only ever
  /// requested after the user explicitly turns this on.
  final bool smsAutomationEnabled;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? billReminders,
    bool? recurringReminders,
    bool? loanReminders,
    bool? smsAutomationEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      billReminders: billReminders ?? this.billReminders,
      recurringReminders: recurringReminders ?? this.recurringReminders,
      loanReminders: loanReminders ?? this.loanReminders,
      smsAutomationEnabled: smsAutomationEnabled ?? this.smsAutomationEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.billReminders == billReminders &&
        other.recurringReminders == recurringReminders &&
        other.loanReminders == loanReminders &&
        other.smsAutomationEnabled == smsAutomationEnabled;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    billReminders,
    recurringReminders,
    loanReminders,
    smsAutomationEnabled,
  );
}
