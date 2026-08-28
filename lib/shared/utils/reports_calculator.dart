import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';

/// How far back "Top expenses" shows by default before "View all" is
/// needed — matches the spec's explicit "limit to 5" instruction.
const int reportsTopExpensesLimit = 5;

enum ReportPeriod {
  thisWeek,
  thisMonth,
  lastMonth,
  last3Months,
  last6Months,
  lastYear,
}

extension ReportPeriodLabel on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.thisWeek:
        return 'This week';
      case ReportPeriod.thisMonth:
        return 'This month';
      case ReportPeriod.lastMonth:
        return 'Last month';
      case ReportPeriod.last3Months:
        return '3 months';
      case ReportPeriod.last6Months:
        return '6 months';
      case ReportPeriod.lastYear:
        return '1 year';
    }
  }
}

/// The concrete calendar window a [ReportPeriod] resolves to at a given
/// moment, plus the immediately-preceding window of equal length used for
/// the month-over-month (period-over-period) comparison. [start] is
/// inclusive, [end]/[previousEnd] are exclusive.
@immutable
class ReportDateRange {
  const ReportDateRange({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
  });

  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;
}

/// A single category's share of total expenses within the selected period.
@immutable
class ReportCategoryBreakdown {
  const ReportCategoryBreakdown({
    required this.categoryId,
    required this.amount,
    required this.percentage,
  });

  final String categoryId;
  final double amount;

  /// 0-100, of total expenses in the period. 0 when total expenses are 0
  /// (never NaN/Infinity).
  final double percentage;
}

/// One of the largest individual expenses in the selected period.
@immutable
class ReportTopExpense {
  const ReportTopExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.walletId,
    required this.walletName,
  });

  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String walletId;

  /// The wallet's display name, resolved once here so the UI never has to
  /// re-look it up — "Unknown wallet" for a (legacy/unresolvable) accountId
  /// that doesn't match any current wallet, never fabricated.
  final String walletName;
}

/// Income/expense/net for a single wallet within the selected period.
/// Attribution is always by `Wallet.id`, never by name.
@immutable
class ReportWalletBreakdown {
  const ReportWalletBreakdown({
    required this.walletId,
    required this.walletName,
    required this.income,
    required this.expense,
  });

  final String walletId;
  final String walletName;
  final double income;
  final double expense;

  double get net => income - expense;
}

/// Income/expense/net for one calendar month — powers the Income vs Expense
/// chart, one bar per month in the selected period.
@immutable
class ReportMonthTotal {
  const ReportMonthTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  /// Always the 1st of the month.
  final DateTime month;
  final double income;
  final double expense;

  double get net => income - expense;
}

/// A single before/after comparison (income, expense, or net) between the
/// selected period and the immediately-preceding period of equal length.
/// [percentage] is null whenever a percentage would be meaningless (the
/// previous value was zero) rather than ever showing a fabricated/infinite
/// number — [isNew] distinguishes "previous was zero, current is positive"
/// (worth a "new this period" message) from "both were zero" (nothing to
/// say at all).
@immutable
class ReportChange {
  const ReportChange({
    required this.previous,
    required this.current,
    required this.percentage,
    required this.isNew,
  });

  final double previous;
  final double current;
  final double? percentage;
  final bool isNew;

  factory ReportChange.compute(double previous, double current) {
    if (previous == 0) {
      return ReportChange(
        previous: previous,
        current: current,
        percentage: null,
        isNew: current > 0,
      );
    }
    return ReportChange(
      previous: previous,
      current: current,
      // previous.abs() as the denominator so a swing across zero (e.g. net
      // cash flow going from -500 to +500) still produces a finite,
      // directionally-sensible percentage instead of a sign-flipped one.
      percentage: (current - previous) / previous.abs() * 100,
      isNew: false,
    );
  }
}

/// Income/expense/net for the selected period vs. the immediately-preceding
/// period of equal length.
@immutable
class ReportPeriodComparison {
  const ReportPeriodComparison({
    required this.currentIncome,
    required this.previousIncome,
    required this.currentExpense,
    required this.previousExpense,
  });

  final double currentIncome;
  final double previousIncome;
  final double currentExpense;
  final double previousExpense;

  double get currentNet => currentIncome - currentExpense;
  double get previousNet => previousIncome - previousExpense;

  ReportChange get incomeChange =>
      ReportChange.compute(previousIncome, currentIncome);
  ReportChange get expenseChange =>
      ReportChange.compute(previousExpense, currentExpense);
  ReportChange get netChange => ReportChange.compute(previousNet, currentNet);
}

/// Everything the Reports screen needs for one selected period — computed
/// once, consumed by every section of the UI. Never mutates any of its
/// inputs; purely derived, read-only data.
@immutable
class ReportsResult {
  const ReportsResult({
    required this.period,
    required this.range,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    required this.categoryBreakdown,
    required this.topExpenses,
    required this.walletBreakdown,
    required this.monthlyTotals,
    required this.comparison,
    required this.insights,
  });

  final ReportPeriod period;
  final ReportDateRange range;
  final double totalIncome;
  final double totalExpense;

  /// Count of income+expense transactions in the period (transfers
  /// excluded) — used to distinguish "no transactions at all" from
  /// "transactions exist but none are income/expense".
  final int transactionCount;

  final List<ReportCategoryBreakdown> categoryBreakdown;
  final List<ReportTopExpense> topExpenses;
  final List<ReportWalletBreakdown> walletBreakdown;
  final List<ReportMonthTotal> monthlyTotals;
  final ReportPeriodComparison comparison;
  final List<String> insights;

  double get netCashFlow => totalIncome - totalExpense;

  /// Null when income is zero — dividing by zero is never attempted; the
  /// UI shows a neutral placeholder instead of NaN/Infinity.
  double? get savingsRate =>
      totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome * 100 : null;

  bool get hasAnyTransactions => transactionCount > 0;
  bool get hasIncome => totalIncome > 0;
  bool get hasExpense => totalExpense > 0;
}

/// Pure, deterministic Reports calculation. No Flutter/Riverpod dependency;
/// transforms already-stored [Transaction]/[Wallet] data — never fabricates
/// values, never calls OpenAI/the backend, never re-derives figures that
/// Safe-to-Spend/Cash Flow/Subscriptions/Financial Health/Monthly Review
/// already own.
class ReportsCalculator {
  ReportsCalculator._();

  static ReportDateRange dateRangeFor(ReportPeriod period, DateTime now) {
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    switch (period) {
      case ReportPeriod.thisWeek:
        // Rolling 7-day window ending today (inclusive), not a calendar
        // week — avoids an arbitrary "week starts on X" assumption nothing
        // else in the app makes. Previous period is the preceding 7 days.
        final todayStart = DateTime(now.year, now.month, now.day);
        final start = todayStart.subtract(const Duration(days: 6));
        final end = todayStart.add(const Duration(days: 1));
        return ReportDateRange(
          start: start,
          end: end,
          previousStart: start.subtract(const Duration(days: 7)),
          previousEnd: start,
        );
      case ReportPeriod.thisMonth:
        return ReportDateRange(
          start: currentMonthStart,
          end: nextMonthStart,
          previousStart: DateTime(now.year, now.month - 1, 1),
          previousEnd: currentMonthStart,
        );
      case ReportPeriod.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        return ReportDateRange(
          start: start,
          end: currentMonthStart,
          previousStart: DateTime(now.year, now.month - 2, 1),
          previousEnd: start,
        );
      case ReportPeriod.last3Months:
        return _rollingWindow(now, nextMonthStart, 3);
      case ReportPeriod.last6Months:
        return _rollingWindow(now, nextMonthStart, 6);
      case ReportPeriod.lastYear:
        return _rollingWindow(now, nextMonthStart, 12);
    }
  }

  static ReportDateRange _rollingWindow(
    DateTime now,
    DateTime end,
    int months,
  ) {
    final start = DateTime(end.year, end.month - months, 1);
    final previousEnd = start;
    final previousStart = DateTime(start.year, start.month - months, 1);
    return ReportDateRange(
      start: start,
      end: end,
      previousStart: previousStart,
      previousEnd: previousEnd,
    );
  }

  static ReportsResult calculate({
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required ReportPeriod period,
    required DateTime now,
  }) {
    final range = dateRangeFor(period, now);
    final periodTx = _inRange(transactions, range.start, range.end);
    final previousTx = _inRange(
      transactions,
      range.previousStart,
      range.previousEnd,
    );

    final totalIncome = _sumByType(periodTx, 'income');
    final totalExpense = _sumByType(periodTx, 'expense');
    final transactionCount = periodTx
        .where((t) => _isIncomeOrExpense(t))
        .length;

    final categoryBreakdown = _categoryBreakdown(periodTx, totalExpense);
    final topExpenses = _topExpenses(periodTx, wallets);
    final walletBreakdown = _walletBreakdown(periodTx, wallets);
    final monthlyTotals = _monthlyTotals(transactions, range.start, range.end);

    final comparison = ReportPeriodComparison(
      currentIncome: totalIncome,
      previousIncome: _sumByType(previousTx, 'income'),
      currentExpense: totalExpense,
      previousExpense: _sumByType(previousTx, 'expense'),
    );

    final insights = _generateInsights(
      categoryBreakdown: categoryBreakdown,
      comparison: comparison,
      currentSavingsRate: totalIncome > 0
          ? (totalIncome - totalExpense) / totalIncome * 100
          : null,
      previousSavingsRate: comparison.previousIncome > 0
          ? (comparison.previousIncome - comparison.previousExpense) /
                comparison.previousIncome *
                100
          : null,
    );

    return ReportsResult(
      period: period,
      range: range,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transactionCount: transactionCount,
      categoryBreakdown: categoryBreakdown,
      topExpenses: topExpenses,
      walletBreakdown: walletBreakdown,
      monthlyTotals: monthlyTotals,
      comparison: comparison,
      insights: insights,
    );
  }

  static bool _isIncomeOrExpense(Transaction t) {
    final type = t.transactionType.toLowerCase();
    return type == 'income' || type == 'expense';
  }

  static List<Transaction> _inRange(
    List<Transaction> all,
    DateTime start,
    DateTime end,
  ) {
    return all
        .where(
          (t) => !t.createdAt.isBefore(start) && t.createdAt.isBefore(end),
        )
        .toList();
  }

  /// [type] is always `'income'` or `'expense'` — a `'transfer'`
  /// transaction never matches either, so transfers are structurally
  /// excluded from every sum this calculator produces.
  static double _sumByType(List<Transaction> tx, String type) {
    return tx
        .where((t) => t.transactionType.toLowerCase() == type)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  static List<ReportCategoryBreakdown> _categoryBreakdown(
    List<Transaction> periodTx,
    double totalExpense,
  ) {
    final grouped = <String, double>{};
    for (final t in periodTx) {
      if (t.transactionType.toLowerCase() != 'expense') {
        continue;
      }
      grouped[t.categoryId] = (grouped[t.categoryId] ?? 0) + t.amount;
    }

    final list = grouped.entries
        .map(
          (entry) => ReportCategoryBreakdown(
            categoryId: entry.key,
            amount: entry.value,
            percentage: totalExpense > 0 ? entry.value / totalExpense * 100 : 0,
          ),
        )
        .toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  static List<ReportTopExpense> _topExpenses(
    List<Transaction> periodTx,
    List<Wallet> wallets, {
    int limit = reportsTopExpensesLimit,
  }) {
    final expenses = periodTx
        .where((t) => t.transactionType.toLowerCase() == 'expense')
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return expenses.take(limit).map((t) {
      final matches = wallets.where((w) => w.id == t.accountId);
      return ReportTopExpense(
        id: t.id,
        title: t.title,
        amount: t.amount,
        categoryId: t.categoryId,
        date: t.createdAt,
        walletId: t.accountId,
        walletName: matches.isEmpty ? 'Unknown wallet' : matches.first.name,
      );
    }).toList();
  }

  /// Filtering is always by `transaction.accountId == wallet.id` — never by
  /// wallet name — and only `'income'`/`'expense'` transactions are ever
  /// summed, so a transfer between two wallets never inflates either
  /// wallet's income/expense here even though it appears in both wallets'
  /// transaction history.
  static List<ReportWalletBreakdown> _walletBreakdown(
    List<Transaction> periodTx,
    List<Wallet> wallets,
  ) {
    final eligibleWallets = wallets.where((w) => !w.isArchived).toList();
    return eligibleWallets.map((wallet) {
      final walletTx = periodTx.where((t) => t.accountId == wallet.id);
      return ReportWalletBreakdown(
        walletId: wallet.id,
        walletName: wallet.name,
        income: walletTx
            .where((t) => t.transactionType.toLowerCase() == 'income')
            .fold<double>(0, (sum, t) => sum + t.amount),
        expense: walletTx
            .where((t) => t.transactionType.toLowerCase() == 'expense')
            .fold<double>(0, (sum, t) => sum + t.amount),
      );
    }).toList();
  }

  static List<ReportMonthTotal> _monthlyTotals(
    List<Transaction> all,
    DateTime start,
    DateTime end,
  ) {
    final months = <DateTime>[];
    var cursor = DateTime(start.year, start.month, 1);
    while (cursor.isBefore(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months.map((month) {
      final monthEnd = DateTime(month.year, month.month + 1, 1);
      final monthTx = _inRange(all, month, monthEnd);
      return ReportMonthTotal(
        month: month,
        income: _sumByType(monthTx, 'income'),
        expense: _sumByType(monthTx, 'expense'),
      );
    }).toList();
  }

  /// Deterministic, data-driven insight strings — never OpenAI/the backend,
  /// never generic filler. Each insight is only added when the underlying
  /// data actually supports the specific claim being made.
  static List<String> _generateInsights({
    required List<ReportCategoryBreakdown> categoryBreakdown,
    required ReportPeriodComparison comparison,
    required double? currentSavingsRate,
    required double? previousSavingsRate,
  }) {
    final insights = <String>[];

    if (categoryBreakdown.isNotEmpty) {
      insights.add(
        'Your highest spending category this period is '
        '${categoryBreakdown.first.categoryId}.',
      );
    }

    final expenseChange = comparison.expenseChange;
    if (expenseChange.percentage != null) {
      final pct = expenseChange.percentage!;
      if (pct > 0.5) {
        insights.add(
          'Your expenses are ${pct.toStringAsFixed(0)}% higher than the '
          'previous period.',
        );
      } else if (pct < -0.5) {
        insights.add(
          'Your expenses are ${pct.abs().toStringAsFixed(0)}% lower than '
          'the previous period.',
        );
      }
    }

    final incomeChange = comparison.incomeChange;
    if (incomeChange.percentage != null) {
      final pct = incomeChange.percentage!;
      if (pct > 0.5) {
        insights.add(
          'Your income increased by ${pct.toStringAsFixed(0)}% compared '
          'with the previous period.',
        );
      } else if (pct < -0.5) {
        insights.add(
          'Your income decreased by ${pct.abs().toStringAsFixed(0)}% '
          'compared with the previous period.',
        );
      }
    }

    if (categoryBreakdown.length >= 3) {
      final topThreeTotal = categoryBreakdown
          .take(3)
          .fold<double>(0, (sum, c) => sum + c.amount);
      insights.add(
        'You spent ₹${topThreeTotal.toStringAsFixed(0)} on your top 3 '
        'categories.',
      );
    }

    if (currentSavingsRate != null &&
        previousSavingsRate != null &&
        (currentSavingsRate - previousSavingsRate).abs() > 0.5) {
      final verb = currentSavingsRate > previousSavingsRate
          ? 'improved'
          : 'dropped';
      insights.add(
        'Your savings rate $verb from '
        '${previousSavingsRate.toStringAsFixed(0)}% to '
        '${currentSavingsRate.toStringAsFixed(0)}%.',
      );
    }

    return insights;
  }
}
