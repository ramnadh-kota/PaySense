import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/decision_memory_record.dart';
import '../models/goal.dart';
import '../models/pain_of_paying_result.dart';
import '../models/transaction.dart';
import 'affordability_calculator.dart';
import 'allowance_calculator.dart';
import 'decision_memory_engine.dart';
import 'financial_planning_calculator.dart';
import 'pain_of_paying_engine.dart';
import 'purchase_impact_calculator.dart';
import 'safe_to_spend_calculator.dart';
import 'spending_limit_calculator.dart';

/// Phase 6C/6E — Spending Decision Integration
///
/// Connects existing calculators into the PaySense purchase-decision flow
/// without duplicating or rewriting any financial formulas.
/// Pure Dart, deterministic, zero side effects.

@immutable
class SpendingDecisionInput {
  const SpendingDecisionInput({
    required this.amount,
    required this.categoryId,
    this.itemDescription,
    required this.safeToSpend,
    required this.planning,
    this.budgets = const [],
    this.goals = const [],
    this.transactions = const [],
    this.decisionHistory = const [],
    required this.now,
  });

  final double amount;
  final String categoryId;
  final String? itemDescription;
  final SafeToSpendResult safeToSpend;
  final FinancialPlanningResult planning;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<Transaction> transactions;
  final List<DecisionMemoryRecord> decisionHistory;
  final DateTime now;
}

@immutable
class SpendingDecisionResult {
  const SpendingDecisionResult({
    required this.amount,
    required this.categoryId,
    this.categorySpendingLimit,
    required this.spendingLimitSummary,
    required this.allowance,
    required this.affordability,
    required this.impact,
    required this.painOfPaying,
    this.memoryInsight,
    required this.verdictLine,
    required this.guidanceLine,
  });

  final double amount;
  final String categoryId;

  /// Status of the specific category's spending limit, if a budget exists.
  final SpendingLimitStatus? categorySpendingLimit;

  /// Aggregate summary across all category spending limits.
  final SpendingLimitSummary spendingLimitSummary;

  /// Discretionary allowance evaluation.
  final AllowanceResult allowance;

  /// Full affordability simulation result.
  final AffordabilityResult affordability;

  /// Purchase impact metrics (EMI, goal pace, spending comparison).
  final PurchaseImpactResult impact;

  /// Behavioral pain-of-paying classification.
  final PainOfPayingResult painOfPaying;

  /// Optional decision memory insight summarizing historical choices.
  final DecisionMemoryInsight? memoryInsight;

  /// Concise verdict line summarizing the decision status.
  final String verdictLine;

  /// Supportive, non-judgmental guidance line.
  final String guidanceLine;

  /// High-level recommendation tier for UI badge / signaling.
  SpendingRecommendationTier get recommendationTier {
    if (affordability.status == AffordabilityStatus.notRecommended ||
        (categorySpendingLimit != null &&
            categorySpendingLimit!.state == SpendingLimitState.exceeded) ||
        allowance.state == AllowanceState.overAllowance) {
      return SpendingRecommendationTier.avoid;
    }
    if (affordability.status == AffordabilityStatus.risky ||
        (categorySpendingLimit != null &&
            categorySpendingLimit!.state == SpendingLimitState.approaching) ||
        allowance.state == AllowanceState.tight ||
        allowance.state == AllowanceState.watchful ||
        painOfPaying.level == PainOfPayingLevel.high ||
        painOfPaying.level == PainOfPayingLevel.veryHigh) {
      return SpendingRecommendationTier.thinkAgain;
    }
    return SpendingRecommendationTier.spend;
  }

  String get recommendationLabel => recommendationTier.label;

  bool get isComfortable =>
      affordability.status == AffordabilityStatus.comfortable &&
      (categorySpendingLimit == null ||
          categorySpendingLimit!.state == SpendingLimitState.comfortable) &&
      allowance.state == AllowanceState.comfortable;

  bool get isCautionary =>
      affordability.status == AffordabilityStatus.notRecommended ||
      affordability.status == AffordabilityStatus.risky ||
      (categorySpendingLimit != null &&
          categorySpendingLimit!.state == SpendingLimitState.exceeded) ||
      allowance.state == AllowanceState.overAllowance;
}

enum SpendingRecommendationTier {
  spend,
  thinkAgain,
  avoid,
}

extension SpendingRecommendationTierExt on SpendingRecommendationTier {
  String get label {
    switch (this) {
      case SpendingRecommendationTier.spend:
        return 'Comfortable to spend';
      case SpendingRecommendationTier.thinkAgain:
        return 'Think again';
      case SpendingRecommendationTier.avoid:
        return 'Consider avoiding';
    }
  }
}

class SpendingDecisionCalculator {
  SpendingDecisionCalculator._();

  /// Evaluates a prospective expense across all 5 decision dimensions.
  static SpendingDecisionResult evaluate(SpendingDecisionInput input) {
    final amount = input.amount.isFinite && input.amount > 0 ? input.amount : 0.0;
    final now = input.now;

    // 1. Current spending limits (category + summary)
    final spendingLimits = SpendingLimitCalculator.calculate(budgets: input.budgets);
    SpendingLimitStatus? categoryLimit;
    for (final limit in spendingLimits.limits) {
      if (limit.categoryId == input.categoryId ||
          limit.categoryName.toLowerCase() == input.categoryId.toLowerCase()) {
        categoryLimit = limit;
        break;
      }
    }

    // 2. Discretionary allowance
    final allowance = input.budgets.isNotEmpty
        ? AllowanceCalculator.fromBudgets(budgets: input.budgets)
        : AllowanceCalculator.fromSafeToSpend(
            safeToSpend: input.safeToSpend,
            spentAmount: 0.0,
          );

    // 3. Purchase affordability
    final affordability = AffordabilityCalculator.calculate(
      AffordabilityInput(
        purchaseAmount: amount,
        safeToSpend: input.safeToSpend,
        planning: input.planning,
        itemDescription: input.itemDescription,
      ),
    );

    // 4. Behavioral & pain-of-paying impact
    final impact = PurchaseImpactCalculator.calculate(
      amount: amount,
      monthlyEmiBurden: input.planning.debt.monthlyEmiBurden,
      goals: input.goals,
      transactions: input.transactions,
      category: input.categoryId,
      now: now,
    );

    final painOfPaying = PainOfPayingEngine.evaluate(
      amount: amount,
      categoryId: input.categoryId,
      transactions: input.transactions,
      budgets: input.budgets,
      goals: input.goals,
      now: now,
      monthlyEmiBurden: input.planning.debt.monthlyEmiBurden,
      safeToSpend: input.safeToSpend,
    );

    // 5. Decision memory context (additive only)
    DecisionMemoryInsight? memoryInsight;
    if (input.decisionHistory.isNotEmpty) {
      final insight = DecisionMemoryEngine.analyze(
        amount: amount,
        categoryId: input.categoryId,
        history: input.decisionHistory,
        now: now,
      );
      if (insight.hasSufficientHistory) {
        memoryInsight = insight;
      }
    }

    // 6. Unified recommendation synthesis
    final verdict = _synthesizeVerdict(
      affordability: affordability,
      categoryLimit: categoryLimit,
      allowance: allowance,
    );

    final guidance = _synthesizeGuidance(
      affordability: affordability,
      categoryLimit: categoryLimit,
      allowance: allowance,
      painOfPaying: painOfPaying,
    );

    return SpendingDecisionResult(
      amount: amount,
      categoryId: input.categoryId,
      categorySpendingLimit: categoryLimit,
      spendingLimitSummary: spendingLimits,
      allowance: allowance,
      affordability: affordability,
      impact: impact,
      painOfPaying: painOfPaying,
      memoryInsight: memoryInsight,
      verdictLine: verdict,
      guidanceLine: guidance,
    );
  }

  static String _synthesizeVerdict({
    required AffordabilityResult affordability,
    required SpendingLimitStatus? categoryLimit,
    required AllowanceResult allowance,
  }) {
    if (affordability.status == AffordabilityStatus.insufficientData) {
      return 'Insufficient financial data for full assessment.';
    }
    if (affordability.status == AffordabilityStatus.notRecommended) {
      return 'Purchase exceeds your available wallet balance.';
    }
    if (categoryLimit != null && categoryLimit.state == SpendingLimitState.exceeded) {
      return 'Category limit reached for ${categoryLimit.categoryName}.';
    }
    if (allowance.state == AllowanceState.overAllowance) {
      return 'Discretionary allowance limit exceeded.';
    }
    if (affordability.status == AffordabilityStatus.risky) {
      return 'Purchase is possible, but will reduce your safety buffer.';
    }
    if (categoryLimit != null && categoryLimit.state == SpendingLimitState.approaching) {
      return 'Approaching monthly limit for ${categoryLimit.categoryName}.';
    }
    if (allowance.state == AllowanceState.tight || allowance.state == AllowanceState.watchful) {
      return 'Remaining discretionary allowance is running low.';
    }
    return 'Purchase looks comfortable within your current spending limits.';
  }

  static String _synthesizeGuidance({
    required AffordabilityResult affordability,
    required SpendingLimitStatus? categoryLimit,
    required AllowanceResult allowance,
    required PainOfPayingResult painOfPaying,
  }) {
    if (affordability.status == AffordabilityStatus.insufficientData) {
      return affordability.recommendation;
    }
    if (affordability.status == AffordabilityStatus.notRecommended) {
      return 'Consider waiting until your available cash balance increases.';
    }
    if (categoryLimit != null && categoryLimit.state == SpendingLimitState.exceeded) {
      return categoryLimit.guidanceLine;
    }
    if (allowance.state == AllowanceState.overAllowance) {
      return allowance.guidanceLine;
    }
    if (affordability.status == AffordabilityStatus.risky) {
      return affordability.recommendation;
    }
    if (categoryLimit != null && categoryLimit.state == SpendingLimitState.approaching) {
      return categoryLimit.guidanceLine;
    }
    if (allowance.state == AllowanceState.tight) {
      return allowance.guidanceLine;
    }
    if (painOfPaying.suggestedAction != null) {
      return painOfPaying.suggestedAction!;
    }
    return affordability.recommendation;
  }
}
