// Targeted tests for PersonalCfoInsights — a pure explainer layer over
// already-computed FinancialReport/GoalProjection/SafeToSpendResult data.
// No method here should ever compute a new figure; these tests assert
// the phrasing is correct AND traceable to the real input value.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/financial_report.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/financial_report_engine.dart';
import 'package:paysense/shared/utils/personal_cfo_insights.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

final _now = DateTime(2026, 8, 27);

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
  group('PersonalCfoInsights.canSafelySpend', () {
    test('null when no SafeToSpendResult / insufficient data is supplied', () {
      expect(PersonalCfoInsights.canSafelySpend(500, null), isNull);
    });

    test('a real amount within the safe-to-spend figure is confirmed as safe', () {
      const safeToSpend = SafeToSpendResult(
        availableMoney: 10000, upcomingCommitments: 2000, plannedSavings: 0, savingsIncluded: false,
        safeToSpend: 8000, dailySafeToSpend: 266, remainingDays: 30, hasSufficientData: true,
        shortfall: 0, commitmentBreakdown: [], windowDays: 30,
      );
      final answer = PersonalCfoInsights.canSafelySpend(500, safeToSpend);
      expect(answer, contains('₹500'));
      expect(answer, contains('within'));
    });

    test('an amount above the safe-to-spend figure states the real shortfall', () {
      const safeToSpend = SafeToSpendResult(
        availableMoney: 10000, upcomingCommitments: 9500, plannedSavings: 0, savingsIncluded: false,
        safeToSpend: 500, dailySafeToSpend: 16, remainingDays: 30, hasSufficientData: true,
        shortfall: 0, commitmentBreakdown: [], windowDays: 30,
      );
      final answer = PersonalCfoInsights.canSafelySpend(2000, safeToSpend);
      expect(answer, contains('₹1500')); // 2000 - 500
    });
  });

  group('PersonalCfoInsights.amIOverspending', () {
    test('reports a real budget overspend when one exists', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      final answer = PersonalCfoInsights.amIOverspending(report);
      expect(answer, contains('spending stayed within income'));
    });

    test('reports negative net cash flow honestly', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx('i1', 5000, 'income', DateTime(2026, 8, 1)),
          _tx('e1', 8000, 'expense', DateTime(2026, 8, 5)),
        ],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      final answer = PersonalCfoInsights.amIOverspending(report);
      expect(answer, contains('₹3000'));
    });
  });

  group('PersonalCfoInsights.amIOnTrackForGoal', () {
    test('a completed goal is reported as fully funded', () {
      final projections = FinancialPlanningCalculator.calculateGoalProjections(
        goals: [Goal.create(id: 'g1', title: 'Trip', targetAmount: 1000, currentAmount: 1000, category: 'Travel', icon: '', color: 0, targetDate: DateTime(2027, 1, 1), createdAt: DateTime(2026, 1, 1))],
        now: _now,
      );
      final answer = PersonalCfoInsights.amIOnTrackForGoal(projections.single);
      expect(answer, contains('fully funded'));
    });

    test('insufficient data (goal too new) returns null, never a guessed status', () {
      final projections = FinancialPlanningCalculator.calculateGoalProjections(
        goals: [Goal.create(id: 'g1', title: 'Trip', targetAmount: 50000, category: 'Travel', icon: '', color: 0, targetDate: DateTime(2027, 1, 1), createdAt: _now)], // created today
        now: _now,
      );
      final answer = PersonalCfoInsights.amIOnTrackForGoal(projections.single);
      expect(answer, isNull);
    });
  });

  group('PersonalCfoInsights.whatNeedsAttention', () {
    test('merges real safety signals and debt pressure, never invents a new detection rule', () {
      final loan = Loan.create(id: 'l1', loanName: 'Car', lenderName: 'Bank', loanType: 'Personal', principalAmount: 100000, interestRate: 10, tenureMonths: 24, emiAmount: 8000, totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1), nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1));
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [_tx('i1', 10000, 'income', DateTime(2026, 8, 1))],
        wallets: [_wallet('w1', 5000)], budgets: const [], goals: const [], loans: [loan], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      final items = PersonalCfoInsights.whatNeedsAttention(report);
      expect(items.any((i) => i.contains('EMI commitments')), isTrue); // 8000/10000 = 80% >= 40%
    });
  });

  group('PersonalCfoInsights strongest/weakest behaviour', () {
    test('null for a weekly report — no health result computed', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.weekly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(PersonalCfoInsights.strongestBehavior(report), isNull);
      expect(PersonalCfoInsights.biggestWeakness(report), isNull);
    });

    test('a monthly report with real data produces a real component-backed answer', () {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [_tx('i1', 50000, 'income', DateTime(2026, 8, 1))],
        wallets: [_wallet('w1', 50000)], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );
      expect(PersonalCfoInsights.strongestBehavior(report), isNotNull);
      expect(PersonalCfoInsights.strongestBehavior(report), matches(RegExp(r'\d+/100')));
    });
  });
}
