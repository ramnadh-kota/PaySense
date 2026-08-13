import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
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
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(LoanAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
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
  await Hive.openBox<AppNotification>('app_notifications');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_bill_test');
    await _initHive(tempDir);

    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-cash',
        name: 'Cash',
        bankName: '',
        type: 'cash',
        openingBalance: 2000,
        currentBalance: 2000,
        createdAt: DateTime.now(),
      ),
    );
    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-hdfc-salary',
        name: 'HDFC Salary',
        bankName: 'HDFC',
        type: 'checking',
        openingBalance: 10000,
        currentBalance: 10000,
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

  group('Bill.computeNextDueDate', () {
    test('advances weekly by seven days', () {
      final next = Bill.computeNextDueDate(DateTime(2026, 3, 10), 'Weekly');
      expect(next, DateTime(2026, 3, 17));
    });

    test('advances monthly and clamps day for shorter months', () {
      final next = Bill.computeNextDueDate(DateTime(2026, 1, 31), 'Monthly');
      expect(next, DateTime(2026, 2, 28));
    });

    test('advances yearly by one year', () {
      final next = Bill.computeNextDueDate(DateTime(2026, 6, 1), 'Yearly');
      expect(next, DateTime(2027, 6, 1));
    });
  });

  group('Bill.isOverdue / isUpcoming', () {
    test('unpaid bill due yesterday is overdue, not upcoming', () {
      final now = DateTime(2026, 8, 10);
      final bill = Bill.create(
        id: 'b1',
        title: 'Test',
        amount: 100,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime(2026, 8, 9),
        createdAt: now,
      );
      expect(bill.isOverdue(now), isTrue);
      expect(bill.isUpcoming(now), isFalse);
    });

    test('unpaid bill due in 3 days is upcoming, not overdue', () {
      final now = DateTime(2026, 8, 10);
      final bill = Bill.create(
        id: 'b2',
        title: 'Test',
        amount: 100,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime(2026, 8, 13),
        createdAt: now,
      );
      expect(bill.isOverdue(now), isFalse);
      expect(bill.isUpcoming(now), isTrue);
    });

    test('unpaid bill due in 30 days is neither overdue nor upcoming', () {
      final now = DateTime(2026, 8, 10);
      final bill = Bill.create(
        id: 'b3',
        title: 'Test',
        amount: 100,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime(2026, 9, 9),
        createdAt: now,
      );
      expect(bill.isOverdue(now), isFalse);
      expect(bill.isUpcoming(now), isFalse);
    });

    test('paid bill is never overdue or upcoming, even past due', () {
      final now = DateTime(2026, 8, 10);
      final bill = Bill.create(
        id: 'b4',
        title: 'Test',
        amount: 100,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime(2026, 8, 1),
        createdAt: now,
      ).markPaid(now);
      expect(bill.isOverdue(now), isFalse);
      expect(bill.isUpcoming(now), isFalse);
    });
  });

  test(
    'markPaid on a one-off bill creates a Transaction, deducts the wallet, '
    'and leaves the bill closed',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bill = Bill.create(
        id: 'bill1',
        title: 'Internet bill',
        amount: 999,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await container
          .read(billsProvider.notifier)
          .addBill(bill)
          .timeout(const Duration(seconds: 5));

      await container
          .read(billsProvider.notifier)
          .markPaid('bill1')
          .timeout(const Duration(seconds: 5));

      final state = container.read(billsProvider);
      final stored = state.value!.single;
      expect(stored.isPaid, isTrue);
      expect(stored.paidDate, isNotNull);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.title, 'Internet bill');
      expect(transactions.single.amount, 999.0);
      expect(transactions.single.transactionType, 'expense');

      final wallet = await WalletRepository.instance.getById('wallet-cash');
      expect(wallet!.currentBalance, 2000.0 - 999.0);
    },
  );

  test(
    'markPaid on a recurring bill rolls the due date forward and reopens it '
    'as unpaid',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bill = Bill.create(
        id: 'bill2',
        title: 'Gym membership',
        amount: 1500,
        categoryId: 'Fitness',
        accountId: 'Checking',
        dueDate: DateTime(2026, 8, 10),
        isRecurring: true,
        frequency: 'Monthly',
        createdAt: DateTime.now(),
      );

      await container
          .read(billsProvider.notifier)
          .addBill(bill)
          .timeout(const Duration(seconds: 5));

      await container
          .read(billsProvider.notifier)
          .markPaid('bill2')
          .timeout(const Duration(seconds: 5));

      final stored = container.read(billsProvider).value!.single;
      expect(stored.isPaid, isFalse);
      expect(stored.dueDate, DateTime(2026, 9, 10));

      final wallet = await WalletRepository.instance.getById(
        'wallet-hdfc-salary',
      );
      expect(wallet!.currentBalance, 10000.0 - 1500.0);
    },
  );

  test('markUnpaid reverts a one-off bill without touching transactions', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bill = Bill.create(
      id: 'bill3',
      title: 'Water bill',
      amount: 400,
      categoryId: 'Utilities',
      accountId: 'Cash',
      dueDate: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await container
        .read(billsProvider.notifier)
        .addBill(bill)
        .timeout(const Duration(seconds: 5));
    await container
        .read(billsProvider.notifier)
        .markPaid('bill3')
        .timeout(const Duration(seconds: 5));
    await container
        .read(billsProvider.notifier)
        .markUnpaid('bill3')
        .timeout(const Duration(seconds: 5));

    final stored = container.read(billsProvider).value!.single;
    expect(stored.isPaid, isFalse);
    expect(stored.paidDate, isNull);

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(1));
  });

  test('deleteBill removes it from storage', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bill = Bill.create(
      id: 'bill4',
      title: 'Rent',
      amount: 15000,
      categoryId: 'Housing',
      accountId: 'Checking',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
    );

    await container
        .read(billsProvider.notifier)
        .addBill(bill)
        .timeout(const Duration(seconds: 5));
    expect(container.read(billsProvider).value, hasLength(1));

    final deleted = await container
        .read(billsProvider.notifier)
        .deleteBill('bill4')
        .timeout(const Duration(seconds: 5));

    expect(deleted, isTrue);
    expect(container.read(billsProvider).value, isEmpty);
    expect(await BillRepository.instance.getAll(), isEmpty);
  });

  test('billTotalsProvider computes unpaid/overdue counts and amounts', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(billsProvider.notifier)
        .addBill(
          Bill.create(
            id: 'bill5',
            title: 'Overdue bill',
            amount: 500,
            categoryId: 'Utilities',
            accountId: 'Cash',
            dueDate: DateTime.now().subtract(const Duration(days: 2)),
            createdAt: DateTime.now(),
          ),
        )
        .timeout(const Duration(seconds: 5));

    await container
        .read(billsProvider.notifier)
        .addBill(
          Bill.create(
            id: 'bill6',
            title: 'Upcoming bill',
            amount: 700,
            categoryId: 'Subscriptions',
            accountId: 'Cash',
            dueDate: DateTime.now().add(const Duration(days: 3)),
            createdAt: DateTime.now(),
          ),
        )
        .timeout(const Duration(seconds: 5));

    final totals = container.read(billTotalsProvider);
    expect(totals.totalBills, 2);
    expect(totals.unpaidBills, 2);
    expect(totals.overdueBills, 1);
    expect(totals.totalUnpaidAmount, 1200.0);

    final upcoming = container.read(upcomingBillsProvider);
    expect(upcoming, hasLength(2));
    expect(upcoming.first.title, 'Overdue bill');
  });

  test('FinancialContextBuilder includes bill fields', () async {
    await BillRepository.instance.add(
      Bill.create(
        id: 'bill7',
        title: 'Phone bill',
        amount: 599,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime.now().add(const Duration(days: 4)),
        createdAt: DateTime.now(),
      ),
    );

    final context = await FinancialContextBuilder.instance.build();
    expect(context.totalBills, 1);
    expect(context.unpaidBills, 1);
    expect(context.overdueBills, 0);
    expect(context.totalUnpaidBillsAmount, 599.0);
    expect(context.nextBillTitle, 'Phone bill');
    expect(context.nextBillDueDate, isNotEmpty);
  });
}
