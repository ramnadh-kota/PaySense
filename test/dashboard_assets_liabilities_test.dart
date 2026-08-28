// BUG FIX regression tests: Dashboard Total Assets / Total Liabilities /
// Net Worth previously showed hardcoded strings ('₹1,68,000'/'₹43,440')
// that never reflected real data. The fix reuses FinancialOverview — the
// SAME already-computed net-worth source of truth
// FinancialPlanningCalculator produces — rather than a second calculation.
// Assets = sum of non-archived wallet balances, Liabilities = sum of
// active loans' outstanding balances, Net Worth = Assets - Liabilities.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';

final _now = DateTime(2026, 8, 20);

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: balance, currentBalance: balance, createdAt: DateTime(2025, 1, 1),
  );
}

Loan _loan(String id, {required double outstanding, double emiAmount = 5000}) {
  final loan = Loan.create(
    id: id, loanName: id, lenderName: 'Bank', loanType: 'Personal',
    principalAmount: outstanding + 20000, interestRate: 10, tenureMonths: 24, emiAmount: emiAmount,
    totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1),
    nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1),
  );
  return loan.copyWith(outstandingAmount: outstanding);
}

Transaction _tx({required double amount, required String type}) {
  return Transaction(
    id: 't-${amount}_$type', title: type, amount: amount, categoryId: 'Other', accountId: 'w1',
    transactionType: type, paymentMethod: 'Bank', note: '', createdAt: _now,
  );
}

FinancialPlanningResult _calc({
  List<Wallet> wallets = const [],
  List<Loan> loans = const [],
  List<Transaction> transactions = const [],
}) {
  return FinancialPlanningCalculator.calculate(
    transactions: transactions,
    wallets: wallets,
    goals: const <Goal>[],
    loans: loans,
    bills: const <Bill>[],
    recurringTransactions: const <RecurringTransaction>[],
    analytics: buildAnalyticsSummary(transactions, _now),
    now: _now,
  );
}

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
  // LoansNotifier._rescheduleReminders writes through NotificationRepository
  // on every add/update — this box must be open for loan mutation tests
  // (see the "Provider reactivity" group below) or the write throws.
  await Hive.openBox<AppNotification>('app_notifications');
}

void main() {
  group('Pure formula — FinancialOverview.totalAssets/totalDebt/netWorth', () {
    test('1. a single ₹10,000 wallet → Assets ₹10,000', () {
      final result = _calc(wallets: [_wallet('w1', 10000)]);
      expect(result.overview.totalAssets, 10000);
    });

    test('2. wallet balance ₹10,000 → ₹15,000 → Assets ₹15,000', () {
      final before = _calc(wallets: [_wallet('w1', 10000)]);
      final after = _calc(wallets: [_wallet('w1', 15000)]);
      expect(before.overview.totalAssets, 10000);
      expect(after.overview.totalAssets, 15000);
    });

    test('3. wallet balance ₹15,000 → ₹7,000 → Assets ₹7,000', () {
      final before = _calc(wallets: [_wallet('w1', 15000)]);
      final after = _calc(wallets: [_wallet('w1', 7000)]);
      expect(before.overview.totalAssets, 15000);
      expect(after.overview.totalAssets, 7000);
    });

    test('4. a single ₹50,000 outstanding loan → Liabilities ₹50,000', () {
      final result = _calc(loans: [_loan('l1', outstanding: 50000)]);
      expect(result.overview.totalDebt, 50000);
    });

    test('5. loan outstanding ₹50,000 → ₹35,000 → Liabilities ₹35,000', () {
      final before = _calc(loans: [_loan('l1', outstanding: 50000)]);
      final after = _calc(loans: [_loan('l1', outstanding: 35000)]);
      expect(before.overview.totalDebt, 50000);
      expect(after.overview.totalDebt, 35000);
    });

    test('6. a paid-off (Closed) loan contributes ₹0 to Liabilities', () {
      final activeLoan = _loan('l1', outstanding: 50000);
      final closedLoan = activeLoan.copyWith(outstandingAmount: 0, status: 'Closed');
      final result = _calc(loans: [closedLoan]);
      expect(result.overview.totalDebt, 0);
    });

    test('7. Assets ₹1,00,000 + Liability ₹40,000 → Net Worth ₹60,000', () {
      final result = _calc(
        wallets: [_wallet('w1', 100000)],
        loans: [_loan('l1', outstanding: 40000)],
      );
      expect(result.overview.totalAssets, 100000);
      expect(result.overview.totalDebt, 40000);
      expect(result.overview.netWorth, 60000);
    });

    test('8. multiple wallets sum correctly', () {
      final result = _calc(wallets: [_wallet('w1', 10000), _wallet('w2', 25000), _wallet('w3', 500)]);
      expect(result.overview.totalAssets, 35500);
    });

    test('9. multiple loans sum correctly', () {
      final result = _calc(loans: [
        _loan('l1', outstanding: 20000),
        _loan('l2', outstanding: 15000),
        _loan('l3', outstanding: 5000),
      ]);
      expect(result.overview.totalDebt, 40000);
    });

    test('10. an empty account → Assets ₹0 / Liabilities ₹0 / Net Worth ₹0', () {
      final result = _calc();
      expect(result.overview.totalAssets, 0);
      expect(result.overview.totalDebt, 0);
      expect(result.overview.netWorth, 0);
    });

    test('13. no double counting: transactions and EMI amount never inflate assets/liabilities', () {
      final result = _calc(
        wallets: [_wallet('w1', 10000)],
        loans: [_loan('l1', outstanding: 50000, emiAmount: 5000)],
        transactions: [_tx(amount: 5000, type: 'income'), _tx(amount: 2000, type: 'expense')],
      );
      // Assets come only from wallet.currentBalance — income transactions
      // are never separately added on top.
      expect(result.overview.totalAssets, 10000);
      // Liabilities come only from outstandingAmount — the EMI amount
      // itself is never added as an additional liability.
      expect(result.overview.totalDebt, 50000);
    });

    test('an archived wallet is excluded from Assets', () {
      final archived = _wallet('w1', 10000).copyWith(isArchived: true);
      final result = _calc(wallets: [archived, _wallet('w2', 5000)]);
      expect(result.overview.totalAssets, 5000);
    });
  });

  group('11/12. Provider reactivity — wallet/loan mutation refreshes financialPlanningProvider', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paysense_assets_liabilities_test');
      await _initHive(tempDir);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('11. a wallet balance mutation is reflected in financialPlanningProvider.overview.totalAssets '
        'without requiring app restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final wallet = _wallet('w1', 10000);
      await WalletRepository.instance.add(wallet);
      await container.read(walletsProvider.future);

      final before = container.read(financialPlanningProvider);
      expect(before.overview.totalAssets, 10000);

      await WalletRepository.instance.update(wallet.copyWith(currentBalance: 15000));
      await container.read(walletsProvider.notifier).reload();

      final after = container.read(financialPlanningProvider);
      expect(after.overview.totalAssets, 15000);
    });

    test('12. a loan payoff mutation is reflected in financialPlanningProvider.overview.totalDebt '
        'without requiring app restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final loan = _loan('l1', outstanding: 50000);
      await LoanRepository.instance.add(loan);
      await container.read(loansProvider.future);

      final before = container.read(financialPlanningProvider);
      expect(before.overview.totalDebt, 50000);

      await LoanRepository.instance.update(loan.copyWith(outstandingAmount: 0, status: 'Closed'));
      await container.read(loansProvider.notifier).reload();

      final after = container.read(financialPlanningProvider);
      expect(after.overview.totalDebt, 0);
    });
  });

  group('14. Dashboard and Financial Planning share the same definition', () {
    test('the Dashboard reads Assets/Liabilities/Net Worth from planning.overview, never a duplicate '
        'calculation or a hardcoded string', () async {
      final source = await File('lib/features/dashboard/dashboard_screen.dart').readAsString();
      expect(source.contains('planning.overview.totalAssets'), isTrue);
      expect(source.contains('planning.overview.totalDebt'), isTrue);
      expect(source.contains('planning.overview.netWorth'), isTrue);
      // The old hardcoded literals must be gone.
      expect(source.contains("'₹1,68,000'"), isFalse);
      expect(source.contains("'₹43,440'"), isFalse);
    });
  });
}
