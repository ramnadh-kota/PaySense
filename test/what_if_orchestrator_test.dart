// Focused tests for WhatIfOrchestrator (PHASE 5/6/7/8/9/10/15/16) — Stage B
// entity resolution against real (synthetic, Hive-backed) financial data,
// wired to the existing calculators. Synthetic data only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/models/what_if_result.dart';
import 'package:paysense/features/ai/services/what_if_intent_parser.dart';
import 'package:paysense/features/ai/services/what_if_orchestrator.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

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
}

final _now = DateTime(2026, 8, 20);

Future<void> _seedIncomeExpense() async {
  await WalletRepository.instance.add(
    Wallet(
      id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
      openingBalance: 0, currentBalance: 100000, createdAt: DateTime(2026, 1, 1),
    ),
  );
  await TransactionRepository.instance.add(
    Transaction(
      id: 't1', title: 'Salary', amount: 50000, categoryId: 'Salary', accountId: 'w1',
      transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, 8, 1),
    ),
  );
  await TransactionRepository.instance.add(
    Transaction(
      id: 't2', title: 'Groceries', amount: 5000, categoryId: 'Food', accountId: 'w1',
      transactionType: 'Expense', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, 8, 5),
    ),
  );
  await TransactionRepository.instance.add(
    Transaction(
      id: 't3', title: 'Rent', amount: 15000, categoryId: 'Rent', accountId: 'w1',
      transactionType: 'Expense', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, 8, 3),
    ),
  );
}

Loan _loan({
  required String id,
  required String loanName,
  String loanType = 'Personal',
  double outstandingAmount = 100000,
  double emiAmount = 10000,
}) {
  return Loan(
    id: id, loanName: loanName, lenderName: 'Bank', loanType: loanType,
    principalAmount: 150000, interestRate: 10, tenureMonths: 15, emiAmount: emiAmount,
    outstandingAmount: outstandingAmount, paidAmount: 50000, accountId: 'w1',
    nextDueDate: DateTime(2026, 9, 1), startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2027, 4, 1), totalInterest: 15000, status: 'Active',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
  );
}

RecurringTransaction _subscription({
  required String id,
  required String title,
  double amount = 500,
}) {
  return RecurringTransaction(
    id: id, title: title, amount: amount, categoryId: 'Entertainment', accountId: 'w1',
    transactionType: 'Expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
    nextDueDate: DateTime(2026, 9, 1), isActive: true, reminderDaysBefore: 1, note: '',
    createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
  );
}

Goal _goal({
  required String id,
  required String title,
  double targetAmount = 100000,
  double currentAmount = 40000,
  DateTime? createdAt,
}) {
  return Goal(
    id: id, title: title, targetAmount: targetAmount, currentAmount: currentAmount,
    targetDate: DateTime(2027, 8, 1), category: 'Savings', icon: 'star', color: 0,
    createdAt: createdAt ?? DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    isCompleted: false,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_whatif_orch_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('11. Category exact matching', () {
    test('a single exact category match calculates immediately', () async {
      await _seedIncomeExpense();
      final intent = WhatIfIntentParser.parse('What if I spend 20% less on food?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.entityName, 'Food');
      expect(outcome.result!.type, WhatIfIntentType.reduceCategorySpending);
      expect(outcome.result!.difference, closeTo(1000, 0.01)); // 20% of ₹5,000
    });
  });

  group('12. Ambiguous category', () {
    test('two categories sharing the candidate substring ask for clarification', () async {
      await _seedIncomeExpense();
      await TransactionRepository.instance.add(
        Transaction(
          id: 't4', title: 'Fast Food', amount: 2000, categoryId: 'Fast Food', accountId: 'w1',
          transactionType: 'Expense', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, 8, 6),
        ),
      );
      final intent = WhatIfIntentParser.parse('What if I spend 20% less on food?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.clarification);
      expect(outcome.message, contains('Food'));
    });
  });

  group('13. Unknown category', () {
    test('a category with no matching spending data reports it honestly', () async {
      await _seedIncomeExpense();
      final intent = WhatIfIntentParser.parse('What if I spend 20% less on travel?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.notFound);
      expect(outcome.message, contains("don't have enough spending data"));
    });
  });

  group('15. Single-loan automatic selection', () {
    test('exactly one active loan is used without asking', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(_loan(id: 'l1', loanName: 'Car Loan'));
      final intent = WhatIfIntentParser.parse('What if I pay ₹20,000 extra toward my loan?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.entityName, 'Car Loan');
      expect(outcome.result!.projectedValue, 80000); // 100000 - 20000
    });
  });

  group('16. Multiple-loan clarification', () {
    test('more than one active loan with no name given asks which one', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(_loan(id: 'l1', loanName: 'Car Loan'));
      await LoanRepository.instance.add(_loan(id: 'l2', loanName: 'Home Loan'));
      final intent = WhatIfIntentParser.parse('What if I pay ₹20,000 extra toward my loan?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.clarification);
      expect(outcome.message, allOf(contains('Car Loan'), contains('Home Loan')));
    });
  });

  group('17. Named loan selection', () {
    test('an explicitly named loan is matched against the real record, not guessed', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(_loan(id: 'l1', loanName: 'Car Loan', loanType: 'Auto'));
      await LoanRepository.instance.add(_loan(id: 'l2', loanName: 'Personal Loan', loanType: 'Personal'));
      final intent = WhatIfIntentParser.parse(
        'What if I pay ₹20,000 extra toward my personal loan?',
      );
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.entityName, 'Personal Loan');
    });
  });

  group('18. Subscription cancellation simulation', () {
    test('a named, matched subscription produces a monthly-savings-freed result', () async {
      await _seedIncomeExpense();
      await _seedIncompleteGoalForProjection();
      await RecurringTransactionRepository.instance.add(
        _subscription(id: 'r1', title: 'Netflix', amount: 500),
      );
      final intent = WhatIfIntentParser.parse('What if I stop Netflix?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.monthlyChange, 500);
      expect(outcome.result!.entityName, contains('Netflix'));
    });
  });

  group('19. Unknown subscription', () {
    test('a subscription name that matches nothing is reported honestly, never fabricated', () async {
      await _seedIncomeExpense();
      await RecurringTransactionRepository.instance.add(
        _subscription(id: 'r1', title: 'Netflix', amount: 500),
      );
      final intent = WhatIfIntentParser.parse('What if I stop Spotify?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.notFound);
      expect(outcome.message, contains('spotify'));
    });
  });

  group('20. Goal projection', () {
    test('a named goal that exists is used, never a fabricated one', () async {
      await _seedIncomeExpense();
      await GoalRepository.instance.add(
        _goal(id: 'g1', title: 'Vacation', currentAmount: 40000, createdAt: DateTime(2026, 2, 1)),
      );
      final intent = WhatIfIntentParser.parse('When will I reach my vacation goal?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.entityName, 'Vacation');
      expect(outcome.result!.type, WhatIfIntentType.reachGoal);
    });

    test('no named goal but a target amount is a pure hypothetical, never touching a real goal', () async {
      await _seedIncomeExpense();
      final intent = WhatIfIntentParser.parse('When will I reach ₹2 lakh?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.entityName, isNull);
      expect(outcome.result!.projectedValue, 200000);
      // ₹200,000 at ₹30,000/month savings = ceil(200000/30000) = 7 months.
      expect(outcome.result!.monthsAfter, 7);
    });
  });

  group('21. Emergency fund projection', () {
    test('a configured emergency fund reports its real current trajectory', () async {
      await _seedIncomeExpense();
      await AppSettingsRepository.instance.setEmergencyFundEligibleWalletIds(['w1']);
      final intent = WhatIfIntentParser.parse('When will I complete my emergency fund?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.type, WhatIfIntentType.reachEmergencyFund);
      expect(outcome.result!.currentValue, 100000); // wallet balance
    });

    test('an unconfigured emergency fund is reported honestly, not fabricated', () async {
      await _seedIncomeExpense();
      final intent = WhatIfIntentParser.parse('When will I complete my emergency fund?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.notFound);
    });
  });

  group('24. WhatIfResult correctness', () {
    test('an extra loan payment produces exact, deterministic before/after figures', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(
        _loan(id: 'l1', loanName: 'Car Loan', outstandingAmount: 100000, emiAmount: 10000),
      );
      final intent = WhatIfIntentParser.parse('What if I pay ₹20,000 extra toward my loan?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      final result = outcome.result!;
      expect(result.currentValue, 100000);
      expect(result.projectedValue, 80000);
      expect(result.difference, -20000);
      expect(result.monthsBefore, 10); // 100000/10000
      expect(result.monthsAfter, 8); // 80000/10000
    });
  });

  group('31. No NaN in what-if scenarios', () {
    test('zero-income data never produces a NaN result', () async {
      await WalletRepository.instance.add(
        Wallet(
          id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
          openingBalance: 0, currentBalance: 0, createdAt: DateTime(2026, 1, 1),
        ),
      );
      final intent = WhatIfIntentParser.parse('What if I save ₹5,000 more every month?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.currentValue.isNaN, isFalse);
      expect(outcome.result!.projectedValue.isNaN, isFalse);
    });
  });

  group('32. No Infinity in what-if scenarios', () {
    test('a loan with a zero EMI never produces an Infinity/garbage months figure', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(
        _loan(id: 'l1', loanName: 'Car Loan', outstandingAmount: 50000, emiAmount: 0),
      );
      final intent = WhatIfIntentParser.parse('What if I pay ₹10,000 extra toward my loan?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, WhatIfOutcomeKind.calculated);
      expect(outcome.result!.monthsBefore, isNull); // never a fabricated/Infinity month count
      expect(outcome.result!.monthsAfter, isNull);
      expect(outcome.result!.projectedValue.isInfinite, isFalse);
      expect(outcome.result!.projectedValue, 40000);
    });
  });

  group('33. Impossible scenario handling', () {
    test('an extra loan payment larger than the outstanding balance clamps to zero, never negative', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(
        _loan(id: 'l1', loanName: 'Car Loan', outstandingAmount: 15000, emiAmount: 10000),
      );
      final intent = WhatIfIntentParser.parse('What if I pay ₹50,000 extra toward my loan?');
      final outcome = await WhatIfOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.result!.projectedValue, 0);
      expect(outcome.result!.projectedValue, greaterThanOrEqualTo(0));
      expect(outcome.result!.monthsAfter, 0);
    });
  });

  group('25-30. No mutation of real financial data', () {
    test('resolving any what-if scenario never writes to wallets/transactions/goals/loans/subscriptions', () async {
      await _seedIncomeExpense();
      await LoanRepository.instance.add(_loan(id: 'l1', loanName: 'Car Loan'));
      await GoalRepository.instance.add(_goal(id: 'g1', title: 'Vacation'));
      await RecurringTransactionRepository.instance.add(_subscription(id: 'r1', title: 'Netflix'));

      final walletBefore = (await WalletRepository.instance.getById('w1'))!.currentBalance;
      final transactionCountBefore = (await TransactionRepository.instance.getAll()).length;
      final budgetCountBefore = (await BudgetRepository.instance.getAll()).length;
      final goalBefore = (await GoalRepository.instance.getById('g1'))!;
      final loanBefore = (await LoanRepository.instance.getById('l1'))!;
      final subscriptionBefore = (await RecurringTransactionRepository.instance.getById('r1'))!;

      // Run every scenario type that resolves successfully — none should
      // mutate anything, regardless of outcome kind.
      for (final question in [
        'What if I save ₹5,000 more every month?',
        'What if I pay ₹20,000 extra toward my loan?',
        'What if I stop Netflix?',
        'When will I reach my vacation goal?',
        'What if I spend 20% less on food?',
      ]) {
        await WhatIfOrchestrator.instance.resolve(WhatIfIntentParser.parse(question), now: _now);
      }

      final walletAfter = (await WalletRepository.instance.getById('w1'))!.currentBalance;
      final transactionCountAfter = (await TransactionRepository.instance.getAll()).length;
      final budgetCountAfter = (await BudgetRepository.instance.getAll()).length;
      final goalAfter = (await GoalRepository.instance.getById('g1'))!;
      final loanAfter = (await LoanRepository.instance.getById('l1'))!;
      final subscriptionAfter = (await RecurringTransactionRepository.instance.getById('r1'))!;

      expect(walletAfter, walletBefore);
      expect(transactionCountAfter, transactionCountBefore);
      expect(budgetCountAfter, budgetCountBefore);
      expect(goalAfter.currentAmount, goalBefore.currentAmount);
      expect(goalAfter.targetAmount, goalBefore.targetAmount);
      expect(loanAfter.outstandingAmount, loanBefore.outstandingAmount);
      expect(loanAfter.status, loanBefore.status);
      expect(subscriptionAfter.isActive, subscriptionBefore.isActive);
    });
  });
}

Future<void> _seedIncompleteGoalForProjection() async {
  await GoalRepository.instance.add(
    Goal(
      id: 'gproj', title: 'Vacation', targetAmount: 100000, currentAmount: 10000,
      targetDate: DateTime(2027, 8, 1), category: 'Savings', icon: 'star', color: 0,
      createdAt: DateTime(2026, 2, 1), updatedAt: DateTime(2026, 2, 1), isCompleted: false,
    ),
  );
}
