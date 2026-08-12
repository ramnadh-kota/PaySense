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
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
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

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
}

Loan _sampleLoan({
  required String id,
  required double principal,
  required double rate,
  required int tenure,
  required DateTime startDate,
  required DateTime nextDueDate,
  String accountId = 'Cash',
  bool useAutoEmi = true,
  double? manualEmi,
}) {
  final calc = Loan.calculateEmi(
    principal: principal,
    annualRatePercent: rate,
    tenureMonths: tenure,
  );
  return Loan.create(
    id: id,
    loanName: 'Loan $id',
    lenderName: 'Test Bank',
    loanType: 'Personal',
    principalAmount: principal,
    interestRate: rate,
    tenureMonths: tenure,
    emiAmount: useAutoEmi ? calc.emiAmount : (manualEmi ?? calc.emiAmount),
    totalInterest: useAutoEmi ? calc.totalInterest : 0,
    accountId: accountId,
    startDate: startDate,
    nextDueDate: nextDueDate,
    createdAt: startDate,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_loan_test');
    await _initHive(tempDir);

    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-cash',
        name: 'Cash',
        bankName: '',
        type: 'cash',
        openingBalance: 100000,
        currentBalance: 100000,
        createdAt: DateTime.now(),
      ),
    );
    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-hdfc-salary',
        name: 'HDFC Salary',
        bankName: 'HDFC',
        type: 'checking',
        openingBalance: 200000,
        currentBalance: 200000,
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

  group('Loan.calculateEmi', () {
    test('computes a standard reducing-balance EMI correctly', () {
      // Known reference: 100000 principal, 10% annual, 12 months ->
      // EMI ~= 8791.59
      final calc = Loan.calculateEmi(
        principal: 100000,
        annualRatePercent: 10,
        tenureMonths: 12,
      );
      expect(calc.emiAmount, closeTo(8791.59, 0.5));
      expect(calc.totalPayable, closeTo(calc.emiAmount * 12, 0.01));
      expect(calc.totalInterest, closeTo(calc.totalPayable - 100000, 0.01));
    });

    test('falls back to an even split for a zero-interest loan', () {
      final calc = Loan.calculateEmi(
        principal: 12000,
        annualRatePercent: 0,
        tenureMonths: 12,
      );
      expect(calc.emiAmount, 1000.0);
      expect(calc.totalInterest, 0.0);
      expect(calc.totalPayable, 12000.0);
    });

    test('returns zeros for a non-positive tenure or principal', () {
      final calc = Loan.calculateEmi(
        principal: 0,
        annualRatePercent: 10,
        tenureMonths: 12,
      );
      expect(calc.emiAmount, 0.0);
    });
  });

  test(
    'markEmiPaid creates a Transaction, deducts the wallet, reduces '
    'outstanding, and advances the due date',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final loan = _sampleLoan(
        id: 'l1',
        principal: 12000,
        rate: 0,
        tenure: 12,
        startDate: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 2, 1),
      );

      await container
          .read(loansProvider.notifier)
          .addLoan(loan)
          .timeout(const Duration(seconds: 5));

      await container
          .read(loansProvider.notifier)
          .markEmiPaid('l1')
          .timeout(const Duration(seconds: 5));

      final stored = container.read(loansProvider).value!.single;
      expect(stored.outstandingAmount, 11000.0);
      expect(stored.paidAmount, 1000.0);
      expect(stored.nextDueDate, DateTime(2026, 3, 1));
      expect(stored.status, 'Active');

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.amount, 1000.0);
      expect(transactions.single.transactionType, 'expense');

      final wallet = await WalletRepository.instance.getById('wallet-cash');
      expect(wallet!.currentBalance, 100000.0 - 1000.0);
    },
  );

  test(
    'markEmiPaid closes the loan once the final installment clears the '
    'outstanding balance',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Single-month loan: one EMI pays it off entirely.
      final loan = _sampleLoan(
        id: 'l2',
        principal: 5000,
        rate: 0,
        tenure: 1,
        startDate: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 2, 1),
        accountId: 'Checking',
      );

      await container
          .read(loansProvider.notifier)
          .addLoan(loan)
          .timeout(const Duration(seconds: 5));
      await container
          .read(loansProvider.notifier)
          .markEmiPaid('l2')
          .timeout(const Duration(seconds: 5));

      final stored = container.read(loansProvider).value!.single;
      expect(stored.status, 'Closed');
      expect(stored.outstandingAmount, 0.0);
      expect(stored.isClosed, isTrue);
    },
  );

  test('closeLoan manually marks a loan closed with zero outstanding', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final loan = _sampleLoan(
      id: 'l3',
      principal: 50000,
      rate: 8,
      tenure: 24,
      startDate: DateTime.now(),
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
    );

    await container
        .read(loansProvider.notifier)
        .addLoan(loan)
        .timeout(const Duration(seconds: 5));
    await container
        .read(loansProvider.notifier)
        .closeLoan('l3')
        .timeout(const Duration(seconds: 5));

    final stored = container.read(loansProvider).value!.single;
    expect(stored.status, 'Closed');
    expect(stored.outstandingAmount, 0.0);
  });

  test('deleteLoan removes it from storage', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final loan = _sampleLoan(
      id: 'l4',
      principal: 20000,
      rate: 5,
      tenure: 12,
      startDate: DateTime.now(),
      nextDueDate: DateTime.now().add(const Duration(days: 10)),
    );

    await container
        .read(loansProvider.notifier)
        .addLoan(loan)
        .timeout(const Duration(seconds: 5));
    expect(container.read(loansProvider).value, hasLength(1));

    final deleted = await container
        .read(loansProvider.notifier)
        .deleteLoan('l4')
        .timeout(const Duration(seconds: 5));

    expect(deleted, isTrue);
    expect(container.read(loansProvider).value, isEmpty);
    expect(await LoanRepository.instance.getAll(), isEmpty);
  });

  test('loanSummaryProvider aggregates active/closed loans correctly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(loansProvider.notifier)
        .addLoan(
          _sampleLoan(
            id: 'l5',
            principal: 100000,
            rate: 10,
            tenure: 12,
            startDate: DateTime.now(),
            nextDueDate: DateTime.now().add(const Duration(days: 5)),
          ),
        )
        .timeout(const Duration(seconds: 5));

    final summary = container.read(loanSummaryProvider);
    expect(summary.totalLoans, 1);
    expect(summary.activeLoans, 1);
    expect(summary.closedLoans, 0);
    expect(summary.outstandingBalance, 100000.0);
    expect(summary.totalEmiPerMonth, closeTo(8791.59, 0.5));
    expect(summary.nextEmiLoanName, 'Loan l5');
  });

  test(
    'buildLoanAnalytics computes loan-to-asset ratio and monthly EMI burden',
    () {
      final loan = _sampleLoan(
        id: 'l6',
        principal: 12000,
        rate: 0,
        tenure: 12,
        startDate: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 2, 1),
      );
      final wallets = [
        Wallet(
          id: 'w1',
          name: 'Cash',
          bankName: '',
          type: 'cash',
          openingBalance: 6000,
          currentBalance: 6000,
          createdAt: DateTime.now(),
        ),
      ];

      final analytics = buildLoanAnalytics(
        [loan],
        wallets,
        24000, // current month income
        DateTime(2026, 1, 15),
      );

      expect(analytics.loanToAssetRatio, closeTo(200.0, 0.01));
      expect(analytics.monthlyEmiBurden, 1000.0);
      expect(
        analytics.monthlyEmiBurdenPercentage,
        closeTo(1000 / 24000 * 100, 0.01),
      );
      expect(analytics.outstandingTrend, hasLength(analyticsTrendMonths));
    },
  );

  test('FinancialContextBuilder includes loan fields', () async {
    await LoanRepository.instance.add(
      _sampleLoan(
        id: 'l7',
        principal: 50000,
        rate: 10,
        tenure: 12,
        startDate: DateTime.now(),
        nextDueDate: DateTime.now().add(const Duration(days: 15)),
      ),
    );

    final context = await FinancialContextBuilder.instance.build();
    expect(context.totalLoanAmount, 50000.0);
    expect(context.outstandingLoanAmount, 50000.0);
    expect(context.activeLoanCount, 1);
    expect(context.monthlyLoanEmi, greaterThan(0));
    expect(context.totalInterestRemaining, greaterThan(0));
    expect(context.nextLoanPayment, contains('Loan l7'));
  });
}
