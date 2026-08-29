import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../models/goal.dart';
import '../models/notification_record.dart';
import '../repositories/app_settings_repository.dart';
import '../utils/proactive_notification_engine.dart';
import 'daily_check_in_provider.dart';
import 'financial_insight_provider.dart';
import 'goal_provider.dart';
import 'notification_provider.dart';
import 'safe_to_spend_provider.dart';
import 'settings_provider.dart';

final proactiveNotificationProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.allowNotifications) return;

  final now = DateTime.now();
  final todayIso =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final repo = AppSettingsRepository.instance;
  final dailyCount = repo.dailyProactiveNotificationCount(todayIso);
  if (dailyCount >= 2) return;

  final dailyCheckInState = ref.watch(dailyCheckInProvider);
  final safeToSpend = ref.watch(safeToSpendProvider);
  final insightResult = ref.watch(financialInsightsProvider);
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final weeklyStory = ref.watch(weeklyMoneyStoryProvider);

  final candidate = ProactiveNotificationEngine.evaluate(
    settings: settings,
    now: now,
    dailyCheckInState: dailyCheckInState,
    safeToSpend: safeToSpend,
    insightResult: insightResult,
    goals: goals,
    weeklyStory: weeklyStory,
    lastCheckInDateIso: repo.lastCheckInNotificationDateIso(),
    lastSafeToSpendState: repo.lastSafeToSpendNotificationState(),
    lastInsightNotificationId: repo.lastInsightNotificationId(),
    lastGoalNotificationId: repo.lastGoalNotificationId(),
    lastWeeklyStoryDateIso: repo.lastWeeklyStoryNotificationDateIso(),
    dailyNotificationCount: dailyCount,
  );

  if (candidate == null) return;

  // Execute candidate notification
  final notifId = candidate.deduplicationKey.hashCode & 0x7fffffff;

  await NotificationService.instance.showImmediateNotification(
    id: notifId,
    title: candidate.title,
    body: candidate.body,
    payload: candidate.actionRoute,
  );

  // Store in in-app notifications
  final notifRecord = AppNotification(
    id: 'proactive:${candidate.category.name}:${candidate.deduplicationKey}',
    title: candidate.title,
    message: candidate.body,
    type: NotificationType.insight.name,
    createdAt: now,
    relatedRoute: candidate.actionRoute,
  );

  await ref.read(notificationsProvider.notifier).addIfNotExists(notifRecord);

  // Update deduplication state & daily cap
  await repo.incrementDailyProactiveNotificationCount(todayIso);

  switch (candidate.category) {
    case ProactiveNotificationCategory.dailyCheckIn:
      await repo.setLastCheckInNotificationDateIso(candidate.deduplicationKey);
      break;
    case ProactiveNotificationCategory.safeToSpend:
      await repo.setLastSafeToSpendNotificationState(candidate.deduplicationKey, todayIso);
      break;
    case ProactiveNotificationCategory.importantInsight:
      await repo.setLastInsightNotificationId(candidate.deduplicationKey, todayIso);
      break;
    case ProactiveNotificationCategory.goalReminder:
      await repo.setLastGoalNotificationId(candidate.deduplicationKey, todayIso);
      break;
    case ProactiveNotificationCategory.weeklyStory:
      await repo.setLastWeeklyStoryNotificationDateIso(candidate.deduplicationKey);
      break;
  }
});
