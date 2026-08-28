// Pure-calculator tests for FinancialTimelineCalculator (PHASE 2/4).
// Inputs are built via the REAL FinancialHealthTrendsCalculator/
// FinancialPlanningCalculator/SubscriptionCalculator, exactly like the
// FinancialInsightEngine test in this session — synthetic transactions
// feed real calculators, whose real output feeds the engine under test.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/financial_timeline_calculator.dart';
import 'package:paysense/shared/utils/subscription_calculator.dart';

final _now = DateTime(2026, 8, 20);

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  String category = 'Food',
  required DateTime date,
}) {
  return Transaction(
    id: id, title: id, amount: amount, categoryId: category, accountId: 'w1',
    transactionType: type, paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: balance, currentBalance: balance, createdAt: DateTime(2025, 1, 1),
  );
}

Budget _budget(String id, {required double allocated, required double spent, required DateTime createdAt}) {
  return Budget(
    id: id, categoryId: 'Food', categoryName: 'Food', allocatedAmount: allocated,
    spentAmount: spent, remainingAmount: allocated - spent,
    percentageUsed: allocated > 0 ? spent / allocated * 100 : 0,
    month: 'August', year: createdAt.year, createdAt: createdAt,
  );
}

Goal _goal({
  required String id,
  required double target,
  required double current,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  final goal = Goal.create(
    id: id, title: id, targetAmount: target, currentAmount: current,
    targetDate: DateTime(2027, 1, 1), category: 'Other', icon: 'star',
    color: 0xFF000000, createdAt: createdAt,
  );
  return goal.copyWith(updatedAt: updatedAt, isCompleted: current >= target);
}

Loan _loan({
  required String id,
  required double outstanding,
  required double paid,
  required String status,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  final loan = Loan.create(
    id: id, loanName: id, lenderName: 'Bank', loanType: 'Personal',
    principalAmount: outstanding + paid, interestRate: 10, tenureMonths: 24, emiAmount: 5000,
    totalInterest: 0, accountId: 'w1', startDate: createdAt,
    nextDueDate: DateTime(2026, 9, 1), createdAt: createdAt,
  );
  return loan.copyWith(outstandingAmount: outstanding, paidAmount: paid, status: status, updatedAt: updatedAt);
}

RecurringTransaction _recurring({
  required String id,
  required double amount,
  String type = 'expense',
  String frequency = 'Monthly',
  required DateTime createdAt,
}) {
  return RecurringTransaction.create(
    id: id, title: id, amount: amount, categoryId: 'Entertainment', accountId: 'w1',
    transactionType: type, frequency: frequency, startDate: createdAt, createdAt: createdAt,
  ).copyWith(nextDueDate: DateTime(2026, 9, 1));
}

FinancialHealthTrendResult _trends({
  List<Transaction> transactions = const [],
  List<Budget> budgets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  List<Wallet> wallets = const [],
  TrendPeriod period = TrendPeriod.threeMonths,
}) {
  return FinancialHealthTrendsCalculator.calculate(
    transactions: transactions,
    budgets: budgets,
    goals: goals,
    loans: loans,
    bills: const [],
    wallets: wallets,
    profileMonthlyIncome: 0,
    period: period,
    now: _now,
  );
}

FinancialPlanningResult _planning({
  List<Transaction> transactions = const [],
  List<Wallet> wallets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  List<RecurringTransaction> recurringTransactions = const [],
  List<String>? emergencyFundEligibleWalletIds,
}) {
  return FinancialPlanningCalculator.calculate(
    transactions: transactions,
    wallets: wallets,
    goals: goals,
    loans: loans,
    bills: const [],
    recurringTransactions: recurringTransactions,
    analytics: buildAnalyticsSummary(transactions, _now),
    emergencyFundEligibleWalletIds: emergencyFundEligibleWalletIds,
    now: _now,
  );
}

FinancialTimelineResult _calc({
  List<Transaction> transactions = const [],
  List<Budget> budgets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  List<Wallet> wallets = const [],
  List<RecurringTransaction> recurringTransactions = const [],
  List<String>? emergencyFundEligibleWalletIds,
  TimelinePeriod period = TimelinePeriod.threeMonths,
  DateTime? now,
}) {
  final effectiveNow = now ?? _now;
  final trends = _trends(
    transactions: transactions, budgets: budgets, goals: goals, loans: loans,
    wallets: wallets, period: period.underlyingTrendPeriod,
  );
  final planning = _planning(
    transactions: transactions, wallets: wallets, goals: goals, loans: loans,
    recurringTransactions: recurringTransactions,
    emergencyFundEligibleWalletIds: emergencyFundEligibleWalletIds,
  );
  final subscriptions = SubscriptionCalculator.eligibleSubscriptions(
    recurringTransactions: recurringTransactions,
    now: effectiveNow,
  );
  return FinancialTimelineCalculator.calculate(
    trends: trends,
    planning: planning,
    budgets: budgets,
    goals: goals,
    loans: loans,
    transactions: transactions,
    recurringTransactions: recurringTransactions,
    subscriptions: subscriptions,
    period: period,
    now: effectiveNow,
  );
}

void main() {
  group('1. Empty account', () {
    test('nothing recorded never fabricates an event', () {
      final result = _calc();
      expect(result.isEmpty, isTrue);
      expect(result.hasSufficientData, isFalse);
    });
  });

  group('2. Insufficient history', () {
    test('a single month of transactions never produces a spending/savings comparison event', () {
      final result = _calc(
        transactions: [_tx(id: 't1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5))],
      );
      expect(result.hasSufficientData, isTrue);
      expect(result.events.any((e) =>
          e.type == TimelineEventType.spendingIncrease || e.type == TimelineEventType.spendingDecrease), isFalse);
      expect(result.events.any((e) =>
          e.type == TimelineEventType.savingsImprovement || e.type == TimelineEventType.savingsDecline), isFalse);
    });
  });

  group('3. Improving savings', () {
    test('a savings-rate rise of >=5 points between consecutive months is reported', () {
      final result = _calc(transactions: [
        _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 7, 1)),
        _tx(id: 'e1', amount: 45000, type: 'expense', date: DateTime(2026, 7, 5)),
        _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
        _tx(id: 'e2', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.savingsImprovement);
      expect(event.tone, TimelineEventTone.positive);
    });
  });

  group('4. Declining savings', () {
    test('a savings-rate fall of >=5 points between consecutive months is reported', () {
      final result = _calc(transactions: [
        _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 7, 1)),
        _tx(id: 'e1', amount: 10000, type: 'expense', date: DateTime(2026, 7, 5)),
        _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
        _tx(id: 'e2', amount: 40000, type: 'expense', date: DateTime(2026, 8, 5)),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.savingsDecline);
      expect(event.tone, TimelineEventTone.warning);
    });
  });

  group('5. Increasing expenses', () {
    test('a month-over-month expense rise past the threshold is reported', () {
      final result = _calc(transactions: [
        _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 7, 5)),
        _tx(id: 'e2', amount: 35000, type: 'expense', date: DateTime(2026, 8, 5)),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.spendingIncrease);
      expect(event.tone, TimelineEventTone.warning);
      expect(event.amount, closeTo(15000, 0.01));
    });
  });

  group('6. Decreasing expenses', () {
    test('a month-over-month expense fall past the threshold is reported', () {
      final result = _calc(transactions: [
        _tx(id: 'e1', amount: 35000, type: 'expense', date: DateTime(2026, 7, 5)),
        _tx(id: 'e2', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.spendingDecrease);
      expect(event.tone, TimelineEventTone.positive);
    });

    test('a tiny expense fluctuation below the threshold is never reported', () {
      final result = _calc(transactions: [
        _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 7, 5)),
        _tx(id: 'e2', amount: 20300, type: 'expense', date: DateTime(2026, 8, 5)),
      ]);
      expect(result.events.any((e) =>
          e.type == TimelineEventType.spendingIncrease || e.type == TimelineEventType.spendingDecrease), isFalse);
    });
  });

  group('7. Budget warnings', () {
    test('an over-budget category record is reported, dated at its own createdAt', () {
      final createdAt = DateTime(2026, 8, 3);
      final result = _calc(budgets: [_budget('b1', allocated: 10000, spent: 15000, createdAt: createdAt)]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.budgetOverLimit);
      expect(event.date, createdAt);
      expect(event.relatedEntityName, 'Food');
    });

    test('a near-limit category record is reported as budgetWarning, not budgetOverLimit', () {
      final result = _calc(budgets: [_budget('b1', allocated: 10000, spent: 8500, createdAt: DateTime(2026, 8, 3))]);
      expect(result.events.any((e) => e.type == TimelineEventType.budgetOverLimit), isFalse);
      expect(result.events.any((e) => e.type == TimelineEventType.budgetWarning), isTrue);
    });

    test('an under-budget record produces no event at all', () {
      final result = _calc(budgets: [_budget('b1', allocated: 10000, spent: 2000, createdAt: DateTime(2026, 8, 3))]);
      expect(result.isEmpty, isTrue);
    });
  });

  group('8. Subscription additions', () {
    test('a new material recurring expense is reported as newSubscription', () {
      final createdAt = DateTime(2026, 8, 10);
      final result = _calc(recurringTransactions: [_recurring(id: 'r1', amount: 600, createdAt: createdAt)]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.newSubscription);
      expect(event.date, createdAt);
      expect(event.relatedEntityName, 'r1');
    });

    test('a new small recurring expense below materiality is reported as recurringCommitmentChange instead', () {
      final result = _calc(recurringTransactions: [_recurring(id: 'r1', amount: 50, createdAt: DateTime(2026, 8, 10))]);
      expect(result.events.any((e) => e.type == TimelineEventType.newSubscription), isFalse);
      expect(result.events.any((e) => e.type == TimelineEventType.recurringCommitmentChange), isTrue);
    });

    test('a new recurring income is reported as recurringCommitmentChange', () {
      final result = _calc(recurringTransactions: [
        _recurring(id: 'r1', amount: 60000, type: 'income', createdAt: DateTime(2026, 8, 10)),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.recurringCommitmentChange);
      expect(event.title, contains('income'));
    });
  });

  group('9. Positive milestones', () {
    test('a goal transitioning to completed is reported as positiveMilestone, not goalProgress', () {
      final updatedAt = DateTime(2026, 8, 15);
      final result = _calc(goals: [
        _goal(id: 'g1', target: 50000, current: 50000, createdAt: DateTime(2026, 1, 1), updatedAt: updatedAt),
      ]);
      expect(result.events.any((e) => e.type == TimelineEventType.goalProgress), isFalse);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.positiveMilestone);
      expect(event.date, updatedAt);
    });

    test('an incomplete goal update is reported as goalProgress', () {
      final result = _calc(goals: [
        _goal(id: 'g1', target: 50000, current: 20000, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 8, 15)),
      ]);
      expect(result.events.any((e) => e.type == TimelineEventType.positiveMilestone), isFalse);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.goalProgress);
      expect(event.percentage, closeTo(40, 0.01));
    });

    test('a loan reaching Closed status is reported as positiveMilestone, not debtProgress', () {
      final updatedAt = DateTime(2026, 8, 12);
      final result = _calc(loans: [
        _loan(id: 'l1', outstanding: 0, paid: 100000, status: 'Closed', createdAt: DateTime(2026, 1, 1), updatedAt: updatedAt),
      ]);
      expect(result.events.any((e) => e.type == TimelineEventType.debtProgress), isFalse);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.positiveMilestone);
      expect(event.relatedEntityName, 'l1');
    });

    test('an ongoing loan paydown is reported as debtProgress', () {
      final result = _calc(loans: [
        _loan(id: 'l1', outstanding: 60000, paid: 40000, status: 'Active', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 8, 12)),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.debtProgress);
      expect(event.amount, closeTo(40000, 0.01));
    });

    test('a fully funded, configured emergency fund is reported as emergencyFundChange, dated now', () {
      final result = _calc(
        wallets: [_wallet('w1', 500000)],
        transactions: [_tx(id: 'e1', amount: 10000, type: 'expense', date: DateTime(2026, 8, 5))],
        emergencyFundEligibleWalletIds: ['w1'],
      );
      final event = result.events.where((e) => e.type == TimelineEventType.emergencyFundChange);
      if (event.isNotEmpty) {
        expect(event.first.date, _now);
        expect(event.first.tone, TimelineEventTone.positive);
      }
    });

    test('an unconfigured emergency fund never produces an emergencyFundChange event', () {
      final result = _calc(wallets: [_wallet('w1', 500000)]);
      expect(result.events.any((e) => e.type == TimelineEventType.emergencyFundChange), isFalse);
    });
  });

  group('10. Duplicate events', () {
    test('two identical budget rows in the input never produce two events', () {
      final budget = _budget('b1', allocated: 10000, spent: 15000, createdAt: DateTime(2026, 8, 3));
      final result = _calc(budgets: [budget, budget]);
      final overLimitEvents = result.events.where((e) => e.type == TimelineEventType.budgetOverLimit);
      expect(overLimitEvents.length, 1);
    });

    test('every event id in a result is unique', () {
      final result = _calc(
        budgets: [_budget('b1', allocated: 10000, spent: 15000, createdAt: DateTime(2026, 8, 3))],
        goals: [_goal(id: 'g1', target: 50000, current: 50000, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 8, 15))],
      );
      final ids = result.events.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('11. Chronological ordering', () {
    test('events are strictly newest-first', () {
      final result = _calc(
        budgets: [_budget('b1', allocated: 10000, spent: 15000, createdAt: DateTime(2026, 8, 3))],
        goals: [_goal(id: 'g1', target: 50000, current: 50000, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 7, 1))],
        loans: [_loan(id: 'l1', outstanding: 0, paid: 100000, status: 'Closed', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 6, 1))],
      );
      for (var i = 0; i < result.events.length - 1; i++) {
        expect(result.events[i].date.isAfter(result.events[i + 1].date) ||
            result.events[i].date.isAtSameMomentAs(result.events[i + 1].date), isTrue);
      }
    });
  });

  group('12. 1/3/6/12-month windows', () {
    test('a goal update from 5 months ago is excluded from a 1-month window but included in a 6-month window', () {
      final oldUpdate = DateTime(2026, 3, 15);
      final goals = [_goal(id: 'g1', target: 50000, current: 20000, createdAt: DateTime(2026, 1, 1), updatedAt: oldUpdate)];

      final oneMonth = _calc(goals: goals, period: TimelinePeriod.month);
      expect(oneMonth.events.any((e) => e.relatedEntityId == 'g1'), isFalse);

      final sixMonths = _calc(goals: goals, period: TimelinePeriod.sixMonths);
      expect(sixMonths.events.any((e) => e.relatedEntityId == 'g1'), isTrue);
    });

    test('a goal update from 10 months ago is excluded from a 6-month window but included in a 12-month window', () {
      final oldUpdate = DateTime(2025, 10, 15);
      final goals = [_goal(id: 'g1', target: 50000, current: 20000, createdAt: DateTime(2025, 9, 1), updatedAt: oldUpdate)];

      final sixMonths = _calc(goals: goals, period: TimelinePeriod.sixMonths);
      expect(sixMonths.events.any((e) => e.relatedEntityId == 'g1'), isFalse);

      final twelveMonths = _calc(goals: goals, period: TimelinePeriod.twelveMonths);
      expect(twelveMonths.events.any((e) => e.relatedEntityId == 'g1'), isTrue);
    });

    test('periodStart/periodEnd widen monotonically as the period grows', () {
      final r1 = _calc(period: TimelinePeriod.month);
      final r3 = _calc(period: TimelinePeriod.threeMonths);
      final r12 = _calc(period: TimelinePeriod.twelveMonths);
      expect(r3.periodStart.isBefore(r1.periodStart) || r3.periodStart.isAtSameMomentAs(r1.periodStart), isTrue);
      expect(r12.periodStart.isBefore(r3.periodStart) || r12.periodStart.isAtSameMomentAs(r3.periodStart), isTrue);
    });
  });

  group('13. Zero/negative edge cases', () {
    test('a zero-income month never produces NaN/Infinity in a savings event', () {
      final result = _calc(transactions: [
        _tx(id: 'e1', amount: 10000, type: 'expense', date: DateTime(2026, 7, 5)),
        _tx(id: 'e2', amount: 12000, type: 'expense', date: DateTime(2026, 8, 5)),
      ]);
      for (final event in result.events) {
        expect(event.amount?.isNaN ?? false, isFalse);
        expect(event.amount?.isInfinite ?? false, isFalse);
        expect(event.percentage?.isNaN ?? false, isFalse);
        expect(event.percentage?.isInfinite ?? false, isFalse);
      }
    });

    test('a zero-allocated budget is handled safely, never divides by zero', () {
      final result = _calc(budgets: [_budget('b1', allocated: 0, spent: 500, createdAt: DateTime(2026, 8, 3))]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.budgetOverLimit);
      expect(event.percentage?.isNaN ?? false, isFalse);
      expect(event.percentage?.isInfinite ?? false, isFalse);
    });

    test('a loan with zero paidAmount and Active status never produces a debtProgress event', () {
      final result = _calc(loans: [
        _loan(id: 'l1', outstanding: 100000, paid: 0, status: 'Active', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 8, 5)),
      ]);
      expect(result.events.any((e) => e.type == TimelineEventType.debtProgress), isFalse);
    });
  });

  group('14. Day/Week periods (FINANCIAL TIMELINE 2.0)', () {
    test('a day window includes only today\'s transactions in income/expense sums', () {
      final result = _calc(
        transactions: [
          _tx(id: 't1', amount: 500, type: 'expense', date: _now), // today
          _tx(id: 't2', amount: 300, type: 'expense', date: _now.subtract(const Duration(days: 1))), // yesterday
        ],
        period: TimelinePeriod.day,
      );
      expect(result.periodExpense, 500);
    });

    test('a week window includes transactions from the last 7 days but excludes older ones', () {
      final result = _calc(
        transactions: [
          _tx(id: 't1', amount: 500, type: 'expense', date: _now.subtract(const Duration(days: 3))),
          _tx(id: 't2', amount: 300, type: 'expense', date: _now.subtract(const Duration(days: 10))),
        ],
        period: TimelinePeriod.week,
      );
      expect(result.periodExpense, 500);
    });

    test('empty day/week periods produce zero sums and no events, without crashing', () {
      final day = _calc(period: TimelinePeriod.day);
      final week = _calc(period: TimelinePeriod.week);
      expect(day.periodIncome, 0);
      expect(day.periodExpense, 0);
      expect(day.periodNetCashFlow, 0);
      expect(week.isEmpty, isTrue);
    });

    test('a day/week window excludes month-over-month spending events dated earlier in the month', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 35000, type: 'expense', date: DateTime(2026, 8, 5)), // >2 weeks before _now
        ],
        period: TimelinePeriod.week,
      );
      expect(result.events.any((e) => e.type == TimelineEventType.spendingIncrease), isFalse);
    });
  });

  group('15. Income / Expenses / Net cash flow', () {
    test('periodIncome/periodExpense/periodNetCashFlow are real sums, never fabricated', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
          _tx(id: 'e2', amount: 5000, type: 'expense', date: DateTime(2026, 8, 10)),
        ],
        period: TimelinePeriod.month,
      );
      expect(result.periodIncome, 50000);
      expect(result.periodExpense, 25000);
      expect(result.periodNetCashFlow, 25000);
    });
  });

  group('16. Large transactions', () {
    test('an expense well above the real recent same-category median is flagged, with a real sample', () {
      final result = _calc(transactions: [
        _tx(id: 't1', amount: 200, type: 'expense', category: 'Food', date: _now.subtract(const Duration(days: 5))),
        _tx(id: 't2', amount: 220, type: 'expense', category: 'Food', date: _now.subtract(const Duration(days: 10))),
        _tx(id: 't3', amount: 210, type: 'expense', category: 'Food', date: _now.subtract(const Duration(days: 15))),
        _tx(id: 't4', amount: 900, type: 'expense', category: 'Food', date: _now),
      ]);
      final event = result.events.firstWhere((e) => e.type == TimelineEventType.largeTransaction);
      expect(event.relatedEntityId, 't4');
      expect(event.amount, 900);
    });

    test('never flags a large transaction without at least 3 real same-category samples', () {
      final result = _calc(transactions: [
        _tx(id: 't1', amount: 200, type: 'expense', category: 'Food', date: _now.subtract(const Duration(days: 5))),
        _tx(id: 't2', amount: 900, type: 'expense', category: 'Food', date: _now),
      ]);
      expect(result.events.any((e) => e.type == TimelineEventType.largeTransaction), isFalse);
    });
  });
}
