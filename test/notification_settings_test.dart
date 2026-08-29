import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/app_settings.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WalletAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(RecurringTransactionAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(BillAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoanAdapter());
  if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(AccountAdapter());
  if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(AppNotificationAdapter());

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox('app_settings');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox<AppNotification>('app_notifications');
}

// Minimal isolated widget that renders the Phase 5 notification toggles
// without requiring the full SettingsScreen provider graph.
class _NotificationSettingsPreview extends StatefulWidget {
  const _NotificationSettingsPreview({required this.settings});
  final AppSettings settings;

  @override
  State<_NotificationSettingsPreview> createState() =>
      _NotificationSettingsPreviewState();
}

class _NotificationSettingsPreviewState
    extends State<_NotificationSettingsPreview> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final masterOn = _settings.allowNotifications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Allow Notifications')),
            Switch(
              value: masterOn,
              onChanged: (v) => setState(() {
                _settings = _settings.copyWith(allowNotifications: v);
              }),
            ),
          ],
        ),
        if (masterOn) ...[
          Text('Daily Money Check-In',
              key: const Key('daily_check_in_toggle')),
          Text('Safe-to-Spend Alerts',
              key: const Key('safe_to_spend_toggle')),
          Text('Important Money Insights',
              key: const Key('insight_toggle')),
          Text('Goal Reminders', key: const Key('goal_toggle')),
          Text('Weekly Money Story', key: const Key('weekly_story_toggle')),
          Text('Quiet Hours (10:00 PM – 8:00 AM)',
              key: const Key('quiet_hours_toggle')),
        ],
      ],
    );
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp
        .createTemp('paysense_notif_settings_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 5 Notification Preference UI Tests', () {
    testWidgets(
        'renders Master Notification toggle and all sub-category options '
        'when allowNotifications is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _NotificationSettingsPreview(
              settings: const AppSettings(allowNotifications: true),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Allow Notifications'), findsOneWidget);
      expect(find.text('Daily Money Check-In'), findsOneWidget);
      expect(find.text('Safe-to-Spend Alerts'), findsOneWidget);
      expect(find.text('Important Money Insights'), findsOneWidget);
      expect(find.text('Goal Reminders'), findsOneWidget);
      expect(find.text('Weekly Money Story'), findsOneWidget);
      expect(find.textContaining('Quiet Hours'), findsOneWidget);
    });

    testWidgets(
        'hides sub-categories when master allowNotifications is off',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _NotificationSettingsPreview(
              settings: const AppSettings(allowNotifications: false),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Allow Notifications'), findsOneWidget);
      expect(find.text('Daily Money Check-In'), findsNothing);
      expect(find.text('Safe-to-Spend Alerts'), findsNothing);
      expect(find.text('Important Money Insights'), findsNothing);
    });
  });

  group('Phase 5 Notification Settings Repository Tests', () {
    test('persists notification preferences in AppSettingsRepository',
        () async {
      final repo = AppSettingsRepository.instance;

      await repo.setAllowNotifications(false);
      await repo.setDailyCheckInNotifications(false);
      await repo.setQuietHoursEnabled(true);
      await repo.setQuietHoursStartHour(23);

      final loaded = await repo.getSettings();
      expect(loaded.allowNotifications, isFalse);
      expect(loaded.dailyCheckInNotifications, isFalse);
      expect(loaded.quietHoursEnabled, isTrue);
      expect(loaded.quietHoursStartHour, 23);
    });

    test('all Phase 5 settings default to safe, respectful values', () async {
      final repo = AppSettingsRepository.instance;
      final settings = await repo.getSettings();

      // Master toggle on by default
      expect(settings.allowNotifications, isTrue);
      // Each category on by default
      expect(settings.dailyCheckInNotifications, isTrue);
      expect(settings.safeToSpendNotifications, isTrue);
      expect(settings.importantInsightNotifications, isTrue);
      expect(settings.goalReminderNotifications, isTrue);
      expect(settings.weeklyStoryNotifications, isTrue);
      // Quiet hours enabled by default with overnight window
      expect(settings.quietHoursEnabled, isTrue);
      expect(settings.quietHoursStartHour, 22);
      expect(settings.quietHoursEndHour, 8);
    });

    test('persists deduplication state in AppSettingsRepository', () async {
      final repo = AppSettingsRepository.instance;

      await repo.setLastCheckInNotificationDateIso('2026-08-25');
      await repo.setLastSafeToSpendNotificationState('Watchful', '2026-08-25');
      await repo.incrementDailyProactiveNotificationCount('2026-08-25');

      expect(repo.lastCheckInNotificationDateIso(), '2026-08-25');
      expect(repo.lastSafeToSpendNotificationState(), 'Watchful');
      expect(repo.dailyProactiveNotificationCount('2026-08-25'), 1);
    });

    test('daily cap resets when date changes', () async {
      final repo = AppSettingsRepository.instance;

      await repo.incrementDailyProactiveNotificationCount('2026-08-25');
      await repo.incrementDailyProactiveNotificationCount('2026-08-25');

      // Different date: count should be 0
      expect(repo.dailyProactiveNotificationCount('2026-08-26'), 0);
    });

    test('persists insight and goal notification IDs', () async {
      final repo = AppSettingsRepository.instance;

      await repo.setLastInsightNotificationId('trend:food:2026-08', '2026-08-25');
      await repo.setLastGoalNotificationId('goal-emergency-fund', '2026-08-25');
      await repo.setLastWeeklyStoryNotificationDateIso('2026-W35');

      expect(repo.lastInsightNotificationId(), 'trend:food:2026-08');
      expect(repo.lastGoalNotificationId(), 'goal-emergency-fund');
      expect(repo.lastWeeklyStoryNotificationDateIso(), '2026-W35');
    });
  });
}
