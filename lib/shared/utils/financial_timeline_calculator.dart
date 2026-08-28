import 'package:flutter/foundation.dart';

import '../../core/routes/app_routes.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/budget.dart';
import '../models/subscription_summary.dart';
import '../models/transaction.dart';
import 'budget_calculator.dart';
import 'financial_health_trends_calculator.dart';
import 'financial_insight_engine.dart' show FinancialInsightEngine;
import 'financial_planning_calculator.dart';

/// FINANCIAL TIMELINE 2.0 — the Timeline's OWN period selector, decoupled
/// from [TrendPeriod] (which stays exactly as-is, owned by the Financial
/// Health Trends screen). [day]/[week] are genuinely new, short-window
/// views this engine didn't support before; [month]/[threeMonths]/
/// [sixMonths]/[twelveMonths] preserve the EXACT existing behavior —
/// they map straight onto the matching [TrendPeriod] for the underlying
/// month-over-month event generation, unchanged.
enum TimelinePeriod { day, week, month, threeMonths, sixMonths, twelveMonths }

extension TimelinePeriodX on TimelinePeriod {
  String get label {
    switch (this) {
      case TimelinePeriod.day:
        return 'Day';
      case TimelinePeriod.week:
        return 'Week';
      case TimelinePeriod.month:
        return '1M';
      case TimelinePeriod.threeMonths:
        return '3M';
      case TimelinePeriod.sixMonths:
        return '6M';
      case TimelinePeriod.twelveMonths:
        return '12M';
    }
  }

  /// The underlying [TrendPeriod] used to compute month-over-month
  /// events for this selection. day/week both use [TrendPeriod.oneMonth]
  /// — enough monthly context to still surface a real month-over-month
  /// comparison alongside the short-window events, without fabricating a
  /// day/week-level version of a comparison that only makes sense
  /// monthly.
  TrendPeriod get underlyingTrendPeriod {
    switch (this) {
      case TimelinePeriod.day:
      case TimelinePeriod.week:
      case TimelinePeriod.month:
        return TrendPeriod.oneMonth;
      case TimelinePeriod.threeMonths:
        return TrendPeriod.threeMonths;
      case TimelinePeriod.sixMonths:
        return TrendPeriod.sixMonths;
      case TimelinePeriod.twelveMonths:
        return TrendPeriod.twelveMonths;
    }
  }
}

/// FINANCIAL INTELLIGENCE TIMELINE 1.0 — a pure Dart, deterministic
/// chronological event log. Like [FinancialInsightEngine], this is
/// deliberately a thin ADAPTER, not a re-derivation of any existing
/// formula:
///
/// - Spending/savings-rate change events walk [FinancialHealthTrendResult]'s
///   already-computed `monthlySeries` (real, per-calendar-month income/
///   expense totals) and reuse [FinancialHealthTrendsThresholds]' EXACT
///   existing threshold constants — the only genuinely new logic is walking
///   consecutive month PAIRS across the whole window, since no existing
///   calculator does that (they only ever compare current vs. one prior
///   period).
/// - Budget events reuse [BudgetCalculator.statusForBudget] as-is, dated at
///   each [Budget.createdAt] (the real timestamp of that month's budget
///   record — the best available real signal; PaySense keeps no continuous
///   day-by-day spend ledger per budget).
/// - Debt/goal events reuse [Loan.updatedAt]/[Goal.updatedAt] — the real
///   timestamp of each record's last change — and [Loan.status]/
///   [Goal.isCompleted] exactly as already computed by those models. No
///   historical wallet/goal/debt balance is ever interpolated: only the
///   CURRENT stored value, attached to the REAL timestamp it was last
///   written at.
/// - Subscription/recurring events reuse [RecurringTransaction.createdAt]
///   and the already-computed [SubscriptionSummary] list (from
///   [SubscriptionCalculator.eligibleSubscriptions]), exactly like
///   [FinancialInsightEngine]'s "new subscription" detection.
/// - The emergency-fund milestone reuses [FinancialPlanningResult]'s
///   already-computed `emergencyFund.isFullyFunded`. PaySense keeps no
///   historical emergency-fund-balance series, so this is deliberately the
///   ONLY emergency-fund event this engine ever emits (a discrete "fully
///   funded" milestone, honestly dated "now" — never a fabricated
///   historical crossing date, and never a decline event, which would
///   require history that doesn't exist).
enum TimelineEventType {
  spendingIncrease,
  spendingDecrease,
  budgetWarning,
  budgetOverLimit,
  savingsImprovement,
  savingsDecline,
  emergencyFundChange,
  goalProgress,
  debtProgress,
  newSubscription,
  recurringCommitmentChange,
  positiveMilestone,
  largeTransaction,
}

enum TimelineEventTone { positive, neutral, warning }

@immutable
class FinancialTimelineEvent {
  const FinancialTimelineEvent({
    required this.id,
    required this.type,
    required this.tone,
    required this.date,
    required this.title,
    required this.explanation,
    this.amount,
    this.percentage,
    this.actionRoute,
    this.relatedEntityId,
    this.relatedEntityName,
  });

  /// Stable deduplication key: `type:relatedEntity:yyyy-MM-dd`.
  final String id;

  final TimelineEventType type;
  final TimelineEventTone tone;

  /// A REAL stored timestamp this event is anchored to — never fabricated
  /// or interpolated. See the class-level doc for exactly which field each
  /// event type is dated from.
  final DateTime date;

  final String title;
  final String explanation;

  final double? amount;
  final double? percentage;

  /// An [AppRoutes] constant — tapping opens the most relevant existing
  /// screen rather than a duplicate detail screen.
  final String? actionRoute;

  final String? relatedEntityId;
  final String? relatedEntityName;
}

@immutable
class FinancialTimelineResult {
  const FinancialTimelineResult({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.events,
    required this.hasSufficientData,
    required this.monthsOfDataAvailable,
    required this.periodIncome,
    required this.periodExpense,
  });

  final TimelinePeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Newest first — matches the existing Notification Center convention
  /// ("getAll returns newest first").
  final List<FinancialTimelineEvent> events;

  /// False only when there's no transaction history at all (mirrors
  /// [FinancialHealthTrendResult.hasSufficientData]) — the timeline never
  /// fabricates events to fill an empty account.
  final bool hasSufficientData;
  final int monthsOfDataAvailable;

  /// Real sums of income/expense transactions falling within
  /// [periodStart]..[periodEnd] — a direct transaction sum, never routed
  /// through [FinancialHealthTrendResult] (which is month-bucketed and
  /// wouldn't have a real day/week figure to offer).
  final double periodIncome;
  final double periodExpense;

  double get periodNetCashFlow => periodIncome - periodExpense;

  bool get isEmpty => events.isEmpty;
}

class FinancialTimelineCalculator {
  FinancialTimelineCalculator._();

  /// Reuses the EXACT SAME thresholds [FinancialHealthTrendsCalculator]
  /// already established for "a change worth mentioning" — this engine
  /// doesn't invent a different policy, it just applies the same one across
  /// every consecutive month pair in the window instead of a single
  /// current-vs-previous comparison.
  static const double spendingChangeMinimumAmount =
      FinancialHealthTrendsThresholds.categoryChangeMinimumAmount;
  static const double spendingChangeThresholdPercent =
      FinancialHealthTrendsThresholds.materialPercentChangeThreshold;
  static const double savingsChangeThresholdPoints =
      FinancialHealthTrendsThresholds.savingsRateChangeThresholdPoints;

  /// Reuses [FinancialInsightEngine]'s exact "material subscription" bar so
  /// the same recurring item is never called "a new subscription" in one
  /// feature and "a minor recurring commitment" in another.
  static const double newSubscriptionMinimumAmount =
      FinancialInsightEngine.newSubscriptionMinimumAmount;

  /// A transaction counts as "large" for the timeline when it's at least
  /// this multiple of the user's own recent median expense in the SAME
  /// category — real personal history, never an external "average
  /// household" figure.
  static const double largeTransactionMedianMultiplier = 3.0;
  static const int largeTransactionLookbackDays = 90;
  static const int largeTransactionMinSample = 3;

  static FinancialTimelineResult calculate({
    required FinancialHealthTrendResult trends,
    required FinancialPlanningResult planning,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<Transaction> transactions,
    required List<RecurringTransaction> recurringTransactions,
    required List<SubscriptionSummary> subscriptions,
    required TimelinePeriod period,
    required DateTime now,
  }) {
    final DateTime windowStart;
    switch (period) {
      case TimelinePeriod.day:
        windowStart = DateTime(now.year, now.month, now.day);
      case TimelinePeriod.week:
        windowStart = now.subtract(const Duration(days: 7));
      case TimelinePeriod.month:
      case TimelinePeriod.threeMonths:
      case TimelinePeriod.sixMonths:
      case TimelinePeriod.twelveMonths:
        // FinancialHealthTrendResult.periodStart/periodEnd are BOTH the
        // current comparison month's single anchor date — not a full
        // window range. The window is derived from the actual multi-month
        // span already reflected in `monthlySeries` (oldest -> newest)
        // instead — UNCHANGED from the original month-based behavior.
        windowStart = trends.monthlySeries.isNotEmpty ? trends.monthlySeries.first.month : now;
    }
    final windowEnd = now;

    final events = <FinancialTimelineEvent>[
      ..._spendingAndSavingsEvents(trends.monthlySeries),
      ..._budgetEvents(budgets, windowStart, windowEnd),
      ..._debtEvents(loans, windowStart, windowEnd),
      ..._goalEvents(goals, windowStart, windowEnd),
      ..._subscriptionAndRecurringEvents(recurringTransactions, subscriptions, windowStart, windowEnd),
      ..._emergencyFundMilestone(planning, now, windowStart, windowEnd),
      ..._largeTransactionEvents(transactions, windowStart, windowEnd),
    ];

    // A final window filter — a no-op for month+ periods (every event
    // above is already generated within [windowStart, windowEnd] by
    // construction) but essential for day/week, where `trends`-derived
    // events (spending/savings, dated by calendar month) must be excluded
    // from a window narrower than a month.
    final windowed = events.where(
      (e) => !e.date.isBefore(windowStart) && !e.date.isAfter(windowEnd),
    ).toList();

    final deduped = _dedupe(windowed)
      ..sort((a, b) => b.date.compareTo(a.date));

    final periodTransactions = transactions.where(
      (t) => !t.createdAt.isBefore(windowStart) && !t.createdAt.isAfter(windowEnd),
    );
    final periodIncome = periodTransactions
        .where((t) => t.transactionType.toLowerCase() == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final periodExpense = periodTransactions
        .where((t) => t.transactionType.toLowerCase() == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);

    return FinancialTimelineResult(
      period: period,
      periodStart: windowStart,
      periodEnd: windowEnd,
      events: deduped,
      hasSufficientData: trends.hasSufficientData,
      monthsOfDataAvailable: trends.monthsOfDataAvailable,
      periodIncome: periodIncome,
      periodExpense: periodExpense,
    );
  }

  // -------------------------------------------------------------------
  // Large transactions — flags an expense that's a real outlier against
  // the user's OWN recent same-category spending (median-based, needs a
  // minimum real sample; never a fabricated "average person" comparison).
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _largeTransactionEvents(
    List<Transaction> transactions,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final events = <FinancialTimelineEvent>[];
    final lookbackStart = windowEnd.subtract(const Duration(days: largeTransactionLookbackDays));

    final byCategory = <String, List<double>>{};
    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.isBefore(lookbackStart) || t.createdAt.isAfter(windowEnd)) continue;
      byCategory.putIfAbsent(t.categoryId, () => []).add(t.amount);
    }

    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.isBefore(windowStart) || t.createdAt.isAfter(windowEnd)) continue;

      final sameCategory = byCategory[t.categoryId] ?? const [];
      if (sameCategory.length < largeTransactionMinSample) continue;

      final median = _median(sameCategory);
      if (median <= 0 || t.amount < median * largeTransactionMedianMultiplier) continue;

      events.add(
        FinancialTimelineEvent(
          id: _id(TimelineEventType.largeTransaction, t.id, t.createdAt),
          type: TimelineEventType.largeTransaction,
          tone: TimelineEventTone.neutral,
          date: t.createdAt,
          title: 'Large ${t.categoryId} transaction',
          explanation: '"${t.title}" (₹${t.amount.toStringAsFixed(0)}) is notably larger than your usual '
              '${t.categoryId} spending.',
          amount: t.amount,
          actionRoute: AppRoutes.transactions,
          relatedEntityId: t.id,
          relatedEntityName: t.title,
        ),
      );
    }
    return events;
  }

  static double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  // -------------------------------------------------------------------
  // Spending/savings — walks FinancialHealthTrendResult.monthlySeries
  // (oldest -> newest), the only genuinely new arithmetic in this engine.
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _spendingAndSavingsEvents(List<MonthlyFinancials> series) {
    final events = <FinancialTimelineEvent>[];

    for (var i = 1; i < series.length; i++) {
      final prev = series[i - 1];
      final curr = series[i];
      if (!prev.hasActivity || !curr.hasActivity) continue;

      if (prev.expense > 0) {
        final delta = curr.expense - prev.expense;
        final pct = delta / prev.expense * 100;
        if (delta.abs() >= spendingChangeMinimumAmount && pct.abs() >= spendingChangeThresholdPercent) {
          final increased = delta > 0;
          events.add(
            FinancialTimelineEvent(
              id: _id(increased ? TimelineEventType.spendingIncrease : TimelineEventType.spendingDecrease, null, curr.month),
              type: increased ? TimelineEventType.spendingIncrease : TimelineEventType.spendingDecrease,
              tone: increased ? TimelineEventTone.warning : TimelineEventTone.positive,
              date: curr.month,
              title: increased ? 'Spending increased' : 'Spending decreased',
              explanation: 'Your total spending ${increased ? 'rose' : 'fell'} by '
                  '${pct.abs().toStringAsFixed(0)}% (₹${delta.abs().toStringAsFixed(0)}) compared to the previous month.',
              amount: delta.abs(),
              percentage: pct.abs(),
              actionRoute: AppRoutes.reports,
            ),
          );
        }
      }

      final prevRate = prev.savingsRate;
      final currRate = curr.savingsRate;
      if (prevRate != null && currRate != null) {
        final ratePointsDelta = currRate - prevRate;
        if (ratePointsDelta.abs() >= savingsChangeThresholdPoints) {
          final improved = ratePointsDelta > 0;
          events.add(
            FinancialTimelineEvent(
              id: _id(improved ? TimelineEventType.savingsImprovement : TimelineEventType.savingsDecline, null, curr.month),
              type: improved ? TimelineEventType.savingsImprovement : TimelineEventType.savingsDecline,
              tone: improved ? TimelineEventTone.positive : TimelineEventTone.warning,
              date: curr.month,
              title: improved ? 'Savings rate improved' : 'Savings rate declined',
              explanation: 'Your savings rate ${improved ? 'rose' : 'fell'} by '
                  '${ratePointsDelta.abs().toStringAsFixed(1)} points month-over-month.',
              percentage: ratePointsDelta.abs(),
              actionRoute: AppRoutes.reports,
            ),
          );
        }
      }
    }
    return events;
  }

  // -------------------------------------------------------------------
  // Budgets — reuses BudgetCalculator.statusForBudget as-is, dated at each
  // Budget's own createdAt (a real stored timestamp for that month/category
  // record).
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _budgetEvents(List<Budget> budgets, DateTime windowStart, DateTime windowEnd) {
    final events = <FinancialTimelineEvent>[];
    for (final budget in budgets) {
      if (budget.createdAt.isBefore(windowStart) || budget.createdAt.isAfter(windowEnd)) continue;

      final status = BudgetCalculator.statusForBudget(budget);
      if (status == BudgetStatus.underBudget) continue;

      final isOver = status == BudgetStatus.overBudget;
      events.add(
        FinancialTimelineEvent(
          id: _id(isOver ? TimelineEventType.budgetOverLimit : TimelineEventType.budgetWarning, budget.id, budget.createdAt),
          type: isOver ? TimelineEventType.budgetOverLimit : TimelineEventType.budgetWarning,
          tone: TimelineEventTone.warning,
          date: budget.createdAt,
          title: isOver ? 'Over budget in ${budget.categoryName}' : '${budget.categoryName} budget nearing its limit',
          explanation: isOver
              ? 'You spent ₹${budget.spentAmount.toStringAsFixed(0)} against a ₹${budget.allocatedAmount.toStringAsFixed(0)} '
                  'budget for ${budget.categoryName} in ${budget.month} ${budget.year}.'
              : 'You used ${budget.percentageUsed.toStringAsFixed(0)}% of your ${budget.categoryName} budget in '
                  '${budget.month} ${budget.year}.',
          amount: budget.spentAmount,
          percentage: budget.percentageUsed,
          actionRoute: AppRoutes.budget,
          relatedEntityId: budget.id,
          relatedEntityName: budget.categoryName,
        ),
      );
    }
    return events;
  }

  // -------------------------------------------------------------------
  // Debt — Loan.updatedAt is the only real "something changed" timestamp
  // available; paidAmount/status are cumulative CURRENT values, never a
  // fabricated per-period delta.
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _debtEvents(List<Loan> loans, DateTime windowStart, DateTime windowEnd) {
    final events = <FinancialTimelineEvent>[];
    for (final loan in loans) {
      if (loan.updatedAt.isAtSameMomentAs(loan.createdAt)) continue;
      if (loan.updatedAt.isBefore(windowStart) || loan.updatedAt.isAfter(windowEnd)) continue;

      if (loan.status == 'Closed') {
        events.add(
          FinancialTimelineEvent(
            id: _id(TimelineEventType.positiveMilestone, loan.id, loan.updatedAt),
            type: TimelineEventType.positiveMilestone,
            tone: TimelineEventTone.positive,
            date: loan.updatedAt,
            title: 'Loan fully paid off',
            explanation: '"${loan.loanName}" has been fully paid off.',
            amount: loan.principalAmount,
            actionRoute: AppRoutes.loans,
            relatedEntityId: loan.id,
            relatedEntityName: loan.loanName,
          ),
        );
      } else if (loan.paidAmount > 0) {
        events.add(
          FinancialTimelineEvent(
            id: _id(TimelineEventType.debtProgress, loan.id, loan.updatedAt),
            type: TimelineEventType.debtProgress,
            tone: TimelineEventTone.positive,
            date: loan.updatedAt,
            title: 'Debt paydown on ${loan.loanName}',
            explanation: 'You\'ve paid down ₹${loan.paidAmount.toStringAsFixed(0)} of "${loan.loanName}" so far.',
            amount: loan.paidAmount,
            actionRoute: AppRoutes.loans,
            relatedEntityId: loan.id,
            relatedEntityName: loan.loanName,
          ),
        );
      }
    }
    return events;
  }

  // -------------------------------------------------------------------
  // Goals — Goal.updatedAt is the only real "something changed" timestamp
  // available; currentAmount/isCompleted are CURRENT values as already
  // computed by Goal itself.
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _goalEvents(List<Goal> goals, DateTime windowStart, DateTime windowEnd) {
    final events = <FinancialTimelineEvent>[];
    for (final goal in goals) {
      if (goal.updatedAt.isAtSameMomentAs(goal.createdAt)) continue;
      if (goal.updatedAt.isBefore(windowStart) || goal.updatedAt.isAfter(windowEnd)) continue;

      if (goal.isCompleted) {
        events.add(
          FinancialTimelineEvent(
            id: _id(TimelineEventType.positiveMilestone, goal.id, goal.updatedAt),
            type: TimelineEventType.positiveMilestone,
            tone: TimelineEventTone.positive,
            date: goal.updatedAt,
            title: 'Goal completed: ${goal.title}',
            explanation: 'You reached your target of ₹${goal.targetAmount.toStringAsFixed(0)} for "${goal.title}".',
            amount: goal.targetAmount,
            actionRoute: AppRoutes.goals,
            relatedEntityId: goal.id,
            relatedEntityName: goal.title,
          ),
        );
      } else {
        events.add(
          FinancialTimelineEvent(
            id: _id(TimelineEventType.goalProgress, goal.id, goal.updatedAt),
            type: TimelineEventType.goalProgress,
            tone: TimelineEventTone.neutral,
            date: goal.updatedAt,
            title: 'Progress on ${goal.title}',
            explanation: '"${goal.title}" is now ${goal.progressPercentage.toStringAsFixed(0)}% funded '
                '(₹${goal.currentAmount.toStringAsFixed(0)} of ₹${goal.targetAmount.toStringAsFixed(0)}).',
            amount: goal.currentAmount,
            percentage: goal.progressPercentage,
            actionRoute: AppRoutes.goals,
            relatedEntityId: goal.id,
            relatedEntityName: goal.title,
          ),
        );
      }
    }
    return events;
  }

  // -------------------------------------------------------------------
  // Subscriptions/recurring commitments — RecurringTransaction.createdAt,
  // exactly like FinancialInsightEngine's "new subscription" detection.
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _subscriptionAndRecurringEvents(
    List<RecurringTransaction> recurringTransactions,
    List<SubscriptionSummary> subscriptions,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final bySourceId = {for (final s in subscriptions) s.sourceId: s};
    final events = <FinancialTimelineEvent>[];

    for (final item in recurringTransactions) {
      if (item.createdAt.isBefore(windowStart) || item.createdAt.isAfter(windowEnd)) continue;

      final subscription = bySourceId[item.id];
      if (subscription != null && subscription.monthlyEquivalent >= newSubscriptionMinimumAmount) {
        events.add(
          FinancialTimelineEvent(
            id: _id(TimelineEventType.newSubscription, item.id, item.createdAt),
            type: TimelineEventType.newSubscription,
            tone: TimelineEventTone.neutral,
            date: item.createdAt,
            title: 'New subscription added',
            explanation: '"${subscription.name}" was added, adding ₹${subscription.monthlyEquivalent.toStringAsFixed(0)}/month '
                'to your subscriptions.',
            amount: subscription.monthlyEquivalent,
            actionRoute: AppRoutes.subscriptions,
            relatedEntityId: item.id,
            relatedEntityName: subscription.name,
          ),
        );
      } else {
        final isIncome = item.transactionType.toLowerCase() == 'income';
        events.add(
          FinancialTimelineEvent(
            id: _id(TimelineEventType.recurringCommitmentChange, item.id, item.createdAt),
            type: TimelineEventType.recurringCommitmentChange,
            tone: TimelineEventTone.neutral,
            date: item.createdAt,
            title: isIncome ? 'New recurring income added' : 'New recurring commitment added',
            explanation: '"${item.title}" (₹${item.amount.toStringAsFixed(0)} ${item.frequency.toLowerCase()}) was added to '
                'your recurring items.',
            amount: item.amount,
            actionRoute: AppRoutes.recurring,
            relatedEntityId: item.id,
            relatedEntityName: item.title,
          ),
        );
      }
    }
    return events;
  }

  // -------------------------------------------------------------------
  // Emergency fund — the ONLY event this engine ever emits for emergency
  // funds (see class doc): a discrete "fully funded" milestone, honestly
  // dated "now" since no historical balance series exists to date it more
  // precisely.
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _emergencyFundMilestone(
    FinancialPlanningResult planning,
    DateTime now,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    if (!planning.emergencyFund.isSourceConfigured || !planning.emergencyFund.isFullyFunded) {
      return const [];
    }
    if (now.isBefore(windowStart) || now.isAfter(windowEnd)) {
      return const [];
    }
    return [
      FinancialTimelineEvent(
        id: _id(TimelineEventType.emergencyFundChange, 'fullyFunded', now),
        type: TimelineEventType.emergencyFundChange,
        tone: TimelineEventTone.positive,
        date: now,
        title: 'Emergency fund fully funded',
        explanation: 'Your emergency fund currently covers your ${planning.emergencyFund.targetMonths}-month target '
            '(reflects current status, not a specific date it was reached).',
        amount: planning.emergencyFund.target,
        actionRoute: AppRoutes.financialPlanning,
      ),
    ];
  }

  // -------------------------------------------------------------------
  // Dedup — same "first occurrence wins" strategy as FinancialInsightEngine.
  // -------------------------------------------------------------------

  static List<FinancialTimelineEvent> _dedupe(List<FinancialTimelineEvent> events) {
    final seen = <String>{};
    final result = <FinancialTimelineEvent>[];
    for (final event in events) {
      if (seen.add(event.id)) result.add(event);
    }
    return result;
  }

  static String _id(TimelineEventType type, String? entity, DateTime date) {
    final day = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${type.name}:${entity ?? 'general'}:$day';
  }
}
