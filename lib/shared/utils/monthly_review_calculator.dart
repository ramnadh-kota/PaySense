import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../providers/analytics_provider.dart'
    show AnalyticsSummary, CategoryBreakdown, buildAnalyticsSummary;
import '../providers/loan_provider.dart' show LoanSummary;
import 'dashboard_helpers.dart' show selectRelevantGoal;
import 'financial_health_calculator.dart' show FinancialHealthResult;

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

@immutable
class MonthlyReviewComparison {
  const MonthlyReviewComparison({required this.changePercent, required this.hasData});

  const MonthlyReviewComparison.insufficient()
    : changePercent = null,
      hasData = false;

  final double? changePercent;
  final bool hasData;
}

@immutable
class MonthlyReviewComparisons {
  const MonthlyReviewComparisons({
    required this.income,
    required this.expenses,
    required this.savings,
  });

  final MonthlyReviewComparison income;
  final MonthlyReviewComparison expenses;
  final MonthlyReviewComparison savings;
}

@immutable
class TransactionHighlight {
  const TransactionHighlight({
    required this.title,
    required this.amount,
    required this.date,
  });

  final String title;
  final double amount;
  final DateTime date;
}

@immutable
class BudgetStatusCounts {
  const BudgetStatusCounts({
    required this.onTrack,
    required this.nearLimit,
    required this.exceeded,
    required this.hasBudgets,
  });

  final int onTrack;
  final int nearLimit;
  final int exceeded;
  final bool hasBudgets;
}

@immutable
class BillStatusSummary {
  const BillStatusSummary({
    required this.paidThisMonth,
    required this.overdueNow,
    required this.upcomingCount,
    required this.hasBills,
  });

  final int paidThisMonth;
  final int overdueNow;
  final int upcomingCount;
  final bool hasBills;
}

@immutable
class MonthlyReviewResult {
  const MonthlyReviewResult({
    required this.monthStart,
    required this.monthLabel,
    required this.hasSufficientData,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.savingsRate,
    required this.comparisons,
    required this.topCategories,
    required this.largestTransaction,
    required this.budgetStatus,
    required this.relevantGoal,
    required this.billStatus,
    required this.loanSummary,
    required this.financialHealth,
    required this.insights,
    required this.whatWentWell,
    required this.whatToImprove,
  });

  final DateTime monthStart;
  final String monthLabel;

  /// False when there are no transactions at all in the reviewed month.
  final bool hasSufficientData;

  final double income;
  final double expenses;
  final double savings;
  final double savingsRate;
  final MonthlyReviewComparisons comparisons;

  /// Top 3-5 expense categories, highest first.
  final List<CategoryBreakdown> topCategories;
  final TransactionHighlight? largestTransaction;
  final BudgetStatusCounts budgetStatus;
  final Goal? relevantGoal;
  final BillStatusSummary billStatus;

  /// Pass-through from [loanSummaryProvider] — current loan state, not
  /// specific to the reviewed month (loans have no historical snapshot).
  final LoanSummary loanSummary;

  /// Pass-through from [financialHealthProvider] — current score, not
  /// re-computed per month (Financial Health has no historical snapshot).
  final FinancialHealthResult financialHealth;

  final List<String> insights;
  final List<String> whatWentWell;
  final List<String> whatToImprove;
}

/// Pure Monthly Financial Review calculation. No Flutter/Riverpod
/// dependency. Reuses [buildAnalyticsSummary] for income/expense/category
/// data and [selectRelevantGoal] for goal selection rather than
/// re-deriving either — the loan and Financial Health sections are simple
/// pass-throughs of already-computed values for the same reason.
class MonthlyReviewCalculator {
  MonthlyReviewCalculator._();

  static MonthlyReviewResult calculate({
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Bill> bills,
    required LoanSummary loanSummary,
    required FinancialHealthResult financialHealth,
    required DateTime targetMonth,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);

    // buildAnalyticsSummary treats its `now` argument as "the current
    // month" — passing a date inside the target month makes it compute
    // that month's income/expense/category breakdown, and its trailing
    // monthlyTotals conveniently include the previous month too.
    final analytics = buildAnalyticsSummary(transactions, monthStart);

    final income = analytics.currentMonthIncome;
    final expenses = analytics.currentMonthExpense;
    final savings = income - expenses;
    final savingsRate = analytics.savingsRate;

    final hasSufficientData = transactions.any(
      (t) => t.createdAt.year == monthStart.year && t.createdAt.month == monthStart.month,
    );

    final comparisons = _buildComparisons(analytics);
    final topCategories = analytics.categoryBreakdown.take(5).toList();
    final largestTransaction = _findLargestExpense(transactions, monthStart);
    final budgetStatus = _computeBudgetStatus(budgets, monthStart);
    final relevantGoal = selectRelevantGoal(goals);
    final billStatus = _computeBillStatus(bills, monthStart, referenceNow);

    final flags = _ReviewFlags(
      income: income,
      savingsRate: savingsRate,
      comparisons: comparisons,
      topCategories: topCategories,
      budgetStatus: budgetStatus,
      billStatus: billStatus,
      loanSummary: loanSummary,
      relevantGoal: relevantGoal,
    );

    return MonthlyReviewResult(
      monthStart: monthStart,
      monthLabel: '${_monthNames[monthStart.month - 1]} ${monthStart.year}',
      hasSufficientData: hasSufficientData,
      income: income,
      expenses: expenses,
      savings: savings,
      savingsRate: savingsRate,
      comparisons: comparisons,
      topCategories: topCategories,
      largestTransaction: largestTransaction,
      budgetStatus: budgetStatus,
      relevantGoal: relevantGoal,
      billStatus: billStatus,
      loanSummary: loanSummary,
      financialHealth: financialHealth,
      insights: flags.insights,
      whatWentWell: flags.whatWentWell,
      whatToImprove: flags.whatToImprove,
    );
  }

  static MonthlyReviewComparisons _buildComparisons(AnalyticsSummary analytics) {
    if (analytics.monthlyTotals.length < 2) {
      return const MonthlyReviewComparisons(
        income: MonthlyReviewComparison.insufficient(),
        expenses: MonthlyReviewComparison.insufficient(),
        savings: MonthlyReviewComparison.insufficient(),
      );
    }
    final current = analytics.monthlyTotals.last;
    final previous = analytics.monthlyTotals[analytics.monthlyTotals.length - 2];

    return MonthlyReviewComparisons(
      income: _percentChange(previous.income, current.income),
      expenses: _percentChange(previous.expense, current.expense),
      savings: _percentChange(
        previous.income - previous.expense,
        current.income - current.expense,
        allowNegativeBaseline: true,
      ),
    );
  }

  static MonthlyReviewComparison _percentChange(
    double previous,
    double current, {
    bool allowNegativeBaseline = false,
  }) {
    if (!allowNegativeBaseline && previous <= 0) {
      return const MonthlyReviewComparison.insufficient();
    }
    if (allowNegativeBaseline && previous == 0) {
      return const MonthlyReviewComparison.insufficient();
    }
    final change = (current - previous) / previous.abs() * 100;
    return MonthlyReviewComparison(changePercent: change, hasData: true);
  }

  static TransactionHighlight? _findLargestExpense(
    List<Transaction> transactions,
    DateTime monthStart,
  ) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    Transaction? largest;
    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.isBefore(monthStart) || !t.createdAt.isBefore(monthEnd)) continue;
      if (largest == null || t.amount > largest.amount) {
        largest = t;
      }
    }
    if (largest == null) return null;
    return TransactionHighlight(
      title: largest.title,
      amount: largest.amount,
      date: largest.createdAt,
    );
  }

  static BudgetStatusCounts _computeBudgetStatus(List<Budget> budgets, DateTime monthStart) {
    final monthName = _monthNames[monthStart.month - 1];
    final relevant = budgets.where(
      (b) => b.month.trim().toLowerCase() == monthName.toLowerCase() && b.year == monthStart.year,
    );

    if (relevant.isEmpty) {
      return const BudgetStatusCounts(onTrack: 0, nearLimit: 0, exceeded: 0, hasBudgets: false);
    }

    var onTrack = 0;
    var nearLimit = 0;
    var exceeded = 0;
    for (final budget in relevant) {
      if (budget.allocatedAmount <= 0) continue;
      final pct = budget.spentAmount / budget.allocatedAmount * 100;
      if (pct > 100) {
        exceeded++;
      } else if (pct >= 85) {
        nearLimit++;
      } else {
        onTrack++;
      }
    }
    return BudgetStatusCounts(
      onTrack: onTrack,
      nearLimit: nearLimit,
      exceeded: exceeded,
      hasBudgets: true,
    );
  }

  static BillStatusSummary _computeBillStatus(
    List<Bill> bills,
    DateTime monthStart,
    DateTime now,
  ) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final paidThisMonth = bills.where((b) {
      final paidDate = b.paidDate;
      return b.isPaid &&
          paidDate != null &&
          !paidDate.isBefore(monthStart) &&
          paidDate.isBefore(monthEnd);
    }).length;
    final overdueNow = bills.where((b) => b.isOverdue(now)).length;
    final upcomingCount = bills.where((b) => b.isUpcoming(now)).length;

    return BillStatusSummary(
      paidThisMonth: paidThisMonth,
      overdueNow: overdueNow,
      upcomingCount: upcomingCount,
      hasBills: bills.isNotEmpty,
    );
  }
}

/// Groups the deterministic "what went well" / "needs improvement" /
/// general-insight text generation so each fact is only evaluated once and
/// filtered into the three lists the UI needs.
class _ReviewFlags {
  _ReviewFlags({
    required double income,
    required double savingsRate,
    required MonthlyReviewComparisons comparisons,
    required List<CategoryBreakdown> topCategories,
    required BudgetStatusCounts budgetStatus,
    required BillStatusSummary billStatus,
    required LoanSummary loanSummary,
    required Goal? relevantGoal,
  }) {
    if (comparisons.expenses.hasData && comparisons.expenses.changePercent! <= -5) {
      _positive(
        "Your expenses decreased ${comparisons.expenses.changePercent!.abs().round()}% compared with last month.",
      );
    }
    if (income > 0 && savingsRate >= 20) {
      _positive("You're saving ${savingsRate.round()}% of your income this month.");
    }
    if (budgetStatus.hasBudgets && budgetStatus.exceeded == 0) {
      _positive('All your budgets stayed within their limits.');
    }
    if (billStatus.hasBills && billStatus.overdueNow == 0) {
      _positive('No overdue bills.');
    }
    if (relevantGoal != null && relevantGoal.progressPercentage > 0) {
      _positive(
        'Your ${relevantGoal.title} goal is ${relevantGoal.progressPercentage.round()}% complete.',
      );
    }

    if (budgetStatus.exceeded > 0) {
      _attention(
        'Your ${budgetStatus.exceeded} budget${budgetStatus.exceeded == 1 ? '' : 's'} exceeded its limit.',
      );
    }
    if (billStatus.overdueNow > 0) {
      _attention(
        'You have ${billStatus.overdueNow} overdue bill${billStatus.overdueNow == 1 ? '' : 's'}.',
      );
    }
    if (loanSummary.activeLoans > 0 && income > 0) {
      final burden = loanSummary.totalEmiPerMonth / income * 100;
      if (burden > 40) {
        _attention('Your EMI commitments represent a significant portion of income.');
      }
    }
    if (income > 0 && savingsRate < 10) {
      _attention('Your savings rate is low this month.');
    }
    if (topCategories.isNotEmpty && topCategories.first.percentage >= 40) {
      _attention(
        '${topCategories.first.categoryId} spending is a large share of your expenses this month.',
      );
    }

    if (_wentWell.isEmpty && _toImprove.isEmpty) {
      _insights.add('Keep tracking your finances to unlock more personalized insights.');
    }
  }

  final List<String> _insights = [];
  final List<String> _wentWell = [];
  final List<String> _toImprove = [];

  void _positive(String message) {
    _insights.add(message);
    _wentWell.add(message);
  }

  void _attention(String message) {
    _insights.add(message);
    _toImprove.add(message);
  }

  List<String> get insights => _insights.take(6).toList();
  List<String> get whatWentWell => _wentWell.take(3).toList();
  List<String> get whatToImprove => _toImprove.take(3).toList();
}
