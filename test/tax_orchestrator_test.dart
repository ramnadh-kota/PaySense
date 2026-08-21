// Focused tests for TaxOrchestrator (PHASE 10/11/12/19) — Stage B
// resolution against real (synthetic, Hive-backed) income/profile data,
// wired to TaxCalculator. Synthetic data only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/models/tax_outcome.dart';
import 'package:paysense/features/ai/services/tax_intent_parser.dart';
import 'package:paysense/features/ai/services/tax_orchestrator.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/tax_settings_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';

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
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(SmsReviewItemAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(TaxSettingsAdapter());

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
  await Hive.openBox<SmsReviewItem>('sms_review_items');
  await Hive.openBox('sms_processed_fingerprints');
  await Hive.openBox<TaxSettings>('tax_settings');
}

final _now = DateTime(2026, 8, 20);

Future<void> _seedIncome() async {
  await WalletRepository.instance.add(
    Wallet(
      id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
      openingBalance: 0, currentBalance: 100000, createdAt: DateTime(2026, 1, 1),
    ),
  );
  for (final month in [4, 5, 6, 7, 8]) {
    await TransactionRepository.instance.add(
      Transaction(
        id: 't$month', title: 'Salary', amount: 100000, categoryId: 'Salary', accountId: 'w1',
        transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, month, 5),
      ),
    );
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_tax_orch_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('21. Missing information / no income', () {
    test('no income data at all and no saved profile reports it honestly, never fabricates a figure', () async {
      final intent = TaxIntentParser.parse('How much tax will I pay?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.notFound);
      expect(outcome.message, contains('annual income'));
    });
  });

  group('PHASE 12 progressive clarification', () {
    test('a bare estimate question with income history but no saved profile asks which regime', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('How much tax will I pay?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.clarification);
      expect(outcome.message, contains('New Regime'));
      expect(outcome.message, contains('Old Regime'));
    });

    test('naming "new regime" explicitly skips the clarification and calculates directly', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('How much tax will I pay under the new regime?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.calculated);
      expect(outcome.result!.regime, TaxRegime.newRegime);
    });

    test('a saved profile skips the clarification even without an explicit regime in the question', () async {
      await _seedIncome();
      await TaxSettingsRepository.instance.save(
        TaxSettings.fromTaxProfile(
          const TaxProfile(annualGrossIncome: 1500000, regime: TaxRegime.old),
        ),
      );
      final intent = TaxIntentParser.parse('How much tax will I pay?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.calculated);
      expect(outcome.result!.regime, TaxRegime.old);
      expect(outcome.result!.grossIncome, 1500000); // the SAVED income, not the PaySense estimate
    });
  });

  group('19. Old vs New comparison (orchestrator)', () {
    test('"compare old and new regime" always returns both, regardless of any saved regime', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('Compare old and new regime');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.comparison);
      expect(outcome.comparison!.oldRegime.regime, TaxRegime.old);
      expect(outcome.comparison!.newRegime.regime, TaxRegime.newRegime);
    });
  });

  group('18. Monthly tax provision (orchestrator)', () {
    test('resolves using the estimated income when no profile is saved', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('How much tax should I keep aside every month?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.calculated);
      expect(outcome.result!.monthlyTaxProvision, greaterThanOrEqualTo(0));
    });
  });

  group('20. Tax What-If', () {
    test('salary what-if with an amount computes a before/after pair', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('What if my salary becomes ₹15 lakh?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.calculated);
      expect(outcome.result!.grossIncome, 1500000);
      expect(outcome.beforeResult, isNotNull);
      expect(outcome.entityLabel, 'Salary change');
    });

    test('80C what-if forces the old regime, where the deduction actually applies', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('What if I invest ₹1.5 lakh under 80C?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.calculated);
      expect(outcome.result!.regime, TaxRegime.old);
      expect(outcome.result!.totalDeductions, greaterThanOrEqualTo(150000));
      expect(outcome.beforeResult!.totalDeductions, lessThan(outcome.result!.totalDeductions));
    });

    test('a what-if with no amount asks a direct clarification', () async {
      await _seedIncome();
      final intent = TaxIntentParser.parse('What if I invest under 80C?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, TaxOutcomeKind.clarification);
      expect(outcome.message, contains('80C'));
    });
  });

  group('34. Empty state (orchestrator)', () {
    test('normal, non-tax questions never reach the orchestrator with an actionable intent', () async {
      final intent = TaxIntentParser.parse('Why did my expenses increase?');
      final outcome = await TaxOrchestrator.instance.resolve(intent, now: _now);
      expect(outcome.kind, TaxOutcomeKind.none);
    });
  });

  group('28-32. No mutation of real financial data', () {
    test('resolving tax scenarios never writes to wallets/transactions/goals/loans/budgets', () async {
      await _seedIncome();
      await GoalRepository.instance.add(
        Goal(
          id: 'g1', title: 'Vacation', targetAmount: 100000, currentAmount: 40000,
          targetDate: DateTime(2027, 8, 1), category: 'Savings', icon: 'star', color: 0,
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1), isCompleted: false,
        ),
      );
      await LoanRepository.instance.add(
        Loan(
          id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Auto',
          principalAmount: 150000, interestRate: 10, tenureMonths: 15, emiAmount: 10000,
          outstandingAmount: 100000, paidAmount: 50000, accountId: 'w1',
          nextDueDate: DateTime(2026, 9, 1), startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2027, 4, 1), totalInterest: 15000, status: 'Active',
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final walletBefore = (await WalletRepository.instance.getById('w1'))!.currentBalance;
      final transactionCountBefore = (await TransactionRepository.instance.getAll()).length;
      final budgetCountBefore = (await BudgetRepository.instance.getAll()).length;
      final goalBefore = (await GoalRepository.instance.getById('g1'))!;
      final loanBefore = (await LoanRepository.instance.getById('l1'))!;

      for (final question in [
        'How much tax will I pay?',
        'Compare old and new regime',
        'What if my salary becomes ₹15 lakh?',
        'What if I invest ₹1.5 lakh under 80C?',
        'How much tax should I keep aside?',
      ]) {
        await TaxOrchestrator.instance.resolve(TaxIntentParser.parse(question), now: _now);
      }

      expect((await WalletRepository.instance.getById('w1'))!.currentBalance, walletBefore);
      expect((await TransactionRepository.instance.getAll()).length, transactionCountBefore);
      expect((await BudgetRepository.instance.getAll()).length, budgetCountBefore);
      final goalAfter = (await GoalRepository.instance.getById('g1'))!;
      expect(goalAfter.currentAmount, goalBefore.currentAmount);
      final loanAfter = (await LoanRepository.instance.getById('l1'))!;
      expect(loanAfter.outstandingAmount, loanBefore.outstandingAmount);
    });
  });
}
