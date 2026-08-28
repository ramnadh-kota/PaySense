import '../models/budget.dart';
import '../models/goal.dart';
import '../models/pain_of_paying_result.dart';
import '../models/transaction.dart';
import 'dashboard_helpers.dart' show selectRelevantGoal;
import 'purchase_impact_calculator.dart';
import 'safe_to_spend_calculator.dart';

/// PAIN-OF-PAYING ENGINE — PaySense's core product idea made concrete:
/// "make people more financially aware at the moment they spend."
///
/// Deterministic, pure Dart, NOT AI. Deliberately a thin ADAPTER over
/// existing calculators rather than a second financial-math engine:
/// - EMI impact %, aggregate savings-goal impact %, and the category
///   "perspective" comparison all come straight from
///   [PurchaseImpactCalculator.calculate] — never re-derived here.
/// - Affordability context comes from an already-computed
///   [SafeToSpendResult] (the same one [SafeToSpendCalculator]/the
///   dashboard's Safe-to-Spend card already produce) — the caller passes
///   it in rather than this engine recomputing wallets/bills/loans/
///   recurring itself.
/// - The single nearest goal (for the neutral "same amount as your X
///   goal" phrasing) reuses [selectRelevantGoal] — the exact same
///   selection the Dashboard's own Goals section already uses.
///
/// Genuinely new arithmetic here (nothing else in the app computes
/// these): this-week same-category spend/frequency, and same-category
/// "is this atypically large" via a real median of recent same-category
/// transactions. Both are omitted entirely when there isn't enough real
/// data (see [minSampleForTypicalComparison]) — never a fabricated
/// average.
///
/// AWARENESS, NOT RISK: [PainOfPayingLevel] never predicts financial
/// risk — it's a deterministic point score over real signals, purely to
/// decide how much (if any) awareness UI to surface. Never shames the
/// user; [suggestedAction] is always neutral, supportive language.
class PainOfPayingEngine {
  PainOfPayingEngine._();

  static const int weeklyWindowDays = 7;
  static const int typicalLookbackDays = 90;
  static const int minSampleForTypicalComparison = 3;

  static const double typicalMultiplierModerate = 1.5;
  static const double typicalMultiplierHigh = 2.0;
  static const double typicalMultiplierVeryHigh = 3.0;

  static const int frequencyThresholdModerate = 3;
  static const int frequencyThresholdHigh = 5;

  static const double budgetThresholdModerate = 50;
  static const double budgetThresholdHigh = 80;
  static const double budgetThresholdVeryHigh = 100;

  static const double emiThresholdModerate = 15;
  static const double emiThresholdHigh = 30;

  /// A purchase counts as "close to" a goal's remaining amount — worth a
  /// neutral mention — once it reaches this fraction of what's left.
  static const double goalProximityRatio = 0.5;

  static const List<String> _fullMonthNames = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];

  /// Evaluates one transaction (already saved, or about to be) against
  /// the user's real, existing financial context.
  ///
  /// [excludeTransactionId]: when evaluating an ALREADY-SAVED transaction
  /// (e.g. for the Dashboard's "today's spending" summary), pass its id
  /// so this-week frequency/total signals don't double-count it against
  /// itself.
  static PainOfPayingResult evaluate({
    required double amount,
    required String categoryId,
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<Goal> goals,
    required DateTime now,
    double? monthlyEmiBurden,
    SafeToSpendResult? safeToSpend,
    String? excludeTransactionId,
  }) {
    final category = categoryId.trim().isEmpty ? 'this' : categoryId;
    final signals = <PainOfPayingSignal>[];
    var points = 0;
    String? suggestedAction;

    final relevantTransactions = excludeTransactionId == null
        ? transactions
        : transactions.where((t) => t.id != excludeTransactionId).toList();

    // ---- Reuse PurchaseImpactCalculator for EMI/goal-aggregate/perspective ----
    final impact = PurchaseImpactCalculator.calculate(
      amount: amount,
      monthlyEmiBurden: monthlyEmiBurden ?? 0,
      goals: goals,
      transactions: relevantTransactions,
      category: categoryId,
      now: now,
    );

    if (impact.emiPercentage != null) {
      final emiPct = impact.emiPercentage!;
      signals.add(
        PainOfPayingSignal(
          label: 'EMI impact',
          detail: 'This is ${emiPct.toStringAsFixed(0)}% of your monthly EMI.',
        ),
      );
      if (emiPct >= emiThresholdHigh) {
        points += 2;
      } else if (emiPct >= emiThresholdModerate) {
        points += 1;
      }
    }

    signals.add(PainOfPayingSignal(label: 'Perspective', detail: impact.perspectiveMessage));

    // ---- Monthly category budget (REAL budgets only — no fabricated weekly budget) ----
    final monthName = _fullMonthNames[now.month - 1];
    Budget? matchingBudget;
    for (final b in budgets) {
      if (b.categoryId == categoryId && b.year == now.year && b.month.toLowerCase() == monthName) {
        matchingBudget = b;
        break;
      }
    }
    if (matchingBudget != null) {
      final projectedSpent = matchingBudget.spentAmount + amount;
      final projectedPct = matchingBudget.allocatedAmount > 0
          ? (projectedSpent / matchingBudget.allocatedAmount * 100)
          : null;
      final remaining = matchingBudget.allocatedAmount - matchingBudget.spentAmount;
      signals.add(
        PainOfPayingSignal(
          label: 'Budget impact',
          detail: remaining > 0
              ? 'You have ₹${remaining.toStringAsFixed(0)} left in your $category budget this month.'
              : 'Your $category budget for this month is already used up.',
        ),
      );
      if (projectedPct != null) {
        if (projectedPct >= budgetThresholdVeryHigh) {
          points += 3;
          suggestedAction ??=
              'Consider keeping upcoming $category purchases lighter until next month\'s budget resets.';
        } else if (projectedPct >= budgetThresholdHigh) {
          points += 2;
        } else if (projectedPct >= budgetThresholdModerate) {
          points += 1;
        }
      }
    }

    // ---- This-week same-category spend + frequency (real counts, no fabrication) ----
    final weekStart = now.subtract(const Duration(days: weeklyWindowDays));
    final sameCategoryThisWeek = relevantTransactions.where(
      (t) =>
          t.transactionType.toLowerCase() == 'expense' &&
          t.categoryId == categoryId &&
          !t.createdAt.isBefore(weekStart) &&
          !t.createdAt.isAfter(now),
    ).toList();
    final weekTotal = sameCategoryThisWeek.fold<double>(0, (sum, t) => sum + t.amount) + amount;
    final weekCount = sameCategoryThisWeek.length + 1;

    signals.add(
      PainOfPayingSignal(
        label: 'This week',
        detail: 'You\'ve now spent ₹${weekTotal.toStringAsFixed(0)} on $category this week '
            '(this is your ${_ordinal(weekCount)} $category purchase).',
      ),
    );
    if (weekCount >= frequencyThresholdHigh) {
      points += 2;
      suggestedAction ??= 'Consider spacing out your next $category purchase.';
    } else if (weekCount >= frequencyThresholdModerate) {
      points += 1;
    }

    // ---- Typical-size comparison — real median of recent same-category spend ----
    final lookbackStart = now.subtract(const Duration(days: typicalLookbackDays));
    final recentSameCategory = relevantTransactions.where(
      (t) =>
          t.transactionType.toLowerCase() == 'expense' &&
          t.categoryId == categoryId &&
          !t.createdAt.isBefore(lookbackStart) &&
          t.createdAt.isBefore(now),
    ).map((t) => t.amount).toList();

    if (recentSameCategory.length >= minSampleForTypicalComparison) {
      final median = _median(recentSameCategory);
      if (median > 0) {
        final ratio = amount / median;
        if (ratio >= typicalMultiplierVeryHigh) {
          points += 3;
          signals.add(PainOfPayingSignal(
            label: 'Size',
            detail: 'This is much larger than your usual $category purchases '
                '(around ${ratio.toStringAsFixed(1)}x your typical amount).',
          ));
          suggestedAction ??= 'This one\'s well above your usual $category spend — worth a quick gut check.';
        } else if (ratio >= typicalMultiplierHigh) {
          points += 2;
          signals.add(PainOfPayingSignal(
            label: 'Size',
            detail: 'This is significantly larger than your usual $category purchases.',
          ));
        } else if (ratio >= typicalMultiplierModerate) {
          points += 1;
          signals.add(PainOfPayingSignal(
            label: 'Size',
            detail: 'This is a bit larger than your usual $category purchases.',
          ));
        }
      }
    }

    // ---- Goal impact — reuse PurchaseImpactCalculator's aggregate figure, ----
    // ---- add the single-nearest-goal neutral phrasing only when genuinely close. ----
    if (impact.savingsGoalPercentage != null) {
      signals.add(
        PainOfPayingSignal(
          label: 'Savings goals',
          detail: '${impact.savingsGoalPercentage!.toStringAsFixed(0)}% of what\'s remaining across your savings goals.',
        ),
      );
    }
    final nearestGoal = selectRelevantGoal(goals);
    if (nearestGoal != null && !nearestGoal.isCompleted) {
      final remaining = nearestGoal.remainingAmount;
      if (remaining > 0 && amount >= remaining * goalProximityRatio) {
        signals.add(
          PainOfPayingSignal(
            label: 'Goal awareness',
            detail: '₹${amount.toStringAsFixed(0)} is close to the ₹${remaining.toStringAsFixed(0)} '
                'still remaining for your "${nearestGoal.title}" goal.',
          ),
        );
      }
    }

    // ---- Upcoming obligations — reuse an already-computed SafeToSpendResult. ----
    if (safeToSpend != null) {
      if (safeToSpend.shortfall > 0) {
        points += 3;
        signals.add(
          PainOfPayingSignal(
            label: 'Upcoming obligations',
            detail: 'Your upcoming bills and EMIs already exceed your available balance by '
                '₹${safeToSpend.shortfall.toStringAsFixed(0)}.',
          ),
        );
        suggestedAction ??= 'Your upcoming obligations already outweigh your balance — '
            'consider delaying non-essential spending.';
      } else if (amount > safeToSpend.safeToSpend) {
        points += 2;
        signals.add(
          PainOfPayingSignal(
            label: 'Upcoming obligations',
            detail: 'This is more than the ₹${safeToSpend.safeToSpend.toStringAsFixed(0)} '
                'PaySense estimates you can safely spend after upcoming commitments.',
          ),
        );
      }
    }

    final level = _levelFor(points);
    return PainOfPayingResult(
      amount: amount,
      level: level,
      headline: '₹${amount.toStringAsFixed(0)} spent on $category.',
      signals: signals,
      suggestedAction: level == PainOfPayingLevel.low ? null : suggestedAction,
    );
  }

  static PainOfPayingLevel _levelFor(int points) {
    if (points >= 5) return PainOfPayingLevel.veryHigh;
    if (points >= 3) return PainOfPayingLevel.high;
    if (points >= 1) return PainOfPayingLevel.moderate;
    return PainOfPayingLevel.low;
  }

  static double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
