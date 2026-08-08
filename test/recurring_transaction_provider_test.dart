import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

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

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox<Bill>('bills');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_recurring_test');
    await _initHive(tempDir);

    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-cash',
        name: 'Cash',
        bankName: '',
        type: 'cash',
        openingBalance: 1000,
        currentBalance: 1000,
        createdAt: DateTime.now(),
      ),
    );
    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-hdfc-salary',
        name: 'HDFC Salary',
        bankName: 'HDFC',
        type: 'checking',
        openingBalance: 5000,
        currentBalance: 5000,
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RecurringTransaction.computeNextDueDate', () {
    test('advances daily by one day', () {
      final next = RecurringTransaction.computeNextDueDate(
        DateTime(2026, 3, 10),
        'Daily',
      );
      expect(next, DateTime(2026, 3, 11));
    });

    test('advances weekly by seven days', () {
      final next = RecurringTransaction.computeNextDueDate(
        DateTime(2026, 3, 10),
        'Weekly',
      );
      expect(next, DateTime(2026, 3, 17));
    });

    test('advances monthly and clamps day for shorter months', () {
      final next = RecurringTransaction.computeNextDueDate(
        DateTime(2026, 1, 31),
        'Monthly',
      );
      expect(next, DateTime(2026, 2, 28));
    });

    test('advances monthly across a year boundary', () {
      final next = RecurringTransaction.computeNextDueDate(
        DateTime(2026, 12, 15),
        'Monthly',
      );
      expect(next, DateTime(2027, 1, 15));
    });

    test('advances yearly by one year', () {
      final next = RecurringTransaction.computeNextDueDate(
        DateTime(2026, 6, 1),
        'Yearly',
      );
      expect(next, DateTime(2027, 6, 1));
    });
  });

  test(
    'RecurringTransactionsNotifier.addRecurringTransaction generates a due '
    'transaction, updates wallet balance, and advances nextDueDate',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container
          .read(recurringTransactionsProvider.future)
          .timeout(const Duration(seconds: 5));
      expect(initial, isEmpty);

      final startDate = DateTime.now().subtract(const Duration(days: 1));
      final recurring = RecurringTransaction.create(
        id: 'r1',
        title: 'Netflix',
        amount: 500,
        categoryId: 'Subscriptions',
        accountId: 'Cash',
        transactionType: 'expense',
        frequency: 'Monthly',
        startDate: startDate,
        createdAt: DateTime.now(),
      );

      await container
          .read(recurringTransactionsProvider.notifier)
          .addRecurringTransaction(recurring)
          .timeout(const Duration(seconds: 5));

      final state = container.read(recurringTransactionsProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(1));

      final stored = state.value!.single;
      expect(stored.lastGeneratedDate, isNotNull);
      expect(stored.nextDueDate.isAfter(DateTime.now()), isTrue);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.title, 'Netflix');
      expect(transactions.single.amount, 500.0);
      expect(transactions.single.transactionType, 'expense');

      final wallet = await WalletRepository.instance.getById('wallet-cash');
      expect(wallet!.currentBalance, 500.0);
    },
  );

  test(
    'generation is idempotent: reloading again does not create duplicate '
    'transactions once nextDueDate is in the future',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final recurring = RecurringTransaction.create(
        id: 'r2',
        title: 'Salary',
        amount: 40000,
        categoryId: 'Salary',
        accountId: 'Checking',
        transactionType: 'income',
        frequency: 'Monthly',
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now(),
      );

      await container
          .read(recurringTransactionsProvider.notifier)
          .addRecurringTransaction(recurring)
          .timeout(const Duration(seconds: 5));

      await container
          .read(recurringTransactionsProvider.notifier)
          .reload()
          .timeout(const Duration(seconds: 5));

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));

      final wallet = await WalletRepository.instance.getById(
        'wallet-hdfc-salary',
      );
      expect(wallet!.currentBalance, 5000.0 + 40000.0);
    },
  );

  test(
    'deleteRecurringTransaction removes the item without touching already '
    'generated transactions',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final recurring = RecurringTransaction.create(
        id: 'r3',
        title: 'Gym membership',
        amount: 1200,
        categoryId: 'Fitness',
        accountId: 'Cash',
        transactionType: 'expense',
        frequency: 'Monthly',
        startDate: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now(),
      );

      await container
          .read(recurringTransactionsProvider.notifier)
          .addRecurringTransaction(recurring)
          .timeout(const Duration(seconds: 5));

      expect(container.read(recurringTransactionsProvider).value, hasLength(1));

      final deleted = await container
          .read(recurringTransactionsProvider.notifier)
          .deleteRecurringTransaction('r3')
          .timeout(const Duration(seconds: 5));

      expect(deleted, isTrue);
      expect(container.read(recurringTransactionsProvider).value, isEmpty);

      final remaining = await RecurringTransactionRepository.instance.getAll();
      expect(remaining, isEmpty);
    },
  );

  test('recurringTotalsProvider computes monthly equivalents correctly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(recurringTransactionsProvider.notifier)
        .addRecurringTransaction(
          RecurringTransaction.create(
            id: 'r4',
            title: 'Weekly allowance',
            amount: 700,
            categoryId: 'Allowance',
            accountId: 'Cash',
            transactionType: 'income',
            frequency: 'Weekly',
            startDate: DateTime.now().add(const Duration(days: 3)),
            createdAt: DateTime.now(),
          ),
        )
        .timeout(const Duration(seconds: 5));

    final totals = container.read(recurringTotalsProvider);
    expect(totals.totalActive, 1);
    expect(totals.monthlyRecurringIncome, closeTo(700 * (30 / 7), 0.01));
    expect(totals.monthlyRecurringExpense, 0.0);
    expect(totals.nextPaymentTitle, 'Weekly allowance');
  });

  test('FinancialContextBuilder includes recurring transaction fields', () async {
    await RecurringTransactionRepository.instance.add(
      RecurringTransaction.create(
        id: 'r5',
        title: 'Rent',
        amount: 15000,
        categoryId: 'Housing',
        accountId: 'Checking',
        transactionType: 'expense',
        frequency: 'Monthly',
        startDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
      ),
    );

    final context = await FinancialContextBuilder.instance.build();
    expect(context.totalRecurringTransactions, 1);
    expect(context.activeRecurringTransactions, 1);
    expect(context.monthlyRecurringExpense, 15000.0);
    expect(context.monthlyRecurringIncome, 0.0);
    expect(context.nextUpcomingPayment, 'Rent');
    expect(context.nextUpcomingPaymentDate, isNotEmpty);
  });
}
