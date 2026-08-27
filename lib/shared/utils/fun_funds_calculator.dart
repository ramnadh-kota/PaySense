import 'package:flutter/foundation.dart';

import '../models/fun_group_expense.dart';
import '../providers/budget_provider.dart' show BudgetTotals;
import 'financial_planning_calculator.dart' show GoalProjection, GoalProjectionStatus;
import 'safe_to_spend_calculator.dart';

/// Fraction of money left after essential obligations, budget commitments,
/// and goal contributions that is held back as a safety cushion rather than
/// counted as "safe to enjoy". A documented policy constant — like
/// [safeToSpendWindowDays] elsewhere in the codebase — not a value read
/// from or inferred about the user's own data.
const double funFundsSafetyBufferFraction = 0.10;

/// Result of a Fun Funds calculation. Every amount here is derived from
/// real PaySense data (Safe-to-Spend, Budgets, Goal projections, and the
/// user's own logged Fun Funds group expenses) plus the one documented
/// policy constant above — nothing is fabricated. When there isn't enough
/// underlying data to produce a meaningful figure, [hasSufficientData] is
/// false and every amount is 0; callers must show "Not enough data yet"
/// rather than a number in that case.
@immutable
class FunFundsResult {
  const FunFundsResult({
    required this.hasSufficientData,
    required this.safeToSpendAvailable,
    required this.budgetCommitted,
    required this.goalCommitted,
    required this.safetyBuffer,
    required this.monthlyAvailable,
    required this.spentThisMonth,
    required this.remaining,
    required this.utilizationPercent,
    required this.dailyBudget,
    required this.weeklyBudget,
    required this.daysRemainingInMonth,
  });

  const FunFundsResult.insufficientData()
    : hasSufficientData = false,
      safeToSpendAvailable = 0,
      budgetCommitted = 0,
      goalCommitted = 0,
      safetyBuffer = 0,
      monthlyAvailable = 0,
      spentThisMonth = 0,
      remaining = 0,
      utilizationPercent = 0,
      dailyBudget = 0,
      weeklyBudget = 0,
      daysRemainingInMonth = 0;

  final bool hasSufficientData;

  /// Pass-through of [SafeToSpendResult.safeToSpend] — the starting point
  /// before Fun Funds nets out budget and goal commitments.
  final double safeToSpendAvailable;

  /// This month's still-unspent budget allocation across every category —
  /// money already earmarked for planned spending, not discretionary.
  final double budgetCommitted;

  /// Sum of every active goal's [GoalProjection.requiredMonthlyContribution]
  /// (only the positive ones — a goal already ahead of pace contributes 0,
  /// never a negative "extra" Fun Fund).
  final double goalCommitted;

  /// `funFundsSafetyBufferFraction` of what's left after the two
  /// deductions above — held back as a cushion, not counted as available.
  final double safetyBuffer;

  /// This month's total Fun Fund: `safeToSpendAvailable - budgetCommitted -
  /// goalCommitted - safetyBuffer`, floored at 0.
  final double monthlyAvailable;

  /// Sum of the user's own share across every Fun Funds group/shared
  /// expense logged this calendar month — the only deterministic signal
  /// PaySense has for "discretionary spending actually happened" (regular
  /// transactions aren't tagged essential/discretionary, and this
  /// calculator never guesses that classification).
  final double spentThisMonth;

  /// `max(0, monthlyAvailable - spentThisMonth)`.
  final double remaining;

  /// `spentThisMonth / monthlyAvailable * 100`, clamped to a sane display
  /// range. 0 when nothing has been spent and there's nothing available.
  final double utilizationPercent;

  /// `remaining / daysRemainingInMonth`.
  final double dailyBudget;

  /// `min(remaining, dailyBudget * 7)` — never suggests spending more in a
  /// week than is actually left for the month.
  final double weeklyBudget;

  final int daysRemainingInMonth;
}

/// Pure, deterministic Fun Funds calculation. No Flutter/Riverpod
/// dependency — composes existing calculators/results rather than
/// re-deriving any of their logic.
class FunFundsCalculator {
  FunFundsCalculator._();

  static FunFundsResult calculate({
    required SafeToSpendResult safeToSpend,
    required BudgetTotals budgetTotals,
    required List<GoalProjection> goalProjections,
    required List<FunGroupExpense> groupExpenses,
    required DateTime now,
  }) {
    if (!safeToSpend.hasSufficientData) {
      return const FunFundsResult.insufficientData();
    }

    final budgetCommitted = budgetTotals.remainingBudget > 0
        ? budgetTotals.remainingBudget
        : 0.0;

    final goalCommitted = goalProjections
        .where((g) => g.status != GoalProjectionStatus.completed)
        .fold<double>(0, (sum, g) {
          final required = g.requiredMonthlyContribution;
          if (required == null || required <= 0) return sum;
          return sum + required;
        });

    final afterBudget = _floorAtZero(
      safeToSpend.safeToSpend - budgetCommitted,
    );
    final afterGoals = _floorAtZero(afterBudget - goalCommitted);
    final safetyBuffer = afterGoals * funFundsSafetyBufferFraction;
    final monthlyAvailable = _floorAtZero(afterGoals - safetyBuffer);

    final spentThisMonth = groupExpenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (sum, e) => sum + e.myShare);

    final remaining = _floorAtZero(monthlyAvailable - spentThisMonth);

    final utilizationPercent = monthlyAvailable > 0
        ? (spentThisMonth / monthlyAvailable * 100)
        : (spentThisMonth > 0 ? 100.0 : 0.0);

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemainingInMonth = (daysInMonth - now.day + 1).clamp(
      1,
      daysInMonth,
    );

    final dailyBudget = remaining / daysRemainingInMonth;
    final weeklyBudget = remaining < dailyBudget * 7
        ? remaining
        : dailyBudget * 7;

    return FunFundsResult(
      hasSufficientData: true,
      safeToSpendAvailable: safeToSpend.safeToSpend,
      budgetCommitted: budgetCommitted,
      goalCommitted: goalCommitted,
      safetyBuffer: safetyBuffer,
      monthlyAvailable: monthlyAvailable,
      spentThisMonth: spentThisMonth,
      remaining: remaining,
      utilizationPercent: utilizationPercent,
      dailyBudget: dailyBudget,
      weeklyBudget: weeklyBudget,
      daysRemainingInMonth: daysRemainingInMonth,
    );
  }

  static double _floorAtZero(double value) => value > 0 ? value : 0.0;
}
