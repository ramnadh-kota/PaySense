import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/dashboard/widgets/your_money_explained_card.dart';
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
import 'package:paysense/shared/models/weekly_money_story.dart';
import 'package:paysense/shared/providers/financial_insight_provider.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';

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
    tempDir = await Directory.systemTemp.createTemp('paysense_widget_intel_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('YourMoneyExplainedCard Widget Tests', () {
    testWidgets('renders section title and segment choices', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: YourMoneyExplainedCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your Money, Explained'), findsOneWidget);
      expect(find.text('Personal Money Intelligence'), findsAtLeastNWidgets(1));
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Weekly Story'), findsOneWidget);
    });

    testWidgets('renders insights list when insights exist', (tester) async {
      final mockInsight = const FinancialInsight(
        id: 'test:1',
        type: InsightType.spendingTrend,
        priority: InsightPriority.high,
        title: 'Food Spending Increase',
        explanation: 'You spent 25% more on food this month.',
        recommendedAction: 'See spending',
        actionRoute: '/transactions',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialInsightsProvider.overrideWithValue(
              FinancialInsightResult(insights: [mockInsight]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: YourMoneyExplainedCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Food Spending Increase'), findsOneWidget);
      expect(find.text('You spent 25% more on food this month.'), findsOneWidget);
      expect(find.text('See spending'), findsOneWidget);
    });

    testWidgets('switches to Weekly Story tab when selected', (tester) async {
      final mockStory = const WeeklyMoneyStory(
        spentThisWeek: 4820,
        savedThisWeek: 2100,
        largestCategory: 'Food',
        largestCategoryAmount: 2100,
        safeToSpendRemaining: 6400,
        safeToSpendStatus: 'Comfortable',
        awarenessStreakDays: 5,
        summaryHeadline: 'Weekly Money Snapshot: Spending Comfortable',
        summaryNarrative:
            'You are spending comfortably this week. Food is your largest discretionary category.',
        hasSufficientData: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyMoneyStoryProvider.overrideWithValue(mockStory),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: YourMoneyExplainedCard(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Weekly Story'));
      await tester.pump();

      expect(find.text('Weekly Money Snapshot: Spending Comfortable'), findsOneWidget);
      expect(find.textContaining('You are spending comfortably this week.'), findsOneWidget);
      expect(find.text('🔥 5 d'), findsOneWidget);
      expect(find.text('₹4820'), findsOneWidget);
      expect(find.text('₹2100'), findsOneWidget);
    });

    testWidgets('renders all-clear empty state when no insights active', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialInsightsProvider.overrideWithValue(
              const FinancialInsightResult(insights: []),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: YourMoneyExplainedCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('All Clear & Steady'), findsOneWidget);
      expect(find.textContaining('No critical risks or pressure detected.'), findsOneWidget);
    });
  });
}
