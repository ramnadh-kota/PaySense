import 'package:flutter/foundation.dart';

import '../../core/routes/app_routes.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../providers/daily_check_in_provider.dart';
import 'financial_action_engine.dart';
import 'financial_health_trends_calculator.dart';
import 'safe_to_spend_calculator.dart';
import 'subscription_calculator.dart';

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
  spendingTrend,
  categoryPressure,
  frequencyAlert,
  subscriptionAwareness,
  goalImpact,
  emiPressure,
  safeToSpendSignal,
  behaviorImprovement,
  checkInCorrelation,
  insufficientData,
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

  final String id;
  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String explanation;
  final String recommendedAction;

  final double? amount;
  final double? percentage;
  final String? actionRoute;
  final String? relatedEntityId;
  final String? relatedEntityName;
}

@immutable
class FinancialInsightResult {
  const FinancialInsightResult({required this.insights});

  final List<FinancialInsight> insights;

  bool get isEmpty => insights.isEmpty;
}

class FinancialInsightEngine {
  FinancialInsightEngine._();

  static const int maxInsights = 3;
  static const int newSubscriptionWindowDays = 30;
  static const double newSubscriptionMinimumAmount =
      FinancialActionEngine.subscriptionMaterialityThreshold;
  static const double upcomingCommitmentPressureFraction = 0.7;

  static FinancialInsightResult generate({
    required FinancialActionPlan actionPlan,
    required FinancialHealthTrendResult trends,
    required SafeToSpendResult safeToSpend,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
    List<Transaction> transactions = const [],
    List<Goal> goals = const [],
    List<Loan> loans = const [],
    DailyCheckInState? dailyCheckInState,
    List<String> dismissedInsightIds = const [],
  }) {
    final period = _periodLabel(now);
    final candidates = <FinancialInsight>[
      ..._fromActionPlan(actionPlan, period),
      ..._fromSpendingSignals(trends.spendingBehaviorSignals, period),
      ..._upcomingCommitmentPressure(safeToSpend, period),
      ..._subscriptionIncrease(recurringTransactions, now, period),
      ..._spendingTrend(transactions, now, period),
      ..._categoryPressure(transactions, now, period),
      ..._frequencyAlert(transactions, now, period),
      ..._subscriptionAwareness(recurringTransactions, period),
      ..._goalImpact(goals, period),
      ..._emiPressure(loans, transactions, now, period),
      ..._safeToSpendSignal(safeToSpend, period),
      ..._behaviorImprovement(dailyCheckInState, period),
      ..._checkInCorrelation(dailyCheckInState, transactions, now, period),
      ..._insufficientData(transactions, period),
    ];

    final seen = <String>{};
    final deduped = <FinancialInsight>[];
    for (final insight in candidates) {
      if (dismissedInsightIds.contains(insight.id)) continue;
      if (seen.add(insight.id)) deduped.add(insight);
    }

    deduped.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return FinancialInsightResult(insights: deduped.take(maxInsights).toList());
  }

  static List<FinancialInsight> _fromActionPlan(FinancialActionPlan plan, String period) {
    final insights = <FinancialInsight>[];
    for (final action in plan.actions) {
      final type = _insightTypeForActionType(action.actionType);
      if (type == null) continue;
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
        return null;
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

  static List<FinancialInsight> _fromSpendingSignals(
    List<FinancialTrendSignal> signals,
    String period,
  ) {
    final insights = <FinancialInsight>[];
    for (final signal in signals) {
      final type = _insightTypeForSignalType(signal.type);
      if (type == null) continue;

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
        return null;
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
  // PHASE 4 DETECTIONS
  // -------------------------------------------------------------------

  static List<FinancialInsight> _spendingTrend(
    List<Transaction> transactions,
    DateTime now,
    String period,
  ) {
    if (transactions.isEmpty) return const [];
    final currentMonth = now.month;
    final currentYear = now.year;
    final prevDate = DateTime(now.year, now.month - 1, 1);
    final prevMonth = prevDate.month;
    final prevYear = prevDate.year;

    double currentTotal = 0;
    double prevTotal = 0;

    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.month == currentMonth && t.createdAt.year == currentYear) {
        currentTotal += t.amount;
      } else if (t.createdAt.month == prevMonth && t.createdAt.year == prevYear) {
        prevTotal += t.amount;
      }
    }

    if (prevTotal > 0 && currentTotal > 0) {
      final pct = ((currentTotal - prevTotal) / prevTotal) * 100;
      if (pct.abs() >= 10) {
        final isIncrease = pct > 0;
        final title = isIncrease
            ? 'Monthly spending is up ${pct.abs().toStringAsFixed(0)}%'
            : 'Monthly spending is down ${pct.abs().toStringAsFixed(0)}%';
        final explanation = isIncrease
            ? 'You spent ${pct.abs().toStringAsFixed(0)}% more this month (₹${currentTotal.toStringAsFixed(0)}) than last month (₹${prevTotal.toStringAsFixed(0)}).'
            : 'Nice work! You spent ${pct.abs().toStringAsFixed(0)}% less this month (₹${currentTotal.toStringAsFixed(0)}) compared to last month (₹${prevTotal.toStringAsFixed(0)}).';

        return [
          FinancialInsight(
            id: _id(InsightType.spendingTrend, 'overall', period),
            type: InsightType.spendingTrend,
            priority: isIncrease ? InsightPriority.high : InsightPriority.positive,
            title: title,
            explanation: explanation,
            recommendedAction: 'See spending details',
            amount: currentTotal,
            percentage: pct,
            actionRoute: AppRoutes.transactions,
          ),
        ];
      }
    }

    return const [];
  }

  static List<FinancialInsight> _categoryPressure(
    List<Transaction> transactions,
    DateTime now,
    String period,
  ) {
    if (transactions.isEmpty) return const [];
    final currentMonth = now.month;
    final currentYear = now.year;

    final catSums = <String, double>{};
    double totalSpend = 0;

    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.month == currentMonth && t.createdAt.year == currentYear) {
        final cat = t.categoryId.isNotEmpty ? t.categoryId : 'General';
        catSums[cat] = (catSums[cat] ?? 0) + t.amount;
        totalSpend += t.amount;
      }
    }

    if (totalSpend <= 0 || catSums.isEmpty) return const [];

    String? topCat;
    double topAmt = 0;
    catSums.forEach((cat, amt) {
      if (amt > topAmt) {
        topAmt = amt;
        topCat = cat;
      }
    });

    if (topCat != null && totalSpend > 0) {
      final pct = (topAmt / totalSpend) * 100;
      if (pct >= 35) {
        return [
          FinancialInsight(
            id: _id(InsightType.categoryPressure, topCat, period),
            type: InsightType.categoryPressure,
            priority: InsightPriority.medium,
            title: '$topCat is your biggest expense',
            explanation: '$topCat currently accounts for ${pct.toStringAsFixed(0)}% (₹${topAmt.toStringAsFixed(0)}) of your discretionary spending this month.',
            recommendedAction: 'Review $topCat spending',
            amount: topAmt,
            percentage: pct,
            actionRoute: AppRoutes.analytics,
            relatedEntityName: topCat,
          ),
        ];
      }
    }

    return const [];
  }

  static List<FinancialInsight> _frequencyAlert(
    List<Transaction> transactions,
    DateTime now,
    String period,
  ) {
    if (transactions.isEmpty) return const [];
    final currentMonth = now.month;
    final currentYear = now.year;

    final counts = <String, int>{};
    final amounts = <String, double>{};

    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.month == currentMonth && t.createdAt.year == currentYear) {
        final cat = t.categoryId.isNotEmpty ? t.categoryId : 'General';
        counts[cat] = (counts[cat] ?? 0) + 1;
        amounts[cat] = (amounts[cat] ?? 0) + t.amount;
      }
    }

    for (final entry in counts.entries) {
      if (entry.value >= 5) {
        final totalAmt = amounts[entry.key] ?? 0;
        return [
          FinancialInsight(
            id: _id(InsightType.frequencyAlert, entry.key, period),
            type: InsightType.frequencyAlert,
            priority: InsightPriority.medium,
            title: 'Frequent small purchases in ${entry.key}',
            explanation: 'You made ${entry.value} ${entry.key} purchases this month totaling ₹${totalAmt.toStringAsFixed(0)}. Small frequent spending can add up over time.',
            recommendedAction: 'Track small expenses',
            amount: totalAmt,
            actionRoute: AppRoutes.transactions,
            relatedEntityName: entry.key,
          ),
        ];
      }
    }

    return const [];
  }

  static List<FinancialInsight> _subscriptionAwareness(
    List<RecurringTransaction> recurringTransactions,
    String period,
  ) {
    final active = recurringTransactions.where((r) => r.transactionType.toLowerCase() == 'expense').toList();
    if (active.isEmpty) return const [];

    double totalMonthly = 0;
    for (final r in active) {
      final freq = r.frequency.toLowerCase();
      if (freq == 'monthly') {
        totalMonthly += r.amount;
      } else if (freq == 'yearly' || freq == 'annually') {
        totalMonthly += r.amount / 12;
      } else if (freq == 'weekly') {
        totalMonthly += r.amount * 4.33;
      } else {
        totalMonthly += r.amount;
      }
    }

    if (totalMonthly <= 0) return const [];

    return [
      FinancialInsight(
        id: _id(InsightType.subscriptionAwareness, 'summary', period),
        type: InsightType.subscriptionAwareness,
        priority: InsightPriority.low,
        title: 'Active Subscriptions Summary',
        explanation: 'You have ₹${totalMonthly.toStringAsFixed(0)}/month committed across ${active.length} active recurring subscriptions.',
        recommendedAction: 'Manage subscriptions',
        amount: totalMonthly,
        actionRoute: AppRoutes.subscriptions,
      ),
    ];
  }

  static List<FinancialInsight> _goalImpact(
    List<Goal> goals,
    String period,
  ) {
    final activeGoals = goals.where((g) => g.currentAmount < g.targetAmount).toList();
    if (activeGoals.isEmpty) return const [];

    final atRisk = activeGoals.where((g) {
      final remaining = g.targetAmount - g.currentAmount;
      return remaining > 0 && g.targetDate.isBefore(DateTime.now().add(const Duration(days: 30)));
    }).toList();

    if (atRisk.isNotEmpty) {
      final goal = atRisk.first;
      return [
        FinancialInsight(
          id: _id(InsightType.goalImpact, goal.id, period),
          type: InsightType.goalImpact,
          priority: InsightPriority.high,
          title: 'Goal Timeline Alert: ${goal.title}',
          explanation: 'Your "${goal.title}" target date is approaching soon with ₹${(goal.targetAmount - goal.currentAmount).toStringAsFixed(0)} remaining to save.',
          recommendedAction: 'Adjust goal savings',
          amount: goal.targetAmount - goal.currentAmount,
          actionRoute: AppRoutes.financialPlanning,
          relatedEntityId: goal.id,
          relatedEntityName: goal.title,
        ),
      ];
    }

    return const [];
  }

  static List<FinancialInsight> _emiPressure(
    List<Loan> loans,
    List<Transaction> transactions,
    DateTime now,
    String period,
  ) {
    if (loans.isEmpty) return const [];
    final activeLoans = loans.where((l) => l.outstandingAmount > 0).toList();
    if (activeLoans.isEmpty) return const [];

    double totalEmi = 0;
    for (final l in activeLoans) {
      totalEmi += l.emiAmount;
    }

    if (totalEmi <= 0) return const [];

    final currentMonth = now.month;
    final currentYear = now.year;
    double incomeTotal = 0;

    for (final t in transactions) {
      if (t.transactionType.toLowerCase() == 'income' && t.createdAt.month == currentMonth && t.createdAt.year == currentYear) {
        incomeTotal += t.amount;
      }
    }

    if (incomeTotal > 0) {
      final emiRatio = (totalEmi / incomeTotal) * 100;
      if (emiRatio >= 20) {
        return [
          FinancialInsight(
            id: _id(InsightType.emiPressure, 'ratio', period),
            type: InsightType.emiPressure,
            priority: emiRatio >= 40 ? InsightPriority.critical : InsightPriority.high,
            title: 'EMI Debt Pressure',
            explanation: 'Your monthly EMIs (₹${totalEmi.toStringAsFixed(0)}) currently consume ${emiRatio.toStringAsFixed(0)}% of your monthly income.',
            recommendedAction: 'Review loan commitments',
            percentage: emiRatio,
            amount: totalEmi,
            actionRoute: AppRoutes.loans,
          ),
        ];
      }
    }

    return const [];
  }

  static List<FinancialInsight> _safeToSpendSignal(
    SafeToSpendResult safeToSpend,
    String period,
  ) {
    if (!safeToSpend.hasSufficientData) return const [];

    final isCaution = safeToSpend.availableMoney > 0 &&
        (safeToSpend.upcomingCommitments / safeToSpend.availableMoney >= 0.7);

    if (isCaution && !safeToSpend.isShortfall) {
      return [
        FinancialInsight(
          id: _id(InsightType.safeToSpendSignal, 'caution', period),
          type: InsightType.safeToSpendSignal,
          priority: InsightPriority.medium,
          title: 'Safe-to-Spend: Watchful',
          explanation: 'You have used over 70% of your safe-to-spend allowance for this cycle.',
          recommendedAction: 'Check daily limit',
          amount: safeToSpend.safeToSpend,
          actionRoute: AppRoutes.dashboard,
        ),
      ];
    }

    return const [];
  }

  static List<FinancialInsight> _behaviorImprovement(
    DailyCheckInState? dailyCheckInState,
    String period,
  ) {
    if (dailyCheckInState != null && dailyCheckInState.streakDays >= 3) {
      return [
        FinancialInsight(
          id: _id(InsightType.behaviorImprovement, 'streak', period),
          type: InsightType.behaviorImprovement,
          priority: InsightPriority.positive,
          title: 'Awareness Streak: ${dailyCheckInState.streakDays} Days',
          explanation: 'Nice progress! You\'ve maintained your daily money awareness streak for ${dailyCheckInState.streakDays} days.',
          recommendedAction: 'Keep it up',
          actionRoute: AppRoutes.dashboard,
        ),
      ];
    }
    return const [];
  }

  static List<FinancialInsight> _checkInCorrelation(
    DailyCheckInState? dailyCheckInState,
    List<Transaction> transactions,
    DateTime now,
    String period,
  ) {
    if (dailyCheckInState == null || !dailyCheckInState.isCheckedInToday) return const [];

    if (dailyCheckInState.mood == 'concerned') {
      return [
        FinancialInsight(
          id: _id(InsightType.checkInCorrelation, 'concerned', period),
          type: InsightType.checkInCorrelation,
          priority: InsightPriority.high,
          title: 'Money Check-In & Spend Correlation',
          explanation: 'Your recent check-in indicates you\'re feeling concerned about money. Want to review your recent expenses together?',
          recommendedAction: 'Review spending',
          actionRoute: AppRoutes.transactions,
        ),
      ];
    } else if (dailyCheckInState.mood == 'comfortable') {
      return [
        FinancialInsight(
          id: _id(InsightType.checkInCorrelation, 'comfortable', period),
          type: InsightType.checkInCorrelation,
          priority: InsightPriority.positive,
          title: 'Money Sentiment: Comfortable',
          explanation: 'You\'re feeling comfortable about your money today and your spending remains in a safe range.',
          recommendedAction: 'View summary',
          actionRoute: AppRoutes.dashboard,
        ),
      ];
    }

    return const [];
  }

  static List<FinancialInsight> _insufficientData(
    List<Transaction> transactions,
    String period,
  ) {
    if (transactions.isNotEmpty && transactions.length < 3) {
      return [
        FinancialInsight(
          id: _id(InsightType.insufficientData, 'guidance', period),
          type: InsightType.insufficientData,
          priority: InsightPriority.low,
          title: 'Personal Money Intelligence',
          explanation: 'Keep tracking for a little longer. PaySense will compare your spending once enough history is available.',
          recommendedAction: 'Add transaction',
          actionRoute: AppRoutes.transactions,
        ),
      ];
    }
    return const [];
  }

  static String _id(InsightType type, String? entity, String period) {
    return '${type.name}:${entity ?? 'general'}:$period';
  }

  static String _periodLabel(DateTime now) => '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
