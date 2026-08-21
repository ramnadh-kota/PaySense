import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/analytics_provider.dart'
    show
        AnalyticsSummary,
        LoanAnalytics,
        buildAnalyticsSummary,
        buildLoanAnalytics;

enum FinancialHealthStatus { needsAttention, gettingStarted, fair, good, excellent }

String financialHealthStatusLabel(FinancialHealthStatus status) {
  switch (status) {
    case FinancialHealthStatus.needsAttention:
      return 'Needs attention';
    case FinancialHealthStatus.gettingStarted:
      return 'Getting started';
    case FinancialHealthStatus.fair:
      return 'Fair';
    case FinancialHealthStatus.good:
      return 'Good';
    case FinancialHealthStatus.excellent:
      return 'Excellent';
  }
}

FinancialHealthStatus financialHealthStatusForScore(int score) {
  if (score >= 90) return FinancialHealthStatus.excellent;
  if (score >= 75) return FinancialHealthStatus.good;
  if (score >= 60) return FinancialHealthStatus.fair;
  if (score >= 40) return FinancialHealthStatus.gettingStarted;
  return FinancialHealthStatus.needsAttention;
}

enum FinancialInsightType { positive, tip, warning }

@immutable
class FinancialInsight {
  const FinancialInsight({required this.message, required this.type});

  final String message;
  final FinancialInsightType type;
}

@immutable
class FinancialHealthComponents {
  const FinancialHealthComponents({
    required this.savings,
    required this.budget,
    required this.goals,
    required this.debt,
    required this.payments,
  });

  final int savings;
  final int budget;
  final int goals;
  final int debt;
  final int payments;
}

/// A single period-over-period comparison. [hasData] is false when the
/// prior period has no recorded activity at all — in that case a percentage
/// change would be meaningless (or a fabricated spike from zero), so the UI
/// should show "Not enough data yet" instead of [changePercent].
@immutable
class FinancialHealthComparison {
  const FinancialHealthComparison({
    required this.currentValue,
    required this.previousValue,
    required this.changePercent,
    required this.hasData,
  });

  const FinancialHealthComparison.insufficient()
    : currentValue = 0,
      previousValue = 0,
      changePercent = null,
      hasData = false;

  final double currentValue;
  final double previousValue;
  final double? changePercent;
  final bool hasData;
}

@immutable
class FinancialHealthComparisons {
  const FinancialHealthComparisons({
    required this.weeklySpending,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlySavings,
  });

  final FinancialHealthComparison weeklySpending;
  final FinancialHealthComparison monthlyIncome;
  final FinancialHealthComparison monthlyExpense;
  final FinancialHealthComparison monthlySavings;
}

@immutable
class FinancialHealthResult {
  const FinancialHealthResult({
    required this.overallScore,
    required this.status,
    required this.components,
    required this.comparisons,
    required this.insights,
    required this.recommendations,
    required this.hasSufficientData,
  });

  /// 0–100. An app-generated wellness indicator, NOT a credit score.
  final int overallScore;
  final FinancialHealthStatus status;
  final FinancialHealthComponents components;
  final FinancialHealthComparisons comparisons;
  final List<FinancialInsight> insights;

  /// Generic, actionable tips keyed off the weakest component scores.
  final List<String> recommendations;

  /// False when there isn't enough transaction history yet to make the
  /// score/insights meaningful (brand-new account).
  final bool hasSufficientData;
}

/// Pure, deterministic Financial Health calculation. No Flutter/Riverpod
/// dependency, no persistence — everything is derived from the existing
/// Transaction/Budget/Goal/Loan/Bill data each time it's called.
class FinancialHealthCalculator {
  FinancialHealthCalculator._();

  /// Component weights for [overallScore] — extracted as named constants
  /// (same values, not a new formula) so FINANCIAL HEALTH TRENDS 3.0 can
  /// reconstruct a historically-honest weighted score for a past month
  /// without silently drifting out of sync with this calculator's own
  /// weighting.
  static const double savingsWeight = 0.25;
  static const double budgetWeight = 0.20;
  static const double goalsWeight = 0.15;
  static const double debtWeight = 0.20;
  static const double paymentsWeight = 0.20;

  static FinancialHealthResult calculate({
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<Bill> bills,
    required List<Wallet> wallets,
    required double profileMonthlyIncome,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();

    final analytics = buildAnalyticsSummary(transactions, referenceNow);
    final effectiveMonthlyIncome = analytics.currentMonthIncome > 0
        ? analytics.currentMonthIncome
        : profileMonthlyIncome;

    final savingsScore = FinancialHealthCalculator.savingsScore(analytics.savingsRate, analytics.currentMonthIncome);
    final budgetScore = FinancialHealthCalculator.budgetScore(budgets);
    final goalsScore = _goalsScore(goals);
    final loanAnalytics = buildLoanAnalytics(
      loans,
      wallets,
      effectiveMonthlyIncome,
      referenceNow,
    );
    final debtScore = _debtScore(loans, loanAnalytics.monthlyEmiBurdenPercentage, effectiveMonthlyIncome);
    final paymentsScore = _paymentsScore(bills, referenceNow);

    final overallScore = (savingsScore * savingsWeight +
            budgetScore * budgetWeight +
            goalsScore * goalsWeight +
            debtScore * debtWeight +
            paymentsScore * paymentsWeight)
        .round()
        .clamp(0, 100);

    final components = FinancialHealthComponents(
      savings: savingsScore.round(),
      budget: budgetScore.round(),
      goals: goalsScore.round(),
      debt: debtScore.round(),
      payments: paymentsScore.round(),
    );

    final comparisons = _buildComparisons(transactions, referenceNow);

    final insights = _buildInsights(
      analytics: analytics,
      budgets: budgets,
      goals: goals,
      bills: bills,
      loanAnalytics: loanAnalytics,
      comparisons: comparisons,
      referenceNow: referenceNow,
    );

    return FinancialHealthResult(
      overallScore: overallScore,
      status: financialHealthStatusForScore(overallScore),
      components: components,
      comparisons: comparisons,
      insights: insights,
      recommendations: _buildRecommendations(components),
      hasSufficientData: transactions.isNotEmpty,
    );
  }

  // ---- Component scores ----

  /// Public (not `_savingsScore`) — see [savingsWeight]'s doc comment for
  /// why: this exact formula is reused, never duplicated, for a past
  /// month's reconstructed score in FINANCIAL HEALTH TRENDS 3.0.
  static double savingsScore(double savingsRate, double currentMonthIncome) {
    if (currentMonthIncome <= 0) {
      // No income recorded this month — can't fairly judge savings behavior.
      return 60;
    }
    // 30%+ savings rate is treated as excellent; 0% or below is poor.
    return (savingsRate / 30 * 100).clamp(0, 100);
  }

  /// Public — see [savingsScore]'s doc comment.
  static double budgetScore(List<Budget> budgets) {
    if (budgets.isEmpty) {
      return 60; // Neutral: nothing to assess, not penalized.
    }
    final totalAllocated = budgets.fold<double>(0, (sum, b) => sum + b.allocatedAmount);
    final totalSpent = budgets.fold<double>(0, (sum, b) => sum + b.spentAmount);
    if (totalAllocated <= 0) {
      return 60;
    }
    final percentageUsed = totalSpent / totalAllocated * 100;

    if (percentageUsed <= 50) {
      return 100;
    }
    if (percentageUsed <= 100) {
      return 100 - (percentageUsed - 50); // 100 -> 50
    }
    return (50 - (percentageUsed - 100)).clamp(0, 50);
  }

  static double _goalsScore(List<Goal> goals) {
    if (goals.isEmpty) {
      return 60; // Neutral: no goals set yet, not penalized.
    }
    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    if (totalTarget <= 0) {
      return 60;
    }
    return (totalSaved / totalTarget * 100).clamp(0, 100);
  }

  static double _debtScore(
    List<Loan> loans,
    double monthlyEmiBurdenPercentage,
    double effectiveMonthlyIncome,
  ) {
    final activeLoans = loans.where((loan) => loan.isActive).toList();
    if (activeLoans.isEmpty) {
      return 100; // No debt is the best possible debt health.
    }
    if (effectiveMonthlyIncome <= 0) {
      // Loans exist but there's no income data to judge burden against —
      // avoid falsely reporting a perfect score from a 0% divide-by-zero.
      return 60;
    }

    final burden = monthlyEmiBurdenPercentage;
    if (burden <= 20) {
      return 100 - (burden / 20 * 10); // 100 -> 90
    }
    if (burden <= 40) {
      return 90 - (burden - 20) / 20 * 30; // 90 -> 60
    }
    if (burden <= 60) {
      return 60 - (burden - 40) / 20 * 30; // 60 -> 30
    }
    return (30 - (burden - 60)).clamp(0, 30);
  }

  static double _paymentsScore(List<Bill> bills, DateTime now) {
    if (bills.isEmpty) {
      return 100; // Nothing tracked to be late on.
    }
    final overdueCount = bills.where((bill) => bill.isOverdue(now)).length;
    if (overdueCount == 0) {
      return 100;
    }
    final overdueRatio = overdueCount / bills.length;
    return (100 - overdueRatio * 100).clamp(0, 100);
  }

  // ---- Comparisons ----

  static FinancialHealthComparisons _buildComparisons(
    List<Transaction> transactions,
    DateTime now,
  ) {
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final startOfPrevWeek = startOfWeek.subtract(const Duration(days: 7));

    final weeklySpending = _compare(
      transactions,
      currentStart: startOfWeek,
      currentEnd: startOfWeek.add(const Duration(days: 7)),
      previousStart: startOfPrevWeek,
      previousEnd: startOfWeek,
      type: 'expense',
    );

    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final startOfPrevMonth = DateTime(now.year, now.month - 1, 1);

    final monthlyIncome = _compare(
      transactions,
      currentStart: startOfMonth,
      currentEnd: startOfNextMonth,
      previousStart: startOfPrevMonth,
      previousEnd: startOfMonth,
      type: 'income',
    );

    final monthlyExpense = _compare(
      transactions,
      currentStart: startOfMonth,
      currentEnd: startOfNextMonth,
      previousStart: startOfPrevMonth,
      previousEnd: startOfMonth,
      type: 'expense',
    );

    final monthlySavings = _compareSavings(
      transactions,
      currentStart: startOfMonth,
      currentEnd: startOfNextMonth,
      previousStart: startOfPrevMonth,
      previousEnd: startOfMonth,
    );

    return FinancialHealthComparisons(
      weeklySpending: weeklySpending,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      monthlySavings: monthlySavings,
    );
  }

  static double _sumInRange(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
    String type,
  ) {
    return transactions
        .where(
          (t) =>
              !t.createdAt.isBefore(start) &&
              t.createdAt.isBefore(end) &&
              t.transactionType.toLowerCase() == type,
        )
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  static FinancialHealthComparison _compare(
    List<Transaction> transactions, {
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime previousStart,
    required DateTime previousEnd,
    required String type,
  }) {
    final current = _sumInRange(transactions, currentStart, currentEnd, type);
    final previous = _sumInRange(transactions, previousStart, previousEnd, type);

    if (previous <= 0) {
      return const FinancialHealthComparison.insufficient();
    }

    final changePercent = (current - previous) / previous * 100;
    return FinancialHealthComparison(
      currentValue: current,
      previousValue: previous,
      changePercent: changePercent,
      hasData: true,
    );
  }

  static FinancialHealthComparison _compareSavings(
    List<Transaction> transactions, {
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime previousStart,
    required DateTime previousEnd,
  }) {
    final currentIncome = _sumInRange(transactions, currentStart, currentEnd, 'income');
    final currentExpense = _sumInRange(transactions, currentStart, currentEnd, 'expense');
    final previousIncome = _sumInRange(transactions, previousStart, previousEnd, 'income');
    final previousExpense = _sumInRange(transactions, previousStart, previousEnd, 'expense');

    if (previousIncome <= 0 && previousExpense <= 0) {
      return const FinancialHealthComparison.insufficient();
    }

    final current = currentIncome - currentExpense;
    final previous = previousIncome - previousExpense;
    if (previous == 0) {
      return const FinancialHealthComparison.insufficient();
    }

    final changePercent = (current - previous) / previous.abs() * 100;
    return FinancialHealthComparison(
      currentValue: current,
      previousValue: previous,
      changePercent: changePercent,
      hasData: true,
    );
  }

  // ---- Insights ----

  static List<FinancialInsight> _buildInsights({
    required AnalyticsSummary analytics,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Bill> bills,
    required LoanAnalytics loanAnalytics,
    required FinancialHealthComparisons comparisons,
    required DateTime referenceNow,
  }) {
    final insights = <FinancialInsight>[];

    final overdueBills = bills.where((b) => b.isOverdue(referenceNow)).length;
    if (overdueBills > 0) {
      insights.add(
        FinancialInsight(
          message:
              'You have $overdueBills overdue bill${overdueBills == 1 ? '' : 's'} that need${overdueBills == 1 ? 's' : ''} attention.',
          type: FinancialInsightType.warning,
        ),
      );
    }

    if (loanAnalytics.monthlyEmiBurdenPercentage > 40) {
      insights.add(
        const FinancialInsight(
          message:
              'Your monthly EMI commitments are taking a significant share of your income.',
          type: FinancialInsightType.warning,
        ),
      );
    }

    Budget? nearLimitBudget;
    for (final budget in budgets) {
      if (budget.allocatedAmount <= 0) continue;
      final pct = budget.spentAmount / budget.allocatedAmount * 100;
      if (pct >= 85) {
        if (nearLimitBudget == null ||
            pct >
                (nearLimitBudget.spentAmount / nearLimitBudget.allocatedAmount * 100)) {
          nearLimitBudget = budget;
        }
      }
    }
    if (nearLimitBudget != null) {
      final pct =
          (nearLimitBudget.spentAmount / nearLimitBudget.allocatedAmount * 100).round();
      insights.add(
        FinancialInsight(
          message: 'Your ${nearLimitBudget.categoryName} budget is $pct% used.',
          type: FinancialInsightType.warning,
        ),
      );
    }

    if (comparisons.weeklySpending.hasData) {
      final change = comparisons.weeklySpending.changePercent!;
      if (change >= 10) {
        insights.add(
          FinancialInsight(
            message:
                "You've spent ${change.round()}% more than last week.",
            type: FinancialInsightType.tip,
          ),
        );
      } else if (change <= -10) {
        insights.add(
          FinancialInsight(
            message:
                "You're spending ${change.abs().round()}% less than last week.",
            type: FinancialInsightType.positive,
          ),
        );
      }
    }

    if (analytics.currentMonthIncome > 0 && analytics.savingsRate >= 15) {
      insights.add(
        FinancialInsight(
          message:
              "You're saving ${analytics.savingsRate.round()}% of your income this month.",
          type: FinancialInsightType.positive,
        ),
      );
    }

    final activeGoals = goals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    if (activeGoals.isNotEmpty && activeGoals.first.progressPercentage > 0) {
      final goal = activeGoals.first;
      insights.add(
        FinancialInsight(
          message:
              'Your ${goal.title} goal is ${goal.progressPercentage.round()}% complete.',
          type: FinancialInsightType.positive,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const FinancialInsight(
          message:
              "You're on track this month. Keep your current spending and saving habits.",
          type: FinancialInsightType.positive,
        ),
      );
    }

    // Warnings first, then the rest — keep it short and scannable.
    insights.sort((a, b) {
      if (a.type == b.type) return 0;
      if (a.type == FinancialInsightType.warning) return -1;
      if (b.type == FinancialInsightType.warning) return 1;
      return 0;
    });

    return insights.take(5).toList();
  }

  // ---- Recommendations ----

  /// Generic, deterministic tips keyed off the weakest component scores —
  /// not tied to any single number, so nothing here is fabricated.
  static List<String> _buildRecommendations(FinancialHealthComponents components) {
    final candidates = <MapEntry<int, String>>[
      MapEntry(
        components.payments,
        'Pay off overdue bills to improve your payment discipline.',
      ),
      MapEntry(
        components.debt,
        'Consider a plan to reduce your EMI burden relative to your income.',
      ),
      MapEntry(
        components.budget,
        'Review your budgets — a few categories may be close to their limit.',
      ),
      MapEntry(
        components.savings,
        'Try setting aside a larger share of your income as savings.',
      ),
      MapEntry(
        components.goals,
        'Contribute a bit more toward your active savings goals.',
      ),
    ];

    final weak = candidates.where((entry) => entry.key < 60).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (weak.isEmpty) {
      return const [
        "You're doing well across the board — keep it up!",
      ];
    }

    return weak.take(3).map((entry) => entry.value).toList();
  }
}
