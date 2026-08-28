import 'package:flutter/foundation.dart';

import '../../core/routes/app_routes.dart';
import '../models/recurring_transaction.dart';
import 'financial_action_engine.dart';
import 'financial_health_trends_calculator.dart';
import 'safe_to_spend_calculator.dart';
import 'subscription_calculator.dart';

/// PROACTIVE FINANCIAL INSIGHTS 1.0 — pure Dart, deterministic. No
/// Flutter widget/Riverpod/Hive/network/AI dependency, and — critically —
/// NO financial arithmetic of its own beyond two small, clearly-scoped new
/// detections (see PHASE below). This is deliberately a thin ADAPTER over
/// calculators that already exist:
///
/// - [FinancialActionEngine] already deterministically detects over-budget,
///   near-limit, savings decline, goal-at-risk, emergency-fund gap, and the
///   "no serious problems" positive signal (Rules A-H). This engine reuses
///   its [FinancialActionPlan] output directly rather than re-deriving any
///   of those thresholds/formulas a second time.
/// - [FinancialHealthTrendsCalculator] already deterministically detects
///   category spending changes and unusually-high-spending months (its own
///   `spendingBehaviorSignals`). This engine reuses that
///   [FinancialTrendSignal] list directly.
/// - The only two GENUINELY NEW detections here are "upcoming commitment
///   pressure" (reuses [SafeToSpendResult]'s already-computed figures —
///   just a threshold comparison, not a new formula) and "a new
///   subscription was added recently" (reuses
///   [SubscriptionCalculator.eligibleSubscriptions]'s already-computed
///   monthly-equivalent cost, keyed off [RecurringTransaction.createdAt] —
///   a real, non-fabricated timestamp already stored today; PaySense has
///   no historical subscription-total snapshots to compute a true
///   before/after "increase" figure, so this is honestly framed as "a new
///   subscription was added", never as a fabricated "cost increased from
///   X to Y").
///
/// This engine's own job is only: convert both existing shapes into one
/// unified [FinancialInsight], drop anything outside the 10 requested
/// insight types, deduplicate, and rank/truncate to the top 3.
enum InsightPriority { critical, high, medium, low, positive }

enum InsightType {
  unusualCategorySpending,
  budgetNearLimit,
  budgetOverLimit,
  savingsRateDecline,
  largeUnusualExpense,
  upcomingCommitmentPressure,
  subscriptionIncrease,
  goalFallingBehind,
  emergencyFundDeterioration,
  positiveImprovement,
}

@immutable
class FinancialInsight {
  const FinancialInsight({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.explanation,
    required this.recommendedAction,
    this.amount,
    this.percentage,
    this.actionRoute,
    this.relatedEntityId,
    this.relatedEntityName,
  });

  /// Stable deduplication key: `type:relatedEntity:period` — see
  /// [FinancialInsightEngine._id]. Reused directly as the persisted
  /// [AppNotification.id] by the notification layer (PHASE 7), so the
  /// SAME insight never produces a second notification within the same
  /// period, across rebuilds or app launches.
  final String id;

  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String explanation;
  final String recommendedAction;

  final double? amount;
  final double? percentage;

  /// An [AppRoutes] constant string — PHASE 5: tapping opens the most
  /// relevant EXISTING screen, never a duplicate detail screen.
  final String? actionRoute;

  final String? relatedEntityId;
  final String? relatedEntityName;
}

@immutable
class FinancialInsightResult {
  const FinancialInsightResult({required this.insights});

  /// Never more than [FinancialInsightEngine.maxInsights], ordered by
  /// priority (critical -> positive).
  final List<FinancialInsight> insights;

  bool get isEmpty => insights.isEmpty;
}

class FinancialInsightEngine {
  FinancialInsightEngine._();

  static const int maxInsights = 3;

  /// A newly-created recurring transaction counts as "a new subscription"
  /// for this many days after [RecurringTransaction.createdAt] — a new,
  /// explicitly documented product window (PaySense has no other notion of
  /// "recent" for this purpose).
  static const int newSubscriptionWindowDays = 30;

  /// Reuses [FinancialActionEngine.subscriptionMaterialityThreshold] for
  /// consistency — the same ₹/month bar already used to decide whether a
  /// subscription is worth surfacing at all.
  static const double newSubscriptionMinimumAmount =
      FinancialActionEngine.subscriptionMaterialityThreshold;

  /// Upcoming commitments are "pressuring" the budget once they consume
  /// this fraction of available wallet cash — a new, explicitly documented
  /// product threshold (below [SafeToSpendResult.isShortfall], which is
  /// already the more severe, unconditionally-critical case).
  static const double upcomingCommitmentPressureFraction = 0.7;

  static FinancialInsightResult generate({
    required FinancialActionPlan actionPlan,
    required FinancialHealthTrendResult trends,
    required SafeToSpendResult safeToSpend,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
  }) {
    final period = _periodLabel(now);
    final candidates = <FinancialInsight>[
      ..._fromActionPlan(actionPlan, period),
      ..._fromSpendingSignals(trends.spendingBehaviorSignals, period),
      ..._upcomingCommitmentPressure(safeToSpend, period),
      ..._subscriptionIncrease(recurringTransactions, now, period),
    ];

    // Deduplicate by id (two upstream sources could in principle describe
    // the same entity+period) — first occurrence wins, matching the
    // priority-source order above.
    final seen = <String>{};
    final deduped = <FinancialInsight>[];
    for (final insight in candidates) {
      if (seen.add(insight.id)) deduped.add(insight);
    }

    deduped.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return FinancialInsightResult(insights: deduped.take(maxInsights).toList());
  }

  // -------------------------------------------------------------------
  // FinancialActionEngine -> FinancialInsight
  // -------------------------------------------------------------------

  static List<FinancialInsight> _fromActionPlan(FinancialActionPlan plan, String period) {
    final insights = <FinancialInsight>[];
    for (final action in plan.actions) {
      final type = _insightTypeForActionType(action.actionType);
      if (type == null) continue; // outside the 10 requested types (e.g. debt burden, subscription cost)
      insights.add(
        FinancialInsight(
          id: _id(type, action.relatedEntityId ?? action.relatedEntityName, period),
          type: type,
          priority: _priorityForActionPriority(action.priority),
          title: action.title,
          explanation: action.explanation,
          recommendedAction: action.recommendedAction,
          amount: action.supportingAmount,
          percentage: action.supportingPercentage,
          actionRoute: _routeForCategory(action.category),
          relatedEntityId: action.relatedEntityId,
          relatedEntityName: action.relatedEntityName,
        ),
      );
    }
    return insights;
  }

  static InsightType? _insightTypeForActionType(ActionType type) {
    switch (type) {
      case ActionType.overBudget:
        return InsightType.budgetOverLimit;
      case ActionType.nearBudgetLimit:
        return InsightType.budgetNearLimit;
      case ActionType.savingsRateDecline:
        return InsightType.savingsRateDecline;
      case ActionType.goalAtRisk:
        return InsightType.goalFallingBehind;
      case ActionType.emergencyFundGap:
        return InsightType.emergencyFundDeterioration;
      case ActionType.allGood:
        return InsightType.positiveImprovement;
      case ActionType.highDebtBurden:
      case ActionType.subscriptionCost:
        return null; // outside the 10 requested insight types
    }
  }

  static InsightPriority _priorityForActionPriority(ActionPriority priority) {
    switch (priority) {
      case ActionPriority.critical:
        return InsightPriority.critical;
      case ActionPriority.high:
        return InsightPriority.high;
      case ActionPriority.medium:
        return InsightPriority.medium;
      case ActionPriority.positive:
        return InsightPriority.positive;
    }
  }

  static String? _routeForCategory(ActionCategory category) {
    switch (category) {
      case ActionCategory.overspending:
      case ActionCategory.budget:
        return AppRoutes.budget;
      case ActionCategory.debt:
        return AppRoutes.loans;
      case ActionCategory.subscriptions:
        return AppRoutes.subscriptions;
      case ActionCategory.emergencyFund:
      case ActionCategory.goals:
      case ActionCategory.savings:
      case ActionCategory.cashFlow:
      case ActionCategory.tax:
      case ActionCategory.positiveProgress:
        return AppRoutes.financialPlanning;
    }
  }

  // -------------------------------------------------------------------
  // FinancialHealthTrendsCalculator.spendingBehaviorSignals -> FinancialInsight
  // -------------------------------------------------------------------

  static List<FinancialInsight> _fromSpendingSignals(
    List<FinancialTrendSignal> signals,
    String period,
  ) {
    final insights = <FinancialInsight>[];
    for (final signal in signals) {
      final type = _insightTypeForSignalType(signal.type);
      if (type == null) continue; // outside the 10 requested types (e.g. lifestyle inflation)

      final amount = signal.supportingValues['after'] as double? ??
          signal.supportingValues['currentExpense'] as double?;
      final before = signal.supportingValues['before'] as double?;
      double? percentage;
      if (before != null && before > 0 && amount != null) {
        percentage = (amount - before) / before * 100;
      }

      insights.add(
        FinancialInsight(
          id: _id(type, signal.id, period),
          type: type,
          priority: _priorityForSeverity(signal.severity),
          title: signal.title,
          explanation: signal.explanation,
          recommendedAction: signal.recommendation ?? 'Review this in your Reports.',
          amount: amount,
          percentage: percentage,
          actionRoute: AppRoutes.reports,
        ),
      );
    }
    return insights;
  }

  static InsightType? _insightTypeForSignalType(SignalType type) {
    switch (type) {
      case SignalType.categoryIncrease:
      case SignalType.categoryDecrease:
        return InsightType.unusualCategorySpending;
      case SignalType.unusuallyHighMonth:
        return InsightType.largeUnusualExpense;
      case SignalType.newRecurringSpend:
      case SignalType.lifestyleInflation:
      case SignalType.healthImprovement:
      case SignalType.healthDecline:
      case SignalType.savingsImprovement:
      case SignalType.savingsDecline:
      case SignalType.debtReduction:
      case SignalType.debtIncrease:
      case SignalType.budgetImprovement:
      case SignalType.budgetDeterioration:
      case SignalType.emergencyFundProgress:
      case SignalType.goalRisk:
        return null; // already covered via the FinancialActionEngine source above, or outside scope
    }
  }

  static InsightPriority _priorityForSeverity(SignalSeverity severity) {
    switch (severity) {
      case SignalSeverity.high:
        return InsightPriority.high;
      case SignalSeverity.notable:
        return InsightPriority.medium;
      case SignalSeverity.info:
        return InsightPriority.low;
    }
  }

  // -------------------------------------------------------------------
  // NEW — upcoming commitment pressure (reuses SafeToSpendResult as-is)
  // -------------------------------------------------------------------

  static List<FinancialInsight> _upcomingCommitmentPressure(SafeToSpendResult safeToSpend, String period) {
    if (!safeToSpend.hasSufficientData) return const [];

    if (safeToSpend.isShortfall) {
      return [
        FinancialInsight(
          id: _id(InsightType.upcomingCommitmentPressure, 'shortfall', period),
          type: InsightType.upcomingCommitmentPressure,
          priority: InsightPriority.critical,
          title: 'Upcoming bills exceed your balance',
          explanation: 'Your upcoming bills/EMIs over the next ${safeToSpend.windowDays} days '
              '(₹${safeToSpend.upcomingCommitments.toStringAsFixed(0)}) exceed your available balance '
              '(₹${safeToSpend.availableMoney.toStringAsFixed(0)}) by ₹${safeToSpend.shortfall.toStringAsFixed(0)}.',
          recommendedAction: 'Review your upcoming bills and EMIs in Cash Flow.',
          amount: safeToSpend.shortfall,
          actionRoute: AppRoutes.cashFlow,
        ),
      ];
    }

    if (safeToSpend.availableMoney > 0 &&
        safeToSpend.upcomingCommitments / safeToSpend.availableMoney >= upcomingCommitmentPressureFraction) {
      final percentage = safeToSpend.upcomingCommitments / safeToSpend.availableMoney * 100;
      return [
        FinancialInsight(
          id: _id(InsightType.upcomingCommitmentPressure, 'pressure', period),
          type: InsightType.upcomingCommitmentPressure,
          priority: InsightPriority.high,
          title: 'Upcoming commitments are high',
          explanation: 'Your upcoming bills/EMIs over the next ${safeToSpend.windowDays} days will use '
              '${percentage.toStringAsFixed(0)}% of your available balance '
              '(₹${safeToSpend.upcomingCommitments.toStringAsFixed(0)} of ₹${safeToSpend.availableMoney.toStringAsFixed(0)}).',
          recommendedAction: 'Check your Cash Flow calendar before making new purchases.',
          percentage: percentage,
          actionRoute: AppRoutes.cashFlow,
        ),
      ];
    }

    return const [];
  }

  // -------------------------------------------------------------------
  // NEW — a recently-added subscription (reuses SubscriptionCalculator and
  // RecurringTransaction.createdAt as-is; never fabricates a "before" cost).
  // -------------------------------------------------------------------

  static List<FinancialInsight> _subscriptionIncrease(
    List<RecurringTransaction> recurringTransactions,
    DateTime now,
    String period,
  ) {
    final subscriptions = SubscriptionCalculator.eligibleSubscriptions(
      recurringTransactions: recurringTransactions,
      now: now,
    );
    final bySourceId = {for (final s in subscriptions) s.sourceId: s};

    final recentlyAdded = recurringTransactions.where((rt) {
      final subscription = bySourceId[rt.id];
      if (subscription == null) return false;
      if (subscription.monthlyEquivalent < newSubscriptionMinimumAmount) return false;
      final age = now.difference(rt.createdAt).inDays;
      return age >= 0 && age <= newSubscriptionWindowDays;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (recentlyAdded.isEmpty) return const [];

    final newest = recentlyAdded.first;
    final subscription = bySourceId[newest.id]!;
    return [
      FinancialInsight(
        id: _id(InsightType.subscriptionIncrease, newest.id, period),
        type: InsightType.subscriptionIncrease,
        priority: InsightPriority.low,
        title: 'New subscription added',
        explanation: '"${subscription.name}" was added recently, adding '
            '₹${subscription.monthlyEquivalent.toStringAsFixed(0)}/month to your subscriptions.',
        recommendedAction: 'Review your subscriptions if this wasn\'t intentional.',
        amount: subscription.monthlyEquivalent,
        actionRoute: AppRoutes.subscriptions,
        relatedEntityId: newest.id,
        relatedEntityName: subscription.name,
      ),
    ];
  }

  // -------------------------------------------------------------------
  // Dedup key (PHASE 1/7) — type + entity + period, coarse enough that
  // rebuilds within the same period never mint a new id.
  // -------------------------------------------------------------------

  static String _id(InsightType type, String? entity, String period) {
    return '${type.name}:${entity ?? 'general'}:$period';
  }

  static String _periodLabel(DateTime now) => '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
