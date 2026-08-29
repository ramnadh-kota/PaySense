import 'package:flutter/foundation.dart';

import '../../core/routes/app_routes.dart';
import '../models/app_settings.dart';
import '../models/goal.dart';
import '../models/weekly_money_story.dart';
import '../providers/daily_check_in_provider.dart';
import 'financial_insight_engine.dart';
import 'notification_copy.dart';
import 'safe_to_spend_calculator.dart';

enum ProactiveNotificationCategory {
  importantInsight,
  safeToSpend,
  goalReminder,
  dailyCheckIn,
  weeklyStory,
}

@immutable
class ProactiveNotificationCandidate {
  const ProactiveNotificationCandidate({
    required this.category,
    required this.title,
    required this.body,
    required this.deduplicationKey,
    this.actionRoute,
    this.entityId,
  });

  final ProactiveNotificationCategory category;
  final String title;
  final String body;
  final String deduplicationKey;
  final String? actionRoute;
  final String? entityId;
}

class ProactiveNotificationEngine {
  ProactiveNotificationEngine._();

  static ProactiveNotificationCandidate? evaluate({
    required AppSettings settings,
    required DateTime now,
    required DailyCheckInState dailyCheckInState,
    required SafeToSpendResult safeToSpend,
    required FinancialInsightResult insightResult,
    required List<Goal> goals,
    required WeeklyMoneyStory weeklyStory,
    required String? lastCheckInDateIso,
    required String? lastSafeToSpendState,
    required String? lastInsightNotificationId,
    required String? lastGoalNotificationId,
    required String? lastWeeklyStoryDateIso,
    required int dailyNotificationCount,
  }) {
    if (!settings.allowNotifications) return null;
    if (dailyNotificationCount >= 2) return null;

    if (settings.quietHoursEnabled) {
      if (isQuietHours(now, settings.quietHoursStartHour, settings.quietHoursEndHour)) {
        return null;
      }
    }

    final todayIso = _dateIso(now);
    final currentWeekKey = _weekKey(now);

    // 1. Critical or High Priority Financial Insight
    if (settings.importantInsightNotifications && settings.insightNotifications) {
      final important = insightResult.insights.where((i) {
        return i.priority == InsightPriority.critical || i.priority == InsightPriority.high;
      }).toList();

      if (important.isNotEmpty) {
        final topInsight = important.first;
        if (topInsight.id != lastInsightNotificationId) {
          return ProactiveNotificationCandidate(
            category: ProactiveNotificationCategory.importantInsight,
            title: NotificationCopy.importantInsightTitle,
            body: NotificationCopy.importantInsightBody,
            deduplicationKey: topInsight.id,
            actionRoute: topInsight.actionRoute ?? AppRoutes.dashboard,
            entityId: topInsight.id,
          );
        }
      }
    }

    // 2. Safe-to-Spend State Change
    if (settings.safeToSpendNotifications && safeToSpend.hasSufficientData) {
      final isCaution = safeToSpend.availableMoney > 0 &&
          (safeToSpend.upcomingCommitments / safeToSpend.availableMoney >= 0.7);

      final currentState = safeToSpend.isShortfall
          ? 'Shortfall'
          : (isCaution ? 'Watchful' : 'Comfortable');

      if ((currentState == 'Shortfall' || currentState == 'Watchful') &&
          currentState != lastSafeToSpendState) {
        return ProactiveNotificationCandidate(
          category: ProactiveNotificationCategory.safeToSpend,
          title: NotificationCopy.safeToSpendTitle,
          body: NotificationCopy.safeToSpendBody,
          deduplicationKey: currentState,
          actionRoute: AppRoutes.dashboard,
        );
      }
    }

    // 3. Goal Deadline / Progress Reminder
    if (settings.goalReminderNotifications && goals.isNotEmpty) {
      final atRisk = goals.where((g) {
        final remaining = g.targetAmount - g.currentAmount;
        return remaining > 0 && g.targetDate.isBefore(now.add(const Duration(days: 30)));
      }).toList();

      if (atRisk.isNotEmpty) {
        final topGoal = atRisk.first;
        if (topGoal.id != lastGoalNotificationId) {
          return ProactiveNotificationCandidate(
            category: ProactiveNotificationCategory.goalReminder,
            title: NotificationCopy.goalReminderTitle,
            body: NotificationCopy.goalReminderBody,
            deduplicationKey: topGoal.id,
            actionRoute: AppRoutes.financialPlanning,
            entityId: topGoal.id,
          );
        }
      }
    }

    // 4. Daily Check-In Reminder
    if (settings.dailyCheckInNotifications) {
      if (!dailyCheckInState.isCheckedInToday && lastCheckInDateIso != todayIso) {
        return ProactiveNotificationCandidate(
          category: ProactiveNotificationCategory.dailyCheckIn,
          title: NotificationCopy.dailyCheckInTitle,
          body: NotificationCopy.dailyCheckInBody,
          deduplicationKey: todayIso,
          actionRoute: AppRoutes.dashboard,
        );
      }
    }

    // 5. Weekly Money Story
    if (settings.weeklyStoryNotifications && weeklyStory.hasSufficientData) {
      if (lastWeeklyStoryDateIso != currentWeekKey) {
        return ProactiveNotificationCandidate(
          category: ProactiveNotificationCategory.weeklyStory,
          title: NotificationCopy.weeklyStoryTitle,
          body: NotificationCopy.weeklyStoryBody,
          deduplicationKey: currentWeekKey,
          actionRoute: AppRoutes.dashboard,
        );
      }
    }

    return null;
  }

  static bool isQuietHours(DateTime now, int startHour, int endHour) {
    final hour = now.hour;
    if (startHour > endHour) {
      // e.g. 22 to 8 (overnight)
      return hour >= startHour || hour < endHour;
    } else if (startHour < endHour) {
      // e.g. 1 to 7 (same day)
      return hour >= startHour && hour < endHour;
    }
    return false;
  }

  static String _dateIso(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _weekKey(DateTime date) {
    // ISO week number calculation
    final dayOfYear = int.parse(_dateIso(date).replaceAll('-', ''));
    return '${date.year}-W${(dayOfYear / 7).floor()}';
  }
}
