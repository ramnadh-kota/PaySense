import '../models/financial_report.dart';
import 'financial_health_calculator.dart';
import 'financial_planning_calculator.dart';
import 'safe_to_spend_calculator.dart';

/// PERSONAL CFO INSIGHTS. Deliberately NOT a second calculation engine —
/// every method here only reads and rephrases figures a
/// `FinancialReport` (see [FinancialReportEngine]) already computed, or
/// (for [canSafelySpend]) an already-computed [SafeToSpendResult]. No
/// method in this class sums a transaction list or derives a percentage
/// itself.
///
/// Every answer is either a FACT (a real number restated in plain
/// language) or an explicitly-labeled SUGGESTION — never phrased as
/// financial advice ("you should invest...") and never shame-based.
class PersonalCfoInsights {
  PersonalCfoInsights._();

  /// "Can I safely spend this amount?" — reuses [SafeToSpendResult] as-is.
  /// Null when there isn't enough real data to answer (no wallets).
  static String? canSafelySpend(double amount, SafeToSpendResult? safeToSpend) {
    if (safeToSpend == null || !safeToSpend.hasSufficientData) return null;
    if (amount <= safeToSpend.safeToSpend) {
      return 'Based on your recorded balances and upcoming commitments, ₹${amount.toStringAsFixed(0)} '
          'is within your safe-to-spend amount of ₹${safeToSpend.safeToSpend.toStringAsFixed(0)}.';
    }
    return 'Based on your recorded balances and upcoming commitments, ₹${amount.toStringAsFixed(0)} is '
        '₹${(amount - safeToSpend.safeToSpend).toStringAsFixed(0)} above your current safe-to-spend amount '
        '(₹${safeToSpend.safeToSpend.toStringAsFixed(0)}).';
  }

  /// "Am I overspending?" — negative net cash flow or a real budget
  /// overspend, both already computed by [FinancialReportEngine].
  static String amIOverspending(FinancialReport report) {
    if (report.budgetOverspend != null && report.budgetOverspend!.hasOverspend) {
      return 'Based on your recorded spending, yes — you\'re ₹${report.budgetOverspend!.totalOverspend.toStringAsFixed(0)} '
          'over budget across ${report.budgetOverspend!.categoryCount} categor${report.budgetOverspend!.categoryCount == 1 ? 'y' : 'ies'} this period.';
    }
    if (report.netCashFlow < 0) {
      return 'Based on your recorded transactions, yes — spending exceeded income by '
          '₹${(-report.netCashFlow).toStringAsFixed(0)} this period.';
    }
    return 'Based on your recorded transactions, spending stayed within income this period.';
  }

  /// "Am I on track for my goal?" — reuses [GoalProjection.status] as-is.
  static String? amIOnTrackForGoal(GoalProjection projection) {
    switch (projection.status) {
      case GoalProjectionStatus.completed:
        return '"${projection.title}" is already fully funded.';
      case GoalProjectionStatus.onTrack:
        return 'Based on your recorded contributions, "${projection.title}" is on track for its target date.';
      case GoalProjectionStatus.atRisk:
        final gap = projection.contributionGap;
        return gap == null
            ? 'Based on your recorded contributions, "${projection.title}" is behind pace for its target date.'
            : 'Based on your recorded contributions, "${projection.title}" is behind pace — you\'d need about '
                '₹${gap.toStringAsFixed(0)} more per month to hit its target date.';
      case GoalProjectionStatus.insufficientData:
        return null;
    }
  }

  /// "What should I reduce?" / "Which category is hurting my financial
  /// progress?" — the same real signal answers both: the category
  /// furthest over its budget, falling back to the single largest
  /// spending category when no budget data exists.
  static String? whatShouldIReduce(FinancialReport report) {
    if (report.spendingByCategory.isEmpty) return null;
    final top = report.spendingByCategory.first;
    return 'Based on your recorded spending, ${top.categoryId} is your largest category this period at '
        '₹${top.amount.toStringAsFixed(0)} (${top.percentOfExpenses.toStringAsFixed(0)}% of your expenses).';
  }

  /// "What needs attention?" — merges the real signals already computed
  /// for the report (safety alerts, budget overspend, EMI pressure) into
  /// one prioritized list. Never invents a new detection rule.
  static List<String> whatNeedsAttention(FinancialReport report) {
    final items = <String>[];
    for (final alert in report.safetySignals) {
      items.add(alert.title);
    }
    if (report.budgetOverspend != null && report.budgetOverspend!.hasOverspend) {
      items.add('${report.budgetOverspend!.categoryCount} budget categor${report.budgetOverspend!.categoryCount == 1 ? 'y' : 'ies'} over allocation');
    }
    if (report.debt != null && report.debt!.hasDebt && report.debt!.emiToIncomePercent != null && report.debt!.emiToIncomePercent! >= 40) {
      items.add('EMI commitments at ${report.debt!.emiToIncomePercent!.toStringAsFixed(0)}% of income');
    }
    return items;
  }

  /// "How much can I save?" — reuses the already-computed safe-to-spend
  /// headroom rather than projecting a new savings figure.
  static String? howMuchCanISave(FinancialReport report) {
    final safeToSpend = report.safeToSpend;
    if (safeToSpend == null || !safeToSpend.hasSufficientData) return null;
    return 'After your recorded upcoming bills and EMIs, PaySense estimates you could set aside up to '
        '₹${safeToSpend.safeToSpend.toStringAsFixed(0)} right now without dipping into committed funds.';
  }

  /// "What upcoming commitments should I prepare for?" — the same
  /// bills/recurring lists the report already computed.
  static List<String> upcomingCommitments(FinancialReport report) {
    final items = <String>[];
    for (final bill in report.upcomingBills) {
      items.add('${bill.title} — ₹${bill.amount.toStringAsFixed(0)} due ${bill.dueDate.day}/${bill.dueDate.month}');
    }
    for (final payment in report.upcomingPayments) {
      items.add('${payment.title} — ₹${payment.amount.toStringAsFixed(0)} due ${payment.nextDueDate.day}/${payment.nextDueDate.month}');
    }
    return items;
  }

  /// "What is my strongest financial behaviour?" / "What is my biggest
  /// financial weakness?" — the highest/lowest scored dimension of the
  /// already-computed [FinancialHealthResult]. Null (never guessed) when
  /// no health result was computed (e.g. a weekly report).
  static String? strongestBehavior(FinancialReport report) {
    final components = report.healthResult?.components;
    if (components == null) return null;
    final entry = _highestComponent(components);
    return 'Your strongest area is ${entry.$1} (${entry.$2}/100).';
  }

  static String? biggestWeakness(FinancialReport report) {
    final components = report.healthResult?.components;
    if (components == null) return null;
    final entry = _lowestComponent(components);
    return 'Your biggest opportunity is ${entry.$1} (${entry.$2}/100).';
  }

  static (String, int) _highestComponent(FinancialHealthComponents c) {
    final entries = {'savings': c.savings, 'budget discipline': c.budget, 'goal progress': c.goals, 'debt management': c.debt, 'on-time payments': c.payments};
    final best = entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (best.key, best.value);
  }

  static (String, int) _lowestComponent(FinancialHealthComponents c) {
    final entries = {'savings': c.savings, 'budget discipline': c.budget, 'goal progress': c.goals, 'debt management': c.debt, 'on-time payments': c.payments};
    final worst = entries.entries.reduce((a, b) => a.value <= b.value ? a : b);
    return (worst.key, worst.value);
  }
}
