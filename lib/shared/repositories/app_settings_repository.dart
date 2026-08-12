import 'package:hive/hive.dart';

import '../models/app_settings.dart';

/// Stores small app-level flags (first-launch detection, user preferences)
/// in an untyped Hive box, separate from the [UserProfile] record itself.
class AppSettingsRepository {
  AppSettingsRepository._();

  static final AppSettingsRepository instance = AppSettingsRepository._();

  static const String _boxName = 'app_settings';
  static const String _isFirstLaunchKey = 'isFirstLaunch';
  static const String _themeModeKey = 'themeMode';
  static const String _billRemindersKey = 'notifyBillReminders';
  static const String _recurringRemindersKey = 'notifyRecurringReminders';
  static const String _loanRemindersKey = 'notifyLoanReminders';

  Box get _box => Hive.box(_boxName);

  /// True until [completeFirstLaunch] has been called at least once.
  Future<bool> isFirstLaunch() async {
    return (_box.get(_isFirstLaunchKey) as bool?) ?? true;
  }

  Future<void> completeFirstLaunch() async {
    await _box.put(_isFirstLaunchKey, false);
  }

  Future<AppSettings> getSettings() async {
    return AppSettings(
      themeMode: _themeModeFromKey(_box.get(_themeModeKey) as String?),
      billReminders: (_box.get(_billRemindersKey) as bool?) ?? true,
      recurringReminders: (_box.get(_recurringRemindersKey) as bool?) ?? true,
      loanReminders: (_box.get(_loanRemindersKey) as bool?) ?? true,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _box.put(_themeModeKey, mode.name);
  }

  Future<void> setBillReminders(bool enabled) async {
    await _box.put(_billRemindersKey, enabled);
  }

  Future<void> setRecurringReminders(bool enabled) async {
    await _box.put(_recurringRemindersKey, enabled);
  }

  Future<void> setLoanReminders(bool enabled) async {
    await _box.put(_loanRemindersKey, enabled);
  }

  /// Synchronous reads used by non-UI call sites (notification scheduling)
  /// that only need a single flag and shouldn't await a full settings load.
  bool billRemindersEnabled() => (_box.get(_billRemindersKey) as bool?) ?? true;

  bool recurringRemindersEnabled() =>
      (_box.get(_recurringRemindersKey) as bool?) ?? true;

  bool loanRemindersEnabled() => (_box.get(_loanRemindersKey) as bool?) ?? true;

  AppThemeMode _themeModeFromKey(String? key) {
    switch (key) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}
