import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/app_settings.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/weekly_money_story.dart';
import 'package:paysense/shared/providers/daily_check_in_provider.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';
import 'package:paysense/shared/utils/notification_copy.dart';
import 'package:paysense/shared/utils/proactive_notification_engine.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

void main() {
  final now = DateTime(2026, 8, 25, 14, 0); // 2:00 PM (not quiet hours)

  const defaultSettings = AppSettings(
    allowNotifications: true,
    dailyCheckInNotifications: true,
    safeToSpendNotifications: true,
    importantInsightNotifications: true,
    goalReminderNotifications: true,
    weeklyStoryNotifications: true,
    quietHoursEnabled: true,
    quietHoursStartHour: 22,
    quietHoursEndHour: 8,
  );

  const defaultSafeToSpend = SafeToSpendResult(
    availableMoney: 10000,
    upcomingCommitments: 1000,
    plannedSavings: 0,
    savingsIncluded: false,
    safeToSpend: 9000,
    dailySafeToSpend: 300,
    remainingDays: 30,
    hasSufficientData: true,
    shortfall: 0,
    commitmentBreakdown: [],
    windowDays: 30,
  );

  const defaultCheckInState = DailyCheckInState(
    lastCheckInDate: null,
    mood: null,
    streakDays: 1,
    isCheckedInToday: false,
  );

  const defaultStory = WeeklyMoneyStory(
    spentThisWeek: 3000,
    savedThisWeek: 1000,
    largestCategory: 'Food',
    largestCategoryAmount: 1500,
    safeToSpendRemaining: 9000,
    safeToSpendStatus: 'Comfortable',
    awarenessStreakDays: 3,
    summaryHeadline: 'Weekly Snapshot',
    summaryNarrative: 'Spending is within safe limits.',
    hasSufficientData: true,
  );

  group('ProactiveNotificationEngine Unit Tests', () {
    test('returns null when master allowNotifications is false', () {
      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings.copyWith(allowNotifications: false),
        now: now,
        dailyCheckInState: defaultCheckInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: const [],
        weeklyStory: defaultStory,
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNull);
    });

    test('returns null during quiet hours (e.g. 11:00 PM)', () {
      final nightTime = DateTime(2026, 8, 25, 23, 0);

      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: nightTime,
        dailyCheckInState: defaultCheckInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: const [],
        weeklyStory: defaultStory,
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNull);
    });

    test('returns null when daily notification count cap (2/day) is reached', () {
      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: defaultCheckInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: const [],
        weeklyStory: defaultStory,
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 2,
      );

      expect(candidate, isNull);
    });

    test('returns null for daily check-in if user has already checked in today', () {
      final checkedInState = defaultCheckInState.copyWith(
        isCheckedInToday: true,
        lastCheckInDate: now,
      );

      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: checkedInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: const [],
        weeklyStory: WeeklyMoneyStory.empty(),
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNull);
    });

    test('surfaces Daily Money Check-In when not checked in today', () {
      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: defaultCheckInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: const [],
        weeklyStory: WeeklyMoneyStory.empty(),
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNotNull);
      expect(candidate!.category, ProactiveNotificationCategory.dailyCheckIn);
      expect(candidate.title, NotificationCopy.dailyCheckInTitle);
      expect(candidate.body, NotificationCopy.dailyCheckInBody);
    });

    test('surfaces High-Priority Financial Insight over lower priority reminders', () {
      const insight = FinancialInsight(
        id: 'trend:food:2026-08',
        type: InsightType.spendingTrend,
        priority: InsightPriority.high,
        title: 'Food spend up',
        explanation: 'Spent 30% more this month',
        recommendedAction: 'Review details',
      );

      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: defaultCheckInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: [insight]),
        goals: const [],
        weeklyStory: defaultStory,
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNotNull);
      expect(candidate!.category, ProactiveNotificationCategory.importantInsight);
      expect(candidate.deduplicationKey, 'trend:food:2026-08');
      expect(candidate.title, NotificationCopy.importantInsightTitle);
    });

    test('deduplicates insights when already notified for the same insight ID', () {
      const insight = FinancialInsight(
        id: 'trend:food:2026-08',
        type: InsightType.spendingTrend,
        priority: InsightPriority.high,
        title: 'Food spend up',
        explanation: 'Spent 30% more this month',
        recommendedAction: 'Review details',
      );

      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: defaultCheckInState,
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: [insight]),
        goals: const [],
        weeklyStory: WeeklyMoneyStory.empty(),
        lastCheckInDateIso: null,
        lastSafeToSpendState: null,
        lastInsightNotificationId: 'trend:food:2026-08', // already notified
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNotNull);
      // Falls back to next eligible candidate: Daily Check-In
      expect(candidate!.category, ProactiveNotificationCategory.dailyCheckIn);
    });

    test('surfaces Safe-to-Spend warning when state shifts to Shortfall or Watchful', () {
      const tightSafeToSpend = SafeToSpendResult(
        availableMoney: 10000,
        upcomingCommitments: 8000, // 80% pressure -> Watchful
        plannedSavings: 0,
        savingsIncluded: false,
        safeToSpend: 2000,
        dailySafeToSpend: 66,
        remainingDays: 30,
        hasSufficientData: true,
        shortfall: 0,
        commitmentBreakdown: [],
        windowDays: 30,
      );

      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: defaultCheckInState.copyWith(isCheckedInToday: true),
        safeToSpend: tightSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: const [],
        weeklyStory: WeeklyMoneyStory.empty(),
        lastCheckInDateIso: '2026-08-25',
        lastSafeToSpendState: 'Comfortable', // previous state was comfortable
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNotNull);
      expect(candidate!.category, ProactiveNotificationCategory.safeToSpend);
      expect(candidate.title, NotificationCopy.safeToSpendTitle);
      expect(candidate.body, NotificationCopy.safeToSpendBody);
    });

    test('surfaces Goal Reminder when goal deadline is approaching within 30 days', () {
      final goal = Goal.create(
        id: 'g1',
        title: 'Emergency Fund',
        category: 'Savings',
        icon: 'flag',
        color: 0xFF10B981,
        targetAmount: 50000,
        currentAmount: 10000,
        targetDate: now.add(const Duration(days: 10)),
        createdAt: DateTime(2026, 1, 1),
      );

      final candidate = ProactiveNotificationEngine.evaluate(
        settings: defaultSettings,
        now: now,
        dailyCheckInState: defaultCheckInState.copyWith(isCheckedInToday: true),
        safeToSpend: defaultSafeToSpend,
        insightResult: const FinancialInsightResult(insights: []),
        goals: [goal],
        weeklyStory: WeeklyMoneyStory.empty(),
        lastCheckInDateIso: '2026-08-25',
        lastSafeToSpendState: null,
        lastInsightNotificationId: null,
        lastGoalNotificationId: null,
        lastWeeklyStoryDateIso: null,
        dailyNotificationCount: 0,
      );

      expect(candidate, isNotNull);
      expect(candidate!.category, ProactiveNotificationCategory.goalReminder);
      expect(candidate.title, NotificationCopy.goalReminderTitle);
      expect(candidate.body, NotificationCopy.goalReminderBody);
    });

    test('privacy verification: notification copy never contains bank or private data', () {
      expect(NotificationCopy.dailyCheckInBody, isNot(contains('HDFC')));
      expect(NotificationCopy.safeToSpendBody, isNot(contains('₹')));
      expect(NotificationCopy.importantInsightBody, isNot(contains('Account')));
      expect(NotificationCopy.goalReminderBody, isNot(contains('PIN')));
    });
  });
}
