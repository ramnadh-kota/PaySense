// Focused tests for BudgetRepository.refreshBudgets' transaction-matching
// logic — the piece that actually computes spentAmount by matching
// transaction.categoryId + createdAt.year/month against each stored
// Budget. This is the repository-level half of items 19-21 (category
// matching, current-month filtering, month boundary); the calculator-level
// half lives in budget_calculator_test.dart. Synthetic data only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';

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

Transaction _expense({
  required String id,
  required double amount,
  required String categoryId,
  required DateTime createdAt,
}) {
  return Transaction(
    id: id,
    title: 'Test expense',
    amount: amount,
    categoryId: categoryId,
    accountId: 'wallet-1',
    transactionType: 'expense',
    paymentMethod: 'cash',
    note: '',
    createdAt: createdAt,
  );
}

void main() {
  late Directory tempDir;
  final repository = BudgetRepository.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'paysense_budget_repo_test',
    );
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // 19. Category matching
  test(
    '19. spentAmount only sums transactions whose categoryId exactly '
    'matches the budget categoryId — no fuzzy matching',
    () async {
      final budget = Budget.create(
        id: 'b1',
        categoryId: 'Groceries',
        categoryName: 'Groceries',
        allocatedAmount: 5000,
        month: 'August',
        year: 2026,
        createdAt: DateTime(2026, 8),
      );
      await repository.add(budget);

      final transactions = [
        _expense(
          id: 't1',
          amount: 1000,
          categoryId: 'Groceries',
          createdAt: DateTime(2026, 8, 5),
        ),
        _expense(
          id: 't2',
          amount: 9999,
          categoryId: 'groceries', // different case — must NOT match
          createdAt: DateTime(2026, 8, 6),
        ),
        _expense(
          id: 't3',
          amount: 500,
          categoryId: 'Dining', // different category — must NOT match
          createdAt: DateTime(2026, 8, 7),
        ),
      ];

      await repository.refreshBudgets(transactions);
      final refreshed = await repository.getById('b1');
      expect(refreshed!.spentAmount, 1000.0);
    },
  );

  // 20. Current month filtering
  test(
    '20. spentAmount excludes transactions from other months/years for '
    'the same category',
    () async {
      final budget = Budget.create(
        id: 'b1',
        categoryId: 'Travel',
        categoryName: 'Travel',
        allocatedAmount: 8000,
        month: 'August',
        year: 2026,
        createdAt: DateTime(2026, 8),
      );
      await repository.add(budget);

      final transactions = [
        _expense(
          id: 't1',
          amount: 2000,
          categoryId: 'Travel',
          createdAt: DateTime(2026, 8, 15),
        ),
        _expense(
          id: 't2',
          amount: 5000,
          categoryId: 'Travel',
          createdAt: DateTime(2026, 7, 15), // previous month
        ),
        _expense(
          id: 't3',
          amount: 3000,
          categoryId: 'Travel',
          createdAt: DateTime(2025, 8, 15), // same month, previous year
        ),
      ];

      await repository.refreshBudgets(transactions);
      final refreshed = await repository.getById('b1');
      expect(refreshed!.spentAmount, 2000.0);
    },
  );

  // 21. Month boundary
  test(
    '21. transactions exactly on the first/last instant of the budget '
    'month are included; the first instant of the next month is not',
    () async {
      final budget = Budget.create(
        id: 'b1',
        categoryId: 'Utilities',
        categoryName: 'Utilities',
        allocatedAmount: 3000,
        month: 'August',
        year: 2026,
        createdAt: DateTime(2026, 8),
      );
      await repository.add(budget);

      final transactions = [
        _expense(
          id: 't1',
          amount: 100,
          categoryId: 'Utilities',
          createdAt: DateTime(2026, 8, 1, 0, 0, 0), // first instant of August
        ),
        _expense(
          id: 't2',
          amount: 200,
          categoryId: 'Utilities',
          createdAt: DateTime(2026, 8, 31, 23, 59, 59), // last instant of August
        ),
        _expense(
          id: 't3',
          amount: 9999,
          categoryId: 'Utilities',
          createdAt: DateTime(2026, 9, 1, 0, 0, 0), // first instant of September
        ),
      ];

      await repository.refreshBudgets(transactions);
      final refreshed = await repository.getById('b1');
      expect(refreshed!.spentAmount, 300.0);
    },
  );
}
