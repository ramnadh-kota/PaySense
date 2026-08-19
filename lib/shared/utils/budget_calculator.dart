import 'package:flutter/foundation.dart';

import '../models/budget.dart';

/// Deterministic classification of how a budget is tracking against its
/// allocation. Thresholds are centralized here — nowhere in the UI should
/// hardcode 80/100 again.
enum BudgetStatus { underBudget, nearLimit, overBudget }

extension BudgetStatusLabel on BudgetStatus {
  String get label {
    switch (this) {
      case BudgetStatus.underBudget:
        return 'On track';
      case BudgetStatus.nearLimit:
        return 'Near limit';
      case BudgetStatus.overBudget:
        return 'Over budget';
    }
  }
}

/// Aggregate budgeted/spent/remaining across a set of budgets — powers both
/// the Dashboard's existing budget card and the Budget screen's overview,
/// via the same single formula.
@immutable
class BudgetMonthlySummary {
  const BudgetMonthlySummary({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
    required this.overallPercentageUsed,
  });

  final double totalBudget;
  final double totalSpent;

  /// `totalBudget - totalSpent` — never floored at 0. A negative value
  /// means the combined budgets are genuinely overspent.
  final double totalRemaining;

  /// 0 when [totalBudget] is 0 (never NaN/Infinity) — otherwise
  /// `totalSpent / totalBudget * 100`, uncapped.
  final double overallPercentageUsed;
}

/// How much, and across how many categories, the user is over budget —
/// powers the "You are ₹X over budget across Y categories" summary.
@immutable
class BudgetOverspendSummary {
  const BudgetOverspendSummary({
    required this.categoryCount,
    required this.totalOverspend,
  });

  final int categoryCount;

  /// Always >= 0 — the positive sum of how far each over-budget category
  /// exceeded its allocation.
  final double totalOverspend;

  bool get hasOverspend => categoryCount > 0;
}

/// One before/after comparison (budget or spend) between two months, safe
/// against a zero previous value — see [percentage]/[isNew].
@immutable
class BudgetChangeValue {
  const BudgetChangeValue({
    required this.previous,
    required this.current,
    required this.percentage,
    required this.isNew,
  });

  final double previous;
  final double current;

  /// Null whenever a percentage would be meaningless (previous was 0) —
  /// never NaN/Infinity.
  final double? percentage;

  /// True when the previous value was 0 and the current value is
  /// positive — the "New this month" case.
  final bool isNew;

  factory BudgetChangeValue.compute(double previous, double current) {
    if (previous == 0) {
      return BudgetChangeValue(
        previous: previous,
        current: current,
        percentage: null,
        isNew: current > 0,
      );
    }
    return BudgetChangeValue(
      previous: previous,
      current: current,
      percentage: (current - previous) / previous.abs() * 100,
      isNew: false,
    );
  }
}

/// Budget-total and spend-total change between the current and previous
/// month, for the same set of categories' worth of budgeting.
@immutable
class BudgetPeriodComparison {
  const BudgetPeriodComparison({
    required this.budgetChange,
    required this.spentChange,
  });

  final BudgetChangeValue budgetChange;
  final BudgetChangeValue spentChange;
}

/// One calendar month's worth of budgets, aggregated — powers Budget
/// History. Only ever built from months where the user actually created at
/// least one [Budget] record; never a fabricated/interpolated month.
@immutable
class BudgetMonthGroup {
  const BudgetMonthGroup({
    required this.month,
    required this.year,
    required this.summary,
    required this.status,
  });

  final String month;
  final int year;
  final BudgetMonthlySummary summary;
  final BudgetStatus status;
}

/// Pure, deterministic Budget analysis. No Flutter/Riverpod/Hive
/// dependency — operates entirely on the [Budget] records the existing
/// [BudgetRepository]/`BudgetsNotifier` already compute (via
/// `Budget.updateMetrics`), never recomputing `spentAmount` itself and
/// never touching a transaction, wallet, or category identifier. This is
/// classification/sorting/aggregation over already-derived data, not a
/// second financial calculation engine.
class BudgetCalculator {
  BudgetCalculator._();

  static const double nearLimitThresholdPercent = 80.0;
  static const double overBudgetThresholdPercent = 100.0;

  /// `allocatedAmount <= 0` is handled without dividing by zero: any actual
  /// spend against a zero/negative budget is definitionally over budget;
  /// no spend at all is under budget.
  static BudgetStatus statusFor({
    required double allocatedAmount,
    required double spentAmount,
  }) {
    if (allocatedAmount <= 0) {
      return spentAmount > 0 ? BudgetStatus.overBudget : BudgetStatus.underBudget;
    }
    final percentage = spentAmount / allocatedAmount * 100;
    if (percentage > overBudgetThresholdPercent) {
      return BudgetStatus.overBudget;
    }
    if (percentage >= nearLimitThresholdPercent) {
      return BudgetStatus.nearLimit;
    }
    return BudgetStatus.underBudget;
  }

  static BudgetStatus statusForBudget(Budget budget) => statusFor(
    allocatedAmount: budget.allocatedAmount,
    spentAmount: budget.spentAmount,
  );

  /// Over-budget first, then near-limit, then under-budget; within the
  /// same status, highest percentage used first.
  static List<Budget> sortByPerformance(List<Budget> budgets) {
    final sorted = List<Budget>.of(budgets);
    sorted.sort((a, b) {
      final rankA = _statusRank(statusForBudget(a));
      final rankB = _statusRank(statusForBudget(b));
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return b.percentageUsed.compareTo(a.percentageUsed);
    });
    return sorted;
  }

  static int _statusRank(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.overBudget:
        return 0;
      case BudgetStatus.nearLimit:
        return 1;
      case BudgetStatus.underBudget:
        return 2;
    }
  }

  static BudgetMonthlySummary summarize(List<Budget> budgets) {
    final totalBudget = budgets.fold<double>(
      0,
      (sum, b) => sum + b.allocatedAmount,
    );
    final totalSpent = budgets.fold<double>(
      0,
      (sum, b) => sum + b.spentAmount,
    );
    return BudgetMonthlySummary(
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      totalRemaining: totalBudget - totalSpent,
      overallPercentageUsed: totalBudget > 0 ? totalSpent / totalBudget * 100 : 0.0,
    );
  }

  static BudgetOverspendSummary overspendSummary(List<Budget> budgets) {
    final overBudgets = budgets
        .where((b) => statusForBudget(b) == BudgetStatus.overBudget)
        .toList();
    final totalOverspend = overBudgets.fold<double>(
      0,
      (sum, b) => sum + (b.spentAmount - b.allocatedAmount),
    );
    return BudgetOverspendSummary(
      categoryCount: overBudgets.length,
      totalOverspend: totalOverspend,
    );
  }

  static int nearLimitCount(List<Budget> budgets) {
    return budgets
        .where((b) => statusForBudget(b) == BudgetStatus.nearLimit)
        .length;
  }

  /// Groups every stored budget by (year, month) and summarizes each —
  /// newest month first. Only months where the user actually created a
  /// budget appear; nothing is fabricated for a month with no records.
  static List<BudgetMonthGroup> history(List<Budget> allBudgets) {
    final grouped = <String, List<Budget>>{};
    for (final budget in allBudgets) {
      final key = '${budget.year}-${budget.month}';
      grouped.putIfAbsent(key, () => []).add(budget);
    }

    final groups = grouped.values.map((monthBudgets) {
      final summary = summarize(monthBudgets);
      return BudgetMonthGroup(
        month: monthBudgets.first.month,
        year: monthBudgets.first.year,
        summary: summary,
        status: statusFor(
          allocatedAmount: summary.totalBudget,
          spentAmount: summary.totalSpent,
        ),
      );
    }).toList();

    groups.sort((a, b) {
      final aDate = DateTime(a.year, monthNameToNumber(a.month));
      final bDate = DateTime(b.year, monthNameToNumber(b.month));
      return bDate.compareTo(aDate);
    });
    return groups;
  }

  /// Budget-total and spend-total change between two months' worth of
  /// budgets — e.g. the current calendar month vs. the previous one.
  static BudgetPeriodComparison compareMonths({
    required List<Budget> currentMonthBudgets,
    required List<Budget> previousMonthBudgets,
  }) {
    final current = summarize(currentMonthBudgets);
    final previous = summarize(previousMonthBudgets);
    return BudgetPeriodComparison(
      budgetChange: BudgetChangeValue.compute(
        previous.totalBudget,
        current.totalBudget,
      ),
      spentChange: BudgetChangeValue.compute(
        previous.totalSpent,
        current.totalSpent,
      ),
    );
  }

  /// Same small lookup `BudgetRepository` already uses internally to match
  /// `Budget.month`/`.year` against real transaction dates — duplicated
  /// here (rather than imported) only because it's a private helper there;
  /// this is a 12-entry lookup table, not a second calculation engine.
  static int monthNameToNumber(String monthName) {
    switch (monthName.toLowerCase()) {
      case 'january':
        return 1;
      case 'february':
        return 2;
      case 'march':
        return 3;
      case 'april':
        return 4;
      case 'may':
        return 5;
      case 'june':
        return 6;
      case 'july':
        return 7;
      case 'august':
        return 8;
      case 'september':
        return 9;
      case 'october':
        return 10;
      case 'november':
        return 11;
      case 'december':
        return 12;
      default:
        return 0;
    }
  }
}
