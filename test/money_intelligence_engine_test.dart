import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
import 'package:paysense/shared/utils/financial_action_engine.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';
import 'package:paysense/shared/utils/weekly_money_story_calculator.dart';

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
  final now = DateTime(2026, 8, 25);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_money_intel_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Personal Money Intelligence Engine Unit Tests', () {
    test('handles insufficient data gracefully without misleading 0% or NaN', () {
      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      final result = FinancialInsightEngine.generate(
        actionPlan: const FinancialActionPlan(actions: []),
        trends: FinancialHealthTrendsCalculator.calculate(
          transactions: const [],
          budgets: const [],
          goals: const [],
          loans: const [],
          bills: const [],
          wallets: const [],
          profileMonthlyIncome: 0,
          period: TrendPeriod.threeMonths,
          now: now,
        ),
        safeToSpend: safeToSpend,
        recurringTransactions: const [],
        transactions: [
          Transaction(
            id: 't0',
            title: 'Start',
            amount: 50,
            categoryId: 'General',
            accountId: 'w1',
            transactionType: 'expense',
            paymentMethod: 'Cash',
            note: '',
            createdAt: now,
          ),
        ],
        now: now,
      );

      expect(result.insights, isNotEmpty);
      final guidance = result.insights.firstWhere((i) => i.type == InsightType.insufficientData);
      expect(guidance.title, 'Personal Money Intelligence');
      expect(guidance.explanation, contains('Keep tracking for a little longer'));
    });

    test('detects spending trend month over month', () {
      final currentMonthTxn = Transaction(
        id: 't1',
        title: 'Food',
        amount: 15000,
        categoryId: 'Food',
        accountId: 'w1',
        transactionType: 'expense',
        paymentMethod: 'UPI',
        note: '',
        createdAt: DateTime(2026, 8, 10),
      );
      final prevMonthTxn = Transaction(
        id: 't2',
        title: 'Food',
        amount: 10000,
        categoryId: 'Food',
        accountId: 'w1',
        transactionType: 'expense',
        paymentMethod: 'UPI',
        note: '',
        createdAt: DateTime(2026, 7, 15),
      );

      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      final result = FinancialInsightEngine.generate(
        actionPlan: const FinancialActionPlan(actions: []),
        trends: FinancialHealthTrendsCalculator.calculate(
          transactions: [currentMonthTxn, prevMonthTxn],
          budgets: const [],
          goals: const [],
          loans: const [],
          bills: const [],
          wallets: const [],
          profileMonthlyIncome: 0,
          period: TrendPeriod.threeMonths,
          now: now,
        ),
        safeToSpend: safeToSpend,
        recurringTransactions: const [],
        transactions: [currentMonthTxn, prevMonthTxn],
        now: now,
      );

      final trend = result.insights.firstWhere((i) => i.type == InsightType.spendingTrend);
      expect(trend.title, contains('Monthly spending is up 50%'));
      expect(trend.explanation, contains('50% more this month'));
    });

    test('detects high category pressure when a single category dominates', () {
      final txns = [
        Transaction(
          id: 't1',
          title: 'Rent',
          amount: 8000,
          categoryId: 'Housing',
          accountId: 'w1',
          transactionType: 'expense',
          paymentMethod: 'Bank Transfer',
          note: '',
          createdAt: DateTime(2026, 8, 5),
        ),
        Transaction(
          id: 't2',
          title: 'Groceries',
          amount: 1000,
          categoryId: 'Food',
          accountId: 'w1',
          transactionType: 'expense',
          paymentMethod: 'UPI',
          note: '',
          createdAt: DateTime(2026, 8, 6),
        ),
      ];

      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      final result = FinancialInsightEngine.generate(
        actionPlan: const FinancialActionPlan(actions: []),
        trends: FinancialHealthTrendsCalculator.calculate(
          transactions: txns,
          budgets: const [],
          goals: const [],
          loans: const [],
          bills: const [],
          wallets: const [],
          profileMonthlyIncome: 0,
          period: TrendPeriod.threeMonths,
          now: now,
        ),
        safeToSpend: safeToSpend,
        recurringTransactions: const [],
        transactions: txns,
        now: now,
      );

      final catPressure = result.insights.firstWhere((i) => i.type == InsightType.categoryPressure);
      expect(catPressure.title, contains('Housing is your biggest expense'));
      expect(catPressure.explanation, contains('89%'));
    });

    test('detects high frequency small purchases', () {
      final txns = List.generate(5, (index) {
        return Transaction(
          id: 't_$index',
          title: 'Coffee',
          amount: 150,
          categoryId: 'Dining Out',
          accountId: 'w1',
          transactionType: 'expense',
          paymentMethod: 'UPI',
          note: '',
          createdAt: DateTime(2026, 8, 2 + index),
        );
      });

      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      final result = FinancialInsightEngine.generate(
        actionPlan: const FinancialActionPlan(actions: []),
        trends: FinancialHealthTrendsCalculator.calculate(
          transactions: txns,
          budgets: const [],
          goals: const [],
          loans: const [],
          bills: const [],
          wallets: const [],
          profileMonthlyIncome: 0,
          period: TrendPeriod.threeMonths,
          now: now,
        ),
        safeToSpend: safeToSpend,
        recurringTransactions: const [],
        transactions: txns,
        now: now,
      );

      final freqAlert = result.insights.firstWhere((i) => i.type == InsightType.frequencyAlert);
      expect(freqAlert.title, contains('Frequent small purchases in Dining Out'));
      expect(freqAlert.explanation, contains('5 Dining Out purchases'));
    });

    test('calculates subscription awareness summary', () {
      final recurrings = [
        RecurringTransaction.create(
          id: 'r1',
          title: 'Netflix',
          amount: 649,
          categoryId: 'Subscriptions',
          accountId: 'w1',
          transactionType: 'expense',
          frequency: 'Monthly',
          startDate: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: recurrings,
        now: now,
      );

      final result = FinancialInsightEngine.generate(
        actionPlan: const FinancialActionPlan(actions: []),
        trends: FinancialHealthTrendsCalculator.calculate(
          transactions: const [],
          budgets: const [],
          goals: const [],
          loans: const [],
          bills: const [],
          wallets: const [],
          profileMonthlyIncome: 0,
          period: TrendPeriod.threeMonths,
          now: now,
        ),
        safeToSpend: safeToSpend,
        recurringTransactions: recurrings,
        transactions: const [],
        now: now,
      );

      final sub = result.insights.firstWhere((i) => i.type == InsightType.subscriptionAwareness);
      expect(sub.title, 'Active Subscriptions Summary');
      expect(sub.explanation, contains('₹649/month committed'));
    });

    test('correlates Daily Check-In sentiment with insights', () {
      final stateConcerned = DailyCheckInState(
        lastCheckInDate: now,
        mood: 'concerned',
        streakDays: 4,
        isCheckedInToday: true,
      );

      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      final result = FinancialInsightEngine.generate(
        actionPlan: const FinancialActionPlan(actions: []),
        trends: FinancialHealthTrendsCalculator.calculate(
          transactions: const [],
          budgets: const [],
          goals: const [],
          loans: const [],
          bills: const [],
          wallets: const [],
          profileMonthlyIncome: 0,
          period: TrendPeriod.threeMonths,
          now: now,
        ),
        safeToSpend: safeToSpend,
        recurringTransactions: const [],
        transactions: const [],
        dailyCheckInState: stateConcerned,
        now: now,
      );

      final checkIn = result.insights.firstWhere((i) => i.type == InsightType.checkInCorrelation);
      expect(checkIn.title, contains('Money Check-In & Spend Correlation'));
      expect(checkIn.explanation, contains('feeling concerned'));
    });

    test('WeeklyMoneyStoryCalculator generates deterministic story', () {
      final txns = [
        Transaction(
          id: 't1',
          title: 'Dining',
          amount: 2500,
          categoryId: 'Food',
          accountId: 'w1',
          transactionType: 'expense',
          paymentMethod: 'UPI',
          note: '',
          createdAt: DateTime(2026, 8, 22),
        ),
        Transaction(
          id: 't2',
          title: 'Salary',
          amount: 50000,
          categoryId: 'Income',
          accountId: 'w1',
          transactionType: 'income',
          paymentMethod: 'Bank Transfer',
          note: '',
          createdAt: DateTime(2026, 8, 20),
        ),
      ];

      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      final story = WeeklyMoneyStoryCalculator.calculate(
        transactions: txns,
        safeToSpend: safeToSpend,
        dailyCheckInState: DailyCheckInState(
          lastCheckInDate: now,
          mood: 'comfortable',
          streakDays: 6,
          isCheckedInToday: true,
        ),
        now: now,
      );

      expect(story.hasSufficientData, isTrue);
      expect(story.spentThisWeek, 2500);
      expect(story.savedThisWeek, 47500);
      expect(story.largestCategory, 'Food');
      expect(story.awarenessStreakDays, 6);
      expect(story.summaryNarrative, contains('2500'));
    });
  });
}
