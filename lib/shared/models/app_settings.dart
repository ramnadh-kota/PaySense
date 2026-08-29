import 'package:flutter/foundation.dart';

enum AppThemeMode { system, light, dark }

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.billReminders = true,
    this.recurringReminders = true,
    this.loanReminders = true,
    this.smsAutomationEnabled = false,
    this.insightNotifications = true,
    this.allowNotifications = true,
    this.dailyCheckInNotifications = true,
    this.safeToSpendNotifications = true,
    this.importantInsightNotifications = true,
    this.goalReminderNotifications = true,
    this.weeklyStoryNotifications = true,
    this.quietHoursEnabled = true,
    this.quietHoursStartHour = 22,
    this.quietHoursEndHour = 8,
  });

  final AppThemeMode themeMode;
  final bool billReminders;
  final bool recurringReminders;
  final bool loanReminders;
  final bool smsAutomationEnabled;
  final bool insightNotifications;

  // Phase 5 Proactive Notification Preferences
  final bool allowNotifications;
  final bool dailyCheckInNotifications;
  final bool safeToSpendNotifications;
  final bool importantInsightNotifications;
  final bool goalReminderNotifications;
  final bool weeklyStoryNotifications;
  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursEndHour;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? billReminders,
    bool? recurringReminders,
    bool? loanReminders,
    bool? smsAutomationEnabled,
    bool? insightNotifications,
    bool? allowNotifications,
    bool? dailyCheckInNotifications,
    bool? safeToSpendNotifications,
    bool? importantInsightNotifications,
    bool? goalReminderNotifications,
    bool? weeklyStoryNotifications,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursEndHour,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      billReminders: billReminders ?? this.billReminders,
      recurringReminders: recurringReminders ?? this.recurringReminders,
      loanReminders: loanReminders ?? this.loanReminders,
      smsAutomationEnabled: smsAutomationEnabled ?? this.smsAutomationEnabled,
      insightNotifications: insightNotifications ?? this.insightNotifications,
      allowNotifications: allowNotifications ?? this.allowNotifications,
      dailyCheckInNotifications:
          dailyCheckInNotifications ?? this.dailyCheckInNotifications,
      safeToSpendNotifications:
          safeToSpendNotifications ?? this.safeToSpendNotifications,
      importantInsightNotifications:
          importantInsightNotifications ?? this.importantInsightNotifications,
      goalReminderNotifications:
          goalReminderNotifications ?? this.goalReminderNotifications,
      weeklyStoryNotifications:
          weeklyStoryNotifications ?? this.weeklyStoryNotifications,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: quietHoursStartHour ?? this.quietHoursStartHour,
      quietHoursEndHour: quietHoursEndHour ?? this.quietHoursEndHour,
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
        other.smsAutomationEnabled == smsAutomationEnabled &&
        other.insightNotifications == insightNotifications &&
        other.allowNotifications == allowNotifications &&
        other.dailyCheckInNotifications == dailyCheckInNotifications &&
        other.safeToSpendNotifications == safeToSpendNotifications &&
        other.importantInsightNotifications == importantInsightNotifications &&
        other.goalReminderNotifications == goalReminderNotifications &&
        other.weeklyStoryNotifications == weeklyStoryNotifications &&
        other.quietHoursEnabled == quietHoursEnabled &&
        other.quietHoursStartHour == quietHoursStartHour &&
        other.quietHoursEndHour == quietHoursEndHour;
  }

  @override
  int get hashCode => Object.hash(
        themeMode,
        billReminders,
        recurringReminders,
        loanReminders,
        smsAutomationEnabled,
        insightNotifications,
        allowNotifications,
        dailyCheckInNotifications,
        safeToSpendNotifications,
        importantInsightNotifications,
        goalReminderNotifications,
        weeklyStoryNotifications,
        quietHoursEnabled,
        quietHoursStartHour,
        quietHoursEndHour,
      );
}
