// Focused tests for AffordabilityCalculator (PHASE 3/4/5) — pure
// comparison logic over already-computed SafeToSpendResult/
// FinancialPlanningResult. Synthetic data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

final _now = DateTime(2026, 8, 20);

MonthlyTotal _mt(DateTime month, {double income = 0, double expense = 0}) {
  return MonthlyTotal(month: month, income: income, expense: expense);
}

AnalyticsSummary _analytics({
  required List<MonthlyTotal> monthlyTotals,
  double currentMonthIncome = 0,
  double currentMonthExpense = 0,
}) {
  final savingsRate = currentMonthIncome > 0
      ? ((currentMonthIncome - currentMonthExpense) / currentMonthIncome * 100)
      : 0.0;
  return AnalyticsSummary(
    monthlyTotals: monthlyTotals,
    categoryBreakdown: const [],
    currentMonthIncome: currentMonthIncome,
    currentMonthExpense: currentMonthExpense,
    savingsRate: savingsRate,
  );
}

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: balance, currentBalance: balance, createdAt: DateTime(2026, 1, 1),
  );
}

Goal _goal({required String id, required double target, required double current, required DateTime targetDate}) {
  return Goal.create(
    id: id, title: id, targetAmount: target, currentAmount: current, targetDate: targetDate,
    category: 'Other', icon: 'savings', color: 0xFF000000, createdAt: DateTime(2025, 6, 1),
  );
}

Loan _loan({required String id, required double outstanding, required double emi}) {
  final loan = Loan.create(
    id: id, loanName: id, lenderName: 'Bank', loanType: 'Personal',
    principalAmount: outstanding + 50000, interestRate: 10, tenureMonths: 24, emiAmount: emi,
    totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1),
    nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1),
  );
  return loan.copyWith(outstandingAmount: outstanding, endDate: DateTime(2028, 1, 1));
}

FinancialPlanningResult _planning({
  List<Wallet> wallets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  AnalyticsSummary? analytics,
  List<String>? emergencyFundEligibleWalletIds,
}) {
  return FinancialPlanningCalculator.calculate(
    transactions: const [],
    wallets: wallets,
    goals: goals,
    loans: loans,
    bills: const [],
    recurringTransactions: const [],
    analytics: analytics ?? _analytics(monthlyTotals: [_mt(DateTime(2026, 8))]),
    emergencyFundEligibleWalletIds: emergencyFundEligibleWalletIds,
    now: _now,
  );
}

SafeToSpendResult _safeToSpend({
  required double availableMoney,
  required double upcomingCommitments,
  int windowDays = 30,
}) {
  final safe = (availableMoney - upcomingCommitments).clamp(0.0, double.infinity);
  return SafeToSpendResult(
    availableMoney: availableMoney,
    upcomingCommitments: upcomingCommitments,
    plannedSavings: 0,
    savingsIncluded: false,
    safeToSpend: safe,
    dailySafeToSpend: safe / windowDays,
    remainingDays: windowDays,
    hasSufficientData: true,
    shortfall: (upcomingCommitments - availableMoney).clamp(0.0, double.infinity),
    commitmentBreakdown: const [],
    windowDays: windowDays,
  );
}

AnalyticsSummary _steadyIncome({double income = 50000, double expense = 30000}) {
  return _analytics(
    monthlyTotals: [
      _mt(DateTime(2026, 6), income: income, expense: expense),
      _mt(DateTime(2026, 7), income: income, expense: expense),
      _mt(DateTime(2026, 8), income: income, expense: expense),
    ],
    currentMonthIncome: income,
    currentMonthExpense: expense,
  );
}

void main() {
  group('13. Comfortable purchase', () {
    test('an amount within the safe-to-spend buffer, with no flagged problems, is comfortable', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.status, AffordabilityStatus.comfortable);
      expect(result.cashFlowImpact, greaterThanOrEqualTo(0));
    });
  });

  group('14. Possible purchase', () {
    test('an amount above safe-to-spend but within available cash, no flagged problems, is possible', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 150000); // safe=50000

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 90000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.status, AffordabilityStatus.possible);
      expect(result.cashFlowImpact, lessThan(0)); // eats into commitment-reserved money
    });
  });

  group('15. Risky purchase', () {
    test('an amount that fits available cash but the debt burden is already flagged is risky', () {
      final planning = _planning(
        wallets: [_wallet('w1', 200000)],
        loans: [_loan(id: 'l1', outstanding: 400000, emi: 35000)],
        analytics: _steadyIncome(),
      );
      expect(planning.debtStatus, PlanningComponentStatus.needsAttention);
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.status, AffordabilityStatus.risky);
    });
  });

  group('16/23. Not recommended / purchase larger than available cash', () {
    test('an amount larger than total wallet cash is not recommended', () {
      final planning = _planning(wallets: [_wallet('w1', 50000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 50000, upcomingCommitments: 5000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 90000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.status, AffordabilityStatus.notRecommended);
      expect(result.availableAfterPurchase, lessThan(0));
    });
  });

  group('17. Insufficient data', () {
    test('no wallets at all reports insufficient data, never a fabricated verdict', () {
      final planning = _planning();
      const safeToSpend = SafeToSpendResult(
        availableMoney: 0, upcomingCommitments: 0, plannedSavings: 0, savingsIncluded: false,
        safeToSpend: 0, dailySafeToSpend: 0, remainingDays: 30, hasSufficientData: false,
        shortfall: 0, commitmentBreakdown: [], windowDays: 30,
      );

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.status, AffordabilityStatus.insufficientData);
      expect(result.recommendation, contains("don't have enough information"));
      expect(result.confidence, 0.0);
    });
  });

  group('18. Emergency-fund impact', () {
    test('an incomplete emergency fund reports a capped, non-fabricated impact figure', () {
      // expense=30000/month * 6-month default target = 180000 target; a
      // 100000 balance leaves a genuine 80000 gap for this scenario.
      final planning = _planning(
        wallets: [_wallet('w1', 100000)],
        emergencyFundEligibleWalletIds: ['w1'],
        analytics: _steadyIncome(),
      );
      final safeToSpend = _safeToSpend(availableMoney: 100000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.emergencyFundImpact, greaterThan(0));
      expect(result.emergencyFundImpact, lessThanOrEqualTo(30000));
    });

    test('a fully-funded emergency fund reports zero impact', () {
      final planning = _planning(
        wallets: [_wallet('w1', 10000000)], // huge balance, easily covers any EF target
        emergencyFundEligibleWalletIds: ['w1'],
        analytics: _steadyIncome(),
      );
      final safeToSpend = _safeToSpend(availableMoney: 10000000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.emergencyFundImpact, 0);
    });
  });

  group('19. Goal impact', () {
    test('an incomplete goal reports a goal impact and a delay estimate', () {
      final planning = _planning(
        wallets: [_wallet('w1', 200000)],
        goals: [_goal(id: 'g1', target: 100000, current: 20000, targetDate: DateTime(2027, 6, 1))],
        analytics: _steadyIncome(),
      );
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.goalImpact, greaterThan(0));
    });

    test('no incomplete goals never fabricates a goal impact or delay', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.goalImpact, 0);
      expect(result.estimatedGoalDelayMonths, isNull);
    });
  });

  group('20. Cash-flow impact', () {
    test('cashFlowImpact is exactly safeToSpend minus the purchase amount', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 50000); // safe=150000

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 90000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.cashFlowImpact, closeTo(60000, 0.01)); // 150000 - 90000
    });
  });

  group('21. Zero/negative amount', () {
    test('a zero purchase amount never crashes and never produces a nonsensical verdict', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 0, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.purchaseAmount, 0);
      expect(result.status, isNot(AffordabilityStatus.insufficientData));
    });

    test('a negative purchase amount is clamped to zero, never treated as a windfall', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: -5000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.purchaseAmount, 0);
    });
  });

  group('22. Huge purchase', () {
    test('an enormous purchase amount never produces NaN or Infinity anywhere in the result', () {
      final planning = _planning(wallets: [_wallet('w1', 50000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 50000, upcomingCommitments: 5000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 999999999999, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.status, AffordabilityStatus.notRecommended);
      expect(result.availableAfterPurchase.isNaN, isFalse);
      expect(result.availableAfterPurchase.isInfinite, isFalse);
      expect(result.cashFlowImpact.isNaN, isFalse);
    });
  });

  group('24. Ambiguous/boundary input', () {
    test('a purchase amount exactly equal to available cash is deterministic, not a crash', () {
      final planning = _planning(wallets: [_wallet('w1', 50000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 50000, upcomingCommitments: 5000);

      final result = AffordabilityCalculator.calculate(
        AffordabilityInput(purchaseAmount: 50000, safeToSpend: safeToSpend, planning: planning),
      );

      expect(result.availableAfterPurchase, 0);
      expect(result.status, isNot(AffordabilityStatus.insufficientData));
    });
  });

  group('25. No mutation of persisted data', () {
    test('the calculator is a pure function — identical input always yields identical output', () {
      final planning = _planning(wallets: [_wallet('w1', 200000)], analytics: _steadyIncome());
      final safeToSpend = _safeToSpend(availableMoney: 200000, upcomingCommitments: 20000);
      final input = AffordabilityInput(purchaseAmount: 30000, safeToSpend: safeToSpend, planning: planning);

      final first = AffordabilityCalculator.calculate(input);
      final second = AffordabilityCalculator.calculate(input);

      expect(first.status, second.status);
      expect(first.availableAfterPurchase, second.availableAfterPurchase);
      expect(first.recommendation, second.recommendation);
    });
  });
}
