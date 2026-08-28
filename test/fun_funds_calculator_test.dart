// FUN FUNDS — "how much money can I safely spend for fun without
// damaging my financial position?" Verifies FunFundsCalculator is a pure
// adapter over SafeToSpendResult/BudgetTotals/GoalProjection: never
// re-derives income/expense/budget math, never fabricates a positive
// amount when commitments exceed what's safe to spend.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/providers/budget_provider.dart' show BudgetTotals;
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/fun_funds_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

final _now = DateTime(2026, 8, 28);

SafeToSpendResult _safeToSpend(double amount, {bool hasSufficientData = true}) {
  return SafeToSpendResult(
    availableMoney: amount,
    upcomingCommitments: 0,
    plannedSavings: 0,
    savingsIncluded: false,
    safeToSpend: amount,
    dailySafeToSpend: amount / 30,
    remainingDays: 30,
    hasSufficientData: hasSufficientData,
    shortfall: 0,
    commitmentBreakdown: const [],
    windowDays: 30,
  );
}

BudgetTotals _budgetTotals({double remaining = 0}) {
  return BudgetTotals(
    totalBudget: remaining,
    totalSpent: 0,
    remainingBudget: remaining,
    percentageUsed: 0,
    highestSpendingCategory: '',
  );
}

List<GoalProjection> _goalRequiring(double monthlyRequired, {DateTime? targetDate, double currentAmount = 0}) {
  final goal = Goal.create(
    id: 'g1',
    title: 'Trip',
    targetAmount: monthlyRequired * 3 + currentAmount,
    targetDate: targetDate ?? _now.add(const Duration(days: 90)),
    category: 'Travel',
    icon: 'flight',
    color: 0xFF000000,
    createdAt: _now.subtract(const Duration(days: 60)),
    currentAmount: currentAmount,
  );
  return FinancialPlanningCalculator.calculateGoalProjections(goals: [goal], now: _now);
}

void main() {
  group('1. Healthy discretionary balance', () {
    test('no budgets, no goals: Fun Funds = SafeToSpend minus the 10% buffer', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(10000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: const [],
      );
      expect(result.hasSufficientData, isTrue);
      expect(result.safetyBuffer, 1000);
      expect(result.funFunds, 9000);
      expect(result.shortfall, 0);
    });
  });

  group('2. Zero discretionary balance', () {
    test('commitments and buffer exactly consume Safe-to-Spend', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(1000),
        budgetTotals: _budgetTotals(remaining: 900),
        goalProjections: const [],
      );
      // buffer = 100; raw = 1000 - 900 - 0 - 100 = 0.
      expect(result.funFunds, 0);
      expect(result.shortfall, 0);
    });
  });

  group('3. Negative discretionary balance (shortfall)', () {
    test('commitments exceed Safe-to-Spend: Fun Funds is 0, never negative', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(1000),
        budgetTotals: _budgetTotals(remaining: 2000),
        goalProjections: const [],
      );
      // buffer = 100; raw = 1000 - 2000 - 0 - 100 = -1100.
      expect(result.funFunds, 0);
      expect(result.shortfall, 1100);
      expect(result.isShortfall, isTrue);
    });
  });

  group('4. Upcoming bill reducing Fun Funds', () {
    test('a lower SafeToSpend input (bill already deducted upstream) reduces Fun Funds proportionally', () {
      final withoutBill = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(10000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: const [],
      );
      // A ₹3,000 upcoming bill reduces SafeToSpend to 7,000 before Fun
      // Funds ever runs — FunFundsCalculator never re-derives bills itself.
      final withBill = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(7000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: const [],
      );
      expect(withoutBill.funFunds, 9000);
      expect(withBill.funFunds, 6300); // 7000 - 700 buffer
      expect(withoutBill.funFunds - withBill.funFunds, 2700);
    });
  });

  group('5. Goal contribution reducing Fun Funds', () {
    test('an active goal\'s required monthly contribution is subtracted exactly, not re-derived', () {
      final goalProjections = _goalRequiring(2000);
      // Derive the expected figure from the SAME FinancialPlanningCalculator
      // projection FunFundsCalculator consumes — this test is about proving
      // FunFundsCalculator passes it through unchanged, not re-verifying
      // FinancialPlanningCalculator's own month-counting math (that has its
      // own 69-test suite).
      final requiredContribution = goalProjections.single.requiredMonthlyContribution!;
      expect(requiredContribution, greaterThan(0));

      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(10000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: goalProjections,
      );
      expect(result.goalContributions, requiredContribution);
      // buffer = 1000; raw = 10000 - 0 - requiredContribution - 1000.
      expect(result.funFunds, 10000 - requiredContribution - 1000);
    });

    test('a completed goal contributes nothing, even though it has a target date', () {
      final goal = Goal.create(
        id: 'g1', title: 'Done', targetAmount: 5000, currentAmount: 5000,
        targetDate: _now.add(const Duration(days: 30)), category: 'Other',
        icon: 'flag', color: 0xFF000000, createdAt: _now.subtract(const Duration(days: 200)),
      );
      final projections = FinancialPlanningCalculator.calculateGoalProjections(goals: [goal], now: _now);
      expect(projections.single.status, GoalProjectionStatus.completed);

      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(10000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: projections,
      );
      expect(result.goalContributions, 0);
    });

    test('a goal whose target date has already passed contributes 0, not a fabricated figure', () {
      final projections = _goalRequiring(1, targetDate: _now.subtract(const Duration(days: 5)));
      expect(projections.single.requiredMonthlyContribution, isNull);

      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(10000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: projections,
      );
      expect(result.goalContributions, 0);
    });
  });

  group('6. Large debt/obligation scenario', () {
    test('SafeToSpend already fully consumed by bills/EMIs: Fun Funds is 0, not negative', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(0),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: const [],
      );
      expect(result.funFunds, 0);
      expect(result.shortfall, 0);
      expect(result.safetyBuffer, 0);
    });
  });

  group('7. Empty account', () {
    test('no wallets (SafeToSpend has insufficient data): Fun Funds reports insufficient data, never a fabricated ₹0-that-looks-computed', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(0, hasSufficientData: false),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: const [],
      );
      expect(result.hasSufficientData, isFalse);
      expect(result.funFunds, 0);
    });
  });

  group('8. Fractional paise', () {
    test('all four inputs combine to exact decimal precision', () {
      final goalProjections = _goalRequiring(50.10);
      final requiredContribution = goalProjections.single.requiredMonthlyContribution!;

      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(1000.50),
        budgetTotals: _budgetTotals(remaining: 100.25),
        goalProjections: goalProjections,
      );
      // buffer = 100.05; raw = 1000.50 - 100.25 - requiredContribution - 100.05.
      expect(result.safetyBuffer, closeTo(100.05, 0.001));
      expect(result.goalContributions, requiredContribution);
      expect(
        result.funFunds,
        closeTo(1000.50 - 100.25 - requiredContribution - 100.05, 0.01),
      );
    });
  });

  group('9. Multiple goals', () {
    test('required contributions from every active goal are summed, not just the nearest one', () {
      final goalA = Goal.create(
        id: 'a', title: 'Phone', targetAmount: 3000, targetDate: _now.add(const Duration(days: 30)),
        category: 'Electronics', icon: 'phone', color: 0xFF000000, createdAt: _now.subtract(const Duration(days: 10)),
      );
      final goalB = Goal.create(
        id: 'b', title: 'Trip', targetAmount: 6000, targetDate: _now.add(const Duration(days: 60)),
        category: 'Travel', icon: 'flight', color: 0xFF000000, createdAt: _now.subtract(const Duration(days: 10)),
      );
      final projections = FinancialPlanningCalculator.calculateGoalProjections(goals: [goalA, goalB], now: _now);
      final expectedTotal = projections.fold<double>(0, (sum, g) => sum + (g.requiredMonthlyContribution ?? 0));

      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(20000),
        budgetTotals: _budgetTotals(remaining: 0),
        goalProjections: projections,
      );
      expect(result.goalContributions, closeTo(expectedTotal, 0.01));
    });
  });

  group('10. Over-budget accounts never double-penalize Fun Funds', () {
    test('a negative remainingBudget (already overspent) reserves 0, not a negative subtraction that inflates Fun Funds', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(10000),
        budgetTotals: _budgetTotals(remaining: -500),
        goalProjections: const [],
      );
      expect(result.budgetCommitments, 0);
      expect(result.funFunds, 9000); // same as the no-budget-data case
    });
  });
}
