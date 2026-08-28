import '../providers/budget_provider.dart' show BudgetTotals;
import 'financial_planning_calculator.dart' show GoalProjection, GoalProjectionStatus;
import 'safe_to_spend_calculator.dart';

/// FUN FUNDS — "how much money can I safely spend for fun without
/// damaging my financial position?"
///
/// A thin ADAPTER over three already-computed, already-tested results —
/// never a fourth independent income/expense/budget formula:
///   - [SafeToSpendResult] (wallets minus overdue/upcoming bills+EMIs+
///     recurring within 30 days) is the starting point.
///   - Remaining budget commitments come from [BudgetTotals.remainingBudget]
///     — money already allocated to a category this month but not yet
///     spent, so it isn't "free" even though it hasn't left a wallet yet.
///   - Required goal contributions come from
///     [GoalProjection.requiredMonthlyContribution] — what the user would
///     need to set aside this month to stay on pace for each active goal's
///     target date.
///
/// PaySense's Safe-to-Spend deliberately does NOT reserve for budgets or
/// goals (see its own doc comment) — Fun Funds is the layer that does,
/// specifically so it never doubles as investment/savings guidance itself.
class FunFundsResult {
  const FunFundsResult({
    required this.safeToSpend,
    required this.budgetCommitments,
    required this.goalContributions,
    required this.safetyBuffer,
    required this.funFunds,
    required this.hasSufficientData,
    required this.shortfall,
  });

  /// The [SafeToSpendResult.safeToSpend] this calculation started from.
  final double safeToSpend;

  /// Money already allocated to a budget category this month but not yet
  /// spent (`BudgetTotals.remainingBudget`, floored at 0 — an over-budget
  /// account has nothing further to reserve here; that overspend already
  /// reduced the wallet balance Safe-to-Spend started from).
  final double budgetCommitments;

  /// Sum of [GoalProjection.requiredMonthlyContribution] across every
  /// goal that isn't already [GoalProjectionStatus.completed]. A goal with
  /// no computable required contribution (target date already passed, or
  /// too little history) contributes 0 here — never a fabricated figure.
  final double goalContributions;

  /// `safeToSpend * FunFundsCalculator.safetyBufferRate` — an explicit,
  /// documented reserve on top of known commitments, never spent by
  /// design. Always shown in the UI breakdown, never silently folded in.
  final double safetyBuffer;

  /// `max(0, safeToSpend - budgetCommitments - goalContributions -
  /// safetyBuffer)`. Never negative — see [shortfall].
  final double funFunds;

  /// False when the underlying [SafeToSpendResult] itself had insufficient
  /// data (no wallets yet) — callers should show "Not enough data yet",
  /// never a fabricated ₹0 that looks like a computed result.
  final bool hasSufficientData;

  /// How much budget+goal+buffer commitments exceed Safe-to-Spend by, or 0
  /// when there's no shortfall. Mutually exclusive with a positive
  /// [funFunds], mirroring [SafeToSpendResult.shortfall]'s convention.
  final double shortfall;

  bool get isShortfall => shortfall > 0;
}

class FunFundsCalculator {
  FunFundsCalculator._();

  /// 10% of Safe-to-Spend, reserved on top of known bills/EMIs/recurring/
  /// budgets/goals — a conservative, explicit buffer so Fun Funds never
  /// recommends spending every last safe rupee. Not user-configurable
  /// today (no existing settings concept to reuse — see
  /// SafeToSpendCalculator's identical reasoning for its own window).
  static const double safetyBufferRate = 0.10;

  static FunFundsResult calculate({
    required SafeToSpendResult safeToSpend,
    required BudgetTotals budgetTotals,
    required List<GoalProjection> goalProjections,
  }) {
    if (!safeToSpend.hasSufficientData) {
      return const FunFundsResult(
        safeToSpend: 0,
        budgetCommitments: 0,
        goalContributions: 0,
        safetyBuffer: 0,
        funFunds: 0,
        hasSufficientData: false,
        shortfall: 0,
      );
    }

    final budgetCommitments = budgetTotals.remainingBudget > 0 ? budgetTotals.remainingBudget : 0.0;

    final goalContributions = goalProjections
        .where((g) => g.status != GoalProjectionStatus.completed)
        .fold<double>(0, (sum, g) => sum + (g.requiredMonthlyContribution ?? 0));

    final safetyBuffer = safeToSpend.safeToSpend * safetyBufferRate;

    final raw = safeToSpend.safeToSpend - budgetCommitments - goalContributions - safetyBuffer;
    final funFunds = raw > 0 ? raw : 0.0;
    final shortfall = raw < 0 ? -raw : 0.0;

    return FunFundsResult(
      safeToSpend: safeToSpend.safeToSpend,
      budgetCommitments: budgetCommitments,
      goalContributions: goalContributions,
      safetyBuffer: safetyBuffer,
      funFunds: funFunds,
      hasSufficientData: true,
      shortfall: shortfall,
    );
  }
}
