import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'budget_calculator.dart';
import 'reports_calculator.dart';

/// COMPARE PERIODS 1.0 — a pure Dart, deterministic calculator. Zero
/// Flutter/Riverpod/Hive/network/AI dependency.
///
/// This is deliberately a thin ADAPTER over [ReportsCalculator] and
/// [BudgetCalculator], not a re-derivation of their formulas:
///
/// - Income/expense/category totals for EACH period are built by calling
///   [ReportsCalculator.calculate] once per constituent calendar month
///   (reusing its exact income/expense-sum and category-grouping logic —
///   `ReportPeriod.thisMonth` resolves purely from the `now` passed to it,
///   so pointing `now` at any past month yields that REAL historical
///   month's real transactions, never a fabricated value) and summing the
///   already-computed monthly results here. This calculator adds no new
///   transaction-summing arithmetic of its own.
/// - The before/after diff primitive (previous/current/percentage/isNew,
///   with the SAME null-safe "never divide by zero" handling) is
///   [ReportChange.compute] — reused as-is, not reimplemented.
/// - Budget comparison reuses [BudgetCalculator.summarize] and
///   [BudgetCalculator.monthNameToNumber] exactly as they already exist.
///
/// LIMITATION (see final report): [FinancialTimelineCalculator] is not
/// integrated here. It's built around ONE window ending at "now"; Compare
/// Periods needs TWO independent, potentially non-recent windows. Forcing
/// that calculator to fit would mean either duplicating its windowing
/// logic or fabricating a false "now" — both are explicitly disallowed by
/// this milestone's own rules, so this is a documented scope boundary
/// rather than a duplicated/guessed implementation.
enum ComparisonDirection { improved, worsened, unchanged, insufficientData }

/// Deliberately SEPARATE from [ComparisonDirection] — category spending
/// changes are never judged "improved"/"worsened" here (a rent increase
/// and an entertainment increase are not equally "bad"), only described
/// neutrally as a real, measured movement.
enum CategoryChangeDirection { increased, decreased, unchanged, insufficientData }

class ComparePeriodsThresholds {
  ComparePeriodsThresholds._();

  /// A new, explicitly documented threshold — "small enough to call the
  /// same value, don't use dramatic language" for a period-to-period
  /// comparison. No existing calculator defines this; it's distinct in
  /// purpose from [FinancialHealthTrendsThresholds]' "material change"
  /// thresholds (which flag when a change IS worth surfacing, not when
  /// two values should be treated as equal).
  static const double unchangedPercentThreshold = 1.0;
  static const double unchangedAbsoluteAmount = 50.0;

  /// How many of the largest category movements to surface — keeps the
  /// UI compact, matching the "keep it compact" precedent already
  /// established by [FinancialActionEngine.maxActions]/
  /// [FinancialInsightEngine.maxInsights] elsewhere in the app (a longer
  /// list is reasonable here since this is a plain list, not an action
  /// queue).
  static const int maxCategoryChanges = 6;
}

@immutable
class ComparePeriod {
  const ComparePeriod({required this.label, required this.start, required this.end});

  final String label;

  /// Inclusive, always the 1st of a month.
  final DateTime start;

  /// Exclusive, always the 1st of a month.
  final DateTime end;
}

/// Wraps a REUSED [ReportChange] with a value-judgment [direction] on top
/// — the calculator's own added interpretation, never a second formula
/// for the underlying numbers.
@immutable
class ComparePeriodMetric {
  const ComparePeriodMetric({required this.change, required this.direction});

  final ReportChange change;
  final ComparisonDirection direction;

  double get currentValue => change.current;
  double get comparisonValue => change.previous;
  double get absoluteDifference => change.current - change.previous;

  /// Null exactly when [ReportChange.percentage] is null (comparison value
  /// was zero) — never a fabricated/infinite percentage.
  double? get percentageDifference => change.percentage;
}

/// Savings rate is expressed in POINTS difference (matching the existing
/// "±X points" convention already used by
/// [FinancialHealthTrendsThresholds.savingsRateChangeThresholdPoints]),
/// never as a percentage-of-a-percentage.
@immutable
class SavingsRateComparison {
  const SavingsRateComparison({
    required this.currentRate,
    required this.comparisonRate,
    required this.pointsDifference,
    required this.direction,
  });

  /// Null when that period's income was zero — never a fabricated rate.
  final double? currentRate;
  final double? comparisonRate;
  final double? pointsDifference;
  final ComparisonDirection direction;
}

@immutable
class CategoryComparison {
  const CategoryComparison({
    required this.categoryId,
    required this.change,
    required this.direction,
  });

  final String categoryId;
  final ReportChange change;
  final CategoryChangeDirection direction;
}

/// Null on [ComparePeriodsResult.budgetComparison] when NEITHER period has
/// any real stored [Budget] record — never fabricated.
@immutable
class ComparePeriodBudgetComparison {
  const ComparePeriodBudgetComparison({
    required this.currentHasBudgets,
    required this.comparisonHasBudgets,
    required this.currentSummary,
    required this.comparisonSummary,
    required this.spentChange,
  });

  final bool currentHasBudgets;
  final bool comparisonHasBudgets;
  final BudgetMonthlySummary currentSummary;
  final BudgetMonthlySummary comparisonSummary;
  final ReportChange spentChange;
}

@immutable
class ComparePeriodsResult {
  const ComparePeriodsResult({
    required this.currentPeriod,
    required this.comparisonPeriod,
    required this.currentPeriodHasData,
    required this.comparisonPeriodHasData,
    required this.hasSufficientData,
    required this.income,
    required this.expense,
    required this.savings,
    required this.savingsRate,
    required this.categoryChanges,
    required this.budgetComparison,
    required this.verdict,
  });

  final ComparePeriod currentPeriod;
  final ComparePeriod comparisonPeriod;

  final bool currentPeriodHasData;
  final bool comparisonPeriodHasData;

  /// True only when BOTH periods have at least one real income/expense
  /// transaction — the calculator never fabricates a comparison when one
  /// side is empty.
  final bool hasSufficientData;

  final ComparePeriodMetric income;
  final ComparePeriodMetric expense;
  final ComparePeriodMetric savings;
  final SavingsRateComparison savingsRate;

  /// Sorted by |absoluteDifference| descending, capped at
  /// [ComparePeriodsThresholds.maxCategoryChanges].
  final List<CategoryComparison> categoryChanges;

  final ComparePeriodBudgetComparison? budgetComparison;

  /// A short, deterministic summary sentence — computed entirely by this
  /// calculator, never by the AI.
  final String verdict;
}

class ComparePeriodsCalculator {
  ComparePeriodsCalculator._();

  static ComparePeriodsResult calculate({
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required List<Budget> budgets,
    required ComparePeriod currentPeriod,
    required ComparePeriod comparisonPeriod,
  }) {
    final currentAgg = _aggregateMonths(transactions, wallets, currentPeriod.start, currentPeriod.end);
    final comparisonAgg = _aggregateMonths(transactions, wallets, comparisonPeriod.start, comparisonPeriod.end);

    final currentHasData = currentAgg.transactionCount > 0;
    final comparisonHasData = comparisonAgg.transactionCount > 0;
    final hasSufficientData = currentHasData && comparisonHasData;

    final incomeChange = ReportChange.compute(comparisonAgg.totalIncome, currentAgg.totalIncome);
    final expenseChange = ReportChange.compute(comparisonAgg.totalExpense, currentAgg.totalExpense);
    final currentSavings = currentAgg.totalIncome - currentAgg.totalExpense;
    final comparisonSavings = comparisonAgg.totalIncome - comparisonAgg.totalExpense;
    final savingsChange = ReportChange.compute(comparisonSavings, currentSavings);

    final income = ComparePeriodMetric(
      change: incomeChange,
      direction: _directionHigherIsBetter(incomeChange, hasSufficientData),
    );
    final expense = ComparePeriodMetric(
      change: expenseChange,
      direction: _directionLowerIsBetter(expenseChange, hasSufficientData),
    );
    final savings = ComparePeriodMetric(
      change: savingsChange,
      direction: _directionHigherIsBetter(savingsChange, hasSufficientData),
    );

    final currentRate = currentAgg.totalIncome > 0 ? (currentSavings / currentAgg.totalIncome * 100) : null;
    final comparisonRate =
        comparisonAgg.totalIncome > 0 ? (comparisonSavings / comparisonAgg.totalIncome * 100) : null;
    final savingsRate = _savingsRateComparison(currentRate, comparisonRate);

    final categoryChanges = _categoryChanges(currentAgg.categoryTotals, comparisonAgg.categoryTotals);
    final budgetComparison = _budgetComparison(budgets, currentPeriod, comparisonPeriod);

    final verdict = _verdict(
      hasSufficientData: hasSufficientData,
      currentHasData: currentHasData,
      comparisonHasData: comparisonHasData,
      income: income,
      expense: expense,
      savings: savings,
      savingsRate: savingsRate,
    );

    return ComparePeriodsResult(
      currentPeriod: currentPeriod,
      comparisonPeriod: comparisonPeriod,
      currentPeriodHasData: currentHasData,
      comparisonPeriodHasData: comparisonHasData,
      hasSufficientData: hasSufficientData,
      income: income,
      expense: expense,
      savings: savings,
      savingsRate: savingsRate,
      categoryChanges: categoryChanges,
      budgetComparison: budgetComparison,
      verdict: verdict,
    );
  }

  // -------------------------------------------------------------------
  // Monthly aggregation — walks each real calendar month in [start, end)
  // via ReportsCalculator.calculate(period: thisMonth, now: monthCursor),
  // summing its already-computed totals. No transaction-summing formula
  // of its own.
  // -------------------------------------------------------------------

  static _PeriodAggregate _aggregateMonths(
    List<Transaction> transactions,
    List<Wallet> wallets,
    DateTime start,
    DateTime end,
  ) {
    double totalIncome = 0;
    double totalExpense = 0;
    var transactionCount = 0;
    final categoryTotals = <String, double>{};

    var cursor = DateTime(start.year, start.month, 1);
    final normalizedEnd = DateTime(end.year, end.month, 1);
    while (cursor.isBefore(normalizedEnd)) {
      final monthResult = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        period: ReportPeriod.thisMonth,
        now: cursor,
      );
      totalIncome += monthResult.totalIncome;
      totalExpense += monthResult.totalExpense;
      transactionCount += monthResult.transactionCount;
      for (final category in monthResult.categoryBreakdown) {
        categoryTotals[category.categoryId] = (categoryTotals[category.categoryId] ?? 0) + category.amount;
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return _PeriodAggregate(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transactionCount: transactionCount,
      categoryTotals: categoryTotals,
    );
  }

  // -------------------------------------------------------------------
  // Direction classification — the calculator's own added interpretation
  // on top of ReportChange's reused, neutral numbers.
  // -------------------------------------------------------------------

  static ComparisonDirection _directionHigherIsBetter(ReportChange change, bool hasSufficientData) {
    if (!hasSufficientData) return ComparisonDirection.insufficientData;
    final diff = change.current - change.previous;
    if (diff.abs() < ComparePeriodsThresholds.unchangedAbsoluteAmount &&
        (change.percentage == null || change.percentage!.abs() < ComparePeriodsThresholds.unchangedPercentThreshold)) {
      return ComparisonDirection.unchanged;
    }
    return diff > 0 ? ComparisonDirection.improved : ComparisonDirection.worsened;
  }

  static ComparisonDirection _directionLowerIsBetter(ReportChange change, bool hasSufficientData) {
    final base = _directionHigherIsBetter(change, hasSufficientData);
    if (base == ComparisonDirection.improved) return ComparisonDirection.worsened;
    if (base == ComparisonDirection.worsened) return ComparisonDirection.improved;
    return base;
  }

  static SavingsRateComparison _savingsRateComparison(double? currentRate, double? comparisonRate) {
    if (currentRate == null || comparisonRate == null) {
      return SavingsRateComparison(
        currentRate: currentRate,
        comparisonRate: comparisonRate,
        pointsDifference: null,
        direction: ComparisonDirection.insufficientData,
      );
    }
    final points = currentRate - comparisonRate;
    final direction = points.abs() < 0.5
        ? ComparisonDirection.unchanged
        : (points > 0 ? ComparisonDirection.improved : ComparisonDirection.worsened);
    return SavingsRateComparison(
      currentRate: currentRate,
      comparisonRate: comparisonRate,
      pointsDifference: points,
      direction: direction,
    );
  }

  // -------------------------------------------------------------------
  // Category changes — neutral direction only, never "improved"/"worsened".
  // -------------------------------------------------------------------

  static List<CategoryComparison> _categoryChanges(
    Map<String, double> currentTotals,
    Map<String, double> comparisonTotals,
  ) {
    final allCategories = <String>{...currentTotals.keys, ...comparisonTotals.keys};
    final changes = allCategories.map((categoryId) {
      final current = currentTotals[categoryId] ?? 0;
      final comparison = comparisonTotals[categoryId] ?? 0;
      final change = ReportChange.compute(comparison, current);
      final diff = current - comparison;

      CategoryChangeDirection direction;
      if (diff.abs() < ComparePeriodsThresholds.unchangedAbsoluteAmount &&
          (change.percentage == null || change.percentage!.abs() < ComparePeriodsThresholds.unchangedPercentThreshold)) {
        direction = CategoryChangeDirection.unchanged;
      } else {
        direction = diff > 0 ? CategoryChangeDirection.increased : CategoryChangeDirection.decreased;
      }

      return CategoryComparison(categoryId: categoryId, change: change, direction: direction);
    }).toList();

    changes.sort((a, b) => (b.change.current - b.change.previous).abs().compareTo(
          (a.change.current - a.change.previous).abs(),
        ));

    return changes.take(ComparePeriodsThresholds.maxCategoryChanges).toList();
  }

  // -------------------------------------------------------------------
  // Budget comparison — reuses BudgetCalculator.summarize/monthNameToNumber
  // exactly as-is. Null when neither period has a real stored Budget row.
  // -------------------------------------------------------------------

  static ComparePeriodBudgetComparison? _budgetComparison(
    List<Budget> budgets,
    ComparePeriod currentPeriod,
    ComparePeriod comparisonPeriod,
  ) {
    final currentBudgets = _budgetsInRange(budgets, currentPeriod.start, currentPeriod.end);
    final comparisonBudgets = _budgetsInRange(budgets, comparisonPeriod.start, comparisonPeriod.end);
    if (currentBudgets.isEmpty && comparisonBudgets.isEmpty) {
      return null;
    }

    final currentSummary = BudgetCalculator.summarize(currentBudgets);
    final comparisonSummary = BudgetCalculator.summarize(comparisonBudgets);
    final spentChange = ReportChange.compute(comparisonSummary.totalSpent, currentSummary.totalSpent);

    return ComparePeriodBudgetComparison(
      currentHasBudgets: currentBudgets.isNotEmpty,
      comparisonHasBudgets: comparisonBudgets.isNotEmpty,
      currentSummary: currentSummary,
      comparisonSummary: comparisonSummary,
      spentChange: spentChange,
    );
  }

  static List<Budget> _budgetsInRange(List<Budget> budgets, DateTime start, DateTime end) {
    return budgets.where((budget) {
      final month = DateTime(budget.year, BudgetCalculator.monthNameToNumber(budget.month), 1);
      return !month.isBefore(start) && month.isBefore(end);
    }).toList();
  }

  // -------------------------------------------------------------------
  // Verdict — deterministic, never AI-generated.
  // -------------------------------------------------------------------

  static String _verdict({
    required bool hasSufficientData,
    required bool currentHasData,
    required bool comparisonHasData,
    required ComparePeriodMetric income,
    required ComparePeriodMetric expense,
    required ComparePeriodMetric savings,
    required SavingsRateComparison savingsRate,
  }) {
    if (!currentHasData && !comparisonHasData) {
      return 'Add some transactions to compare your financial periods.';
    }
    if (!hasSufficientData) {
      return "There's not enough historical data to make a meaningful comparison.";
    }

    final directions = [income.direction, expense.direction, savings.direction];
    final improvedCount = directions.where((d) => d == ComparisonDirection.improved).length;
    final worsenedCount = directions.where((d) => d == ComparisonDirection.worsened).length;
    final rateUnchangedOrUnknown = savingsRate.direction == ComparisonDirection.unchanged ||
        savingsRate.direction == ComparisonDirection.insufficientData;

    if (improvedCount == 0 && worsenedCount == 0 && rateUnchangedOrUnknown) {
      return 'No meaningful change.';
    }
    if (worsenedCount == 0 && improvedCount > 0) {
      return "You're financially stronger than the previous period.";
    }
    if (improvedCount == 0 && worsenedCount > 0) {
      return 'Your financial position weakened compared with the previous period.';
    }
    if (income.direction == ComparisonDirection.unchanged && expense.direction == ComparisonDirection.worsened) {
      return 'Your income is stable, but expenses increased.';
    }
    if (savings.direction == ComparisonDirection.improved && expense.direction == ComparisonDirection.worsened) {
      return 'Your savings improved, but discretionary spending needs attention.';
    }
    return 'Your finances show mixed changes compared with the previous period.';
  }
}

class _PeriodAggregate {
  const _PeriodAggregate({
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    required this.categoryTotals,
  });

  final double totalIncome;
  final double totalExpense;
  final int transactionCount;
  final Map<String, double> categoryTotals;
}
