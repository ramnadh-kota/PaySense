import 'package:flutter/foundation.dart';

import '../models/goal.dart';
import '../models/transaction.dart';

/// "THINK BEFORE YOU PAY" BUG FIX — a pure, read-only Dart calculator.
///
/// BUG: the Decision Coach dialog (`DecisionCoachDialog`) previously
/// received `emiPercentage: 18`, `savingsGoalPercentage: 3`, and
/// `comparisonMessage: 'This equals two days of groceries.'` as LITERAL
/// HARDCODED CONSTANTS in `add_expense_screen.dart` — they never reflected
/// the amount the user actually typed. This calculator replaces those
/// constants with real, deterministic figures derived from the SAME amount
/// the dialog's header displays, reusing already-computed application data:
///
/// - EMI Impact reuses [FinancialOverview.totalDebt]-adjacent data — the
///   caller passes `monthlyEmiBurden` straight from
///   `FinancialPlanningResult.debt.monthlyEmiBurden` (already computed by
///   `FinancialPlanningCalculator`), never re-summed here.
/// - Savings Goal Impact reuses the real, stored [Goal.targetAmount]/
///   [Goal.currentAmount]/[Goal.isCompleted] fields — never a fabricated
///   contribution rate.
/// - Perspective reuses real [Transaction] history for the purchase's own
///   category (falling back to whichever category has the most recorded
///   history if the current category has none) — never a generic "Indian
///   household" average.
///
/// This calculator is READ-ONLY: it never touches a repository, never
/// creates/modifies a Transaction/Wallet/Goal/Loan/Budget/Subscription. It
/// has no Flutter/BuildContext dependency, so it's directly unit-testable.
@immutable
class PurchaseImpactResult {
  const PurchaseImpactResult({
    required this.amount,
    required this.emiPercentage,
    required this.savingsGoalPercentage,
    required this.perspectiveMessage,
  });

  final double amount;

  /// `amount / monthlyEmiBurden * 100`. Null when there's no active-loan
  /// EMI data to compare against (no active loans, or a zero EMI burden) —
  /// never a fabricated percentage or a divide-by-zero.
  final double? emiPercentage;

  /// `amount / remainingGoalAmount * 100`, where `remainingGoalAmount` is
  /// the sum of `targetAmount - currentAmount` across every incomplete
  /// goal. Null when there's no incomplete goal to compare against.
  final double? savingsGoalPercentage;

  /// Always non-null — either a real spending-history comparison, or an
  /// honest "not enough history" note. Never a generic/fabricated average.
  final String perspectiveMessage;
}

class PurchaseImpactCalculator {
  PurchaseImpactCalculator._();

  /// How far back to look for a category's spending history when building
  /// the Perspective insight. A new, explicitly documented window — no
  /// existing calculator computes a per-category weekly average today.
  static const int perspectiveLookbackDays = 90;

  static PurchaseImpactResult calculate({
    required double amount,
    required double monthlyEmiBurden,
    required List<Goal> goals,
    required List<Transaction> transactions,
    String? category,
    required DateTime now,
  }) {
    final emiPercentage = monthlyEmiBurden > 0 ? (amount / monthlyEmiBurden * 100) : null;

    final remainingGoalAmount = goals.where((g) => !g.isCompleted).fold<double>(
      0,
      (sum, g) => sum + (g.targetAmount - g.currentAmount).clamp(0, double.infinity),
    );
    final savingsGoalPercentage = remainingGoalAmount > 0 ? (amount / remainingGoalAmount * 100) : null;

    final perspectiveMessage = _perspectiveFor(
      amount: amount,
      transactions: transactions,
      category: category,
      now: now,
    );

    return PurchaseImpactResult(
      amount: amount,
      emiPercentage: emiPercentage,
      savingsGoalPercentage: savingsGoalPercentage,
      perspectiveMessage: perspectiveMessage,
    );
  }

  static String _perspectiveFor({
    required double amount,
    required List<Transaction> transactions,
    required String? category,
    required DateTime now,
  }) {
    final windowStart = now.subtract(const Duration(days: perspectiveLookbackDays));
    final expensesInWindow = transactions.where(
      (t) => t.transactionType.toLowerCase() == 'expense' &&
          !t.createdAt.isBefore(windowStart) &&
          !t.createdAt.isAfter(now),
    );

    double totalFor(String categoryId) => expensesInWindow
        .where((t) => t.categoryId == categoryId)
        .fold<double>(0, (sum, t) => sum + t.amount);

    String? resolvedCategory;
    double categoryTotal = 0;

    if (category != null && category.isNotEmpty) {
      final total = totalFor(category);
      if (total > 0) {
        resolvedCategory = category;
        categoryTotal = total;
      }
    }

    // Fall back to whichever category has the most recorded history in the
    // window — "another clearly supported spending category" per the
    // product spec, never a generic/fabricated average.
    if (resolvedCategory == null) {
      final totalsByCategory = <String, double>{};
      for (final t in expensesInWindow) {
        totalsByCategory[t.categoryId] = (totalsByCategory[t.categoryId] ?? 0) + t.amount;
      }
      if (totalsByCategory.isNotEmpty) {
        final best = totalsByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);
        resolvedCategory = best.key;
        categoryTotal = best.value;
      }
    }

    if (resolvedCategory == null || categoryTotal <= 0) {
      return "Not enough spending history yet for a personalized comparison.";
    }

    final weeksInWindow = perspectiveLookbackDays / 7;
    final weeklyAverage = categoryTotal / weeksInWindow;
    if (weeklyAverage <= 0) {
      return "Not enough spending history yet for a personalized comparison.";
    }

    final weeks = amount / weeklyAverage;
    final categoryLabel = resolvedCategory.toLowerCase();
    if (weeks < 0.75) {
      return "This is less than a week of your $categoryLabel spending.";
    }
    final roundedWeeks = weeks.round().clamp(1, 999);
    return "This is about $roundedWeeks week${roundedWeeks == 1 ? '' : 's'} of your $categoryLabel spending.";
  }
}
