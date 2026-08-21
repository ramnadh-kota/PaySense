import 'package:flutter/foundation.dart';

import '../models/subscription_summary.dart' show SubscriptionSummary;
import 'financial_planning_calculator.dart' show FinancialOverview, GoalProjection;

/// Deterministic "what if?" scenario math for the AI Financial Assistant
/// (PHASE 8/9). None of this touches persisted data — every function takes
/// already-computed figures (from [FinancialPlanningCalculator]/
/// [SubscriptionCalculator]/etc.) and returns a parallel, throwaway
/// projection. The AI is only ever handed the *result* of these
/// calculations to explain in plain language — it never does the
/// arithmetic itself.
///
/// [FinancialPlanningCalculator.whatIf] already covers the "what if I saved
/// a different amount per month" scenario; this file covers the other
/// scenario shapes named in the milestone spec (expense change, extra loan
/// payment, dropping a subscription, cutting a category) without
/// duplicating that one.
class WhatIfCalculator {
  WhatIfCalculator._();

  /// Whole months to accumulate [remaining] at a fixed [monthlyRate]. Null
  /// when the rate is zero or negative (would never complete) or
  /// [remaining] is already covered.
  static int? monthsToReachAmount({
    required double remaining,
    required double monthlyRate,
  }) {
    if (remaining <= 0) return 0;
    if (monthlyRate <= 0) return null;
    return (remaining / monthlyRate).ceil();
  }

  static DateTime addMonths(DateTime from, int months) {
    final totalMonths = from.month - 1 + months;
    final year = from.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = from.day > daysInTargetMonth ? daysInTargetMonth : from.day;
    return DateTime(year, month, day, from.hour, from.minute);
  }

  /// "What if my monthly expenses increased/decreased by [deltaAmount]?"
  /// (positive = expenses go up, negative = expenses go down). Recomputes
  /// monthly savings and savings rate only — never touches [overview].
  static ExpenseChangeProjection whatIfExpenseChange({
    required FinancialOverview overview,
    required double deltaAmount,
  }) {
    final newExpenses = (overview.monthlyExpenses + deltaAmount).clamp(0.0, double.infinity);
    final newSavings = overview.monthlyIncome - newExpenses;
    final newRate = overview.hasIncomeData && overview.monthlyIncome > 0
        ? (newSavings / overview.monthlyIncome * 100)
        : null;

    return ExpenseChangeProjection(
      deltaAmount: deltaAmount,
      monthlySavingsBefore: overview.monthlySavings,
      monthlySavingsAfter: newSavings,
      savingsRateBefore: overview.savingsRatePercent,
      savingsRateAfter: newRate,
    );
  }

  /// "What if I paid [extraAmount] extra toward this loan?" A simplified,
  /// transparent projection — NOT a full amortization re-run (which would
  /// require the loan's payment schedule/compounding details this app
  /// doesn't retain beyond [Loan]'s own summary fields): outstanding
  /// balance drops by [extraAmount] immediately, and payoff time shortens
  /// by however many fewer EMI installments are now needed at the
  /// unchanged [emiAmount]. Never claims a new interest total — that would
  /// require re-amortizing, which this deliberately doesn't fabricate.
  static ExtraLoanPaymentProjection whatIfExtraLoanPayment({
    required double outstandingAmount,
    required double emiAmount,
    required int? remainingMonthsBefore,
    required double extraAmount,
  }) {
    final newOutstanding = (outstandingAmount - extraAmount).clamp(0.0, outstandingAmount);

    int? monthsSaved;
    int? remainingMonthsAfter;
    if (emiAmount > 0 && remainingMonthsBefore != null) {
      remainingMonthsAfter = (newOutstanding / emiAmount).ceil();
      monthsSaved = (remainingMonthsBefore - remainingMonthsAfter).clamp(0, remainingMonthsBefore);
    }

    return ExtraLoanPaymentProjection(
      extraAmount: extraAmount,
      outstandingBefore: outstandingAmount,
      outstandingAfter: newOutstanding,
      remainingMonthsBefore: remainingMonthsBefore,
      remainingMonthsAfter: remainingMonthsAfter,
      monthsSaved: monthsSaved,
    );
  }

  /// "What if I stopped this subscription?" Redirects its monthly-
  /// equivalent cost into monthly savings and re-projects how many fewer
  /// months it would take to close [remainingTarget] (e.g. the emergency
  /// fund gap, or a goal's remaining amount) at the new, higher rate.
  static StopSubscriptionProjection whatIfStopSubscription({
    required SubscriptionSummary subscription,
    required double currentMonthlyContribution,
    required double remainingTarget,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final newContribution = currentMonthlyContribution + subscription.monthlyEquivalent;

    final monthsBefore = monthsToReachAmount(
      remaining: remainingTarget,
      monthlyRate: currentMonthlyContribution,
    );
    final monthsAfter = monthsToReachAmount(
      remaining: remainingTarget,
      monthlyRate: newContribution,
    );

    return StopSubscriptionProjection(
      subscriptionName: subscription.name,
      monthlySavingsFreed: subscription.monthlyEquivalent,
      annualSavingsFreed: subscription.annualCost,
      monthsBefore: monthsBefore,
      monthsAfter: monthsAfter,
      dateBefore: monthsBefore == null ? null : addMonths(referenceNow, monthsBefore),
      dateAfter: monthsAfter == null ? null : addMonths(referenceNow, monthsAfter),
    );
  }

  /// "What if I reduced my [categoryName] spending by [percentReduction]%?"
  /// [currentCategoryAmount] must already be a real, calculator-derived
  /// figure (e.g. from `AnalyticsSummary.categoryBreakdown` or
  /// `ReportsResult.categoryBreakdown`) — this function never invents one.
  static CategoryReductionProjection whatIfReduceCategorySpending({
    required FinancialOverview overview,
    required String categoryName,
    required double currentCategoryAmount,
    required double percentReduction,
  }) {
    final clampedPercent = percentReduction.clamp(0.0, 100.0);
    final amountSaved = currentCategoryAmount * clampedPercent / 100;
    final newSavings = overview.monthlySavings + amountSaved;
    final newRate = overview.hasIncomeData && overview.monthlyIncome > 0
        ? (newSavings / overview.monthlyIncome * 100)
        : null;

    return CategoryReductionProjection(
      categoryName: categoryName,
      percentReduction: clampedPercent,
      monthlyAmountSaved: amountSaved,
      monthlySavingsBefore: overview.monthlySavings,
      monthlySavingsAfter: newSavings,
      savingsRateBefore: overview.savingsRatePercent,
      savingsRateAfter: newRate,
    );
  }

  /// "What if I put [extraMonthlyAmount] more per month toward this named
  /// goal?" Reuses [GoalProjection]'s own remaining amount and implied pace
  /// as-is — only adds a hypothetical top-up rate on top of them, it never
  /// re-derives what [FinancialPlanningCalculator] already computed.
  static GoalContributionProjection whatIfGoalContribution({
    required GoalProjection goal,
    required double extraMonthlyAmount,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final baseRate = goal.impliedMonthlyContribution ?? 0;
    final newRate = baseRate + extraMonthlyAmount;

    final monthsAfter = monthsToReachAmount(
      remaining: goal.remainingAmount,
      monthlyRate: newRate,
    );

    return GoalContributionProjection(
      goalId: goal.goalId,
      goalTitle: goal.title,
      extraMonthlyAmount: extraMonthlyAmount,
      monthsBefore: goal.estimatedMonths,
      monthsAfter: monthsAfter,
      dateBefore: goal.estimatedCompletionDate,
      dateAfter: monthsAfter == null ? null : addMonths(referenceNow, monthsAfter),
    );
  }
}

@immutable
class ExpenseChangeProjection {
  const ExpenseChangeProjection({
    required this.deltaAmount,
    required this.monthlySavingsBefore,
    required this.monthlySavingsAfter,
    required this.savingsRateBefore,
    required this.savingsRateAfter,
  });

  final double deltaAmount;
  final double monthlySavingsBefore;
  final double monthlySavingsAfter;
  final double? savingsRateBefore;
  final double? savingsRateAfter;
}

@immutable
class ExtraLoanPaymentProjection {
  const ExtraLoanPaymentProjection({
    required this.extraAmount,
    required this.outstandingBefore,
    required this.outstandingAfter,
    required this.remainingMonthsBefore,
    required this.remainingMonthsAfter,
    required this.monthsSaved,
  });

  final double extraAmount;
  final double outstandingBefore;
  final double outstandingAfter;
  final int? remainingMonthsBefore;
  final int? remainingMonthsAfter;
  final int? monthsSaved;
}

@immutable
class StopSubscriptionProjection {
  const StopSubscriptionProjection({
    required this.subscriptionName,
    required this.monthlySavingsFreed,
    required this.annualSavingsFreed,
    required this.monthsBefore,
    required this.monthsAfter,
    required this.dateBefore,
    required this.dateAfter,
  });

  final String subscriptionName;
  final double monthlySavingsFreed;
  final double annualSavingsFreed;
  final int? monthsBefore;
  final int? monthsAfter;
  final DateTime? dateBefore;
  final DateTime? dateAfter;
}

@immutable
class CategoryReductionProjection {
  const CategoryReductionProjection({
    required this.categoryName,
    required this.percentReduction,
    required this.monthlyAmountSaved,
    required this.monthlySavingsBefore,
    required this.monthlySavingsAfter,
    required this.savingsRateBefore,
    required this.savingsRateAfter,
  });

  final String categoryName;
  final double percentReduction;
  final double monthlyAmountSaved;
  final double monthlySavingsBefore;
  final double monthlySavingsAfter;
  final double? savingsRateBefore;
  final double? savingsRateAfter;
}

@immutable
class GoalContributionProjection {
  const GoalContributionProjection({
    required this.goalId,
    required this.goalTitle,
    required this.extraMonthlyAmount,
    required this.monthsBefore,
    required this.monthsAfter,
    required this.dateBefore,
    required this.dateAfter,
  });

  final String goalId;
  final String goalTitle;
  final double extraMonthlyAmount;
  final int? monthsBefore;
  final int? monthsAfter;
  final DateTime? dateBefore;
  final DateTime? dateAfter;
}
