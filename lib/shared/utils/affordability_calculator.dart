import 'package:flutter/foundation.dart';

import 'financial_planning_calculator.dart';
import 'safe_to_spend_calculator.dart';

/// FINANCIAL ACTION ENGINE 1.0 / "CAN I AFFORD THIS?" — PHASE 3/4/5.
/// Pure Dart, no Flutter/Riverpod/Hive/network/AI dependency, and no
/// financial arithmetic of its own beyond simple comparisons: every input
/// figure is read from [SafeToSpendResult]/[FinancialPlanningResult],
/// which already reuse Wallet/Bill/Loan/RecurringTransaction/Goal data.
/// This is a SIMULATION ONLY — it never persists anything and never
/// mutates any of its inputs.
///
/// METHODOLOGY (explicit, not invented on the fly — see the milestone
/// report for the full reasoning):
/// - "Available cash" is [SafeToSpendResult.availableMoney] (wallet
///   balances) — never compared to the purchase price alone.
/// - "Can this be paid for without touching money already earmarked for
///   known upcoming bills/EMIs/recurring items" is
///   [SafeToSpendResult.safeToSpend] — the SAME figure the Safe-to-Spend
///   screen already shows, reused as-is.
/// - "Is there an existing, already-flagged structural problem this
///   purchase would compound" reuses
///   [FinancialPlanningResult.emergencyFundStatus] /
///   [FinancialPlanningResult.debtStatus] directly — no new percentage-of-
///   income threshold is invented here.
/// - The emergency-fund and goal impact figures both rest on one explicit,
///   stated assumption: a one-time purchase is money that would otherwise
///   have gone toward the emergency fund gap / the earliest incomplete
///   goal's own current pace. This is stated plainly in each result's
///   [reasons] rather than silently assumed.
enum AffordabilityStatus { comfortable, possible, risky, notRecommended, insufficientData }

@immutable
class AffordabilityInput {
  const AffordabilityInput({
    required this.purchaseAmount,
    required this.safeToSpend,
    required this.planning,
    this.itemDescription,
  });

  final double purchaseAmount;
  final SafeToSpendResult safeToSpend;
  final FinancialPlanningResult planning;

  /// Optional free-text label ("phone", "laptop") — display only, never
  /// used in any calculation.
  final String? itemDescription;
}

@immutable
class AffordabilityResult {
  const AffordabilityResult({
    required this.status,
    required this.purchaseAmount,
    required this.availableAfterPurchase,
    required this.emergencyFundImpact,
    required this.goalImpact,
    required this.cashFlowImpact,
    required this.estimatedGoalDelayMonths,
    required this.recommendation,
    required this.reasons,
    required this.warnings,
    required this.confidence,
  });

  final AffordabilityStatus status;
  final double purchaseAmount;

  /// Wallet cash remaining immediately after paying, before accounting for
  /// any upcoming commitment — [SafeToSpendResult.availableMoney] minus
  /// [purchaseAmount]. Never floored at 0: a negative value is a real,
  /// meaningful signal (the purchase alone exceeds available cash).
  final double availableAfterPurchase;

  /// How much of this purchase is money that would otherwise have gone
  /// toward the emergency-fund gap — 0 when the fund is already fully
  /// funded or not configured (never fabricated).
  final double emergencyFundImpact;

  /// Same reasoning as [emergencyFundImpact], but against the earliest
  /// incomplete goal's remaining amount — 0 when there's no incomplete
  /// goal to weigh against.
  final double goalImpact;

  /// [SafeToSpendResult.safeToSpend] minus [purchaseAmount] — negative
  /// means the purchase would eat into money already earmarked for known
  /// upcoming bills/EMIs/recurring commitments.
  final double cashFlowImpact;

  /// `ceil(purchaseAmount / earliestIncompleteGoal.impliedMonthlyContribution)`
  /// — null when there's no incomplete goal, or no positive implied
  /// contribution pace to divide by (never a fabricated estimate).
  final int? estimatedGoalDelayMonths;

  final String recommendation;
  final List<String> reasons;
  final List<String> warnings;

  /// 0.0-1.0 — reduced (not just described) when underlying data is
  /// incomplete (no emergency fund configured, no goals to weigh against,
  /// no income data for debt burden), so a caller can visually distinguish
  /// a well-supported verdict from a thin one.
  final double confidence;
}

class AffordabilityCalculator {
  AffordabilityCalculator._();

  static AffordabilityResult calculate(AffordabilityInput input) {
    final amount = input.purchaseAmount.isFinite && input.purchaseAmount > 0 ? input.purchaseAmount : 0.0;
    final safeToSpend = input.safeToSpend;
    final planning = input.planning;
    final overview = planning.overview;

    final reasons = <String>[];
    final warnings = <String>[];

    if (!safeToSpend.hasSufficientData || !overview.hasIncomeData) {
      if (!safeToSpend.hasSufficientData) reasons.add('No wallet balance data is available.');
      if (!overview.hasIncomeData) reasons.add('No income data is available.');
      return AffordabilityResult(
        status: AffordabilityStatus.insufficientData,
        purchaseAmount: amount,
        availableAfterPurchase: 0,
        emergencyFundImpact: 0,
        goalImpact: 0,
        cashFlowImpact: 0,
        estimatedGoalDelayMonths: null,
        recommendation: "I don't have enough information to confidently assess this purchase.",
        reasons: reasons,
        warnings: warnings,
        confidence: 0.0,
      );
    }

    final availableMoney = safeToSpend.availableMoney;
    final availableAfterPurchase = availableMoney - amount;
    final cashFlowImpact = safeToSpend.safeToSpend - amount;

    // Emergency fund impact — see the class-level doc comment for the
    // stated assumption.
    final ef = planning.emergencyFund;
    final emergencyFundImpact = (ef.isSourceConfigured && !ef.isFullyFunded && ef.remaining != null)
        ? amount.clamp(0.0, ef.remaining!)
        : 0.0;

    // Goal impact — earliest incomplete goal, same selection rule
    // FinancialPlanningCalculator.whatIf already uses.
    final incompleteGoals = planning.goalProjections
        .where((g) => g.status != GoalProjectionStatus.completed)
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final targetGoal = incompleteGoals.isEmpty ? null : incompleteGoals.first;
    final goalImpact = targetGoal != null ? amount.clamp(0.0, targetGoal.remainingAmount) : 0.0;
    final pace = targetGoal?.impliedMonthlyContribution;
    final estimatedGoalDelayMonths = (targetGoal != null && pace != null && pace > 0)
        ? (amount / pace).ceil()
        : null;

    // `emergencyFundStatus` scores an UNCONFIGURED fund the same as a
    // critically underfunded one (current=0 against a real target) — for
    // affordability specifically that would flag nearly every user who
    // simply hasn't set up emergency-fund tracking yet. Only treat it as a
    // real red flag when the user has actually configured it.
    final emergencyFundFlagged =
        ef.isSourceConfigured && planning.emergencyFundStatus == PlanningComponentStatus.needsAttention;
    final debtFlagged = planning.debtStatus == PlanningComponentStatus.needsAttention;

    AffordabilityStatus status;
    if (amount > availableMoney) {
      status = AffordabilityStatus.notRecommended;
      reasons.add('This purchase costs more than your available wallet balance.');
    } else if (amount > safeToSpend.safeToSpend) {
      reasons.add('This purchase would use money already needed for upcoming bills/EMIs '
          'within the next ${safeToSpend.windowDays} days.');
      status = (emergencyFundFlagged || debtFlagged) ? AffordabilityStatus.risky : AffordabilityStatus.possible;
      if (emergencyFundFlagged) reasons.add('Your emergency fund already needs attention.');
      if (debtFlagged) reasons.add('Your existing debt commitments are already relatively high.');
    } else if (emergencyFundFlagged || debtFlagged) {
      status = AffordabilityStatus.risky;
      if (emergencyFundFlagged) reasons.add('Your emergency fund already needs attention.');
      if (debtFlagged) reasons.add('Your existing debt commitments are already relatively high.');
    } else {
      status = AffordabilityStatus.comfortable;
      reasons.add('This purchase fits within your available safe-to-spend balance.');
    }

    if (emergencyFundImpact > 0) {
      warnings.add(
        'This purchase would reduce money that could otherwise go toward your '
        'emergency-fund gap by up to ₹${emergencyFundImpact.toStringAsFixed(0)}.',
      );
    }
    if (estimatedGoalDelayMonths != null && estimatedGoalDelayMonths > 0) {
      warnings.add(
        'At your current pace toward "${targetGoal!.title}", this purchase represents '
        'roughly $estimatedGoalDelayMonths month${estimatedGoalDelayMonths == 1 ? '' : 's'} '
        'of contribution.',
      );
    }
    if (cashFlowImpact < 0) {
      warnings.add('After this purchase, you would be ₹${(-cashFlowImpact).toStringAsFixed(0)} '
          'short of covering known upcoming commitments from your safe-to-spend buffer.');
    }

    final recommendation = _recommendationFor(status, amount, safeToSpend.safeToSpend);

    var confidence = 1.0;
    if (!ef.isSourceConfigured) confidence -= 0.2;
    if (targetGoal == null) confidence -= 0.15;
    if (!planning.debt.hasIncomeData) confidence -= 0.15;
    confidence = confidence.clamp(0.0, 1.0);

    return AffordabilityResult(
      status: status,
      purchaseAmount: amount,
      availableAfterPurchase: availableAfterPurchase,
      emergencyFundImpact: emergencyFundImpact,
      goalImpact: goalImpact,
      cashFlowImpact: cashFlowImpact,
      estimatedGoalDelayMonths: estimatedGoalDelayMonths,
      recommendation: recommendation,
      reasons: reasons,
      warnings: warnings,
      confidence: confidence,
    );
  }

  static String _recommendationFor(AffordabilityStatus status, double amount, double safeToSpend) {
    switch (status) {
      case AffordabilityStatus.comfortable:
        return 'Based on the information currently available, this purchase looks comfortable.';
      case AffordabilityStatus.possible:
        return 'Based on the information currently available, this purchase is possible, '
            'but it would reduce your near-term buffer.';
      case AffordabilityStatus.risky:
        final gap = amount - safeToSpend;
        return 'Based on the information currently available, this purchase is possible, but risky. '
            'Consider waiting until your available balance is higher'
            '${gap > 0 ? ' by around ₹${gap.toStringAsFixed(0)}' : ''}.';
      case AffordabilityStatus.notRecommended:
        return 'Based on the information currently available, this purchase is not recommended right now.';
      case AffordabilityStatus.insufficientData:
        return "I don't have enough information to confidently assess this purchase.";
    }
  }
}
