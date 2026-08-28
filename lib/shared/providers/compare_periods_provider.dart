import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../utils/compare_periods_calculator.dart';
import 'budget_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

/// COMPARE PERIODS 1.0 (PHASE 2) — a small, dedicated preset enum. Neither
/// [TrendPeriod] (financial_health_trends_calculator.dart) nor
/// [ReportPeriod] (reports_calculator.dart) model TWO independent periods
/// at once, so reusing either would force an awkward fit — this is a
/// genuinely different concept (a PAIR of periods), not a duplicate of
/// either existing abstraction.
enum ComparePeriodsPreset { thisVsLastMonth, last3MonthsVsPrevious3, last6MonthsVsPrevious6, custom }

extension ComparePeriodsPresetLabel on ComparePeriodsPreset {
  String get label {
    switch (this) {
      case ComparePeriodsPreset.thisVsLastMonth:
        return 'This month vs last month';
      case ComparePeriodsPreset.last3MonthsVsPrevious3:
        return 'Last 3 months vs previous 3';
      case ComparePeriodsPreset.last6MonthsVsPrevious6:
        return 'Last 6 months vs previous 6';
      case ComparePeriodsPreset.custom:
        return 'Custom';
    }
  }
}

final comparePeriodsPresetProvider = StateProvider<ComparePeriodsPreset>((ref) {
  return ComparePeriodsPreset.thisVsLastMonth;
});

/// Only read when [comparePeriodsPresetProvider] is [ComparePeriodsPreset.custom]
/// — the month the user picked as the "current" side of a custom comparison.
final compareCustomCurrentMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Only read when [comparePeriodsPresetProvider] is [ComparePeriodsPreset.custom]
/// — the month the user picked as the "comparison" side.
final compareCustomComparisonMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month - 1, 1);
});

final _monthYearFormat = DateFormat('MMMM yyyy');
final _monthFormat = DateFormat('MMM');

String _singleMonthLabel(DateTime month) => _monthYearFormat.format(month);

/// [end] is exclusive (the 1st of the month AFTER the range) — the label
/// covers the last REAL month in the range, i.e. `end` minus one month.
String _rangeLabel(DateTime start, DateTime end) {
  final lastMonth = DateTime(end.year, end.month - 1, 1);
  if (start.year == lastMonth.year && start.month == lastMonth.month) {
    return _singleMonthLabel(start);
  }
  if (start.year == lastMonth.year) {
    return '${_monthFormat.format(start)} - ${_monthYearFormat.format(lastMonth)}';
  }
  return '${_monthYearFormat.format(start)} - ${_monthYearFormat.format(lastMonth)}';
}

(ComparePeriod, ComparePeriod) _periodsForPreset(
  ComparePeriodsPreset preset,
  DateTime now,
  DateTime customCurrentMonth,
  DateTime customComparisonMonth,
) {
  switch (preset) {
    case ComparePeriodsPreset.thisVsLastMonth:
      final currentStart = DateTime(now.year, now.month, 1);
      final currentEnd = DateTime(now.year, now.month + 1, 1);
      final comparisonStart = DateTime(now.year, now.month - 1, 1);
      return (
        ComparePeriod(label: _rangeLabel(currentStart, currentEnd), start: currentStart, end: currentEnd),
        ComparePeriod(label: _rangeLabel(comparisonStart, currentStart), start: comparisonStart, end: currentStart),
      );
    case ComparePeriodsPreset.last3MonthsVsPrevious3:
      return _rollingComparison(now, 3);
    case ComparePeriodsPreset.last6MonthsVsPrevious6:
      return _rollingComparison(now, 6);
    case ComparePeriodsPreset.custom:
      final currentStart = DateTime(customCurrentMonth.year, customCurrentMonth.month, 1);
      final currentEnd = DateTime(customCurrentMonth.year, customCurrentMonth.month + 1, 1);
      final comparisonStart = DateTime(customComparisonMonth.year, customComparisonMonth.month, 1);
      final comparisonEnd = DateTime(customComparisonMonth.year, customComparisonMonth.month + 1, 1);
      return (
        ComparePeriod(label: _rangeLabel(currentStart, currentEnd), start: currentStart, end: currentEnd),
        ComparePeriod(label: _rangeLabel(comparisonStart, comparisonEnd), start: comparisonStart, end: comparisonEnd),
      );
  }
}

/// "Last N months" INCLUDES the current (possibly partial) month plus the
/// (N-1) before it — matching [ReportPeriod.last3Months]/[last6Months]'s
/// existing rolling-window convention exactly, so "3 months" here means
/// the same real calendar window Reports already uses for that phrase.
(ComparePeriod, ComparePeriod) _rollingComparison(DateTime now, int months) {
  final currentEnd = DateTime(now.year, now.month + 1, 1);
  final currentStart = DateTime(currentEnd.year, currentEnd.month - months, 1);
  final comparisonEnd = currentStart;
  final comparisonStart = DateTime(comparisonEnd.year, comparisonEnd.month - months, 1);
  return (
    ComparePeriod(label: _rangeLabel(currentStart, currentEnd), start: currentStart, end: currentEnd),
    ComparePeriod(label: _rangeLabel(comparisonStart, comparisonEnd), start: comparisonStart, end: comparisonEnd),
  );
}

/// Derived, in-memory only — no persistence, no second data store. Reuses
/// the SAME already-watched transactions/wallets/budgets providers every
/// other Reports/Budget/Planning provider already depends on.
final comparePeriodsProvider = Provider<ComparePeriodsResult>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final preset = ref.watch(comparePeriodsPresetProvider);
  final customCurrent = ref.watch(compareCustomCurrentMonthProvider);
  final customComparison = ref.watch(compareCustomComparisonMonthProvider);

  final (currentPeriod, comparisonPeriod) =
      _periodsForPreset(preset, DateTime.now(), customCurrent, customComparison);

  return ComparePeriodsCalculator.calculate(
    transactions: transactions,
    wallets: wallets,
    budgets: budgets,
    currentPeriod: currentPeriod,
    comparisonPeriod: comparisonPeriod,
  );
});
