// Focused tests for FinancialContextBuilder — the "existing calculators ->
// FinancialContext -> AI service" bridge for AI Financial Assistant 2.0.
// Verifies the new aggregated sections are populated from existing
// calculators (never re-derived), and — critically — that no raw SMS,
// phone number, or account/card number ever appears anywhere in the
// serialized context. Synthetic data only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/ai_question_router.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
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
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';

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
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SmsReviewItemAdapter());
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
  await Hive.openBox<SmsReviewItem>('sms_review_items');
  await Hive.openBox('sms_processed_fingerprints');
}

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id,
    name: id,
    bankName: 'Test Bank',
    type: 'Bank',
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
}

Transaction _transaction(String id, double amount, String type, {DateTime? createdAt}) {
  return Transaction(
    id: id,
    title: 'Test $type',
    amount: amount,
    categoryId: 'Groceries',
    accountId: 'w1',
    transactionType: type,
    paymentMethod: 'bank',
    note: '',
    createdAt: createdAt ?? DateTime.now(),
  );
}

Goal _goal(String id, double target, double current) {
  return Goal.create(
    id: id,
    title: id,
    targetAmount: target,
    currentAmount: current,
    targetDate: DateTime.now().add(const Duration(days: 180)),
    category: 'Other',
    icon: 'savings',
    color: 0xFF000000,
    createdAt: DateTime.now().subtract(const Duration(days: 60)),
  );
}

Loan _loan(String id, double outstanding, double emi, double rate) {
  final loan = Loan.create(
    id: id,
    loanName: id,
    lenderName: 'Bank',
    loanType: 'Personal',
    principalAmount: outstanding + 20000,
    interestRate: rate,
    tenureMonths: 24,
    emiAmount: emi,
    totalInterest: 5000,
    accountId: 'w1',
    startDate: DateTime(2026, 1, 1),
    nextDueDate: DateTime.now().add(const Duration(days: 10)),
    createdAt: DateTime(2026, 1, 1),
  );
  return loan.copyWith(outstandingAmount: outstanding);
}

Bill _bill(String id, double amount, {bool paid = false}) {
  final bill = Bill.create(
    id: id,
    title: id,
    amount: amount,
    categoryId: 'Utilities',
    accountId: 'w1',
    dueDate: DateTime.now().add(const Duration(days: 5)),
    createdAt: DateTime.now(),
  );
  return paid ? bill.markPaid(DateTime.now()) : bill;
}

RecurringTransaction _subscription(String id, double amount) {
  return RecurringTransaction.create(
    id: id,
    title: id,
    amount: amount,
    categoryId: 'Entertainment',
    accountId: 'w1',
    transactionType: 'expense',
    frequency: 'Monthly',
    startDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ).copyWith(nextDueDate: DateTime.now().add(const Duration(days: 15)));
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_ai_context_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1-8. Financial context section inclusion', () {
    test('1. includes the Financial Planning result', () async {
      await WalletRepository.instance.add(_wallet('w1', 100000));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.planningContext, isNotEmpty);
      expect(context.planningContext['readinessScore'], isA<int>());
    });

    test('2. includes Safe-to-Spend', () async {
      await WalletRepository.instance.add(_wallet('w1', 50000));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.safeToSpendContext, isNotEmpty);
      expect(context.safeToSpendContext['availableMoney'], 50000);
    });

    test('3. includes Budget (existing flat fields)', () async {
      final context = await FinancialContextBuilder.instance.build();
      expect(context.toMap().containsKey('totalBudget'), isTrue);
      expect(context.toMap().containsKey('budgetUsagePercentage'), isTrue);
    });

    test('4. includes Goals', () async {
      await GoalRepository.instance.add(_goal('Vacation', 100000, 40000));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.totalGoals, 1);
      expect(context.nearestGoal, 'Vacation');
      expect(context.planningContext, isNotEmpty);
    });

    test('5. includes Loans', () async {
      await LoanRepository.instance.add(_loan('CarLoan', 80000, 5000, 9.5));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.activeLoanCount, 1);
      expect(context.outstandingLoanAmount, 80000);
      expect(context.planningContext['totalDebt'], 80000);
    });

    test('6. includes Bills', () async {
      await BillRepository.instance.add(_bill('Electricity', 1200));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.totalBills, 1);
      expect(context.unpaidBills, 1);
    });

    test('7. includes Subscriptions', () async {
      await RecurringTransactionRepository.instance.add(_subscription('Netflix', 500));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.subscriptionsContext, isNotEmpty);
      expect(context.subscriptionsContext['activeCount'], 1);
      expect(context.subscriptionsContext['totalMonthlyCost'], 500);
    });

    test('8. includes Cash Flow', () async {
      await BillRepository.instance.add(_bill('Rent', 15000));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.cashFlowContext, isNotEmpty);
      expect(context.cashFlowContext['hasActivity'], isTrue);
    });
  });

  group('9-11. Privacy — never sent to the AI backend', () {
    test('9. excludes raw SMS content — no such field exists anywhere in the payload', () async {
      await WalletRepository.instance.add(_wallet('w1', 10000));
      await TransactionRepository.instance.add(_transaction('t1', 500, 'expense'));
      final context = await FinancialContextBuilder.instance.build();
      final serialized = jsonEncode(context.toMap()).toLowerCase();
      expect(serialized.contains('smsbody'), isFalse);
      expect(serialized.contains('sms_body'), isFalse);
      expect(serialized.contains('rawsms'), isFalse);
    });

    test('10. excludes phone numbers — no phone field exists anywhere in the payload', () async {
      final context = await FinancialContextBuilder.instance.build();
      final keys = _allKeysRecursive(context.toMap());
      expect(keys.any((k) => k.toLowerCase().contains('phone')), isFalse);
    });

    test('11. excludes account/card numbers — Wallet has no such field to leak', () async {
      await WalletRepository.instance.add(_wallet('w1', 10000));
      final context = await FinancialContextBuilder.instance.build();
      final keys = _allKeysRecursive(context.toMap());
      expect(keys.any((k) => k.toLowerCase().contains('accountnumber')), isFalse);
      expect(keys.any((k) => k.toLowerCase().contains('cardnumber')), isFalse);
      expect(keys.any((k) => k.toLowerCase().contains('ifsc')), isFalse);
    });
  });

  group('12. Zero-income context', () {
    test('never produces NaN/Infinity when there is no income data', () async {
      await WalletRepository.instance.add(_wallet('w1', 5000));
      await LoanRepository.instance.add(_loan('l1', 40000, 3000, 10));
      final context = await FinancialContextBuilder.instance.build();
      expect(context.planningContext['savingsRatePercent'], isNull);
      expect(context.planningContext['emiToIncomePercent'], isNull);
      final serialized = jsonEncode(context.toMap());
      expect(serialized.contains('NaN'), isFalse);
      expect(serialized.contains('Infinity'), isFalse);
    });
  });

  group('13. Empty financial context', () {
    test('a brand-new account with nothing recorded never crashes', () async {
      final context = await FinancialContextBuilder.instance.build();
      expect(context.totalGoals, 0);
      expect(context.totalBills, 0);
      expect(context.activeLoanCount, 0);
      expect(context.planningContext['hasSufficientData'], isFalse);
      // Still JSON-serializable end to end, matching what ai_provider.dart
      // actually sends.
      expect(() => jsonEncode(context.toMap()), returnsNormally);
    });
  });

  group('14-19. Question-category-driven context trimming', () {
    test('14. a Financial Planning question includes planningContext', () async {
      await WalletRepository.instance.add(_wallet('w1', 10000));
      final categories = classifyQuestion("What should I do with my next salary?");
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      expect(context.planningContext, isNotEmpty);
    });

    test('15. a Budget question includes reportsContext (spending breakdown)', () async {
      await TransactionRepository.instance.add(_transaction('t1', 500, 'expense'));
      final categories = classifyQuestion('Am I overspending my budget?');
      expect(categories, contains(FinancialQuestionCategory.budget));
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      expect(context.reportsContext, isNotEmpty);
    });

    test('16. a savings question includes planningContext', () async {
      final categories = classifyQuestion('How much should I save every month?');
      expect(categories, contains(FinancialQuestionCategory.savings));
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      expect(context.planningContext, isNotEmpty);
    });

    test('17. a debt question includes planningContext (debt burden)', () async {
      await LoanRepository.instance.add(_loan('l1', 40000, 3000, 10));
      final categories = classifyQuestion('How can I pay off my loans faster?');
      expect(categories, contains(FinancialQuestionCategory.debt));
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      expect(context.planningContext['totalDebt'], 40000);
    });

    test('18. a goal question includes planningContext (goal projections)', () async {
      await GoalRepository.instance.add(_goal('Vacation', 100000, 40000));
      final categories = classifyQuestion('Am I on track for my goals?');
      expect(categories, contains(FinancialQuestionCategory.goals));
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      expect(context.planningContext, isNotEmpty);
    });

    test('19. a safe-to-spend question includes safeToSpendContext and cashFlowContext', () async {
      await WalletRepository.instance.add(_wallet('w1', 20000));
      final categories = classifyQuestion('How much can I safely spend this month?');
      expect(categories, contains(FinancialQuestionCategory.safeToSpend));
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      expect(context.safeToSpendContext, isNotEmpty);
      expect(context.cashFlowContext, isNotEmpty);
    });

    test('an unrelated question category leaves an unrequested section empty', () async {
      await GoalRepository.instance.add(_goal('Vacation', 100000, 40000));
      final categories = <FinancialQuestionCategory>{FinancialQuestionCategory.bills};
      final context = await FinancialContextBuilder.instance.build(relevantCategories: categories);
      // Bills-only routing should not pull in the goals/planning-only
      // aggregated section — the always-present flat goal fields are
      // untouched by trimming, but the new nested map is.
      expect(context.planningContext, isEmpty);
    });
  });
}

/// Recursively collects every map key in [value], for asserting the
/// absence of a field name anywhere in a nested structure.
List<String> _allKeysRecursive(dynamic value) {
  final keys = <String>[];
  if (value is Map) {
    for (final entry in value.entries) {
      keys.add(entry.key.toString());
      keys.addAll(_allKeysRecursive(entry.value));
    }
  } else if (value is List) {
    for (final item in value) {
      keys.addAll(_allKeysRecursive(item));
    }
  }
  return keys;
}
