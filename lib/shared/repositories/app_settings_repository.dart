import 'package:hive/hive.dart';

import '../models/app_lock_settings.dart';
import '../models/app_settings.dart';
import '../utils/password_hasher.dart';

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
  static const String _insightNotificationsKey = 'notifyInsights';
  static const String _appLockEnabledKey = 'appLockEnabled';
  static const String _appLockMethodKey = 'appLockMethod';
  static const String _appLockTimeoutKey = 'appLockTimeout';
  static const String _appLockPinHashKey = 'appLockPinHash';
  static const String _appLockPinSaltKey = 'appLockPinSalt';
  static const String _walletTransactionAccountMigrationV1Key =
      'walletTransactionAccountMigrationV1';
  static const String _smsAutomationEnabledKey = 'smsAutomationEnabled';
  static const String _smsLastProcessingStatusKey = 'smsLastProcessingStatus';
  static const String _smsLastProcessingErrorKey = 'smsLastProcessingError';
  static const String _smsLastProcessingAtKey = 'smsLastProcessingAt';
  static const String _emergencyFundEligibleWalletIdsKey =
      'emergencyFundEligibleWalletIds';
  static const String _emergencyFundTargetMonthsKey = 'emergencyFundTargetMonths';

  // ---- Consumer Monetization Foundation: onboarding personalization/resume ----
  //
  // Presentation-only — see OnboardingPersonalization. Never feeds a
  // financial calculation.
  static const String _onboardingGoalsKey = 'onboardingGoals';
  static const String _onboardingIncomeSourceKey = 'onboardingIncomeSource';
  static const String _onboardingGoalsSetKey = 'onboardingGoalsSet';
  static const String _onboardingIncomeSourceSetKey = 'onboardingIncomeSourceSet';
  static const String _onboardingBuildPictureAcknowledgedKey = 'onboardingBuildPictureAcknowledged';
  static const String _onboardingSnapshotViewedKey = 'onboardingSnapshotViewed';
  static const String _onboardingAhaMomentViewedKey = 'onboardingAhaMomentViewed';

  Box get _box => Hive.box(_boxName);

  /// True until [completeFirstLaunch] has been called at least once.
  Future<bool> isFirstLaunch() async {
    return (_box.get(_isFirstLaunchKey) as bool?) ?? true;
  }

  Future<void> completeFirstLaunch() async {
    await _box.put(_isFirstLaunchKey, false);
  }

  /// Whether the one-time `Transaction.accountId` legacy-label-to-wallet-id
  /// migration (see `TransactionAccountMigration`) has already completed —
  /// purely an optimization to skip re-scanning every transaction on every
  /// app start once there's nothing left to do; the migration itself is
  /// idempotent even without this flag.
  Future<bool> isWalletTransactionAccountMigrationV1Complete() async {
    return (_box.get(_walletTransactionAccountMigrationV1Key) as bool?) ?? false;
  }

  Future<void> completeWalletTransactionAccountMigrationV1() async {
    await _box.put(_walletTransactionAccountMigrationV1Key, true);
  }

  Future<AppSettings> getSettings() async {
    return AppSettings(
      themeMode: _themeModeFromKey(_box.get(_themeModeKey) as String?),
      billReminders: (_box.get(_billRemindersKey) as bool?) ?? true,
      recurringReminders: (_box.get(_recurringRemindersKey) as bool?) ?? true,
      loanReminders: (_box.get(_loanRemindersKey) as bool?) ?? true,
      smsAutomationEnabled: (_box.get(_smsAutomationEnabledKey) as bool?) ?? false,
      insightNotifications: (_box.get(_insightNotificationsKey) as bool?) ?? true,
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

  Future<void> setSmsAutomationEnabled(bool enabled) async {
    await _box.put(_smsAutomationEnabledKey, enabled);
  }

  Future<void> setInsightNotifications(bool enabled) async {
    await _box.put(_insightNotificationsKey, enabled);
  }

  /// Synchronous reads used by non-UI call sites (notification scheduling)
  /// that only need a single flag and shouldn't await a full settings load.
  bool billRemindersEnabled() => (_box.get(_billRemindersKey) as bool?) ?? true;

  bool recurringRemindersEnabled() =>
      (_box.get(_recurringRemindersKey) as bool?) ?? true;

  bool loanRemindersEnabled() => (_box.get(_loanRemindersKey) as bool?) ?? true;

  bool insightNotificationsEnabled() =>
      (_box.get(_insightNotificationsKey) as bool?) ?? true;

  /// Synchronous read used by the SMS processor, which runs outside a
  /// normal widget build cycle (app startup, receiver-triggered flush) and
  /// shouldn't await a full settings load just to check one flag.
  bool smsAutomationEnabled() =>
      (_box.get(_smsAutomationEnabledKey) as bool?) ?? false;

  // ---- SMS processing diagnostics ----
  //
  // Purely observational — never read by any business logic, only by the
  // Settings diagnostics panel so a manual real-device tester can see which
  // pipeline stage last ran without needing raw logs. Never records SMS
  // body/sender text, only a human-readable, pre-sanitized error string.

  Future<void> recordSmsProcessingSuccess() async {
    await _box.put(_smsLastProcessingStatusKey, 'success');
    await _box.delete(_smsLastProcessingErrorKey);
    await _box.put(_smsLastProcessingAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> recordSmsProcessingFailure(String errorMessage) async {
    await _box.put(_smsLastProcessingStatusKey, 'failed');
    await _box.put(_smsLastProcessingErrorKey, errorMessage);
    await _box.put(_smsLastProcessingAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 'success', 'failed', or null if SMS processing has never run.
  String? smsLastProcessingStatus() =>
      _box.get(_smsLastProcessingStatusKey) as String?;

  String? smsLastProcessingError() =>
      _box.get(_smsLastProcessingErrorKey) as String?;

  DateTime? smsLastProcessingAt() {
    final millis = _box.get(_smsLastProcessingAtKey) as int?;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  // ---- Financial Planning: Emergency Fund source ----
  //
  // Deliberately the smallest possible setting for Feature 3 of Financial
  // Planning 2.0: which wallets count as "emergency fund eligible". Never
  // guessed from wallet type/name — the user explicitly opts wallets in.
  // Distinguishes "never configured" (null) from "explicitly configured to
  // zero wallets" (empty list) so the UI can tell the difference between
  // "needs setup" and "user chose none".

  /// Null when the user has never configured this. Never touches wallet
  /// balances — purely a list of ids read back by the planning calculator.
  List<String>? emergencyFundEligibleWalletIds() {
    final raw = _box.get(_emergencyFundEligibleWalletIdsKey) as List<Object?>?;
    return raw?.cast<String>();
  }

  Future<void> setEmergencyFundEligibleWalletIds(List<String> walletIds) async {
    await _box.put(_emergencyFundEligibleWalletIdsKey, walletIds);
  }

  int emergencyFundTargetMonths() =>
      (_box.get(_emergencyFundTargetMonthsKey) as int?) ?? 6;

  Future<void> setEmergencyFundTargetMonths(int months) async {
    await _box.put(_emergencyFundTargetMonthsKey, months);
  }

  // ---- Consumer Monetization Foundation: onboarding personalization/resume ----

  /// The raw [FinancialGoalPreference] names the user selected on "What
  /// matters most to you?" — empty (never null) when not yet answered.
  List<String> onboardingGoals() {
    final raw = _box.get(_onboardingGoalsKey) as List<Object?>?;
    return raw?.cast<String>() ?? const [];
  }

  Future<void> setOnboardingGoals(List<String> goals) async {
    await _box.put(_onboardingGoalsKey, goals);
    await _box.put(_onboardingGoalsSetKey, true);
  }

  bool onboardingGoalsSet() => (_box.get(_onboardingGoalsSetKey) as bool?) ?? false;

  /// The raw [IncomeSourceType] name the user selected — null when not yet
  /// answered.
  String? onboardingIncomeSource() => _box.get(_onboardingIncomeSourceKey) as String?;

  Future<void> setOnboardingIncomeSource(String incomeSource) async {
    await _box.put(_onboardingIncomeSourceKey, incomeSource);
    await _box.put(_onboardingIncomeSourceSetKey, true);
  }

  bool onboardingIncomeSourceSet() => (_box.get(_onboardingIncomeSourceSetKey) as bool?) ?? false;

  bool onboardingBuildPictureAcknowledged() =>
      (_box.get(_onboardingBuildPictureAcknowledgedKey) as bool?) ?? false;

  Future<void> setOnboardingBuildPictureAcknowledged() async {
    await _box.put(_onboardingBuildPictureAcknowledgedKey, true);
  }

  bool onboardingSnapshotViewed() => (_box.get(_onboardingSnapshotViewedKey) as bool?) ?? false;

  Future<void> setOnboardingSnapshotViewed() async {
    await _box.put(_onboardingSnapshotViewedKey, true);
  }

  bool onboardingAhaMomentViewed() => (_box.get(_onboardingAhaMomentViewedKey) as bool?) ?? false;

  Future<void> setOnboardingAhaMomentViewed() async {
    await _box.put(_onboardingAhaMomentViewedKey, true);
  }

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

  // ---- App Lock ----
  //
  // App Lock is a separate, local re-entry gate on top of the existing
  // account session — it never touches login/logout state. Only the
  // enabled/method/timeout flags and a salted PIN hash are stored here;
  // never a plaintext PIN, never biometric data (biometrics are handled
  // entirely by the platform via BiometricService and never reach the app).

  Future<AppLockSettings> getAppLockSettings() async {
    return AppLockSettings(
      enabled: (_box.get(_appLockEnabledKey) as bool?) ?? false,
      method: _lockMethodFromKey(_box.get(_appLockMethodKey) as String?),
      timeout: _lockTimeoutFromKey(_box.get(_appLockTimeoutKey) as String?),
      hasPinConfigured: hasPin(),
    );
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _box.put(_appLockEnabledKey, enabled);
  }

  Future<void> setAppLockMethod(LockAuthMethod method) async {
    await _box.put(_appLockMethodKey, method.name);
  }

  Future<void> setAppLockTimeout(LockTimeout timeout) async {
    await _box.put(_appLockTimeoutKey, timeout.name);
  }

  bool hasPin() =>
      (_box.get(_appLockPinHashKey) as String?) != null &&
      (_box.get(_appLockPinSaltKey) as String?) != null;

  /// Hashes and stores [pin]. Never persists the plaintext value.
  Future<void> setPin(String pin) async {
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(pin, salt);
    await _box.put(_appLockPinHashKey, hash);
    await _box.put(_appLockPinSaltKey, salt);
  }

  Future<void> clearPin() async {
    await _box.delete(_appLockPinHashKey);
    await _box.delete(_appLockPinSaltKey);
  }

  bool verifyPin(String pin) {
    final hash = _box.get(_appLockPinHashKey) as String?;
    final salt = _box.get(_appLockPinSaltKey) as String?;
    if (hash == null || salt == null) {
      return false;
    }
    return PasswordHasher.verify(pin, salt, hash);
  }

  LockAuthMethod _lockMethodFromKey(String? key) {
    return key == 'pin' ? LockAuthMethod.pin : LockAuthMethod.biometric;
  }

  LockTimeout _lockTimeoutFromKey(String? key) {
    switch (key) {
      case 'afterOneMinute':
        return LockTimeout.afterOneMinute;
      case 'afterFiveMinutes':
        return LockTimeout.afterFiveMinutes;
      case 'afterFifteenMinutes':
        return LockTimeout.afterFifteenMinutes;
      default:
        return LockTimeout.immediately;
    }
  }

  // ---- Daily Money Awareness & Retention Engine ----
  static const String _dailyCheckInLastDateIsoKey = 'dailyCheckInLastDateIso';
  static const String _dailyCheckInMoodKey = 'dailyCheckInMood';
  static const String _dailyAwarenessStreakKey = 'dailyAwarenessStreak';
  static const String _dailyStreakLastDateIsoKey = 'dailyStreakLastDateIso';

  String? dailyCheckInLastDateIso() => _box.get(_dailyCheckInLastDateIsoKey) as String?;
  String? dailyCheckInMood() => _box.get(_dailyCheckInMoodKey) as String?;
  int dailyAwarenessStreak() => (_box.get(_dailyAwarenessStreakKey) as int?) ?? 1;
  String? dailyStreakLastDateIso() => _box.get(_dailyStreakLastDateIsoKey) as String?;

  Future<void> setDailyCheckIn({
    required String dateIso,
    required String mood,
    required int streak,
  }) async {
    await _box.put(_dailyCheckInLastDateIsoKey, dateIso);
    await _box.put(_dailyCheckInMoodKey, mood);
    await _box.put(_dailyAwarenessStreakKey, streak);
    await _box.put(_dailyStreakLastDateIsoKey, dateIso);
  }

  Future<void> recordDailyStreakActivity(String dateIso) async {
    final lastIso = dailyStreakLastDateIso();
    int streak = dailyAwarenessStreak();
    if (lastIso == null || lastIso.isEmpty) {
      streak = 1;
    } else {
      final lastDate = DateTime.tryParse(lastIso);
      final currentDate = DateTime.tryParse(dateIso);
      if (lastDate != null && currentDate != null) {
        final diff = DateTime(currentDate.year, currentDate.month, currentDate.day)
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;
        if (diff == 1) {
          streak += 1;
        } else if (diff > 1) {
          streak = 1;
        }
      }
    }
    await _box.put(_dailyAwarenessStreakKey, streak);
    await _box.put(_dailyStreakLastDateIsoKey, dateIso);
  }
}
