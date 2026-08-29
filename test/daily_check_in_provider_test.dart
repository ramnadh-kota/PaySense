import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/dashboard/widgets/daily_check_in_card.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/daily_check_in_provider.dart';
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_daily_check_in_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Daily Check-In & Money Awareness Streak tests', () {
    test('initial state defaults to non-checked-in and 1 day streak', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(dailyCheckInProvider);
      expect(state.isCheckedInToday, isFalse);
      expect(state.mood, isNull);
      expect(state.streakDays, 1);
    });

    test('submitCheckIn persists mood, marks checked-in, and updates streak', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(dailyCheckInProvider.notifier).submitCheckIn('comfortable');

      final state = container.read(dailyCheckInProvider);
      expect(state.isCheckedInToday, isTrue);
      expect(state.mood, 'comfortable');
      expect(state.streakDays, 1);

      final repo = AppSettingsRepository.instance;
      expect(repo.dailyCheckInMood(), 'comfortable');
      expect(repo.dailyAwarenessStreak(), 1);
    });

    testWidgets('DailyCheckInCard renders initial check-in options', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DailyCheckInCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daily Money Check-In'), findsOneWidget);
      expect(find.text('🙂 Comfortable'), findsOneWidget);
      expect(find.text('😐 Unsure'), findsOneWidget);
      expect(find.text('😟 Concerned'), findsOneWidget);
    });

    testWidgets('DailyCheckInCard renders checked-in summary when completed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyCheckInProvider.overrideWith((ref) {
              return DailyCheckInNotifier()
                ..state = DailyCheckInState(
                  lastCheckInDate: DateTime.now(),
                  mood: 'comfortable',
                  streakDays: 5,
                  isCheckedInToday: true,
                );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DailyCheckInCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daily Money Check-In'), findsOneWidget);
      expect(find.textContaining('Recorded for today: 🙂 Comfortable'), findsOneWidget);
      expect(find.textContaining('Awareness beats perfection'), findsOneWidget);
      expect(find.text('🔥 5 days'), findsOneWidget);
    });
  });
}
