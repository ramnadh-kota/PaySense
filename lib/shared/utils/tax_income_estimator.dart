import 'package:flutter/foundation.dart';

import '../models/transaction.dart';

/// PHASE 3 — derives an annual income ESTIMATE from PaySense's own income
/// transaction history. This is explicitly NOT authoritative tax income —
/// every caller must label it "Estimated from PaySense income history" and
/// let the user override it with a manually-confirmed actual annual income
/// (see PHASE 3's "Use my actual annual income"). This class never mutates
/// anything and never claims certainty it doesn't have.
@immutable
class IncomeEstimate {
  const IncomeEstimate({
    required this.observedIncome,
    required this.averageMonthlyIncome,
    required this.estimatedAnnualIncome,
    required this.estimationPeriodLabel,
    required this.observedMonths,
    required this.isEstimate,
    required this.hasIncomeData,
    required this.isIrregular,
  });

  /// Sum of income-type transactions actually observed in the current
  /// financial year so far.
  final double observedIncome;

  final double averageMonthlyIncome;

  /// averageMonthlyIncome * 12 — a projection, never PaySense's claim of
  /// the user's real annual income.
  final double estimatedAnnualIncome;

  /// Human-readable window this was derived from, e.g. "Apr 2026 - Aug 2026
  /// (5 months)".
  final String estimationPeriodLabel;

  final int observedMonths;

  /// Always true for this class — a marker so callers never need to
  /// re-derive "is this a real figure or an estimate" from context.
  final bool isEstimate;

  final bool hasIncomeData;

  /// True when at least one elapsed month in the financial-year-to-date
  /// window had NO income transaction at all — a simple gap heuristic, not
  /// a statistical regularity model. Callers should surface this so the
  /// user understands why the estimate might be unreliable.
  final bool isIrregular;
}

/// Pure, deterministic income estimation. No Flutter/Riverpod/Hive
/// dependency — takes an already-loaded transaction list.
class TaxIncomeEstimator {
  TaxIncomeEstimator._();

  static (DateTime start, DateTime end) financialYearBounds(DateTime now) {
    final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    return (DateTime(fyStartYear, 4, 1), DateTime(fyStartYear + 1, 3, 31));
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Estimates annual income from [transactions]' income entries within the
  /// current financial year up to and including [now]'s month.
  static IncomeEstimate estimate(List<Transaction> transactions, DateTime now) {
    final (fyStart, _) = financialYearBounds(now);
    final currentMonthStart = DateTime(now.year, now.month, 1);

    // Every elapsed calendar month from FY start through the current month,
    // inclusive — the denominator for both the average and the gap check.
    final elapsedMonths = <DateTime>[];
    var cursor = fyStart;
    while (!cursor.isAfter(currentMonthStart)) {
      elapsedMonths.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    final incomeByMonth = <DateTime, double>{for (final m in elapsedMonths) m: 0};
    for (final transaction in transactions) {
      if (transaction.transactionType.toLowerCase() != 'income') continue;
      final txMonth = DateTime(transaction.createdAt.year, transaction.createdAt.month, 1);
      if (!incomeByMonth.containsKey(txMonth)) continue; // outside FY-to-date window
      incomeByMonth[txMonth] = (incomeByMonth[txMonth] ?? 0) + transaction.amount;
    }

    final observedIncome = incomeByMonth.values.fold<double>(0, (sum, v) => sum + v);
    final observedMonths = elapsedMonths.length;
    final hasIncomeData = observedIncome > 0;
    final isIrregular = hasIncomeData && incomeByMonth.values.any((v) => v <= 0);

    final averageMonthlyIncome = observedMonths > 0 ? observedIncome / observedMonths : 0.0;
    final estimatedAnnualIncome = averageMonthlyIncome * 12;

    final periodLabel = elapsedMonths.isEmpty
        ? 'No data'
        : '${_monthLabel(elapsedMonths.first)} - ${_monthLabel(elapsedMonths.last)} '
            '($observedMonths month${observedMonths == 1 ? '' : 's'})';

    return IncomeEstimate(
      observedIncome: observedIncome,
      averageMonthlyIncome: averageMonthlyIncome,
      estimatedAnnualIncome: estimatedAnnualIncome,
      estimationPeriodLabel: periodLabel,
      observedMonths: observedMonths,
      isEstimate: true,
      hasIncomeData: hasIncomeData,
      isIrregular: isIrregular,
    );
  }

  static String _monthLabel(DateTime date) => '${_monthNames[date.month - 1]} ${date.year}';
}
