import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import 'budget_calculator.dart';

/// Phase 6 — Smart Spending Limits
///
/// A pure presentation-layer wrapper over the existing [Budget]/[BudgetCalculator]
/// infrastructure. Every number here comes from an already-computed [Budget]
/// record. No new financial arithmetic is introduced.
///
/// Why not use [BudgetStatus] directly?
/// [BudgetStatus] labels ('On track', 'Near limit', 'Over budget') are generic.
/// This class produces Phase 6 copy that is non-judgmental, time-aware, and
/// category-specific — e.g. "Food is at 72% of your monthly limit."
enum SpendingLimitState {
  /// percentageUsed < [BudgetCalculator.nearLimitThresholdPercent]
  comfortable,

  /// percentageUsed >= [BudgetCalculator.nearLimitThresholdPercent] && < 100
  approaching,

  /// percentageUsed >= 100
  exceeded,
}

/// Status of a single category spending limit for the current period.
@immutable
class SpendingLimitStatus {
  const SpendingLimitStatus({
    required this.categoryId,
    required this.categoryName,
    required this.limitAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.state,
    required this.summaryLine,
    required this.guidanceLine,
  });

  final String categoryId;
  final String categoryName;

  /// The monthly limit (= Budget.allocatedAmount).
  final double limitAmount;

  /// Amount spent so far this period (= Budget.spentAmount).
  final double spentAmount;

  /// limitAmount - spentAmount. May be negative if exceeded.
  final double remainingAmount;

  /// 0–100+ (uncapped when exceeded).
  final double percentageUsed;

  final SpendingLimitState state;

  /// E.g. "Food is at 72% of your monthly limit."
  final String summaryLine;

  /// Non-judgmental guidance, shown on approaching/exceeded only.
  /// Empty string when state is comfortable.
  final String guidanceLine;

  bool get isApproachingOrExceeded =>
      state == SpendingLimitState.approaching ||
      state == SpendingLimitState.exceeded;
}

/// Aggregate across all category limits.
@immutable
class SpendingLimitSummary {
  const SpendingLimitSummary({
    required this.limits,
    required this.approachingCount,
    required this.exceededCount,
    required this.hasBudgets,
  });

  final List<SpendingLimitStatus> limits;
  final int approachingCount;
  final int exceededCount;
  final bool hasBudgets;

  bool get hasAnyAlert => approachingCount > 0 || exceededCount > 0;

  /// Highest-priority limit to surface on the dashboard (exceeded first,
  /// then approaching, then whichever has the highest % used).
  SpendingLimitStatus? get topAlert {
    if (!hasAnyAlert) return null;
    final alerting = limits
        .where((l) => l.isApproachingOrExceeded)
        .toList()
      ..sort((a, b) {
        // exceeded > approaching
        if (a.state != b.state) {
          if (a.state == SpendingLimitState.exceeded) return -1;
          if (b.state == SpendingLimitState.exceeded) return 1;
        }
        return b.percentageUsed.compareTo(a.percentageUsed);
      });
    return alerting.isEmpty ? null : alerting.first;
  }
}

/// Pure, deterministic calculation — no Flutter/Riverpod/Hive dependency.
/// Converts already-computed [Budget] list into [SpendingLimitSummary].
class SpendingLimitCalculator {
  SpendingLimitCalculator._();

  static SpendingLimitSummary calculate({required List<Budget> budgets}) {
    if (budgets.isEmpty) {
      return const SpendingLimitSummary(
        limits: [],
        approachingCount: 0,
        exceededCount: 0,
        hasBudgets: false,
      );
    }

    final limits = budgets.map((b) => _forBudget(b)).toList()
      ..sort((a, b) => b.percentageUsed.compareTo(a.percentageUsed));

    final approachingCount =
        limits.where((l) => l.state == SpendingLimitState.approaching).length;
    final exceededCount =
        limits.where((l) => l.state == SpendingLimitState.exceeded).length;

    return SpendingLimitSummary(
      limits: limits,
      approachingCount: approachingCount,
      exceededCount: exceededCount,
      hasBudgets: true,
    );
  }

  static SpendingLimitStatus _forBudget(Budget b) {
    final pct = b.allocatedAmount > 0
        ? (b.spentAmount / b.allocatedAmount * 100)
        : (b.spentAmount > 0 ? 100.0 : 0.0);

    final state = _stateFor(pct);
    final summary = _summaryLine(b.categoryName, pct);
    final guidance = _guidanceLine(state, b.categoryName, b.remainingAmount);

    return SpendingLimitStatus(
      categoryId: b.categoryId,
      categoryName: b.categoryName,
      limitAmount: b.allocatedAmount,
      spentAmount: b.spentAmount,
      remainingAmount: b.remainingAmount,
      percentageUsed: pct,
      state: state,
      summaryLine: summary,
      guidanceLine: guidance,
    );
  }

  static SpendingLimitState _stateFor(double pct) {
    if (pct >= 100) return SpendingLimitState.exceeded;
    if (pct >= BudgetCalculator.nearLimitThresholdPercent) {
      return SpendingLimitState.approaching;
    }
    return SpendingLimitState.comfortable;
  }

  static String _summaryLine(String category, double pct) {
    final rounded = pct.round().clamp(0, 999);
    return '$category is at $rounded% of your monthly limit.';
  }

  static String _guidanceLine(
    SpendingLimitState state,
    String category,
    double remaining,
  ) {
    switch (state) {
      case SpendingLimitState.comfortable:
        return '';
      case SpendingLimitState.approaching:
        return "You're close to your $category limit. "
            'You still have some room, but keep an eye on the remaining days.';
      case SpendingLimitState.exceeded:
        return "Your $category limit has been reached for this month. "
            'No stress — just something to be aware of going forward.';
    }
  }
}
