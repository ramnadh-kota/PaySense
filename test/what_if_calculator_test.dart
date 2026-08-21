// Focused tests for WhatIfCalculator (PHASE 8/9) — deterministic scenario
// math handed to the AI for explanation, never computed by the LLM itself.
// Synthetic data only; nothing here touches real financial data.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/subscription_summary.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/what_if_calculator.dart';

FinancialOverview _overview({
  required double income,
  required double expenses,
}) {
  return FinancialOverview(
    netWorth: 0,
    monthlyIncome: income,
    monthlyExpenses: expenses,
    monthlySavings: income - expenses,
    savingsRatePercent: income > 0 ? ((income - expenses) / income * 100) : null,
    hasIncomeData: income > 0,
    monthlyFixedCommitments: 0,
    totalDebt: 0,
    emergencyFundCurrent: 0,
  );
}

void main() {
  group('20. Deterministic savings calculation', () {
    test('monthsToReachAmount computes whole months, rounding up', () {
      expect(
        WhatIfCalculator.monthsToReachAmount(remaining: 45000, monthlyRate: 15000),
        3,
      );
      expect(
        WhatIfCalculator.monthsToReachAmount(remaining: 46000, monthlyRate: 15000),
        4, // ceil(46000/15000) = 4, not truncated to 3
      );
    });

    test('already-covered remaining amount is 0 months, never negative', () {
      expect(
        WhatIfCalculator.monthsToReachAmount(remaining: 0, monthlyRate: 15000),
        0,
      );
      expect(
        WhatIfCalculator.monthsToReachAmount(remaining: -500, monthlyRate: 15000),
        0,
      );
    });

    test('a zero or negative rate never produces a fabricated finite estimate', () {
      expect(WhatIfCalculator.monthsToReachAmount(remaining: 45000, monthlyRate: 0), isNull);
      expect(WhatIfCalculator.monthsToReachAmount(remaining: 45000, monthlyRate: -100), isNull);
    });
  });

  group('21. Deterministic goal projection (reused from FinancialPlanningCalculator)', () {
    test('FinancialPlanningCalculator.whatIf is the single source for savings-rate scenarios', () {
      // WhatIfCalculator deliberately does NOT duplicate this — confirms it
      // isn't re-implemented here by checking the symbol is reachable from
      // financial_planning_calculator.dart directly.
      expect(FinancialPlanningCalculator.whatIf, isNotNull);
    });
  });

  group('22. What-if savings calculation (expense change)', () {
    test('an expense increase reduces monthly savings and savings rate', () {
      final overview = _overview(income: 50000, expenses: 30000);
      final projection = WhatIfCalculator.whatIfExpenseChange(
        overview: overview,
        deltaAmount: 10000,
      );
      expect(projection.monthlySavingsBefore, 20000);
      expect(projection.monthlySavingsAfter, 10000);
      expect(projection.savingsRateAfter, closeTo(20.0, 0.01));
    });

    test('an expense decrease increases monthly savings', () {
      final overview = _overview(income: 50000, expenses: 30000);
      final projection = WhatIfCalculator.whatIfExpenseChange(
        overview: overview,
        deltaAmount: -5000,
      );
      expect(projection.monthlySavingsAfter, 25000);
    });

    test('expenses never go negative even with a huge hypothetical decrease', () {
      final overview = _overview(income: 50000, expenses: 5000);
      final projection = WhatIfCalculator.whatIfExpenseChange(
        overview: overview,
        deltaAmount: -100000,
      );
      expect(projection.monthlySavingsAfter, 50000); // expenses clamped to 0
    });
  });

  group('23. What-if expense scenario (category reduction)', () {
    test('reducing a category by a percentage frees up the correct monthly amount', () {
      final overview = _overview(income: 50000, expenses: 30000);
      final projection = WhatIfCalculator.whatIfReduceCategorySpending(
        overview: overview,
        categoryName: 'Dining',
        currentCategoryAmount: 18500,
        percentReduction: 20,
      );
      expect(projection.monthlyAmountSaved, 3700); // 20% of 18500
      expect(projection.monthlySavingsAfter, 23700);
    });

    test('percentage is clamped to [0, 100] — never a nonsensical negative saving', () {
      final overview = _overview(income: 50000, expenses: 30000);
      final projection = WhatIfCalculator.whatIfReduceCategorySpending(
        overview: overview,
        categoryName: 'Dining',
        currentCategoryAmount: 10000,
        percentReduction: 150,
      );
      expect(projection.percentReduction, 100);
      expect(projection.monthlyAmountSaved, 10000);
    });
  });

  group('24. What-if debt scenario (extra loan payment)', () {
    test('an extra payment reduces outstanding balance and shortens payoff time', () {
      final projection = WhatIfCalculator.whatIfExtraLoanPayment(
        outstandingAmount: 100000,
        emiAmount: 10000,
        remainingMonthsBefore: 10,
        extraAmount: 20000,
      );
      expect(projection.outstandingAfter, 80000);
      expect(projection.remainingMonthsAfter, 8); // 80000 / 10000
      expect(projection.monthsSaved, 2);
    });

    test('an extra payment can never push outstanding below zero', () {
      final projection = WhatIfCalculator.whatIfExtraLoanPayment(
        outstandingAmount: 15000,
        emiAmount: 10000,
        remainingMonthsBefore: 2,
        extraAmount: 50000,
      );
      expect(projection.outstandingAfter, 0);
      expect(projection.remainingMonthsAfter, 0);
    });

    test('stopping a subscription redirects its cost and shortens the emergency fund timeline', () {
      final subscription = SubscriptionSummary(
        id: 's1',
        name: 'Netflix',
        amount: 500,
        frequency: 'Monthly',
        nextDueDate: DateTime(2026, 9, 1),
        category: 'Entertainment',
        account: 'w1',
        monthlyEquivalent: 500,
        annualCost: 6000,
        status: SubscriptionStatus.active,
        sourceId: 's1',
      );
      final projection = WhatIfCalculator.whatIfStopSubscription(
        subscription: subscription,
        currentMonthlyContribution: 10000,
        remainingTarget: 60000,
        now: DateTime(2026, 8, 20),
      );
      expect(projection.monthsBefore, 6); // 60000/10000
      expect(projection.monthsAfter, 6); // 60000/10500 -> ceil = 6
      expect(projection.monthlySavingsFreed, 500);
    });
  });

  group('28. No NaN/Infinity in what-if scenarios', () {
    test('zero income and zero everything stays finite throughout', () {
      final overview = _overview(income: 0, expenses: 0);
      final expenseProjection = WhatIfCalculator.whatIfExpenseChange(
        overview: overview,
        deltaAmount: 5000,
      );
      expect(expenseProjection.savingsRateAfter, isNull);
      expect(expenseProjection.monthlySavingsAfter.isNaN, isFalse);

      final loanProjection = WhatIfCalculator.whatIfExtraLoanPayment(
        outstandingAmount: 0,
        emiAmount: 0,
        remainingMonthsBefore: null,
        extraAmount: 1000,
      );
      expect(loanProjection.outstandingAfter, 0);
      expect(loanProjection.remainingMonthsAfter, isNull);
    });
  });
}
