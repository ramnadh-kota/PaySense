/// FINANCIAL HEALTH TRENDS 3.0 — pure Dart, deterministic. No Flutter
/// widget/Riverpod/Hive/network/AI dependency.
///
/// REUSE, NOT RECREATION: every domain figure comes from an existing
/// calculator —
/// [FinancialHealthCalculator] (score + its exposed `savingsScore`/
/// `budgetScore`/weight constants), [FinancialPlanningCalculator]
/// (emergency fund, goal projections, debt overview), and the same
/// "sum income/expense per calendar month from transactions" arithmetic
/// [AnalyticsSummary]/`TaxIncomeEstimator` already use, just over a wider
/// (up to 12-month) window since [AnalyticsSummary] itself is capped at 6.
///
/// A DOCUMENTED, HONEST LIMITATION (see [ScorePoint.isApproximated] and
/// [DebtTrend]/[GoalTrend]/[EmergencyFundTrend]'s doc comments): PaySense
/// stores no historical snapshots of wallet balances, loan outstanding
/// amounts, or goal progress — only transactions carry a genuine
/// per-month timestamp. `MonthlyReviewCalculator` (an existing feature)
/// already establishes this exact precedent, passing through CURRENT
/// loan/Financial-Health state rather than pretending to recompute it
/// historically. This calculator follows the same principle: every
/// month-by-month figure is either (a) genuinely reconstructed from
/// transaction/Budget history, or (b) clearly labelled as reflecting only
/// the CURRENT state, never silently fabricated.
library;

import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/analytics_provider.dart' show buildAnalyticsSummary;
import 'budget_calculator.dart';
import 'financial_action_engine.dart' show FinancialActionEngine;
import 'financial_health_calculator.dart';
import 'financial_planning_calculator.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum TrendPeriod { oneMonth, threeMonths, sixMonths, twelveMonths }

extension TrendPeriodMonths on TrendPeriod {
  int get months {
    switch (this) {
      case TrendPeriod.oneMonth:
        return 1;
      case TrendPeriod.threeMonths:
        return 3;
      case TrendPeriod.sixMonths:
        return 6;
      case TrendPeriod.twelveMonths:
        return 12;
    }
  }

  String get label {
    switch (this) {
      case TrendPeriod.oneMonth:
        return '1M';
      case TrendPeriod.threeMonths:
        return '3M';
      case TrendPeriod.sixMonths:
        return '6M';
      case TrendPeriod.twelveMonths:
        return '12M';
    }
  }
}

enum TrendDirection { improving, declining, stable, insufficientData }

enum IncomePattern { stable, increasing, declining, irregular, insufficientData }

enum OverallTrajectory {
  stronglyImproving,
  improving,
  stable,
  mixed,
  declining,
  insufficientData,
}

enum SignalSeverity { info, notable, high }

enum SignalType {
  categoryIncrease,
  categoryDecrease,
  newRecurringSpend,
  unusuallyHighMonth,
  lifestyleInflation,
  healthImprovement,
  healthDecline,
  savingsImprovement,
  savingsDecline,
  debtReduction,
  debtIncrease,
  budgetImprovement,
  budgetDeterioration,
  emergencyFundProgress,
  goalRisk,
}

// ---------------------------------------------------------------------------
// PHASE 18 — the shared, notification-ready signal shape. Used for BOTH
// spending-behavior signals (PHASE 8) and key insights (PHASE 14) so a
// future proactive-notification engine can consume either without a
// second model.
// ---------------------------------------------------------------------------

@immutable
class FinancialTrendSignal {
  const FinancialTrendSignal({
    required this.id,
    required this.type,
    required this.severity,
    required this.period,
    required this.title,
    required this.explanation,
    this.supportingValues = const {},
    this.actionRoute,
    this.recommendation,
  });

  final String id;
  final SignalType type;
  final SignalSeverity severity;

  /// Human-readable period label this signal is about, e.g. "August 2026"
  /// or "Last 3 months".
  final String period;

  final String title;
  final String explanation;

  /// Plain numeric/text values backing [explanation] — e.g.
  /// {'amount': 2400.0, 'percentage': 34.0} — never a raw transaction row.
  final Map<String, dynamic> supportingValues;

  /// An [AppRoutes] constant string, for a future "tap to see more" —
  /// nullable since not every signal has an obvious destination.
  final String? actionRoute;

  final String? recommendation;
}

// ---------------------------------------------------------------------------
// Monthly series (PHASE 2)
// ---------------------------------------------------------------------------

@immutable
class MonthlyFinancials {
  const MonthlyFinancials({
    required this.month,
    required this.income,
    required this.expense,
    required this.hasActivity,
  });

  final DateTime month;
  final double income;
  final double expense;
  final bool hasActivity;

  double get net => income - expense;
  double? get savingsRate => income > 0 ? (net / income * 100) : null;
}

@immutable
class ScorePoint {
  const ScorePoint({required this.month, required this.score, required this.isApproximated});

  final DateTime month;
  final int score;

  /// True for every month except the most recent — PaySense has no
  /// historical wallet/goal/loan/bill snapshots, so a past month's score
  /// is reconstructed using only the two components that genuinely have
  /// per-month history (savings from transactions, budget from
  /// month-scoped Budget records), holding goals/debt/payments at a
  /// documented neutral baseline. The current month always uses the real,
  /// complete [FinancialHealthCalculator.calculate] result.
  final bool isApproximated;
}

// ---------------------------------------------------------------------------
// Domain trend models (PHASE 1)
// ---------------------------------------------------------------------------

@immutable
class ScoreTrend {
  const ScoreTrend({
    required this.currentScore,
    required this.previousScore,
    required this.change,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.direction,
    required this.history,
    required this.hasSufficientData,
  });

  final int? currentScore;
  final int? previousScore;
  final int? change;
  final int? averageScore;
  final int? highestScore;
  final int? lowestScore;
  final TrendDirection direction;
  final List<ScorePoint> history;
  final bool hasSufficientData;
}

@immutable
class SavingsTrend {
  const SavingsTrend({
    required this.averageSavingsRate,
    required this.currentSavingsRate,
    required this.previousSavingsRate,
    required this.direction,
    required this.bestMonth,
    required this.bestMonthRate,
    required this.weakestMonth,
    required this.weakestMonthRate,
    required this.hasSufficientData,
  });

  final double? averageSavingsRate;
  final double? currentSavingsRate;
  final double? previousSavingsRate;
  final TrendDirection direction;
  final DateTime? bestMonth;
  final double? bestMonthRate;
  final DateTime? weakestMonth;
  final double? weakestMonthRate;
  final bool hasSufficientData;
}

@immutable
class IncomeTrend {
  const IncomeTrend({
    required this.averageIncome,
    required this.currentIncome,
    required this.previousIncome,
    required this.highestMonth,
    required this.highestAmount,
    required this.lowestMonth,
    required this.lowestAmount,
    required this.pattern,
    required this.direction,
    required this.hasSufficientData,
  });

  final double? averageIncome;
  final double? currentIncome;
  final double? previousIncome;
  final DateTime? highestMonth;
  final double? highestAmount;
  final DateTime? lowestMonth;
  final double? lowestAmount;
  final IncomePattern pattern;
  final TrendDirection direction;
  final bool hasSufficientData;
}

@immutable
class ExpenseTrend {
  const ExpenseTrend({
    required this.averageExpense,
    required this.currentExpense,
    required this.previousExpense,
    required this.highestMonth,
    required this.highestAmount,
    required this.lowestMonth,
    required this.lowestAmount,
    required this.direction,
    required this.hasSufficientData,
  });

  final double? averageExpense;
  final double? currentExpense;
  final double? previousExpense;
  final DateTime? highestMonth;
  final double? highestAmount;
  final DateTime? lowestMonth;
  final double? lowestAmount;

  /// Deliberately NOT "expenses up = bad" — see [FinancialHealthTrendsCalculator._expenseDirection].
  /// An expense increase alongside a proportionally larger income increase
  /// is `stable`/`improving`, never flagged as `declining` on its own.
  final TrendDirection direction;
  final bool hasSufficientData;
}

@immutable
class CashFlowTrend {
  const CashFlowTrend({
    required this.currentNet,
    required this.previousNet,
    required this.averageNet,
    required this.direction,
    required this.hasSufficientData,
  });

  final double? currentNet;
  final double? previousNet;
  final double? averageNet;
  final TrendDirection direction;
  final bool hasSufficientData;
}

@immutable
class BudgetTrend {
  const BudgetTrend({
    required this.monthsWithinBudget,
    required this.monthsNearLimit,
    required this.monthsOverBudget,
    required this.currentOverBudgetCount,
    required this.previousOverBudgetCount,
    required this.direction,
    required this.hasSufficientData,
  });

  final int monthsWithinBudget;
  final int monthsNearLimit;
  final int monthsOverBudget;
  final int? currentOverBudgetCount;
  final int? previousOverBudgetCount;
  final TrendDirection direction;
  final bool hasSufficientData;
}

@immutable
class DebtTrend {
  const DebtTrend({
    required this.currentOutstanding,
    required this.totalPaidDown,
    required this.activeLoanCount,
    required this.debtToIncomePercent,
    required this.direction,
    required this.hasSufficientData,
  });

  final double currentOutstanding;

  /// `sum(principalAmount) - sum(outstandingAmount)` across every loan
  /// PaySense has a record of (active + closed) — a real, cumulative,
  /// non-fabricated figure. NOT a month-by-month time series: PaySense
  /// stores no historical outstanding-balance snapshots (same limitation
  /// `MonthlyReviewCalculator` already documents for loans).
  final double totalPaidDown;
  final int activeLoanCount;
  final double? debtToIncomePercent;

  /// `insufficientData` when there are no loan records at all — "no debt"
  /// is never itself reported as `improving` without evidence debt existed
  /// and was reduced (the exact mistake already found and fixed in
  /// FinancialActionEngine's positive-signal rule).
  final TrendDirection direction;
  final bool hasSufficientData;
}

@immutable
class EmergencyFundTrend {
  const EmergencyFundTrend({
    required this.target,
    required this.current,
    required this.progressPercent,
    required this.isConfigured,
    required this.direction,
  });

  final double? target;
  final double? current;
  final double? progressPercent;
  final bool isConfigured;

  /// Always `insufficientData` — PaySense has no historical wallet-balance
  /// snapshots, so a genuine emergency-fund trajectory cannot be
  /// reconstructed. Only the CURRENT state is real.
  final TrendDirection direction;
}

@immutable
class GoalTrend {
  const GoalTrend({
    required this.totalGoals,
    required this.goalsCompleted,
    required this.goalsOnTrack,
    required this.goalsAtRisk,
    required this.direction,
  });

  final int totalGoals;
  final int goalsCompleted;
  final int goalsOnTrack;
  final int goalsAtRisk;

  /// Always `insufficientData` for the same reason as
  /// [EmergencyFundTrend.direction] — no historical goal-progress
  /// snapshots exist. The on-track/at-risk/completed COUNTS are real and
  /// current; only the notion of a "trend over time" is unavailable.
  final TrendDirection direction;
}

// ---------------------------------------------------------------------------
// Central result (PHASE 1)
// ---------------------------------------------------------------------------

@immutable
class FinancialHealthTrendResult {
  const FinancialHealthTrendResult({
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.previousPeriodStart,
    required this.previousPeriodEnd,
    required this.scoreTrend,
    required this.savingsTrend,
    required this.incomeTrend,
    required this.expenseTrend,
    required this.cashFlowTrend,
    required this.budgetTrend,
    required this.debtTrend,
    required this.emergencyFundTrend,
    required this.goalTrend,
    required this.trajectory,
    required this.spendingBehaviorSignals,
    required this.keyInsights,
    required this.monthlySeries,
    required this.monthsOfDataAvailable,
    required this.hasSufficientData,
  });

  final TrendPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime previousPeriodStart;
  final DateTime previousPeriodEnd;

  final ScoreTrend scoreTrend;
  final SavingsTrend savingsTrend;
  final IncomeTrend incomeTrend;
  final ExpenseTrend expenseTrend;
  final CashFlowTrend cashFlowTrend;
  final BudgetTrend budgetTrend;
  final DebtTrend debtTrend;
  final EmergencyFundTrend emergencyFundTrend;
  final GoalTrend goalTrend;

  final OverallTrajectory trajectory;

  /// PHASE 8 — max not enforced here (callers may want all of them for the
  /// AI context); the UI takes the top few.
  final List<FinancialTrendSignal> spendingBehaviorSignals;

  /// PHASE 14 — always <= 5.
  final List<FinancialTrendSignal> keyInsights;

  /// The `period.months` months being analyzed (oldest first) — the same
  /// per-month income/expense figures every domain trend above was
  /// derived from, exposed for the UI's cash-flow/savings charts (PHASE
  /// 15) rather than making the screen re-derive them.
  final List<MonthlyFinancials> monthlySeries;

  final int monthsOfDataAvailable;

  /// False only when there are zero transactions at all — PHASE 19.
  final bool hasSufficientData;
}

// ---------------------------------------------------------------------------
// Thresholds (PHASE 3) — centralized, documented, never scattered in
// widgets.
// ---------------------------------------------------------------------------

class FinancialHealthTrendsThresholds {
  FinancialHealthTrendsThresholds._();

  /// Reuses the SAME magnitude FinancialActionEngine already established
  /// for "materially declined" savings rate — one app-wide definition of
  /// "a savings-rate change worth mentioning", applied symmetrically here
  /// (improving OR declining) rather than only to declines.
  static const double savingsRateChangeThresholdPoints =
      FinancialActionEngine.savingsRateDeclineThresholdPoints;

  /// A new, explicitly documented product threshold — no existing
  /// constant addresses "material income/expense change" specifically.
  static const double materialPercentChangeThreshold = 10.0;

  /// A month's income is "irregular" relative to the window's average
  /// income when the highest and lowest months differ by more than this
  /// fraction of the average — a simple, deterministic spread check
  /// (PHASE 6 explicitly forbids ML).
  static const double incomeIrregularitySpreadFraction = 0.5;

  /// Financial Health score points; smaller changes are noise.
  static const int materialScoreChangeThreshold = 5;

  /// Fraction of total principal that must be paid down before debt is
  /// reported as `improving` — avoids reporting a single small EMI
  /// payment as a meaningful reduction.
  static const double debtChangeMaterialityFraction = 0.02;

  /// A category's spending must change by at least this fraction AND this
  /// absolute amount to be surfaced as a spending-behavior signal —
  /// avoids flagging a ₹50 swing in a ₹100 category as "significant".
  static const double categoryChangeFraction = 0.30;
  static const double categoryChangeMinimumAmount = 1000.0;

  /// A month's total expense is "unusually high" when it exceeds the
  /// window's average by this fraction.
  static const double unusualMonthSpendFraction = 0.40;

  static const int maxKeyInsights = 5;
}

// ---------------------------------------------------------------------------
// Calculator (PHASE 2-14)
// ---------------------------------------------------------------------------

class FinancialHealthTrendsCalculator {
  FinancialHealthTrendsCalculator._();

  static FinancialHealthTrendResult calculate({
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<Bill> bills,
    required List<Wallet> wallets,
    required double profileMonthlyIncome,
    required TrendPeriod period,
    List<String>? emergencyFundEligibleWalletIds,
    int emergencyFundTargetMonths = defaultEmergencyFundTargetMonths,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final hasSufficientData = transactions.isNotEmpty;

    // `period.months` for the analyzed window, plus 1 extra month as the
    // "previous" comparison anchor — see the class-level doc comment for
    // why `previous` is defined as "the month at the start of the window"
    // rather than always the single prior calendar month.
    final totalMonths = period.months + 1;
    final series = _monthlySeries(transactions, referenceNow, totalMonths);
    final monthsOfDataAvailable = series.where((m) => m.hasActivity).length;

    final previousPoint = series.first;
    final window = series.sublist(1); // the `period.months` months being analyzed
    final currentPoint = window.last;

    // ---- Income / Expense / Savings / Cash flow ----
    final incomeTrend = _incomeTrend(previousPoint, currentPoint, window);
    final savingsTrend = _savingsTrend(previousPoint, currentPoint, window);
    final expenseTrend = _expenseTrend(previousPoint, currentPoint, window, savingsTrend.direction);
    final cashFlowTrend = _cashFlowTrend(previousPoint, currentPoint, window);

    // ---- Financial Planning (emergency fund, goals, debt) — reused ----
    final settings = _EfSettings(emergencyFundEligibleWalletIds, emergencyFundTargetMonths);
    final planning = FinancialPlanningCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      goals: goals,
      loans: loans,
      bills: bills,
      recurringTransactions: const [],
      analytics: buildAnalyticsSummary(transactions, referenceNow),
      emergencyFundEligibleWalletIds: settings.eligibleWalletIds,
      emergencyFundTargetMonths: settings.targetMonths,
      now: referenceNow,
    );

    final debtTrend = _debtTrend(loans, planning);
    final emergencyFundTrend = _emergencyFundTrend(planning);
    final goalTrend = _goalTrend(planning);

    // ---- Budget ----
    final budgetTrend = _budgetTrend(budgets, window, previousPoint, currentPoint);

    // ---- Financial Health score history ----
    final scoreTrend = _scoreTrend(
      series: series,
      window: window,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      loans: loans,
      bills: bills,
      wallets: wallets,
      profileMonthlyIncome: profileMonthlyIncome,
      referenceNow: referenceNow,
    );

    final trajectory = _computeTrajectory(
      score: scoreTrend.direction,
      savings: savingsTrend.direction,
      cashFlow: cashFlowTrend.direction,
      budget: budgetTrend.direction,
      debt: debtTrend.direction,
      goals: goalTrend.direction,
      emergencyFund: emergencyFundTrend.direction,
    );

    final spendingSignals = _spendingBehaviorSignals(
      transactions: transactions,
      previousPoint: previousPoint,
      currentPoint: currentPoint,
      window: window,
      incomeTrend: incomeTrend,
      savingsTrend: savingsTrend,
    );

    final keyInsights = _keyInsights(
      scoreTrend: scoreTrend,
      savingsTrend: savingsTrend,
      budgetTrend: budgetTrend,
      debtTrend: debtTrend,
      goalTrend: goalTrend,
      emergencyFundTrend: emergencyFundTrend,
      spendingSignals: spendingSignals,
    );

    return FinancialHealthTrendResult(
      period: period,
      periodStart: currentPoint.month,
      periodEnd: currentPoint.month,
      previousPeriodStart: previousPoint.month,
      previousPeriodEnd: previousPoint.month,
      scoreTrend: scoreTrend,
      savingsTrend: savingsTrend,
      incomeTrend: incomeTrend,
      expenseTrend: expenseTrend,
      cashFlowTrend: cashFlowTrend,
      budgetTrend: budgetTrend,
      debtTrend: debtTrend,
      emergencyFundTrend: emergencyFundTrend,
      goalTrend: goalTrend,
      trajectory: trajectory,
      spendingBehaviorSignals: spendingSignals,
      keyInsights: keyInsights,
      monthlySeries: window,
      monthsOfDataAvailable: monthsOfDataAvailable,
      hasSufficientData: hasSufficientData,
    );
  }

  // -------------------------------------------------------------------
  // Monthly series — same "sum by type per calendar month" arithmetic
  // AnalyticsSummary/TaxIncomeEstimator already use, just over a wider,
  // caller-specified window (AnalyticsSummary itself is capped at 6).
  // -------------------------------------------------------------------

  static List<MonthlyFinancials> _monthlySeries(
    List<Transaction> transactions,
    DateTime now,
    int totalMonths,
  ) {
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final start = DateTime(currentMonthStart.year, currentMonthStart.month - (totalMonths - 1), 1);

    final months = <DateTime>[
      for (var i = 0; i < totalMonths; i++) DateTime(start.year, start.month + i, 1),
    ];

    return months.map((month) {
      double income = 0;
      double expense = 0;
      var hasActivity = false;
      for (final t in transactions) {
        if (t.createdAt.year != month.year || t.createdAt.month != month.month) continue;
        final type = t.transactionType.toLowerCase();
        if (type == 'income') {
          income += t.amount;
          hasActivity = true;
        } else if (type == 'expense') {
          expense += t.amount;
          hasActivity = true;
        }
      }
      return MonthlyFinancials(month: month, income: income, expense: expense, hasActivity: hasActivity);
    }).toList();
  }

  // -------------------------------------------------------------------
  // Direction classifiers — PHASE 3, all thresholds centralized in
  // FinancialHealthTrendsThresholds.
  // -------------------------------------------------------------------

  static TrendDirection _percentDirection(
    double? previous,
    double? current, {
    required double threshold,
    bool higherIsBetter = true,
  }) {
    if (previous == null || current == null) return TrendDirection.insufficientData;
    if (previous == 0) {
      if (current == 0) return TrendDirection.stable;
      return higherIsBetter ? TrendDirection.improving : TrendDirection.declining;
    }
    final change = (current - previous) / previous.abs() * 100;
    if (change.abs() < threshold) return TrendDirection.stable;
    final isIncrease = change > 0;
    if (higherIsBetter) return isIncrease ? TrendDirection.improving : TrendDirection.declining;
    return isIncrease ? TrendDirection.declining : TrendDirection.improving;
  }

  static TrendDirection _pointsDirection(
    double? previous,
    double? current, {
    required double threshold,
  }) {
    if (previous == null || current == null) return TrendDirection.insufficientData;
    final change = current - previous;
    if (change.abs() < threshold) return TrendDirection.stable;
    return change > 0 ? TrendDirection.improving : TrendDirection.declining;
  }

  // -------------------------------------------------------------------
  // Income (PHASE 6)
  // -------------------------------------------------------------------

  static IncomeTrend _incomeTrend(
    MonthlyFinancials previousPoint,
    MonthlyFinancials currentPoint,
    List<MonthlyFinancials> window,
  ) {
    final activeMonths = window.where((m) => m.hasActivity).toList();
    if (activeMonths.isEmpty) {
      return const IncomeTrend(
        averageIncome: null, currentIncome: null, previousIncome: null,
        highestMonth: null, highestAmount: null, lowestMonth: null, lowestAmount: null,
        pattern: IncomePattern.insufficientData, direction: TrendDirection.insufficientData,
        hasSufficientData: false,
      );
    }

    final avg = activeMonths.fold<double>(0, (sum, m) => sum + m.income) / activeMonths.length;
    final highest = window.reduce((a, b) => a.income >= b.income ? a : b);
    final lowest = window.reduce((a, b) => a.income <= b.income ? a : b);

    return IncomeTrend(
      averageIncome: avg,
      currentIncome: currentPoint.income,
      previousIncome: previousPoint.income,
      highestMonth: highest.month,
      highestAmount: highest.income,
      lowestMonth: lowest.month,
      lowestAmount: lowest.income,
      pattern: _incomePattern(window),
      direction: _percentDirection(
        previousPoint.income,
        currentPoint.income,
        threshold: FinancialHealthTrendsThresholds.materialPercentChangeThreshold,
      ),
      hasSufficientData: true,
    );
  }

  static IncomePattern _incomePattern(List<MonthlyFinancials> window) {
    final incomes = window.map((m) => m.income).toList();
    if (incomes.every((v) => v <= 0)) return IncomePattern.insufficientData;

    final avg = incomes.fold<double>(0, (a, b) => a + b) / incomes.length;
    final hasZeroAmongActive = incomes.any((v) => v <= 0) && incomes.any((v) => v > 0);
    final maxV = incomes.reduce((a, b) => a > b ? a : b);
    final minV = incomes.reduce((a, b) => a < b ? a : b);
    final spread = avg > 0 ? (maxV - minV) / avg : 0.0;

    if (hasZeroAmongActive || spread > FinancialHealthTrendsThresholds.incomeIrregularitySpreadFraction) {
      return IncomePattern.irregular;
    }

    final first = incomes.first;
    final last = incomes.last;
    if (first <= 0) return IncomePattern.stable;
    final change = (last - first) / first.abs() * 100;
    if (change.abs() < FinancialHealthTrendsThresholds.materialPercentChangeThreshold) {
      return IncomePattern.stable;
    }
    return change > 0 ? IncomePattern.increasing : IncomePattern.declining;
  }

  // -------------------------------------------------------------------
  // Savings (PHASE 5)
  // -------------------------------------------------------------------

  static SavingsTrend _savingsTrend(
    MonthlyFinancials previousPoint,
    MonthlyFinancials currentPoint,
    List<MonthlyFinancials> window,
  ) {
    final ratedMonths = window.where((m) => m.income > 0).toList();
    if (ratedMonths.isEmpty) {
      return const SavingsTrend(
        averageSavingsRate: null, currentSavingsRate: null, previousSavingsRate: null,
        direction: TrendDirection.insufficientData, bestMonth: null, bestMonthRate: null,
        weakestMonth: null, weakestMonthRate: null, hasSufficientData: false,
      );
    }

    final avg =
        ratedMonths.fold<double>(0, (sum, m) => sum + m.savingsRate!) / ratedMonths.length;
    final best = ratedMonths.reduce((a, b) => a.savingsRate! >= b.savingsRate! ? a : b);
    final weakest = ratedMonths.reduce((a, b) => a.savingsRate! <= b.savingsRate! ? a : b);

    return SavingsTrend(
      averageSavingsRate: avg,
      currentSavingsRate: currentPoint.savingsRate,
      previousSavingsRate: previousPoint.savingsRate,
      direction: _pointsDirection(
        previousPoint.savingsRate,
        currentPoint.savingsRate,
        threshold: FinancialHealthTrendsThresholds.savingsRateChangeThresholdPoints,
      ),
      bestMonth: best.month,
      bestMonthRate: best.savingsRate,
      weakestMonth: weakest.month,
      weakestMonthRate: weakest.savingsRate,
      hasSufficientData: true,
    );
  }

  // -------------------------------------------------------------------
  // Expense (PHASE 7) — judged via its effect on the savings position,
  // never in isolation.
  // -------------------------------------------------------------------

  static ExpenseTrend _expenseTrend(
    MonthlyFinancials previousPoint,
    MonthlyFinancials currentPoint,
    List<MonthlyFinancials> window,
    TrendDirection savingsDirection,
  ) {
    final activeMonths = window.where((m) => m.hasActivity).toList();
    if (activeMonths.isEmpty) {
      return const ExpenseTrend(
        averageExpense: null, currentExpense: null, previousExpense: null,
        highestMonth: null, highestAmount: null, lowestMonth: null, lowestAmount: null,
        direction: TrendDirection.insufficientData, hasSufficientData: false,
      );
    }

    final avg = activeMonths.fold<double>(0, (sum, m) => sum + m.expense) / activeMonths.length;
    final highest = window.reduce((a, b) => a.expense >= b.expense ? a : b);
    final lowest = window.reduce((a, b) => a.expense <= b.expense ? a : b);

    final expenseChangePct = previousPoint.expense == 0
        ? (currentPoint.expense > 0 ? 100.0 : 0.0)
        : (currentPoint.expense - previousPoint.expense) / previousPoint.expense.abs() * 100;
    final direction = expenseChangePct.abs() < FinancialHealthTrendsThresholds.materialPercentChangeThreshold
        ? TrendDirection.stable
        : savingsDirection;

    return ExpenseTrend(
      averageExpense: avg,
      currentExpense: currentPoint.expense,
      previousExpense: previousPoint.expense,
      highestMonth: highest.month,
      highestAmount: highest.expense,
      lowestMonth: lowest.month,
      lowestAmount: lowest.expense,
      direction: direction,
      hasSufficientData: true,
    );
  }

  // -------------------------------------------------------------------
  // Cash flow
  // -------------------------------------------------------------------

  static CashFlowTrend _cashFlowTrend(
    MonthlyFinancials previousPoint,
    MonthlyFinancials currentPoint,
    List<MonthlyFinancials> window,
  ) {
    final activeMonths = window.where((m) => m.hasActivity).toList();
    if (activeMonths.isEmpty) {
      return const CashFlowTrend(
        currentNet: null, previousNet: null, averageNet: null,
        direction: TrendDirection.insufficientData, hasSufficientData: false,
      );
    }
    final avg = activeMonths.fold<double>(0, (sum, m) => sum + m.net) / activeMonths.length;

    return CashFlowTrend(
      currentNet: currentPoint.net,
      previousNet: previousPoint.net,
      averageNet: avg,
      direction: _percentDirection(
        previousPoint.net,
        currentPoint.net,
        threshold: FinancialHealthTrendsThresholds.materialPercentChangeThreshold,
      ),
      hasSufficientData: true,
    );
  }

  // -------------------------------------------------------------------
  // Budget (PHASE 9) — reuses BudgetCalculator.statusFor per month.
  // -------------------------------------------------------------------

  static BudgetTrend _budgetTrend(
    List<Budget> budgets,
    List<MonthlyFinancials> window,
    MonthlyFinancials previousPoint,
    MonthlyFinancials currentPoint,
  ) {
    var within = 0;
    var near = 0;
    var over = 0;
    var anyMonthHadBudgets = false;

    for (final point in window) {
      final monthBudgets = _budgetsForMonth(budgets, point.month);
      if (monthBudgets.isEmpty) continue;
      anyMonthHadBudgets = true;
      final totalAllocated = monthBudgets.fold<double>(0, (s, b) => s + b.allocatedAmount);
      final totalSpent = monthBudgets.fold<double>(0, (s, b) => s + b.spentAmount);
      switch (BudgetCalculator.statusFor(allocatedAmount: totalAllocated, spentAmount: totalSpent)) {
        case BudgetStatus.underBudget:
          within++;
        case BudgetStatus.nearLimit:
          near++;
        case BudgetStatus.overBudget:
          over++;
      }
    }

    final currentMonthBudgets = _budgetsForMonth(budgets, currentPoint.month);
    final previousMonthBudgets = _budgetsForMonth(budgets, previousPoint.month);
    final currentOverCount = currentMonthBudgets.isEmpty
        ? null
        : currentMonthBudgets
            .where((b) =>
                BudgetCalculator.statusFor(allocatedAmount: b.allocatedAmount, spentAmount: b.spentAmount) ==
                BudgetStatus.overBudget)
            .length;
    final previousOverCount = previousMonthBudgets.isEmpty
        ? null
        : previousMonthBudgets
            .where((b) =>
                BudgetCalculator.statusFor(allocatedAmount: b.allocatedAmount, spentAmount: b.spentAmount) ==
                BudgetStatus.overBudget)
            .length;

    TrendDirection direction;
    if (currentOverCount == null || previousOverCount == null) {
      direction = TrendDirection.insufficientData;
    } else if (currentOverCount < previousOverCount) {
      direction = TrendDirection.improving;
    } else if (currentOverCount > previousOverCount) {
      direction = TrendDirection.declining;
    } else {
      direction = TrendDirection.stable;
    }

    return BudgetTrend(
      monthsWithinBudget: within,
      monthsNearLimit: near,
      monthsOverBudget: over,
      currentOverBudgetCount: currentOverCount,
      previousOverBudgetCount: previousOverCount,
      direction: direction,
      hasSufficientData: anyMonthHadBudgets,
    );
  }

  static List<Budget> _budgetsForMonth(List<Budget> budgets, DateTime month) {
    final monthName = _monthNames[month.month - 1];
    return budgets
        .where((b) => b.month.trim().toLowerCase() == monthName.toLowerCase() && b.year == month.year)
        .toList();
  }

  // -------------------------------------------------------------------
  // Debt (PHASE 10) — a real, cumulative (not month-by-month) figure; see
  // DebtTrend's doc comment for why no month-by-month series is attempted.
  // -------------------------------------------------------------------

  static DebtTrend _debtTrend(List<Loan> loans, FinancialPlanningResult planning) {
    if (loans.isEmpty) {
      return const DebtTrend(
        currentOutstanding: 0, totalPaidDown: 0, activeLoanCount: 0,
        debtToIncomePercent: null, direction: TrendDirection.insufficientData, hasSufficientData: false,
      );
    }

    final totalPrincipal = loans.fold<double>(0, (s, l) => s + l.principalAmount);
    final totalOutstanding = loans.fold<double>(0, (s, l) => s + l.outstandingAmount);
    final totalPaidDown = (totalPrincipal - totalOutstanding).clamp(0.0, double.infinity);

    final direction = totalPrincipal > 0 && totalPaidDown / totalPrincipal >= FinancialHealthTrendsThresholds.debtChangeMaterialityFraction
        ? TrendDirection.improving
        : TrendDirection.stable;

    return DebtTrend(
      currentOutstanding: planning.debt.totalOutstanding,
      totalPaidDown: totalPaidDown,
      activeLoanCount: planning.debt.activeLoanCount,
      debtToIncomePercent: planning.debt.emiToIncomePercent,
      direction: direction,
      hasSufficientData: true,
    );
  }

  // -------------------------------------------------------------------
  // Emergency fund (PHASE 11) / Goals (PHASE 12) — current-state
  // pass-throughs; see each model's doc comment for why `direction` is
  // always `insufficientData`.
  // -------------------------------------------------------------------

  static EmergencyFundTrend _emergencyFundTrend(FinancialPlanningResult planning) {
    final ef = planning.emergencyFund;
    if (!ef.isSourceConfigured) {
      return const EmergencyFundTrend(
        target: null, current: null, progressPercent: null,
        isConfigured: false, direction: TrendDirection.insufficientData,
      );
    }
    final progress = (ef.target != null && ef.target! > 0) ? (ef.current / ef.target! * 100) : null;
    return EmergencyFundTrend(
      target: ef.target,
      current: ef.current,
      progressPercent: progress,
      isConfigured: true,
      direction: TrendDirection.insufficientData,
    );
  }

  static GoalTrend _goalTrend(FinancialPlanningResult planning) {
    final projections = planning.goalProjections;
    return GoalTrend(
      totalGoals: projections.length,
      goalsCompleted: projections.where((g) => g.status == GoalProjectionStatus.completed).length,
      goalsOnTrack: projections.where((g) => g.status == GoalProjectionStatus.onTrack).length,
      goalsAtRisk: projections.where((g) => g.status == GoalProjectionStatus.atRisk).length,
      direction: TrendDirection.insufficientData,
    );
  }

  // -------------------------------------------------------------------
  // Financial Health score history (PHASE 4)
  // -------------------------------------------------------------------

  static ScoreTrend _scoreTrend({
    required List<MonthlyFinancials> series,
    required List<MonthlyFinancials> window,
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<Bill> bills,
    required List<Wallet> wallets,
    required double profileMonthlyIncome,
    required DateTime referenceNow,
  }) {
    if (transactions.isEmpty) {
      return const ScoreTrend(
        currentScore: null, previousScore: null, change: null, averageScore: null,
        highestScore: null, lowestScore: null, direction: TrendDirection.insufficientData,
        history: [], hasSufficientData: false,
      );
    }

    final history = <ScorePoint>[];
    for (var i = 0; i < window.length; i++) {
      final point = window[i];
      final isCurrent = i == window.length - 1;

      if (isCurrent) {
        final result = FinancialHealthCalculator.calculate(
          transactions: transactions,
          budgets: budgets,
          goals: goals,
          loans: loans,
          bills: bills,
          wallets: wallets,
          profileMonthlyIncome: profileMonthlyIncome,
          now: referenceNow,
        );
        history.add(ScorePoint(month: point.month, score: result.overallScore, isApproximated: false));
      } else {
        if (!point.hasActivity) continue; // never fabricate a score for a month with no data at all
        final analytics = buildAnalyticsSummary(transactions, point.month);
        final savings =
            FinancialHealthCalculator.savingsScore(analytics.savingsRate, analytics.currentMonthIncome);
        final monthBudgets = _budgetsForMonth(budgets, point.month);
        final budget = FinancialHealthCalculator.budgetScore(monthBudgets);
        const neutral = 60.0;
        final approxScore = (savings * FinancialHealthCalculator.savingsWeight +
                budget * FinancialHealthCalculator.budgetWeight +
                neutral * FinancialHealthCalculator.goalsWeight +
                neutral * FinancialHealthCalculator.debtWeight +
                neutral * FinancialHealthCalculator.paymentsWeight)
            .round()
            .clamp(0, 100);
        history.add(ScorePoint(month: point.month, score: approxScore, isApproximated: true));
      }
    }

    if (history.isEmpty) {
      return const ScoreTrend(
        currentScore: null, previousScore: null, change: null, averageScore: null,
        highestScore: null, lowestScore: null, direction: TrendDirection.insufficientData,
        history: [], hasSufficientData: false,
      );
    }

    final scores = history.map((p) => p.score).toList();
    final currentScore = history.last.score;
    final previousScore = history.first.score;
    final average = (scores.fold<int>(0, (a, b) => a + b) / scores.length).round();

    return ScoreTrend(
      currentScore: currentScore,
      previousScore: history.length > 1 ? previousScore : null,
      change: history.length > 1 ? currentScore - previousScore : null,
      averageScore: average,
      highestScore: scores.reduce((a, b) => a > b ? a : b),
      lowestScore: scores.reduce((a, b) => a < b ? a : b),
      direction: history.length > 1
          ? _pointsDirection(
              previousScore.toDouble(),
              currentScore.toDouble(),
              threshold: FinancialHealthTrendsThresholds.materialScoreChangeThreshold.toDouble(),
            )
          : TrendDirection.insufficientData,
      history: history,
      hasSufficientData: true,
    );
  }

  // -------------------------------------------------------------------
  // Overall trajectory (PHASE 13)
  // -------------------------------------------------------------------

  static OverallTrajectory _computeTrajectory({
    required TrendDirection score,
    required TrendDirection savings,
    required TrendDirection cashFlow,
    required TrendDirection budget,
    required TrendDirection debt,
    required TrendDirection goals,
    required TrendDirection emergencyFund,
  }) {
    // A user can have income up, expenses up, savings up, AND debt up all
    // at once — that's a genuine MIXED trajectory, not something to force
    // into a single improving/declining bucket. Checked BEFORE the
    // weighted average, using only the domains with a real, non-neutral
    // direction signal (goals/emergencyFund are excluded here since they
    // are always `insufficientData` today — see their own doc comments).
    final core = [score, savings, cashFlow, budget, debt];
    final hasImproving = core.contains(TrendDirection.improving);
    final hasDeclining = core.contains(TrendDirection.declining);
    if (hasImproving && hasDeclining) return OverallTrajectory.mixed;

    const weights = <String, double>{
      'score': 0.30,
      'savings': 0.20,
      'cashFlow': 0.15,
      'budget': 0.15,
      'debt': 0.10,
      'goals': 0.05,
      'emergencyFund': 0.05,
    };
    final directions = <String, TrendDirection>{
      'score': score,
      'savings': savings,
      'cashFlow': cashFlow,
      'budget': budget,
      'debt': debt,
      'goals': goals,
      'emergencyFund': emergencyFund,
    };

    var weightedSum = 0.0;
    var weightTotal = 0.0;
    for (final entry in weights.entries) {
      final direction = directions[entry.key]!;
      if (direction == TrendDirection.insufficientData) continue;
      final signed = direction == TrendDirection.improving
          ? 1.0
          : (direction == TrendDirection.declining ? -1.0 : 0.0);
      weightedSum += signed * entry.value;
      weightTotal += entry.value;
    }

    if (weightTotal == 0) return OverallTrajectory.insufficientData;
    final avg = weightedSum / weightTotal;

    if (avg >= 0.6) return OverallTrajectory.stronglyImproving;
    if (avg >= 0.2) return OverallTrajectory.improving;
    if (avg <= -0.2) return OverallTrajectory.declining;
    return OverallTrajectory.stable;
  }

  // -------------------------------------------------------------------
  // Spending behavior signals (PHASE 8) / Key insights (PHASE 14) — both
  // built as FinancialTrendSignal (PHASE 18).
  // -------------------------------------------------------------------

  static List<FinancialTrendSignal> _spendingBehaviorSignals({
    required List<Transaction> transactions,
    required MonthlyFinancials previousPoint,
    required MonthlyFinancials currentPoint,
    required List<MonthlyFinancials> window,
    required IncomeTrend incomeTrend,
    required SavingsTrend savingsTrend,
  }) {
    final signals = <FinancialTrendSignal>[];

    // Category increase/decrease between the window's start and end month.
    final previousCategories = _categoryTotals(transactions, previousPoint.month);
    final currentCategories = _categoryTotals(transactions, currentPoint.month);
    final allCategories = {...previousCategories.keys, ...currentCategories.keys};
    for (final category in allCategories) {
      final before = previousCategories[category] ?? 0;
      final after = currentCategories[category] ?? 0;
      final delta = after - before;
      if (delta.abs() < FinancialHealthTrendsThresholds.categoryChangeMinimumAmount) continue;
      if (before > 0 && delta.abs() / before < FinancialHealthTrendsThresholds.categoryChangeFraction) continue;
      if (before == 0 && after == 0) continue;

      final increased = delta > 0;
      signals.add(
        FinancialTrendSignal(
          id: 'category-${increased ? 'increase' : 'decrease'}-$category',
          type: increased ? SignalType.categoryIncrease : SignalType.categoryDecrease,
          severity: delta.abs() >= FinancialHealthTrendsThresholds.categoryChangeMinimumAmount * 3
              ? SignalSeverity.notable
              : SignalSeverity.info,
          period: _monthLabel(currentPoint.month),
          title: increased ? '$category spending increased' : '$category spending decreased',
          explanation: before > 0
              ? '$category spending ${increased ? 'increased' : 'decreased'} '
                  '${(delta.abs() / before * 100).round()}% (₹${before.toStringAsFixed(0)} → ₹${after.toStringAsFixed(0)}).'
              : '$category is a new spending category this period, at ₹${after.toStringAsFixed(0)}.',
          supportingValues: {'before': before, 'after': after, 'change': delta},
          recommendation: increased ? 'Review your $category spending if this was unplanned.' : null,
        ),
      );
    }

    // Unusually high spending month.
    final activeWindow = window.where((m) => m.hasActivity).toList();
    if (activeWindow.length > 1) {
      final avgExpense = activeWindow.fold<double>(0, (s, m) => s + m.expense) / activeWindow.length;
      if (avgExpense > 0 &&
          currentPoint.expense > avgExpense * (1 + FinancialHealthTrendsThresholds.unusualMonthSpendFraction)) {
        signals.add(
          FinancialTrendSignal(
            id: 'unusually-high-month-${currentPoint.month.toIso8601String()}',
            type: SignalType.unusuallyHighMonth,
            severity: SignalSeverity.notable,
            period: _monthLabel(currentPoint.month),
            title: 'Unusually high spending month',
            explanation: 'This month\'s spending (₹${currentPoint.expense.toStringAsFixed(0)}) is well above '
                'your recent average of ₹${avgExpense.toStringAsFixed(0)}.',
            supportingValues: {'currentExpense': currentPoint.expense, 'averageExpense': avgExpense},
          ),
        );
      }
    }

    // Lifestyle inflation: income improved but savings didn't follow.
    if (incomeTrend.direction == TrendDirection.improving &&
        savingsTrend.direction != TrendDirection.improving &&
        savingsTrend.hasSufficientData) {
      signals.add(
        FinancialTrendSignal(
          id: 'lifestyle-inflation-${currentPoint.month.toIso8601String()}',
          type: SignalType.lifestyleInflation,
          severity: SignalSeverity.notable,
          period: _monthLabel(currentPoint.month),
          title: 'Spending is keeping pace with income',
          explanation: 'Your income increased, but your savings rate hasn\'t improved along with it.',
          supportingValues: {
            if (incomeTrend.currentIncome != null) 'currentIncome': incomeTrend.currentIncome,
            if (savingsTrend.currentSavingsRate != null) 'currentSavingsRate': savingsTrend.currentSavingsRate,
          },
          recommendation: 'Consider directing some of your income growth toward savings or your goals.',
        ),
      );
    }

    return signals;
  }

  static Map<String, double> _categoryTotals(List<Transaction> transactions, DateTime month) {
    final totals = <String, double>{};
    for (final t in transactions) {
      if (t.transactionType.toLowerCase() != 'expense') continue;
      if (t.createdAt.year != month.year || t.createdAt.month != month.month) continue;
      totals.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return totals;
  }

  static List<FinancialTrendSignal> _keyInsights({
    required ScoreTrend scoreTrend,
    required SavingsTrend savingsTrend,
    required BudgetTrend budgetTrend,
    required DebtTrend debtTrend,
    required GoalTrend goalTrend,
    required EmergencyFundTrend emergencyFundTrend,
    required List<FinancialTrendSignal> spendingSignals,
  }) {
    // Priority order per PHASE 14: major deterioration, major improvement,
    // important risk, strong positive behavior, actionable opportunity.
    final deterioration = <FinancialTrendSignal>[];
    final improvement = <FinancialTrendSignal>[];
    final risk = <FinancialTrendSignal>[];
    final positive = <FinancialTrendSignal>[];
    final opportunity = <FinancialTrendSignal>[];

    if (scoreTrend.change != null && scoreTrend.direction == TrendDirection.declining) {
      deterioration.add(_insight(
        id: 'health-decline', type: SignalType.healthDecline, severity: SignalSeverity.high,
        title: 'Financial Health declined',
        explanation: 'Your Financial Health score changed from ${scoreTrend.previousScore} to '
            '${scoreTrend.currentScore}.',
        values: {'previous': scoreTrend.previousScore, 'current': scoreTrend.currentScore},
      ));
    }
    if (scoreTrend.change != null && scoreTrend.direction == TrendDirection.improving) {
      improvement.add(_insight(
        id: 'health-improvement', type: SignalType.healthImprovement, severity: SignalSeverity.notable,
        title: 'Financial Health improved',
        explanation: 'Your Financial Health score improved from ${scoreTrend.previousScore} to '
            '${scoreTrend.currentScore}.',
        values: {'previous': scoreTrend.previousScore, 'current': scoreTrend.currentScore},
      ));
    }

    if (savingsTrend.direction == TrendDirection.declining &&
        savingsTrend.currentSavingsRate != null &&
        savingsTrend.previousSavingsRate != null) {
      final delta = (savingsTrend.currentSavingsRate! - savingsTrend.previousSavingsRate!).abs();
      risk.add(_insight(
        id: 'savings-decline', type: SignalType.savingsDecline, severity: SignalSeverity.high,
        title: 'Savings rate dropped',
        explanation: 'Your savings rate dropped by ${delta.round()} percentage points.',
        values: {'delta': delta},
      ));
    }
    if (savingsTrend.direction == TrendDirection.improving &&
        savingsTrend.currentSavingsRate != null &&
        savingsTrend.previousSavingsRate != null) {
      final delta = (savingsTrend.currentSavingsRate! - savingsTrend.previousSavingsRate!).abs();
      improvement.add(_insight(
        id: 'savings-improvement', type: SignalType.savingsImprovement, severity: SignalSeverity.notable,
        title: 'Savings rate improved',
        explanation: 'Your savings rate improved by ${delta.round()} percentage points.',
        values: {'delta': delta},
      ));
    }

    if (budgetTrend.direction == TrendDirection.improving) {
      positive.add(_insight(
        id: 'budget-improvement', type: SignalType.budgetImprovement, severity: SignalSeverity.info,
        title: 'Budget performance improved',
        explanation: 'Fewer categories went over budget compared to before '
            '(${budgetTrend.previousOverBudgetCount} → ${budgetTrend.currentOverBudgetCount}).',
        values: {'before': budgetTrend.previousOverBudgetCount, 'after': budgetTrend.currentOverBudgetCount},
      ));
    }
    if (budgetTrend.direction == TrendDirection.declining) {
      risk.add(_insight(
        id: 'budget-deterioration', type: SignalType.budgetDeterioration, severity: SignalSeverity.notable,
        title: 'More categories went over budget',
        explanation: 'Over-budget categories increased '
            '(${budgetTrend.previousOverBudgetCount} → ${budgetTrend.currentOverBudgetCount}).',
        values: {'before': budgetTrend.previousOverBudgetCount, 'after': budgetTrend.currentOverBudgetCount},
      ));
    }

    if (debtTrend.direction == TrendDirection.improving) {
      positive.add(_insight(
        id: 'debt-reduction', type: SignalType.debtReduction, severity: SignalSeverity.info,
        title: 'Outstanding debt decreased',
        explanation: 'You\'ve paid down ₹${debtTrend.totalPaidDown.toStringAsFixed(0)} of your recorded loans.',
        values: {'totalPaidDown': debtTrend.totalPaidDown},
      ));
    }

    if (emergencyFundTrend.isConfigured &&
        emergencyFundTrend.progressPercent != null &&
        emergencyFundTrend.progressPercent! < 50) {
      opportunity.add(_insight(
        id: 'emergency-fund-opportunity', type: SignalType.emergencyFundProgress, severity: SignalSeverity.info,
        title: 'Emergency fund progressing',
        explanation: 'Your emergency fund is ${emergencyFundTrend.progressPercent!.round()}% of the way to '
            'your target.',
        values: {'progressPercent': emergencyFundTrend.progressPercent},
      ));
    }

    if (goalTrend.goalsAtRisk > 0) {
      opportunity.add(_insight(
        id: 'goals-at-risk', type: SignalType.goalRisk, severity: SignalSeverity.notable,
        title: 'A goal needs attention',
        explanation: 'You have ${goalTrend.goalsAtRisk} goal${goalTrend.goalsAtRisk == 1 ? '' : 's'} that may '
            'fall behind target, out of ${goalTrend.totalGoals}.',
        values: {'atRisk': goalTrend.goalsAtRisk, 'total': goalTrend.totalGoals},
      ));
    }

    final notableSpending = spendingSignals.where((s) => s.severity != SignalSeverity.info).toList();

    return [
      ...deterioration,
      ...improvement,
      ...risk,
      ...positive,
      ...notableSpending,
      ...opportunity,
    ].take(FinancialHealthTrendsThresholds.maxKeyInsights).toList();
  }

  static FinancialTrendSignal _insight({
    required String id,
    required SignalType type,
    required SignalSeverity severity,
    required String title,
    required String explanation,
    required Map<String, dynamic> values,
  }) {
    return FinancialTrendSignal(
      id: id,
      type: type,
      severity: severity,
      period: '',
      title: title,
      explanation: explanation,
      supportingValues: values,
    );
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _monthLabel(DateTime month) => '${_monthNames[month.month - 1]} ${month.year}';
}

/// Small internal holder so `calculate`'s emergency-fund settings pass
/// through cleanly without a 3rd-party dependency on AppSettingsRepository
/// (this file stays pure Dart) — the caller (provider layer) supplies
/// them, matching how every other pure calculator in this app takes
/// settings as plain parameters rather than reading them itself.
class _EfSettings {
  _EfSettings(this.eligibleWalletIds, this.targetMonths);
  final List<String>? eligibleWalletIds;
  final int targetMonths;
}
