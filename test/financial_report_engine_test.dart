// Targeted tests for FinancialReportEngine — a deterministic ADAPTER over
// already-existing calculators. Focus: correct period windows, real sums,
// no fabrication when data is insufficient, and that each reused
// calculator's output actually flows through untouched.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/financial_report.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_report_engine.dart';

final _now = DateTime(2026, 8, 27); // a Thursday, matches other test fixtures this session

Transaction _tx(String id, double amount, String type, DateTime date, {String category = 'Food'}) {
  return Transaction(
    id: id, title: category, amount: amount, categoryId: category, accountId: 'w1',
    transactionType: type, paymentMethod: 'card', note: '', createdAt: date,
  );
}

Wallet _wallet(String id, double balance) => Wallet(
  id: id, name: id, bankName: '', type: 'Bank', openingBalance: balance, currentBalance: balance, createdAt: DateTime(2025, 1, 1),
);

void main() {
  group('FinancialReportEngine — period windows', () {
    test('weekly report only includes transactions from the last 7 days', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.weekly,
        transactions: [
          _tx('t1', 500, 'expense', _now.subtract(const Duration(days: 3))),
          _tx('t2', 300, 'expense', _now.subtract(const Duration(days: 10))),
        ],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.totalExpenses, 500);
    });

    test('monthly report includes transactions from the 1st of the calendar month', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx('t1', 500, 'expense', DateTime(2026, 8, 5)),
          _tx('t2', 300, 'expense', DateTime(2026, 7, 25)), // last month, excluded
        ],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.totalExpenses, 500);
    });
  });

  group('FinancialReportEngine — data integrity (never fabricate)', () {
    test('an empty account never fabricates content — hasAnyActivity is false', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.hasAnyActivity, isFalse);
      expect(report.spendingByCategory, isEmpty);
      expect(report.largestTransactions, isEmpty);
      expect(report.savingsRatePercent, isNull); // zero income -> null, never 0% or a fabricated rate
    });

    test('savingsRatePercent is null (never a fabricated 0%) when income is zero', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [_tx('t1', 500, 'expense', DateTime(2026, 8, 5))],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.savingsRatePercent, isNull);
    });

    test('budgetSummary is null for a weekly report — budgets are monthly-only records', () {
      final budget = Budget.create(id: 'b1', categoryId: 'Food', categoryName: 'Food', allocatedAmount: 5000, month: 'August', year: 2026, createdAt: _now);
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.weekly,
        transactions: const [], wallets: const [], budgets: [budget], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.budgetSummary, isNull);
    });

    test('budgetSummary is populated for a monthly report when a matching budget exists', () {
      final budget = Budget.create(id: 'b1', categoryId: 'Food', categoryName: 'Food', allocatedAmount: 5000, month: 'August', year: 2026, createdAt: _now)
          .copyWith(spentAmount: 6000, remainingAmount: -1000, percentageUsed: 120);
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: [budget], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.budgetSummary, isNotNull);
      expect(report.budgetSummary!.totalSpent, 6000);
      expect(report.budgetOverspend!.hasOverspend, isTrue);
    });

    test('healthResult is null for a weekly report — not part of the weekly content spec', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.weekly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.healthResult, isNull);
    });

    test('healthResult is populated for a monthly report', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [_tx('t1', 1000, 'income', DateTime(2026, 8, 1))],
        wallets: [_wallet('w1', 5000)], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.healthResult, isNotNull);
    });
  });

  group('FinancialReportEngine — reuses existing calculators (no duplicate logic)', () {
    test('goalProjections come straight from FinancialPlanningCalculator.calculateGoalProjections', () {
      final goal = Goal.create(id: 'g1', title: 'Trip', targetAmount: 50000, category: 'Travel', icon: '', color: 0, targetDate: DateTime(2027, 1, 1), createdAt: DateTime(2026, 1, 1));
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: const [], goals: [goal], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.goalProjections, hasLength(1));
      expect(report.goalProjections.single.goalId, 'g1');
    });

    test('safetySignals come straight from FinancialSafetyEngine.generate — a real cash-flow deficit is surfaced', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx('i1', 10000, 'income', DateTime(2026, 8, 1)),
          _tx('e1', 15000, 'expense', DateTime(2026, 8, 5)),
        ],
        wallets: [_wallet('w1', 5000)], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.safetySignals.any((a) => a.type.name == 'cashFlowDeficit'), isTrue);
    });

    test('debt comes straight from FinancialPlanningCalculator\'s DebtOverview', () {
      final loan = Loan.create(id: 'l1', loanName: 'Car', lenderName: 'Bank', loanType: 'Personal', principalAmount: 100000, interestRate: 10, tenureMonths: 24, emiAmount: 5000, totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1));
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: [loan], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.debt, isNotNull);
      expect(report.debt!.activeLoanCount, 1);
    });

    test('recurringSummary comes straight from RecurringMoneyAggregator.summarize', () {
      final recurring = RecurringTransaction.create(id: 'r1', title: 'Netflix', amount: 649, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1), createdAt: DateTime(2026, 1, 1));
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: [recurring],
        now: _now,
      );
      expect(report.recurringSummary, isNotNull);
      expect(report.recurringSummary!.subscriptions.any((s) => s.name == 'Netflix'), isTrue);
    });
  });

  group('FinancialReportEngine — notable spending behaviors (Pain-of-Paying reuse)', () {
    test('only transactions at MODERATE Pain-of-Paying level or above are included, never all of them', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [_tx('t1', 100, 'expense', DateTime(2026, 8, 5))], // small, routine — should stay LOW
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.notableSpendingBehaviors, isEmpty);
    });

    test('never shame-based language in any generated recommendation', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx('i1', 5000, 'income', DateTime(2026, 8, 1)),
          _tx('e1', 20000, 'expense', DateTime(2026, 8, 5)),
        ],
        wallets: [_wallet('w1', 1000)], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      for (final r in report.recommendations) {
        expect(r.toLowerCase(), isNot(contains('should have')));
        expect(r.toLowerCase(), isNot(contains('bad')));
        expect(r.toLowerCase(), isNot(contains('failed')));
      }
    });
  });

  group('FinancialReportEngine — category spend', () {
    test('spendingByCategory sums correctly and is sorted descending, percentages never NaN', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx('t1', 3000, 'expense', DateTime(2026, 8, 5), category: 'Food'),
          _tx('t2', 1000, 'expense', DateTime(2026, 8, 6), category: 'Food'),
          _tx('t3', 2000, 'expense', DateTime(2026, 8, 7), category: 'Shopping'),
        ],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(report.spendingByCategory.first.categoryId, 'Food');
      expect(report.spendingByCategory.first.amount, 4000);
      expect(report.spendingByCategory.first.percentOfExpenses, closeTo(66.67, 0.1));
      for (final c in report.spendingByCategory) {
        expect(c.percentOfExpenses.isNaN, isFalse);
      }
    });
  });
}
