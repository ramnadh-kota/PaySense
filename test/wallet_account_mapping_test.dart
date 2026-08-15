import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';

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
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(AccountAdapter());
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
  await Hive.openBox('app_settings');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox<AppNotification>('app_notifications');
}

Future<Wallet> _addWallet(String id, String name, {double balance = 10000, String type = 'Bank'}) async {
  final wallet = Wallet(
    id: id,
    name: name,
    bankName: '',
    type: type,
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
  await WalletRepository.instance.add(wallet);
  return wallet;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_wallet_account_mapping_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('1. a new expense transaction stores the real wallet id, never a display label', () async {
    final wallet = await _addWallet('w-hdfc', 'HDFC Bank');
    final transaction = Transaction(
      id: 'tx-expense',
      title: 'Groceries',
      amount: 500,
      categoryId: 'Groceries',
      accountId: wallet.id, // exactly what AddExpenseScreen now stores
      transactionType: 'expense',
      paymentMethod: 'card',
      note: '',
      createdAt: DateTime.now(),
    );
    await TransactionRepository.instance.add(transaction);

    final stored = (await TransactionRepository.instance.getAll()).single;
    expect(stored.accountId, wallet.id);
    expect(stored.accountId, isNot('HDFC Bank'));
  });

  test('2. a new income transaction stores the real wallet id, never a display label', () async {
    final wallet = await _addWallet('w-cash', 'Cash', type: 'Cash');
    final transaction = Transaction(
      id: 'tx-income',
      title: 'Salary',
      amount: 60000,
      categoryId: 'Salary',
      accountId: wallet.id, // exactly what AddIncomeScreen now stores
      transactionType: 'income',
      paymentMethod: 'bank',
      note: '',
      createdAt: DateTime.now(),
    );
    await TransactionRepository.instance.add(transaction);

    final stored = (await TransactionRepository.instance.getAll()).single;
    expect(stored.accountId, wallet.id);
    expect(stored.accountId, isNot('Cash'));
  });

  test('3. paying a bill records a Transaction with the real wallet id', () async {
    final wallet = await _addWallet('w-hdfc', 'HDFC Bank');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await BillRepository.instance.add(
      Bill.create(
        id: 'bill1',
        title: 'Internet',
        amount: 999,
        categoryId: 'Utilities',
        accountId: 'HDFC Bank', // legacy-style label the bill form still stores
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    await container.read(billsProvider.future);
    await container.read(billsProvider.notifier).markPaid('bill1');

    final stored = (await TransactionRepository.instance.getAll()).single;
    expect(stored.accountId, wallet.id);
  });

  test('4. paying a loan EMI records a Transaction with the real wallet id', () async {
    final wallet = await _addWallet('w-hdfc', 'HDFC Bank');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await LoanRepository.instance.add(
      Loan.create(
        id: 'loan1',
        loanName: 'Car Loan',
        lenderName: 'Bank',
        loanType: 'Auto',
        principalAmount: 100000,
        interestRate: 8,
        tenureMonths: 12,
        emiAmount: 9000,
        totalInterest: 8000,
        accountId: 'HDFC Bank',
        startDate: DateTime.now(),
        nextDueDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    await container.read(loansProvider.future);
    await container.read(loansProvider.notifier).markEmiPaid('loan1');

    final stored = (await TransactionRepository.instance.getAll()).single;
    expect(stored.accountId, wallet.id);
  });

  test('5. a due recurring transaction records a Transaction with the real wallet id', () async {
    final wallet = await _addWallet('w-hdfc', 'HDFC Bank');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await RecurringTransactionRepository.instance.add(
      RecurringTransaction.create(
        id: 'rec1',
        title: 'Netflix',
        amount: 649,
        categoryId: 'Entertainment',
        accountId: 'HDFC Bank',
        transactionType: 'expense',
        frequency: 'Monthly',
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

    // Triggers _generateDueTransactions since the item is already due.
    await container.read(recurringTransactionsProvider.future);

    final stored = (await TransactionRepository.instance.getAll()).single;
    expect(stored.accountId, wallet.id);
  });

  test('6. a wallet transfer uses real wallet ids on both legs', () async {
    await _addWallet('w-a', 'Wallet A', balance: 50000);
    await _addWallet('w-b', 'Wallet B', balance: 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'w-a',
      toWalletId: 'w-b',
      amount: 5000,
    );

    final all = await TransactionRepository.instance.getAll();
    expect(all, hasLength(2));
    expect(all.map((t) => t.accountId), containsAll(['w-a', 'w-b']));
  });

  test('7. wallet-detail attribution matches transactions by wallet id', () async {
    final walletA = await _addWallet('w-a', 'Wallet A');
    final walletB = await _addWallet('w-b', 'Wallet B');

    final txForA = Transaction(
      id: 't-a',
      title: 'For A',
      amount: 100,
      categoryId: 'General',
      accountId: walletA.id,
      transactionType: 'expense',
      paymentMethod: 'card',
      note: '',
      createdAt: DateTime.now(),
    );

    final wallets = [walletA, walletB];
    expect(resolveWalletIdForAccount(txForA.accountId, wallets), walletA.id);
    expect(resolveWalletIdForAccount(txForA.accountId, wallets), isNot(walletB.id));
  });

  test('14. a transfer never counts toward income or expense totals', () async {
    await _addWallet('w-a', 'Wallet A', balance: 50000);
    await _addWallet('w-b', 'Wallet B', balance: 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'w-a',
      toWalletId: 'w-b',
      amount: 5000,
    );

    final all = await TransactionRepository.instance.getAll();
    final income = all.where((t) => t.transactionType.toLowerCase() == 'income');
    final expense = all.where((t) => t.transactionType.toLowerCase() == 'expense');
    expect(income, isEmpty);
    expect(expense, isEmpty);
    expect(all.every((t) => t.transactionType == 'transfer'), isTrue);
  });

  test('15. three wallets remain distinguishable — a bill attributes to the correct one', () async {
    await _addWallet('w-a', 'Wallet A');
    final targetWallet = await _addWallet('w-b', 'Wallet B');
    await _addWallet('w-c', 'Wallet C');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await BillRepository.instance.add(
      Bill.create(
        id: 'bill1',
        title: 'Gym',
        amount: 1500,
        categoryId: 'Health',
        accountId: 'Wallet B', // matches exactly one of the three wallets by name
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    await container.read(billsProvider.future);
    await container.read(billsProvider.notifier).markPaid('bill1');

    final stored = (await TransactionRepository.instance.getAll()).single;
    expect(stored.accountId, targetWallet.id);
    expect(stored.accountId, isNot('w-a'));
    expect(stored.accountId, isNot('w-c'));
  });

  test('16. wallet-specific transaction history only includes that wallet\'s transactions', () async {
    final walletA = await _addWallet('w-a', 'Wallet A');
    final walletB = await _addWallet('w-b', 'Wallet B');

    await TransactionRepository.instance.add(
      Transaction(
        id: 't-a1',
        title: 'A1',
        amount: 100,
        categoryId: 'General',
        accountId: walletA.id,
        transactionType: 'expense',
        paymentMethod: 'card',
        note: '',
        createdAt: DateTime.now(),
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 't-b1',
        title: 'B1',
        amount: 200,
        categoryId: 'General',
        accountId: walletB.id,
        transactionType: 'expense',
        paymentMethod: 'card',
        note: '',
        createdAt: DateTime.now(),
      ),
    );

    final all = await TransactionRepository.instance.getAll();
    final wallets = [walletA, walletB];
    final aHistory = all.where((t) => resolveWalletIdForAccount(t.accountId, wallets) == walletA.id);
    final bHistory = all.where((t) => resolveWalletIdForAccount(t.accountId, wallets) == walletB.id);

    expect(aHistory.map((t) => t.id), ['t-a1']);
    expect(bHistory.map((t) => t.id), ['t-b1']);
  });
}
