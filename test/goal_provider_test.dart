import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BudgetAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(GoalAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BillAdapter());
  }
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(LoanAdapter());
  }

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox('app_settings');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_goal_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'GoalsNotifier.addGoal persists to Hive, resolves to AsyncData, and '
    'goalTotalsProvider computes correctly',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container
          .read(goalsProvider.future)
          .timeout(const Duration(seconds: 5));
      expect(initial, isEmpty);

      final goal = Goal.create(
        id: 'g1',
        title: 'New laptop',
        targetAmount: 50000,
        currentAmount: 20000,
        targetDate: DateTime(2026, 12, 31),
        category: 'Electronics',
        icon: 'laptop',
        color: 0xFF5B4CF8,
        createdAt: DateTime.now(),
      );

      await container
          .read(goalsProvider.notifier)
          .addGoal(goal)
          .timeout(const Duration(seconds: 5));

      final state = container.read(goalsProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(1));
      expect(state.value!.single.title, 'New laptop');
      expect(state.value!.single.currentAmount, 20000.0);
      expect(state.value!.single.isCompleted, isFalse);

      final stored = await GoalRepository.instance.getAll();
      expect(stored, hasLength(1));

      final totals = container.read(goalTotalsProvider);
      expect(totals.totalGoals, 1);
      expect(totals.totalTarget, 50000.0);
      expect(totals.totalSaved, 20000.0);
      expect(totals.totalRemaining, 30000.0);
      expect(totals.closestGoal, 'New laptop');
    },
  );

  test('FinancialContextBuilder includes goal fields', () async {
    final goal = Goal.create(
      id: 'g1',
      title: 'Vacation',
      targetAmount: 10000,
      currentAmount: 10000,
      targetDate: DateTime(2026, 6, 1),
      category: 'Travel',
      icon: 'flight',
      color: 0xFF5B4CF8,
      createdAt: DateTime.now(),
    );
    await GoalRepository.instance.add(goal);

    final context = await FinancialContextBuilder.instance.build();
    expect(context.totalGoals, 1);
    expect(context.completedGoals, 1);
    expect(context.totalTargetSavings, 10000.0);
    expect(context.totalCurrentSavings, 10000.0);
    expect(context.goalCompletionPercentage, 100.0);
    expect(context.nearestGoal, '');
  });
}
