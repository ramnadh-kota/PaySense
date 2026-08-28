import 'package:flutter/foundation.dart';

import 'bill.dart';
import 'financial_safety_alert.dart';
import 'pain_of_paying_result.dart';
import 'recurring_transaction.dart';
import 'transaction.dart';
import '../utils/budget_calculator.dart';
import '../utils/financial_health_calculator.dart';
import '../utils/financial_planning_calculator.dart';
import '../utils/recurring_money_aggregator.dart';
import '../utils/safe_to_spend_calculator.dart';

/// FINANCIAL REPORT ENGINE. Only two periods are implemented today
/// (weekly/monthly, per this milestone's explicit scope) but the enum and
/// [FinancialReportEngine.generate] are both structured so `quarterly`/
/// `yearly` are a pure additive change later: add an enum value, add one
/// case to the date-range switch — nothing else in the model or engine
/// depends on which period was requested.
enum FinancialReportPeriod { weekly, monthly }

extension FinancialReportPeriodX on FinancialReportPeriod {
  String get label {
    switch (this) {
      case FinancialReportPeriod.weekly:
        return 'Weekly';
      case FinancialReportPeriod.monthly:
        return 'Monthly';
    }
  }
}

/// One category's real spend within the report window.
@immutable
class ReportCategorySpend {
  const ReportCategorySpend({required this.categoryId, required this.amount, required this.percentOfExpenses});
  final String categoryId;
  final double amount;

  /// 0 when total expenses are 0 — never NaN/Infinity.
  final double percentOfExpenses;
}

/// The full, structured output of [FinancialReportEngine.generate].
///
/// DATA INTEGRITY RULE: every field here is either a real value traced
/// directly to stored data (via an existing calculator — see each field's
/// doc) or explicitly null/empty when there isn't enough real data to
/// compute it. Nothing in this class is ever a fabricated/estimated
/// figure with no real backing.
@immutable
class FinancialReport {
  const FinancialReport({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.hasAnyActivity,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
    this.savingsRatePercent,
    required this.spendingByCategory,
    required this.largestTransactions,
    this.recurringSummary,
    required this.upcomingBills,
    required this.upcomingPayments,
    required this.goalProjections,
    required this.safetySignals,
    this.budgetSummary,
    this.budgetOverspend,
    this.debt,
    this.healthResult,
    this.safeToSpend,
    required this.notableSpendingBehaviors,
    required this.recommendations,
  });

  final FinancialReportPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;

  /// False only when there are zero transactions in the window AND no
  /// other real signal (bills/recurring/goals) exists either — the
  /// report never fabricates content for a genuinely empty account.
  final bool hasAnyActivity;

  /// Real sums of transactions within [periodStart]..[periodEnd].
  final double totalIncome;
  final double totalExpenses;
  final double netCashFlow;

  /// `netCashFlow / totalIncome * 100`. Null when [totalIncome] is 0 —
  /// never a fabricated rate.
  final double? savingsRatePercent;

  /// Sorted descending by amount.
  final List<ReportCategorySpend> spendingByCategory;

  /// Sorted descending by amount, capped to a display-friendly count.
  final List<Transaction> largestTransactions;

  /// Reuses [RecurringMoneyAggregator.summarize] as-is — null only if the
  /// caller didn't supply recurring/bill/loan data (never computed twice).
  final RecurringMoneySummary? recurringSummary;

  /// Bills due within the report window, soonest first.
  final List<Bill> upcomingBills;

  /// Active recurring payments due within the report window, soonest first.
  final List<RecurringTransaction> upcomingPayments;

  /// Reuses [FinancialPlanningCalculator.calculateGoalProjections] as-is.
  final List<GoalProjection> goalProjections;

  /// Reuses [FinancialSafetyEngine.generate] as-is (current signals, not
  /// filtered to the report window — safety is a "right now" concept).
  final List<FinancialSafetyAlert> safetySignals;

  /// Reuses [BudgetCalculator.summarize]/[overspendSummary]. Null for a
  /// weekly report (budgets are monthly-only records — see
  /// `BudgetRepository`; there is no real weekly budget figure to show)
  /// or when no budgets exist for the report's month.
  final BudgetMonthlySummary? budgetSummary;
  final BudgetOverspendSummary? budgetOverspend;

  /// Reuses [FinancialPlanningCalculator]'s [DebtOverview] as-is.
  final DebtOverview? debt;

  /// Reuses [FinancialHealthCalculator.calculate] as-is. Populated for
  /// monthly reports only, per this milestone's own content spec (the
  /// weekly report list doesn't include a health score).
  final FinancialHealthResult? healthResult;

  /// Reuses [SafeToSpendCalculator.calculate] as-is.
  final SafeToSpendResult? safeToSpend;

  /// Reuses [PainOfPayingEngine.evaluate] against each of [largestTransactions]
  /// — only entries at MODERATE level or above are kept, so this is never
  /// padded with "nothing notable" rows.
  final List<PainOfPayingResult> notableSpendingBehaviors;

  /// Short, neutral, data-backed suggestions — see
  /// `PersonalCfoInsights`/`FinancialReportEngine._buildRecommendations`
  /// for exactly which real signals can produce one. Empty, never
  /// padded, when nothing warrants a suggestion.
  final List<String> recommendations;
}
