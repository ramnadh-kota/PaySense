import 'package:flutter/foundation.dart';

import 'financial_action_engine.dart';
import 'financial_health_calculator.dart' show FinancialHealthResult, FinancialHealthStatus;
import 'financial_insight_engine.dart';
import 'financial_planning_calculator.dart';
import 'safe_to_spend_calculator.dart';

/// CONSUMER MONETIZATION FOUNDATION — PHASE 2. A pure Dart, deterministic
/// assembler for the onboarding "Financial Snapshot" — deliberately a thin
/// ADAPTER over ALREADY-COMPUTED results from
/// [FinancialPlanningCalculator]/[FinancialHealthCalculator]/
/// [FinancialActionEngine]/[FinancialInsightEngine]/[SafeToSpendCalculator],
/// exactly like [FinancialInsightEngine] and [FinancialTimelineCalculator]
/// are thin adapters over their own upstream calculators. This file adds
/// NO new financial formula — its only original logic is composing the ONE
/// personalized summary sentence, which nothing else in the app produces.
///
/// Callers (the `financialSnapshotProvider`) are responsible for computing
/// each of these five results via the SAME calculators/providers the rest
/// of the app already uses — never a second, divergent calculation.
@immutable
class FinancialSnapshotResult {
  const FinancialSnapshotResult({
    required this.hasSufficientData,
    required this.netWorth,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.savingsRatePercent,
    required this.safeToSpend,
    required this.healthScore,
    required this.healthStatus,
    required this.healthHasSufficientData,
    required this.emergencyFund,
    required this.debt,
    required this.goalProjections,
    required this.topActions,
    required this.topInsights,
    required this.personalizedSummary,
  });

  /// False only when there's truly nothing to show yet (no profile income
  /// AND no transaction history at all) — the ONLY case where the UI
  /// should show "add a little more financial data" instead of numbers.
  final bool hasSufficientData;

  final double netWorth;
  final double monthlyIncome;
  final double monthlyExpenses;

  /// Null when [monthlyIncome] is 0 — never a fabricated rate.
  final double? savingsRatePercent;

  final SafeToSpendResult safeToSpend;

  final int healthScore;
  final FinancialHealthStatus healthStatus;
  final bool healthHasSufficientData;

  final EmergencyFundResult emergencyFund;
  final DebtOverview debt;
  final List<GoalProjection> goalProjections;

  /// Already capped at [FinancialActionEngine.maxActions] (3) by the
  /// engine itself.
  final List<FinancialAction> topActions;

  /// Already capped at [FinancialInsightEngine.maxInsights] (3) by the
  /// engine itself.
  final List<FinancialInsight> topInsights;

  /// A single deterministic sentence — see [FinancialSnapshotBuilder._summaryFor].
  /// Never AI-generated.
  final String personalizedSummary;
}

class FinancialSnapshotBuilder {
  FinancialSnapshotBuilder._();

  /// Below this fraction of income committed to fixed
  /// commitments+EMIs+bills+subscriptions, the summary doesn't call it out
  /// as the headline concern. A new, explicitly documented threshold — no
  /// existing calculator defines "commitments are the headline story" for
  /// a one-sentence summary.
  static const double _highCommitmentFraction = 0.40;

  /// Emergency fund progress below this percent (of an already-configured
  /// target) is considered "the biggest financial gap" when savings are
  /// otherwise healthy.
  static const double _lowEmergencyFundProgressPercent = 50.0;

  /// Savings rate at/above this is called out as "doing well."
  static const double _healthySavingsRatePercent = 20.0;

  static FinancialSnapshotResult build({
    required FinancialPlanningResult planning,
    required FinancialHealthResult health,
    required FinancialActionPlan actionPlan,
    required FinancialInsightResult insights,
    required SafeToSpendResult safeToSpend,
  }) {
    final overview = planning.overview;
    final hasSufficientData = planning.hasSufficientData || health.hasSufficientData;

    return FinancialSnapshotResult(
      hasSufficientData: hasSufficientData,
      netWorth: overview.netWorth,
      monthlyIncome: overview.monthlyIncome,
      monthlyExpenses: overview.monthlyExpenses,
      savingsRatePercent: overview.savingsRatePercent,
      safeToSpend: safeToSpend,
      healthScore: health.overallScore,
      healthStatus: health.status,
      healthHasSufficientData: health.hasSufficientData,
      emergencyFund: planning.emergencyFund,
      debt: planning.debt,
      goalProjections: planning.goalProjections,
      topActions: actionPlan.actions,
      topInsights: insights.insights,
      personalizedSummary: _summaryFor(planning: planning, health: health, hasSufficientData: hasSufficientData),
    );
  }

  /// Deterministic, priority-ordered — never AI-generated, never a
  /// fabricated claim. Each branch only fires when the underlying data
  /// genuinely supports the specific claim being made.
  static String _summaryFor({
    required FinancialPlanningResult planning,
    required FinancialHealthResult health,
    required bool hasSufficientData,
  }) {
    if (!hasSufficientData) {
      return 'Add a little more financial data and PaySense will build your full financial picture.';
    }

    final overview = planning.overview;
    final emergencyFund = planning.emergencyFund;
    final savingsRate = overview.savingsRatePercent;

    // Emergency fund is configured but under-funded, and savings are
    // otherwise reasonable — the fund is genuinely the standout gap.
    if (emergencyFund.isSourceConfigured &&
        !emergencyFund.isFullyFunded &&
        emergencyFund.target != null &&
        emergencyFund.target! > 0 &&
        (emergencyFund.current / emergencyFund.target! * 100) < _lowEmergencyFundProgressPercent &&
        savingsRate != null &&
        savingsRate >= 10) {
      return "You're saving well, but your emergency fund is still your biggest financial gap.";
    }

    // A large share of income is already committed to fixed
    // commitments/EMIs/bills/subscriptions.
    if (overview.hasIncomeData &&
        overview.monthlyIncome > 0 &&
        (overview.monthlyFixedCommitments / overview.monthlyIncome) >= _highCommitmentFraction) {
      return 'Your money is doing okay, but ₹${overview.monthlyFixedCommitments.toStringAsFixed(0)} of your '
          'monthly income is currently committed to expenses and EMIs.';
    }

    if (savingsRate != null && savingsRate < 0) {
      return "You're spending more than you earn this month — let's find where to cut back.";
    }

    if (savingsRate != null && savingsRate >= _healthySavingsRatePercent) {
      return "You're managing your money well — keep building on your strong savings habit.";
    }

    return 'PaySense has enough data to start giving you personalized guidance — keep tracking to unlock deeper insights.';
  }
}
