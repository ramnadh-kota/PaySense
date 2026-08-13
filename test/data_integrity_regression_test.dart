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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_data_integrity_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'regression: rapid double-invocation of Bill markPaid records only one '
    'expense transaction and deducts the wallet only once',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await WalletRepository.instance.add(
        Wallet(
          id: 'wallet-cash',
          name: 'Cash',
          bankName: '',
          type: 'cash',
          openingBalance: 5000,
          currentBalance: 5000,
          createdAt: DateTime.now(),
        ),
      );

      await container.read(billsProvider.notifier).addBill(
        Bill.create(
          id: 'bill1',
          title: 'Internet',
          amount: 999,
          categoryId: 'Utilities',
          accountId: 'Cash',
          dueDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      // Simulate a rapid double-tap: both calls start before either finishes.
      final notifier = container.read(billsProvider.notifier);
      final first = notifier.markPaid('bill1');
      final second = notifier.markPaid('bill1');
      await Future.wait([first, second]);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.title, 'Internet');

      final wallet = await WalletRepository.instance.getById('wallet-cash');
      expect(wallet!.currentBalance, 5000 - 999);
    },
  );

  test(
    'regression: rapid double-invocation of Loan markEmiPaid records only '
    'one EMI transaction and deducts the wallet only once',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await WalletRepository.instance.add(
        Wallet(
          id: 'wallet-hdfc-salary',
          name: 'HDFC Salary',
          bankName: 'HDFC',
          type: 'checking',
          openingBalance: 100000,
          currentBalance: 100000,
          createdAt: DateTime.now(),
        ),
      );

      await container.read(loansProvider.notifier).addLoan(
        Loan.create(
          id: 'loan1',
          loanName: 'Car Loan',
          lenderName: 'Bank',
          loanType: 'Auto',
          principalAmount: 500000,
          interestRate: 9,
          tenureMonths: 60,
          emiAmount: 10000,
          totalInterest: 50000,
          accountId: 'Checking',
          startDate: DateTime.now(),
          nextDueDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      final notifier = container.read(loansProvider.notifier);
      final first = notifier.markEmiPaid('loan1');
      final second = notifier.markEmiPaid('loan1');
      await Future.wait([first, second]);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.title, 'Car Loan EMI');

      final wallet = await WalletRepository.instance.getById('wallet-hdfc-salary');
      expect(wallet!.currentBalance, 100000 - 10000);
    },
  );
}
