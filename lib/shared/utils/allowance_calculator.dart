import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/transaction.dart';
import 'budget_calculator.dart';
import 'safe_to_spend_calculator.dart';

/// Phase 6 — Discretionary Allowance Calculator
///
/// Deterministic, awareness-oriented classification of discretionary spending
/// against an allowance. Supports shame-free visibility into discretionary funds.

/// Classification of the user's spending against their allowance.
enum AllowanceState {
  /// Spending is well within the allowance (< 70%).
  comfortable,

  /// Spending is approaching the allowance limit (>= 70% and < 90%).
  watchful,

  /// Remaining allowance is running low (>= 90% and <= 100%).
  tight,

  /// Spending has exceeded the planned allowance (> 100%).
  overAllowance,
}

extension AllowanceStateLabel on AllowanceState {
  String get label {
    switch (this) {
      case AllowanceState.comfortable:
        return 'Comfortable';
      case AllowanceState.watchful:
        return 'Watchful';
      case AllowanceState.tight:
        return 'Tight';
      case AllowanceState.overAllowance:
        return 'Over allowance';
    }
  }
}

/// Result of an [AllowanceCalculator] evaluation.
/// Every field is deterministic, finite, and non-null.
@immutable
class AllowanceResult {
  const AllowanceResult({
    required this.totalAllowance,
    required this.spentAmount,
    required this.remainingAllowance,
    required this.percentageUsed,
    required this.state,
    required this.summaryLine,
    required this.guidanceLine,
    required this.hasSufficientData,
  });

  /// The total discretionary allowance allocated for the period.
  final double totalAllowance;

  /// Amount spent against this allowance.
  final double spentAmount;

  /// `totalAllowance - spentAmount`. Can be negative if over allowance.
  final double remainingAllowance;

  /// Percentage of allowance used (0–100+). Always finite, never NaN/Infinity.
  final double percentageUsed;

  /// Awareness classification.
  final AllowanceState state;

  /// Clear, concise summary message.
  final String summaryLine;

  /// Supportive, non-punitive guidance message.
  final String guidanceLine;

  /// True when input data contains non-zero allowance or spending activity.
  final bool hasSufficientData;

  /// Convenience getter: remaining allowance floored at zero for safe display.
  double get safeRemaining => remainingAllowance > 0 ? remainingAllowance : 0.0;

  /// How much spending exceeded the allowance, or 0.0 if within allowance.
  double get overspendAmount =>
      remainingAllowance < 0 ? -remainingAllowance : 0.0;

  bool get isOverAllowance => state == AllowanceState.overAllowance;
  bool get isTight => state == AllowanceState.tight;
  bool get isWatchful => state == AllowanceState.watchful;
  bool get isComfortable => state == AllowanceState.comfortable;
}

/// Pure, deterministic calculator for discretionary allowance tracking.
class AllowanceCalculator {
  AllowanceCalculator._();

  static const double watchfulThresholdPercent = 70.0;
  static const double tightThresholdPercent = 90.0;
  static const double overAllowanceThresholdPercent = 100.0;

  /// Evaluates spending against total allowance.
  static AllowanceResult calculate({
    required double totalAllowance,
    required double spentAmount,
  }) {
    final safeTotal =
        (totalAllowance.isNaN || totalAllowance.isInfinite || totalAllowance < 0)
            ? 0.0
            : totalAllowance;
    final safeSpent =
        (spentAmount.isNaN || spentAmount.isInfinite || spentAmount < 0)
            ? 0.0
            : spentAmount;

    final remaining = safeTotal - safeSpent;
    final hasData = safeTotal > 0 || safeSpent > 0;

    final double pct;
    final AllowanceState state;

    if (safeTotal <= 0) {
      if (safeSpent > 0) {
        pct = 100.0;
        state = AllowanceState.overAllowance;
      } else {
        pct = 0.0;
        state = AllowanceState.comfortable;
      }
    } else {
      pct = safeSpent / safeTotal * 100.0;
      if (pct > overAllowanceThresholdPercent) {
        state = AllowanceState.overAllowance;
      } else if (pct >= tightThresholdPercent) {
        state = AllowanceState.tight;
      } else if (pct >= watchfulThresholdPercent) {
        state = AllowanceState.watchful;
      } else {
        state = AllowanceState.comfortable;
      }
    }

    final summary = _summaryLine(
      safeTotal: safeTotal,
      safeSpent: safeSpent,
      remaining: remaining,
      pct: pct,
      state: state,
      hasData: hasData,
    );

    final guidance = _guidanceLine(
      state: state,
      remaining: remaining,
      hasData: hasData,
    );

    return AllowanceResult(
      totalAllowance: safeTotal,
      spentAmount: safeSpent,
      remainingAllowance: remaining,
      percentageUsed: pct,
      state: state,
      summaryLine: summary,
      guidanceLine: guidance,
      hasSufficientData: hasData,
    );
  }

  /// Convenience adapter computing allowance from an existing [SafeToSpendResult].
  static AllowanceResult fromSafeToSpend({
    required SafeToSpendResult safeToSpend,
    required double spentAmount,
  }) {
    if (!safeToSpend.hasSufficientData) {
      return calculate(totalAllowance: 0, spentAmount: 0);
    }
    final total = safeToSpend.safeToSpend + spentAmount;
    return calculate(totalAllowance: total, spentAmount: spentAmount);
  }

  /// Convenience adapter computing aggregate allowance from [Budget] list.
  static AllowanceResult fromBudgets({
    required List<Budget> budgets,
  }) {
    if (budgets.isEmpty) {
      return calculate(totalAllowance: 0, spentAmount: 0);
    }
    final summary = BudgetCalculator.summarize(budgets);
    return calculate(
      totalAllowance: summary.totalBudget,
      spentAmount: summary.totalSpent,
    );
  }

  /// Convenience adapter computing spending from transactions against an allowance.
  static AllowanceResult fromTransactions({
    required double totalAllowance,
    required List<Transaction> transactions,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? categoryId,
  }) {
    double spent = 0.0;
    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      if (periodStart != null && t.createdAt.isBefore(periodStart)) continue;
      if (periodEnd != null && t.createdAt.isAfter(periodEnd)) continue;
      spent += t.amount;
    }
    return calculate(totalAllowance: totalAllowance, spentAmount: spent);
  }

  static String _summaryLine({
    required double safeTotal,
    required double safeSpent,
    required double remaining,
    required double pct,
    required AllowanceState state,
    required bool hasData,
  }) {
    if (!hasData) {
      return 'No allowance data available.';
    }
    if (state == AllowanceState.overAllowance && safeTotal <= 0) {
      return 'Spending recorded without an allocated allowance.';
    }
    final rounded = pct.round().clamp(0, 999);
    return 'You have used $rounded% of your discretionary allowance.';
  }

  static String _guidanceLine({
    required AllowanceState state,
    required double remaining,
    required bool hasData,
  }) {
    if (!hasData) {
      return 'Set up your spending allowance to track discretionary money.';
    }
    switch (state) {
      case AllowanceState.comfortable:
        return 'Your spending is comfortably within your planned allowance.';
      case AllowanceState.watchful:
        return "You're approaching your allowance threshold. Keep an eye on upcoming discretionary spending.";
      case AllowanceState.tight:
        return 'Your remaining allowance is running low for this period. Pace your discretionary spending.';
      case AllowanceState.overAllowance:
        return "You've moved past your planned allowance for this period. No stress — awareness is the first step.";
    }
  }
}
