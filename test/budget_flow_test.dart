import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/budget_provider.dart';

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

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_budget_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'BudgetsNotifier.addBudget persists to Hive and resolves to AsyncData '
    '(regression test: previously hung forever because build() read '
    'transactionsProvider synchronously instead of awaiting its .future)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container
          .read(budgetsProvider.future)
          .timeout(const Duration(seconds: 5));
      expect(initial, isEmpty);

      final sample = Budget.create(
        id: 'b1',
        categoryId: 'groceries',
        categoryName: 'Groceries',
        allocatedAmount: 5000,
        month: 'August',
        year: 2026,
        createdAt: DateTime.now(),
      );

      await container
          .read(budgetsProvider.notifier)
          .addBudget(sample)
          .timeout(const Duration(seconds: 5));

      final state = container.read(budgetsProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(1));
      expect(state.value!.single.categoryName, 'Groceries');
      expect(state.value!.single.allocatedAmount, 5000.0);

      final totals = container.read(budgetTotalsProvider);
      expect(totals.totalBudget, 5000.0);
      expect(totals.totalSpent, 0.0);
      expect(totals.remainingBudget, 5000.0);
      expect(totals.highestSpendingCategory, 'Groceries');
    },
  );
}
