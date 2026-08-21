import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/subscription_summary.dart';
import 'budget_calculator.dart';
import 'financial_planning_calculator.dart';

/// FINANCIAL ACTION ENGINE 1.0 — turns already-computed calculator outputs
/// into a short, prioritized "what should I do next" list. Pure Dart: no
/// Flutter/Riverpod/Hive/network/AI dependency, and — critically — no
/// financial arithmetic of its own. Every number here is read straight from
/// [FinancialPlanningResult]/[BudgetCalculator]/[SubscriptionSummary],
/// which are themselves built from Wallet/Transaction/Budget/Goal/Loan/
/// RecurringTransaction data elsewhere. This class only classifies,
/// compares, and ranks numbers other calculators already produced.
///
/// The two thresholds below ([savingsRateDeclineThresholdPoints],
/// [subscriptionMaterialityThreshold]) are genuinely new — there was no
/// existing "materially declined"/"material subscription cost" constant
/// anywhere in the app — chosen conservatively and documented explicitly,
/// the same way [BudgetCalculator.nearLimitThresholdPercent] (80%) was a
/// deliberate, labelled product threshold rather than a financial rule.
/// Every other classification below (over-budget, near-limit, debt burden,
/// goal-at-risk) reuses a threshold/status an existing calculator already
/// established.
enum ActionPriority { critical, high, medium, positive }

enum ActionCategory {
  emergencyFund,
  overspending,
  budget,
  debt,
  subscriptions,
  goals,
  savings,
  cashFlow,
  tax,
  positiveProgress,
}

/// A stable identity for the specific rule that produced an action —
/// distinct from [ActionCategory] (a broader grouping used for icon/filter
/// purposes) so the UI/tests can key off exactly which rule fired.
enum ActionType {
  emergencyFundGap,
  overBudget,
  nearBudgetLimit,
  savingsRateDecline,
  highDebtBurden,
  subscriptionCost,
  goalAtRisk,
  allGood,
}

@immutable
class FinancialAction {
  const FinancialAction({
    required this.priority,
    required this.category,
    required this.actionType,
    required this.title,
    required this.explanation,
    required this.recommendedAction,
    this.supportingAmount,
    this.supportingPercentage,
    this.relatedEntityId,
    this.relatedEntityName,
  });

  final ActionPriority priority;
  final ActionCategory category;
  final ActionType actionType;

  final String title;
  final String explanation;
  final String recommendedAction;

  final double? supportingAmount;
  final double? supportingPercentage;

  final String? relatedEntityId;
  final String? relatedEntityName;
}

@immutable
class FinancialActionPlan {
  const FinancialActionPlan({required this.actions});

  /// Never more than [FinancialActionEngine.maxActions].
  final List<FinancialAction> actions;

  bool get isEmpty => actions.isEmpty;
}

/// Everything [FinancialActionEngine.generate] needs — all of it already
/// computed elsewhere. [subscriptions] is optional and used only to name
/// the largest individual subscriptions in Rule F; the aggregate monthly
/// subscription cost itself is read from
/// `planning.commitments.subscriptions` (already computed), not from this
/// list.
@immutable
class FinancialActionEngineInput {
  const FinancialActionEngineInput({
    required this.planning,
    required this.budgets,
    this.subscriptions = const [],
    this.now,
  });

  final FinancialPlanningResult planning;
  final List<Budget> budgets;
  final List<SubscriptionSummary> subscriptions;
  final DateTime? now;
}

class FinancialActionEngine {
  FinancialActionEngine._();

  static const int maxActions = 3;

  /// A month-over-month drop of this many percentage points (current vs.
  /// [SavingsPlan.currentSavingsRatePercent], which is the multi-month
  /// average) counts as "materially" declined. A new, explicit product
  /// threshold — see the class-level doc comment.
  static const double savingsRateDeclineThresholdPoints = 5.0;

  /// Minimum aggregate monthly subscription cost (₹) before Rule F
  /// surfaces at all — avoids flagging a single small subscription as
  /// noteworthy. A new, explicit product threshold — see the class-level
  /// doc comment.
  static const double subscriptionMaterialityThreshold = 500.0;

  static FinancialActionPlan generate(FinancialActionEngineInput input) {
    final actions = <FinancialAction>[
      ..._emergencyFund(input),
      ..._overBudget(input),
      ..._nearBudgetLimit(input),
      ..._savingsDecline(input),
      ..._debtBurden(input),
      ..._subscriptions(input),
      ..._goalsAtRisk(input),
    ];

    if (actions.isEmpty) {
      final positive = _positiveSignal(input);
      if (positive != null) actions.add(positive);
    }

    actions.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return FinancialActionPlan(actions: actions.take(maxActions).toList());
  }

  // ---------------------------------------------------------------------
  // RULE A — Emergency Fund
  // ---------------------------------------------------------------------

  static List<FinancialAction> _emergencyFund(FinancialActionEngineInput input) {
    final ef = input.planning.emergencyFund;
    if (!ef.isSourceConfigured || ef.remaining == null || ef.remaining! <= 0) return const [];

    // `monthlyContribution` is already clamped to the user's real current
    // monthly savings (never negative, never invented) — recommending
    // exactly that amount can never itself create negative cash flow.
    final recommended = ef.monthlyContribution;
    return [
      FinancialAction(
        priority: input.planning.emergencyFundStatus == PlanningComponentStatus.needsAttention
            ? ActionPriority.high
            : ActionPriority.medium,
        category: ActionCategory.emergencyFund,
        actionType: ActionType.emergencyFundGap,
        title: 'Emergency fund',
        explanation:
            'You are ₹${ef.remaining!.toStringAsFixed(0)} away from your emergency-fund target.',
        recommendedAction: (recommended != null && recommended > 0)
            ? 'Consider allocating ₹${recommended.toStringAsFixed(0)}/month toward your emergency fund.'
            : 'Review your budget to find room to start building your emergency fund.',
        supportingAmount: ef.remaining,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE B — Over budget
  // ---------------------------------------------------------------------

  static List<FinancialAction> _overBudget(FinancialActionEngineInput input) {
    final overspend = BudgetCalculator.overspendSummary(input.budgets);
    if (!overspend.hasOverspend) return const [];

    final overBudgetCategories = input.budgets
        .where((b) => BudgetCalculator.statusFor(allocatedAmount: b.allocatedAmount, spentAmount: b.spentAmount) ==
            BudgetStatus.overBudget)
        .toList()
      ..sort((a, b) => (b.spentAmount - b.allocatedAmount).compareTo(a.spentAmount - a.allocatedAmount));
    final largest = overBudgetCategories.first;

    return [
      FinancialAction(
        priority: ActionPriority.high,
        category: ActionCategory.overspending,
        actionType: ActionType.overBudget,
        title: 'Over budget',
        explanation: 'You are ₹${overspend.totalOverspend.toStringAsFixed(0)} over budget in '
            '${overspend.categoryCount} categor${overspend.categoryCount == 1 ? 'y' : 'ies'}.',
        recommendedAction: 'Review your spending in ${largest.categoryName}.',
        supportingAmount: overspend.totalOverspend,
        relatedEntityId: largest.id,
        relatedEntityName: largest.categoryName,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE C — Near budget limit
  // ---------------------------------------------------------------------

  static List<FinancialAction> _nearBudgetLimit(FinancialActionEngineInput input) {
    final nearLimit = input.budgets
        .where((b) => BudgetCalculator.statusFor(allocatedAmount: b.allocatedAmount, spentAmount: b.spentAmount) ==
            BudgetStatus.nearLimit)
        .toList()
      ..sort((a, b) => b.percentageUsed.compareTo(a.percentageUsed));
    if (nearLimit.isEmpty) return const [];

    final budget = nearLimit.first;
    return [
      FinancialAction(
        priority: ActionPriority.medium,
        category: ActionCategory.budget,
        actionType: ActionType.nearBudgetLimit,
        title: 'Approaching budget limit',
        explanation:
            'Your ${budget.categoryName} budget is approaching its limit (${budget.percentageUsed.toStringAsFixed(0)}% used).',
        recommendedAction: 'Keep an eye on ${budget.categoryName} spending for the rest of the month.',
        supportingPercentage: budget.percentageUsed,
        relatedEntityId: budget.id,
        relatedEntityName: budget.categoryName,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE D — Savings rate decline
  // ---------------------------------------------------------------------

  static List<FinancialAction> _savingsDecline(FinancialActionEngineInput input) {
    final current = input.planning.overview.savingsRatePercent;
    final average = input.planning.savingsPlan.currentSavingsRatePercent;
    if (current == null || average == null || !input.planning.savingsPlan.hasSufficientData) {
      return const [];
    }
    final drop = average - current;
    if (drop < savingsRateDeclineThresholdPoints) return const [];

    return [
      FinancialAction(
        priority: ActionPriority.medium,
        category: ActionCategory.savings,
        actionType: ActionType.savingsRateDecline,
        title: 'Savings rate dropped',
        explanation: 'Your savings rate dropped this month to ${current.toStringAsFixed(1)}%, '
            'compared to your average of ${average.toStringAsFixed(1)}%.',
        recommendedAction: 'Review this month\'s spending to see what changed.',
        supportingPercentage: drop,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE E — Debt burden
  // ---------------------------------------------------------------------

  static List<FinancialAction> _debtBurden(FinancialActionEngineInput input) {
    if (input.planning.debtStatus != PlanningComponentStatus.needsAttention) return const [];
    final debt = input.planning.debt;
    if (!debt.hasDebt) return const [];

    return [
      FinancialAction(
        priority: ActionPriority.high,
        category: ActionCategory.debt,
        actionType: ActionType.highDebtBurden,
        title: 'High debt commitments',
        explanation: 'Your monthly debt commitments are relatively high'
            '${debt.emiToIncomePercent != null ? ' (${debt.emiToIncomePercent!.toStringAsFixed(0)}% of income)' : ''}.'
            ' This is not professional financial advice.',
        recommendedAction: 'Consider reviewing your loans in the Debt Overview.',
        supportingPercentage: debt.emiToIncomePercent,
        supportingAmount: debt.monthlyEmiBurden,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE F — Subscriptions
  // ---------------------------------------------------------------------

  static List<FinancialAction> _subscriptions(FinancialActionEngineInput input) {
    final monthlyCost = input.planning.commitments.subscriptions;
    if (monthlyCost < subscriptionMaterialityThreshold) return const [];

    final largest = [...input.subscriptions]..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
    final topName = largest.isNotEmpty ? largest.first.name : null;

    return [
      FinancialAction(
        priority: ActionPriority.medium,
        category: ActionCategory.subscriptions,
        actionType: ActionType.subscriptionCost,
        title: 'Subscriptions',
        explanation: 'Your subscriptions cost approximately ₹${monthlyCost.toStringAsFixed(0)}/month'
            '${topName != null ? ', the largest being $topName' : ''}.',
        recommendedAction: 'Review your subscriptions to see which ones you still use.',
        supportingAmount: monthlyCost,
        relatedEntityId: largest.isNotEmpty ? largest.first.id : null,
        relatedEntityName: topName,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE G — Goals at risk
  // ---------------------------------------------------------------------

  static List<FinancialAction> _goalsAtRisk(FinancialActionEngineInput input) {
    final atRisk = input.planning.goalProjections
        .where((g) => g.status == GoalProjectionStatus.atRisk)
        .toList()
      ..sort((a, b) => (b.contributionGap ?? 0).compareTo(a.contributionGap ?? 0));
    if (atRisk.isEmpty) return const [];

    final goal = atRisk.first;
    final gap = goal.contributionGap;
    return [
      FinancialAction(
        priority: ActionPriority.medium,
        category: ActionCategory.goals,
        actionType: ActionType.goalAtRisk,
        title: 'Goal at risk',
        explanation: '"${goal.title}" may fall behind its target. '
            'Current: ₹${goal.currentAmount.toStringAsFixed(0)} of ₹${goal.targetAmount.toStringAsFixed(0)}'
            '${goal.estimatedCompletionDate != null ? ', estimated completion ${_shortDate(goal.estimatedCompletionDate!)}' : ''}.',
        recommendedAction: gap != null && gap > 0
            ? 'Consider increasing the monthly contribution by ₹${gap.toStringAsFixed(0)} if affordable.'
            : 'Review your contribution plan for this goal.',
        supportingAmount: gap,
        relatedEntityId: goal.goalId,
        relatedEntityName: goal.title,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // RULE H — Positive signal
  // ---------------------------------------------------------------------

  static FinancialAction? _positiveSignal(FinancialActionEngineInput input) {
    final planning = input.planning;

    if (planning.emergencyFundStatus == PlanningComponentStatus.good) {
      return const FinancialAction(
        priority: ActionPriority.positive,
        category: ActionCategory.positiveProgress,
        actionType: ActionType.allGood,
        title: 'You are on track',
        explanation: 'Your emergency fund is in good shape.',
        recommendedAction: 'Keep it up.',
      );
    }
    if (planning.goalStatus == PlanningComponentStatus.good) {
      return const FinancialAction(
        priority: ActionPriority.positive,
        category: ActionCategory.positiveProgress,
        actionType: ActionType.allGood,
        title: 'You are on track',
        explanation: 'Your goals are progressing well.',
        recommendedAction: 'Keep it up.',
      );
    }
    if (planning.savingsStatus == PlanningComponentStatus.good) {
      return const FinancialAction(
        priority: ActionPriority.positive,
        category: ActionCategory.positiveProgress,
        actionType: ActionType.allGood,
        title: 'You are on track',
        explanation: 'Your savings rate is healthy.',
        recommendedAction: 'Keep it up.',
      );
    }
    // `debtStatus` is trivially "good" (score 100) whenever the user has
    // no loans at all — that's the absence of a problem, not an earned
    // positive signal, so it must never be the sole basis for "on track".
    if (planning.debtStatus == PlanningComponentStatus.good && planning.debt.hasDebt) {
      return const FinancialAction(
        priority: ActionPriority.positive,
        category: ActionCategory.positiveProgress,
        actionType: ActionType.allGood,
        title: 'You are on track',
        explanation: 'Your debt commitments are well under control.',
        recommendedAction: 'Keep it up.',
      );
    }
    // Never manufacture praise when nothing is actually measurably good.
    return null;
  }

  static String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
