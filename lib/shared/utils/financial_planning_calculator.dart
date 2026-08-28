import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/analytics_provider.dart' show AnalyticsSummary, MonthlyTotal;
import 'subscription_calculator.dart' show subscriptionOccurrencesPerYear, SubscriptionCalculator;

/// Financial Planning 2.0 — a read-only forward-looking layer over data that
/// already exists elsewhere in PaySense (Wallets, Transactions, Goals,
/// Loans, Bills, RecurringTransactions). Nothing here persists anything,
/// mutates a balance, or creates a transaction; every number is either
/// copied straight from an existing model/calculator or derived from one
/// with the derivation documented on the field.
///
/// This is deliberately a *different* score from
/// [FinancialHealthCalculator]'s wellness/behavior score: Financial Health
/// asks "how well am I managing money right now" (savings/budget-adherence/
/// goals/debt/on-time-payments); Financial Planning asks "how prepared am I
/// for the future" (emergency fund, debt burden, goal pacing, fixed
/// commitment load, cash-flow consistency). The two share some inputs
/// (loans, goals) but score them for different purposes with different
/// bands — this is intentional, not a duplicate.

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

enum PlanningReadinessStatus { needsAttention, buildingFoundation, onTrack, wellPrepared }

String planningReadinessStatusLabel(PlanningReadinessStatus status) {
  switch (status) {
    case PlanningReadinessStatus.needsAttention:
      return 'Needs attention';
    case PlanningReadinessStatus.buildingFoundation:
      return 'Building foundation';
    case PlanningReadinessStatus.onTrack:
      return 'On track';
    case PlanningReadinessStatus.wellPrepared:
      return 'Well prepared';
  }
}

PlanningReadinessStatus planningReadinessStatusForScore(int score) {
  if (score >= 80) return PlanningReadinessStatus.wellPrepared;
  if (score >= 60) return PlanningReadinessStatus.onTrack;
  if (score >= 35) return PlanningReadinessStatus.buildingFoundation;
  return PlanningReadinessStatus.needsAttention;
}

/// Per-component status used throughout the planning result. Distinct from
/// a numeric score so the UI/tests can reason about "insufficient data"
/// without treating it as a (fabricated) zero.
enum PlanningComponentStatus { good, fair, needsAttention, insufficientData }

@immutable
class FinancialOverview {
  const FinancialOverview({
    required this.netWorth,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.monthlySavings,
    required this.savingsRatePercent,
    required this.hasIncomeData,
    required this.monthlyFixedCommitments,
    required this.totalDebt,
    required this.emergencyFundCurrent,
    this.totalAssets = 0.0,
  });

  /// Sum of wallet balances minus outstanding loan balances. Does not
  /// include investments/property — PaySense doesn't track those today, so
  /// this is deliberately not padded with a guessed figure.
  final double netWorth;

  final double monthlyIncome;
  final double monthlyExpenses;
  final double monthlySavings;

  /// Null when [monthlyIncome] is 0 — a percentage would be meaningless.
  final double? savingsRatePercent;
  final bool hasIncomeData;

  final double monthlyFixedCommitments;
  final double totalDebt;

  /// Sum of non-archived wallet balances — the SAME `totalWalletBalance`
  /// already used to compute [netWorth] above, just also exposed on its
  /// own so callers (e.g. the Dashboard's Total Assets card) can show it
  /// without re-summing wallets a second time. Defaults to 0 only for the
  /// rare direct-construction call site (a test fixture) that predates this
  /// field and doesn't exercise it.
  final double totalAssets;

  /// Sum of balances across the user-configured emergency-fund-eligible
  /// wallets — 0 (not fabricated) when none are configured.
  final double emergencyFundCurrent;
}

// ---------------------------------------------------------------------------
// Emergency Fund
// ---------------------------------------------------------------------------

/// Allowed target-month presets for the Emergency Fund Planner.
const List<int> emergencyFundTargetMonthOptions = [3, 6, 9, 12];
const int defaultEmergencyFundTargetMonths = 6;

/// How many trailing *complete* calendar months of expense history are
/// averaged to estimate a monthly baseline — deliberately excludes the
/// current, possibly-still-in-progress month.
const int emergencyFundLookbackMonths = 3;

@immutable
class EmergencyFundResult {
  const EmergencyFundResult({
    required this.targetMonths,
    required this.monthlyExpenseBaseline,
    required this.target,
    required this.current,
    required this.remaining,
    required this.monthlyContribution,
    required this.estimatedMonths,
    required this.estimatedCompletionDate,
    required this.isSourceConfigured,
    required this.hasExpenseData,
  });

  final int targetMonths;

  /// Average total monthly expense over the last
  /// [emergencyFundLookbackMonths] complete months. Deliberately the *total*
  /// spend, not a guessed "essentials only" subset — PaySense has no
  /// essential/discretionary classification for categories, and fabricating
  /// one would violate the "never guess" rule. Using total spend is also the
  /// more conservative (safer) baseline for an emergency fund. Null when
  /// there isn't at least one month of expense history.
  final double? monthlyExpenseBaseline;

  /// `monthlyExpenseBaseline * targetMonths`, or null when
  /// [monthlyExpenseBaseline] is null.
  final double? target;

  /// Sum of balances across the configured eligible wallets. 0 when no
  /// wallets are configured (never guessed).
  final double current;

  /// `max(0, target - current)`, or null when [target] is null.
  final double? remaining;

  /// The monthly contribution used to project [estimatedMonths] — currently
  /// always the overview's `monthlySavings` (what the user is actually
  /// saving today), clamped at 0 (a negative savings rate can't "contribute"
  /// toward anything). Null when there's no income data to derive it from.
  final double? monthlyContribution;

  /// `ceil(remaining / monthlyContribution)`. Null when it can't be safely
  /// computed (missing target, or a zero/unknown monthly contribution — a
  /// zero contribution would imply an infinite/never date, which is never
  /// shown as a number).
  final int? estimatedMonths;

  final DateTime? estimatedCompletionDate;

  /// Whether the user has explicitly selected at least one
  /// emergency-fund-eligible wallet in Settings.
  final bool isSourceConfigured;

  final bool hasExpenseData;

  bool get isFullyFunded =>
      target != null && current >= target! && target! > 0;
}

// ---------------------------------------------------------------------------
// Goal projection
// ---------------------------------------------------------------------------

enum GoalProjectionStatus { completed, onTrack, atRisk, insufficientData }

@immutable
class GoalProjection {
  const GoalProjection({
    required this.goalId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.targetDate,
    required this.impliedMonthlyContribution,
    required this.estimatedMonths,
    required this.estimatedCompletionDate,
    required this.requiredMonthlyContribution,
    required this.contributionGap,
    required this.status,
  });

  final String goalId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final double remainingAmount;
  final DateTime targetDate;

  /// `currentAmount / monthsSinceCreated` — the goal's own average pace of
  /// progress since it was created. This is a derived approximation, not a
  /// stored contribution rate (Goal has no such field) — null when the goal
  /// is less than a month old (too little history to average safely).
  final double? impliedMonthlyContribution;

  /// `ceil(remainingAmount / impliedMonthlyContribution)`. Null when
  /// [impliedMonthlyContribution] is null or 0 (a 0 pace never completes).
  final int? estimatedMonths;

  final DateTime? estimatedCompletionDate;

  /// `remainingAmount / monthsUntilTargetDate` — what the user would need to
  /// contribute monthly to hit [targetDate]. Null when the target date has
  /// already passed (there are 0 months left to spread the remainder over).
  final double? requiredMonthlyContribution;

  /// `requiredMonthlyContribution - impliedMonthlyContribution`, positive
  /// meaning the user needs to contribute *more* to stay on pace for
  /// [targetDate]. Null when either input is null.
  final double? contributionGap;

  final GoalProjectionStatus status;
}

/// GOAL INTELLIGENCE — a weekly view of the SAME [GoalProjection.requiredMonthlyContribution]
/// figure, not a separately-derived weekly pace (there is no weekly
/// contribution-history data to derive one from). `4.345` is the average
/// number of weeks in a month (365.25 / 12 / 7) — a fixed calendar
/// constant, never a fabricated figure.
extension GoalProjectionWeekly on GoalProjection {
  static const double weeksPerMonth = 4.345;

  double? get requiredWeeklyContribution =>
      requiredMonthlyContribution == null ? null : requiredMonthlyContribution! / weeksPerMonth;
}

// ---------------------------------------------------------------------------
// Commitment load
// ---------------------------------------------------------------------------

@immutable
class CommitmentBreakdown {
  const CommitmentBreakdown({
    required this.loanEmi,
    required this.recurringBills,
    required this.subscriptions,
    required this.otherRecurring,
    required this.total,
    required this.percentageOfIncome,
    required this.hasIncomeData,
    required this.excludedRecurringCount,
  });

  final double loanEmi;

  /// Monthly-equivalent cost of unpaid *recurring* bills only — a one-off
  /// bill isn't a recurring monthly commitment, so it's intentionally not
  /// included here (Safe-to-Spend already covers near-term one-off bills).
  final double recurringBills;

  /// From [SubscriptionCalculator.eligibleSubscriptions] — reused directly,
  /// never recomputed, so this always matches what the Subscriptions screen
  /// shows.
  final double subscriptions;

  /// Active, non-expired, expense-type recurring transactions that are
  /// *not* already counted in [subscriptions] (i.e. failed the subscription
  /// eligibility filter but still have a recognized frequency) — the
  /// non-overlapping remainder, so [subscriptions] and [otherRecurring]
  /// never double-count the same RecurringTransaction.
  final double otherRecurring;

  final double total;

  final double? percentageOfIncome;
  final bool hasIncomeData;

  /// Active expense recurring transactions that could NOT be safely
  /// converted to a monthly figure (unrecognized frequency) and were
  /// excluded from [otherRecurring] rather than guessed at.
  final int excludedRecurringCount;
}

// ---------------------------------------------------------------------------
// Debt planning
// ---------------------------------------------------------------------------

@immutable
class LoanPlanningDetail {
  const LoanPlanningDetail({
    required this.loanId,
    required this.name,
    required this.outstandingAmount,
    required this.emiAmount,
    required this.interestRate,
    required this.remainingMonths,
    required this.payoffDate,
  });

  final String loanId;
  final String name;
  final double outstandingAmount;
  final double emiAmount;

  /// Null is never produced today (Loan.interestRate is a required,
  /// always-populated field) — kept nullable so the type honestly reflects
  /// "may be unavailable" per the feature spec, and so a future optional
  /// interest rate wouldn't require a signature change.
  final double? interestRate;

  /// Months between now and [payoffDate], clamped to 0. Null if
  /// [payoffDate] has already passed.
  final int? remainingMonths;

  /// The loan's own stored end date — never recomputed via a fresh
  /// amortization projection, so this always agrees with what the Loan
  /// screen itself shows.
  final DateTime payoffDate;
}

@immutable
class DebtOverview {
  const DebtOverview({
    required this.totalOutstanding,
    required this.monthlyEmiBurden,
    required this.activeLoanCount,
    required this.emiToIncomePercent,
    required this.hasIncomeData,
    required this.loans,
  });

  final double totalOutstanding;
  final double monthlyEmiBurden;
  final int activeLoanCount;
  final double? emiToIncomePercent;
  final bool hasIncomeData;
  final List<LoanPlanningDetail> loans;

  bool get hasDebt => activeLoanCount > 0;
}

enum DebtPriorityMethod { byInterestRate, byOutstandingBalance, none }

@immutable
class DebtPriorityEntry {
  const DebtPriorityEntry({
    required this.loanId,
    required this.name,
    required this.interestRate,
    required this.outstandingAmount,
  });

  final String loanId;
  final String name;
  final double? interestRate;
  final double outstandingAmount;
}

@immutable
class DebtPriorityResult {
  const DebtPriorityResult({
    required this.method,
    required this.ranked,
    required this.reason,
  });

  final DebtPriorityMethod method;
  final List<DebtPriorityEntry> ranked;

  /// Human-readable explanation of why this method was chosen (or why no
  /// automatic ranking was produced) — always non-null so the UI never has
  /// to fabricate its own reasoning.
  final String reason;
}

// ---------------------------------------------------------------------------
// Savings plan
// ---------------------------------------------------------------------------

/// A commonly-cited general savings-rate benchmark (the "20%" portion of the
/// 50/30/20 budgeting guideline) — shown explicitly labeled as a general
/// benchmark, never presented as personalized financial advice.
const double recommendedSavingsRatePercent = 20.0;

@immutable
class SavingsPlan {
  const SavingsPlan({
    required this.averageMonthlyIncome,
    required this.averageMonthlyExpense,
    required this.averageMonthlySavings,
    required this.currentSavingsRatePercent,
    required this.recommendedTargetPercent,
    required this.monthlyGapToTarget,
    required this.hasSufficientData,
  });

  final double averageMonthlyIncome;
  final double averageMonthlyExpense;
  final double averageMonthlySavings;

  final double? currentSavingsRatePercent;
  final double recommendedTargetPercent;

  /// How much more the user would need to save per month to reach
  /// [recommendedTargetPercent], or null if they're already at/above it or
  /// there's no income data. Never negative.
  final double? monthlyGapToTarget;

  final bool hasSufficientData;
}

// ---------------------------------------------------------------------------
// What-if
// ---------------------------------------------------------------------------

@immutable
class WhatIfProjection {
  const WhatIfProjection({
    required this.hypotheticalMonthlySavings,
    required this.emergencyFundMonthsBefore,
    required this.emergencyFundMonthsAfter,
    required this.emergencyFundDateBefore,
    required this.emergencyFundDateAfter,
    required this.goalId,
    required this.goalMonthsBefore,
    required this.goalMonthsAfter,
    required this.goalDateBefore,
    required this.goalDateAfter,
  });

  final double hypotheticalMonthlySavings;

  final int? emergencyFundMonthsBefore;
  final int? emergencyFundMonthsAfter;
  final DateTime? emergencyFundDateBefore;
  final DateTime? emergencyFundDateAfter;

  /// The single goal this projection was computed for (the earliest
  /// incomplete goal by target date), or null when there are no incomplete
  /// goals to project.
  final String? goalId;
  final int? goalMonthsBefore;
  final int? goalMonthsAfter;
  final DateTime? goalDateBefore;
  final DateTime? goalDateAfter;
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

enum PlanningMilestoneType { now, emergencyFund, goal, debtPayoff }

@immutable
class PlanningMilestone {
  const PlanningMilestone({
    required this.type,
    required this.label,
    required this.date,
  });

  final PlanningMilestoneType type;
  final String label;
  final DateTime date;
}

// ---------------------------------------------------------------------------
// Score components + top-level result
// ---------------------------------------------------------------------------

@immutable
class FinancialPlanningScoreComponents {
  const FinancialPlanningScoreComponents({
    required this.emergencyFund,
    required this.savings,
    required this.debt,
    required this.goals,
    required this.commitments,
    required this.cashFlowConsistency,
  });

  final int emergencyFund;
  final int savings;
  final int debt;
  final int goals;
  final int commitments;
  final int cashFlowConsistency;
}

@immutable
class FinancialPlanningResult {
  const FinancialPlanningResult({
    required this.readinessScore,
    required this.status,
    required this.components,
    required this.overview,
    required this.emergencyFund,
    required this.emergencyFundStatus,
    required this.goalProjections,
    required this.goalStatus,
    required this.commitments,
    required this.commitmentStatus,
    required this.debt,
    required this.debtStatus,
    required this.debtPriority,
    required this.savingsPlan,
    required this.savingsStatus,
    required this.recommendations,
    required this.hasSufficientData,
  });

  final int readinessScore;
  final PlanningReadinessStatus status;
  final FinancialPlanningScoreComponents components;

  final FinancialOverview overview;

  final EmergencyFundResult emergencyFund;
  final PlanningComponentStatus emergencyFundStatus;

  final List<GoalProjection> goalProjections;
  final PlanningComponentStatus goalStatus;

  final CommitmentBreakdown commitments;
  final PlanningComponentStatus commitmentStatus;

  final DebtOverview debt;
  final PlanningComponentStatus debtStatus;
  final DebtPriorityResult debtPriority;

  final SavingsPlan savingsPlan;
  final PlanningComponentStatus savingsStatus;

  /// Top-priority, deterministic action items — see
  /// [FinancialPlanningCalculator._buildActionPlan]. At most 3, always at
  /// least 1 (a neutral "on track" message when nothing is actionable).
  final List<String> recommendations;

  /// False only when there are no wallets AND no transactions AND no
  /// goals/loans/bills/recurring items at all — a genuinely brand-new
  /// account with nothing to plan around yet.
  final bool hasSufficientData;
}

/// Pure, deterministic Financial Planning calculation. No Flutter/Riverpod
/// dependency, no persistence, no writes of any kind — every input is an
/// already-loaded list from an existing repository/provider, and every
/// output is either copied straight through or clearly documented as a
/// derived estimate.
class FinancialPlanningCalculator {
  FinancialPlanningCalculator._();

  static FinancialPlanningResult calculate({
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<Bill> bills,
    required List<RecurringTransaction> recurringTransactions,
    required AnalyticsSummary analytics,
    List<String>? emergencyFundEligibleWalletIds,
    int emergencyFundTargetMonths = defaultEmergencyFundTargetMonths,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final eligibleWallets = wallets.where((w) => !w.isArchived).toList();
    final activeLoans = loans.where((l) => l.isActive).toList();

    final totalWalletBalance = eligibleWallets.fold<double>(
      0,
      (sum, w) => sum + w.currentBalance,
    );
    final totalOutstandingDebt = activeLoans.fold<double>(
      0,
      (sum, l) => sum + l.outstandingAmount,
    );

    final monthlyIncome = analytics.currentMonthIncome;
    final monthlyExpenses = analytics.currentMonthExpense;
    final hasIncomeData = monthlyIncome > 0;
    final monthlySavings = monthlyIncome - monthlyExpenses;

    final emergencyFund = calculateEmergencyFund(
      analytics: analytics,
      wallets: eligibleWallets,
      eligibleWalletIds: emergencyFundEligibleWalletIds,
      targetMonths: emergencyFundTargetMonths,
      monthlySavings: monthlySavings,
      hasIncomeData: hasIncomeData,
      now: referenceNow,
    );

    final goalProjections = calculateGoalProjections(goals: goals, now: referenceNow);

    final commitments = calculateCommitments(
      bills: bills,
      loans: activeLoans,
      recurringTransactions: recurringTransactions,
      monthlyIncome: monthlyIncome,
      hasIncomeData: hasIncomeData,
      now: referenceNow,
    );

    final debt = calculateDebtOverview(
      loans: activeLoans,
      monthlyIncome: monthlyIncome,
      hasIncomeData: hasIncomeData,
      now: referenceNow,
    );

    final debtPriority = calculateDebtPriority(activeLoans);

    final savingsPlan = calculateSavingsPlan(analytics);

    final overview = FinancialOverview(
      netWorth: totalWalletBalance - totalOutstandingDebt,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      monthlySavings: monthlySavings,
      savingsRatePercent: hasIncomeData ? (monthlySavings / monthlyIncome * 100) : null,
      hasIncomeData: hasIncomeData,
      monthlyFixedCommitments: commitments.total,
      totalDebt: totalOutstandingDebt,
      emergencyFundCurrent: emergencyFund.current,
      totalAssets: totalWalletBalance,
    );

    final cashFlowConsistencyScore = _cashFlowConsistencyScore(analytics.monthlyTotals);

    final emergencyFundScore = _emergencyFundScore(emergencyFund);
    final savingsScore = _savingsScore(savingsPlan);
    final debtScore = _debtBurdenScore(debt);
    final goalsScore = _goalsScore(goalProjections);
    final commitmentsScore = _commitmentScore(commitments);

    final components = FinancialPlanningScoreComponents(
      emergencyFund: emergencyFundScore,
      savings: savingsScore,
      debt: debtScore,
      goals: goalsScore,
      commitments: commitmentsScore,
      cashFlowConsistency: cashFlowConsistencyScore,
    );

    final readinessScore = (emergencyFundScore * 0.25 +
            savingsScore * 0.20 +
            debtScore * 0.20 +
            goalsScore * 0.15 +
            commitmentsScore * 0.10 +
            cashFlowConsistencyScore * 0.10)
        .round()
        .clamp(0, 100);

    final hasSufficientData = transactions.isNotEmpty ||
        eligibleWallets.isNotEmpty ||
        goals.isNotEmpty ||
        activeLoans.isNotEmpty ||
        bills.isNotEmpty ||
        recurringTransactions.isNotEmpty;

    return FinancialPlanningResult(
      readinessScore: readinessScore,
      status: planningReadinessStatusForScore(readinessScore),
      components: components,
      overview: overview,
      emergencyFund: emergencyFund,
      emergencyFundStatus: _statusFor(emergencyFundScore, hasData: emergencyFund.hasExpenseData),
      goalProjections: goalProjections,
      goalStatus: _statusFor(goalsScore, hasData: goalProjections.isNotEmpty),
      commitments: commitments,
      commitmentStatus: _statusFor(commitmentsScore, hasData: hasIncomeData),
      debt: debt,
      debtStatus: _statusFor(debtScore, hasData: true),
      debtPriority: debtPriority,
      savingsPlan: savingsPlan,
      savingsStatus: _statusFor(savingsScore, hasData: savingsPlan.hasSufficientData),
      recommendations: _buildActionPlan(
        emergencyFund: emergencyFund,
        commitments: commitments,
        goalProjections: goalProjections,
        savingsPlan: savingsPlan,
      ),
      hasSufficientData: hasSufficientData,
    );
  }

  // ---- Emergency Fund ----

  static EmergencyFundResult calculateEmergencyFund({
    required AnalyticsSummary analytics,
    required List<Wallet> wallets,
    required List<String>? eligibleWalletIds,
    required DateTime now,
    int targetMonths = defaultEmergencyFundTargetMonths,
    double? monthlySavings,
    bool hasIncomeData = false,
  }) {
    final isSourceConfigured = eligibleWalletIds != null && eligibleWalletIds.isNotEmpty;
    final eligibleIdSet = (eligibleWalletIds ?? const <String>[]).toSet();
    final current = wallets
        .where((w) => eligibleIdSet.contains(w.id))
        .fold<double>(0, (sum, w) => sum + w.currentBalance);

    final monthlyExpenseBaseline = _trailingCompleteMonthsAverageExpense(
      analytics.monthlyTotals,
      now,
    );

    final target = monthlyExpenseBaseline == null
        ? null
        : monthlyExpenseBaseline * targetMonths;

    final remaining = target == null ? null : (target - current).clamp(0.0, target);

    final contribution = (hasIncomeData && monthlySavings != null && monthlySavings > 0)
        ? monthlySavings
        : null;

    int? estimatedMonths;
    DateTime? completionDate;
    if (remaining != null && contribution != null && contribution > 0) {
      if (remaining <= 0) {
        estimatedMonths = 0;
        completionDate = now;
      } else {
        estimatedMonths = (remaining / contribution).ceil();
        completionDate = _addMonths(now, estimatedMonths);
      }
    }

    return EmergencyFundResult(
      targetMonths: targetMonths,
      monthlyExpenseBaseline: monthlyExpenseBaseline,
      target: target,
      current: current,
      remaining: remaining,
      monthlyContribution: contribution,
      estimatedMonths: estimatedMonths,
      estimatedCompletionDate: completionDate,
      isSourceConfigured: isSourceConfigured,
      hasExpenseData: monthlyExpenseBaseline != null,
    );
  }

  /// Averages the last [emergencyFundLookbackMonths] *complete* months from
  /// [monthlyTotals] (which is ordered oldest-to-newest, ending with the
  /// current, possibly-partial month) — skips the current month entirely.
  /// Only months with actual recorded expense activity count toward the
  /// average; returns null when none of the lookback months have any.
  static double? _trailingCompleteMonthsAverageExpense(
    List<MonthlyTotal> monthlyTotals,
    DateTime now,
  ) {
    if (monthlyTotals.length < 2) {
      return null;
    }
    // Drop the current (possibly in-progress) month, then take up to the
    // last [emergencyFundLookbackMonths] of what remains.
    final completeMonths = monthlyTotals.sublist(0, monthlyTotals.length - 1);
    final window = completeMonths.length > emergencyFundLookbackMonths
        ? completeMonths.sublist(completeMonths.length - emergencyFundLookbackMonths)
        : completeMonths;

    final withActivity = window.where((m) => m.expense > 0).toList();
    if (withActivity.isEmpty) {
      return null;
    }
    final total = withActivity.fold<double>(0, (sum, m) => sum + m.expense);
    return total / withActivity.length;
  }

  // ---- Goal projection ----

  static List<GoalProjection> calculateGoalProjections({
    required List<Goal> goals,
    required DateTime now,
  }) {
    return goals.map((g) => _projectGoal(g, now)).toList();
  }

  static GoalProjection _projectGoal(Goal goal, DateTime now) {
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, goal.targetAmount);

    final monthsSinceCreated = _monthsBetween(goal.createdAt, now);
    final impliedMonthlyContribution = monthsSinceCreated >= 1
        ? goal.currentAmount / monthsSinceCreated
        : null;

    int? estimatedMonths;
    DateTime? estimatedCompletionDate;
    if (goal.isCompleted) {
      estimatedMonths = 0;
      estimatedCompletionDate = now;
    } else if (impliedMonthlyContribution != null && impliedMonthlyContribution > 0) {
      estimatedMonths = (remaining / impliedMonthlyContribution).ceil();
      estimatedCompletionDate = _addMonths(now, estimatedMonths);
    }

    final monthsUntilTarget = _monthsBetween(now, goal.targetDate);
    final requiredMonthlyContribution = (!goal.isCompleted && monthsUntilTarget > 0)
        ? remaining / monthsUntilTarget
        : null;

    final contributionGap = (requiredMonthlyContribution != null && impliedMonthlyContribution != null)
        ? requiredMonthlyContribution - impliedMonthlyContribution
        : null;

    final status = goal.isCompleted
        ? GoalProjectionStatus.completed
        : (requiredMonthlyContribution == null || impliedMonthlyContribution == null)
            ? GoalProjectionStatus.insufficientData
            : (impliedMonthlyContribution >= requiredMonthlyContribution
                ? GoalProjectionStatus.onTrack
                : GoalProjectionStatus.atRisk);

    return GoalProjection(
      goalId: goal.id,
      title: goal.title,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      remainingAmount: remaining,
      targetDate: goal.targetDate,
      impliedMonthlyContribution: impliedMonthlyContribution,
      estimatedMonths: estimatedMonths,
      estimatedCompletionDate: estimatedCompletionDate,
      requiredMonthlyContribution: requiredMonthlyContribution,
      contributionGap: contributionGap,
      status: status,
    );
  }

  // ---- Commitment load ----

  static CommitmentBreakdown calculateCommitments({
    required List<Bill> bills,
    required List<Loan> loans,
    required List<RecurringTransaction> recurringTransactions,
    required double monthlyIncome,
    required bool hasIncomeData,
    required DateTime now,
  }) {
    final loanEmi = loans.fold<double>(0, (sum, l) => sum + l.emiAmount);

    final recurringBills = bills
        .where((b) => b.isRecurring && !b.isPaid)
        .fold<double>(0, (sum, b) => sum + _monthlyEquivalentFromAnnual(b.amount, b.frequency));

    final subscriptions = SubscriptionCalculator.eligibleSubscriptions(
      recurringTransactions: recurringTransactions,
      now: now,
    );
    final subscriptionIds = subscriptions.map((s) => s.sourceId).toSet();
    final subscriptionsTotal = SubscriptionCalculator.totalMonthlyCost(subscriptions);

    double otherRecurring = 0;
    var excludedRecurringCount = 0;
    for (final item in recurringTransactions) {
      if (!item.isActive || item.isExpired) continue;
      if (item.transactionType.toLowerCase() != 'expense') continue;
      if (subscriptionIds.contains(item.id)) continue; // already counted above
      if (item.amount <= 0) continue;
      if (!subscriptionOccurrencesPerYear.containsKey(item.frequency)) {
        excludedRecurringCount++;
        continue;
      }
      otherRecurring += _monthlyEquivalentFromAnnual(item.amount, item.frequency);
    }

    final total = loanEmi + recurringBills + subscriptionsTotal + otherRecurring;
    final percentageOfIncome = hasIncomeData ? (total / monthlyIncome * 100) : null;

    return CommitmentBreakdown(
      loanEmi: loanEmi,
      recurringBills: recurringBills,
      subscriptions: subscriptionsTotal,
      otherRecurring: otherRecurring,
      total: total,
      percentageOfIncome: percentageOfIncome,
      hasIncomeData: hasIncomeData,
      excludedRecurringCount: excludedRecurringCount,
    );
  }

  /// Same annualize-then-divide-by-12 methodology as
  /// [SubscriptionCalculator.annualCostFor], reused here for bills/other
  /// recurring items so every monthly-equivalent figure in this file is
  /// computed the same way. Note this is a *different* (more precise)
  /// convention than `RecurringTotals`' own `_monthlyEquivalent` helper in
  /// recurring_transaction_provider.dart (which uses a flat 30-day-month
  /// approximation for its Dashboard summary) — a small pre-existing
  /// inconsistency between two independent, unrelated features that this
  /// milestone does not change (see final report).
  static double _monthlyEquivalentFromAnnual(double amount, String frequency) {
    final occurrences = subscriptionOccurrencesPerYear[frequency];
    if (occurrences == null) return 0;
    return amount * occurrences / 12;
  }

  // ---- Debt planning ----

  static DebtOverview calculateDebtOverview({
    required List<Loan> loans,
    required double monthlyIncome,
    required bool hasIncomeData,
    required DateTime now,
  }) {
    final totalOutstanding = loans.fold<double>(0, (sum, l) => sum + l.outstandingAmount);
    final monthlyEmiBurden = loans.fold<double>(0, (sum, l) => sum + l.emiAmount);
    final emiToIncomePercent = hasIncomeData ? (monthlyEmiBurden / monthlyIncome * 100) : null;

    final details = loans.map((loan) {
      final hasPassedEnd = loan.endDate.isBefore(now);
      return LoanPlanningDetail(
        loanId: loan.id,
        name: loan.loanName,
        outstandingAmount: loan.outstandingAmount,
        emiAmount: loan.emiAmount,
        interestRate: loan.interestRate,
        remainingMonths: hasPassedEnd ? null : _monthsBetween(now, loan.endDate),
        payoffDate: loan.endDate,
      );
    }).toList();

    return DebtOverview(
      totalOutstanding: totalOutstanding,
      monthlyEmiBurden: monthlyEmiBurden,
      activeLoanCount: loans.length,
      emiToIncomePercent: emiToIncomePercent,
      hasIncomeData: hasIncomeData,
      loans: details,
    );
  }

  static DebtPriorityResult calculateDebtPriority(List<Loan> loans) {
    if (loans.isEmpty) {
      return const DebtPriorityResult(
        method: DebtPriorityMethod.none,
        ranked: [],
        reason: 'No active loans to prioritize.',
      );
    }
    if (loans.length == 1) {
      final loan = loans.single;
      return DebtPriorityResult(
        method: DebtPriorityMethod.none,
        ranked: [
          DebtPriorityEntry(
            loanId: loan.id,
            name: loan.loanName,
            interestRate: loan.interestRate,
            outstandingAmount: loan.outstandingAmount,
          ),
        ],
        reason: 'Only one active loan — nothing to prioritize between.',
      );
    }

    final allHaveInterestRate = loans.every((l) => l.interestRate > 0);
    final entries = loans
        .map(
          (l) => DebtPriorityEntry(
            loanId: l.id,
            name: l.loanName,
            interestRate: l.interestRate,
            outstandingAmount: l.outstandingAmount,
          ),
        )
        .toList();

    if (allHaveInterestRate) {
      entries.sort((a, b) => b.interestRate!.compareTo(a.interestRate!));
      return DebtPriorityResult(
        method: DebtPriorityMethod.byInterestRate,
        ranked: entries,
        reason: 'Ranked by highest interest rate first — paying these down '
            'first saves the most in interest over time.',
      );
    }

    entries.sort((a, b) => b.outstandingAmount.compareTo(a.outstandingAmount));
    return DebtPriorityResult(
      method: DebtPriorityMethod.byOutstandingBalance,
      ranked: entries,
      reason: 'One or more loans have no recorded interest rate, so ranking '
          'falls back to the highest outstanding balance first.',
    );
  }

  // ---- Savings plan ----

  static SavingsPlan calculateSavingsPlan(AnalyticsSummary analytics) {
    final monthsWithData = analytics.monthlyTotals
        .where((m) => m.income > 0 || m.expense > 0)
        .toList();

    if (monthsWithData.isEmpty) {
      return const SavingsPlan(
        averageMonthlyIncome: 0,
        averageMonthlyExpense: 0,
        averageMonthlySavings: 0,
        currentSavingsRatePercent: null,
        recommendedTargetPercent: recommendedSavingsRatePercent,
        monthlyGapToTarget: null,
        hasSufficientData: false,
      );
    }

    final avgIncome =
        monthsWithData.fold<double>(0, (sum, m) => sum + m.income) / monthsWithData.length;
    final avgExpense =
        monthsWithData.fold<double>(0, (sum, m) => sum + m.expense) / monthsWithData.length;
    final avgSavings = avgIncome - avgExpense;

    final currentRate = avgIncome > 0 ? (avgSavings / avgIncome * 100) : null;

    double? gap;
    if (avgIncome > 0 && currentRate != null && currentRate < recommendedSavingsRatePercent) {
      final targetSavings = avgIncome * recommendedSavingsRatePercent / 100;
      gap = (targetSavings - avgSavings).clamp(0.0, double.infinity);
    }

    return SavingsPlan(
      averageMonthlyIncome: avgIncome,
      averageMonthlyExpense: avgExpense,
      averageMonthlySavings: avgSavings,
      currentSavingsRatePercent: currentRate,
      recommendedTargetPercent: recommendedSavingsRatePercent,
      monthlyGapToTarget: gap,
      hasSufficientData: true,
    );
  }

  // ---- What-if ----

  /// Recomputes emergency-fund and (earliest incomplete) goal completion
  /// estimates using [hypotheticalMonthlySavings] instead of the real
  /// derived contribution figures — a parallel, throwaway calculation that
  /// never touches [result] or any persisted data.
  static WhatIfProjection whatIf({
    required FinancialPlanningResult result,
    required double hypotheticalMonthlySavings,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final ef = result.emergencyFund;

    int? efMonthsAfter;
    DateTime? efDateAfter;
    if (ef.remaining != null && hypotheticalMonthlySavings > 0) {
      efMonthsAfter = ef.remaining! <= 0 ? 0 : (ef.remaining! / hypotheticalMonthlySavings).ceil();
      efDateAfter = _addMonths(referenceNow, efMonthsAfter);
    }

    final incompleteGoals = result.goalProjections.where((g) => g.status != GoalProjectionStatus.completed).toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final goal = incompleteGoals.isEmpty ? null : incompleteGoals.first;

    int? goalMonthsAfter;
    DateTime? goalDateAfter;
    if (goal != null && hypotheticalMonthlySavings > 0) {
      goalMonthsAfter = goal.remainingAmount <= 0
          ? 0
          : (goal.remainingAmount / hypotheticalMonthlySavings).ceil();
      goalDateAfter = _addMonths(referenceNow, goalMonthsAfter);
    }

    return WhatIfProjection(
      hypotheticalMonthlySavings: hypotheticalMonthlySavings,
      emergencyFundMonthsBefore: ef.estimatedMonths,
      emergencyFundMonthsAfter: efMonthsAfter,
      emergencyFundDateBefore: ef.estimatedCompletionDate,
      emergencyFundDateAfter: efDateAfter,
      goalId: goal?.goalId,
      goalMonthsBefore: goal?.estimatedMonths,
      goalMonthsAfter: goalMonthsAfter,
      goalDateBefore: goal?.estimatedCompletionDate,
      goalDateAfter: goalDateAfter,
    );
  }

  // ---- Timeline ----

  /// Only ever includes milestones with a real, already-computed date —
  /// never fabricates one. Sorted chronologically after "Now".
  static List<PlanningMilestone> buildTimeline(FinancialPlanningResult result, DateTime now) {
    final milestones = <PlanningMilestone>[
      PlanningMilestone(type: PlanningMilestoneType.now, label: 'Now', date: now),
    ];

    final efDate = result.emergencyFund.estimatedCompletionDate;
    if (efDate != null && efDate.isAfter(now)) {
      milestones.add(
        PlanningMilestone(
          type: PlanningMilestoneType.emergencyFund,
          label: 'Emergency fund target',
          date: efDate,
        ),
      );
    }

    for (final goal in result.goalProjections) {
      final date = goal.estimatedCompletionDate;
      if (date != null && date.isAfter(now) && goal.status != GoalProjectionStatus.completed) {
        milestones.add(
          PlanningMilestone(
            type: PlanningMilestoneType.goal,
            label: goal.title,
            date: date,
          ),
        );
      }
    }

    for (final loan in result.debt.loans) {
      if (loan.payoffDate.isAfter(now)) {
        milestones.add(
          PlanningMilestone(
            type: PlanningMilestoneType.debtPayoff,
            label: '${loan.name} payoff',
            date: loan.payoffDate,
          ),
        );
      }
    }

    milestones.sort((a, b) => a.date.compareTo(b.date));
    return milestones;
  }

  // ---- Action plan ----

  static List<String> _buildActionPlan({
    required EmergencyFundResult emergencyFund,
    required CommitmentBreakdown commitments,
    required List<GoalProjection> goalProjections,
    required SavingsPlan savingsPlan,
  }) {
    final actions = <String>[];

    if (emergencyFund.remaining != null && emergencyFund.remaining! > 0) {
      actions.add(
        'Build ₹${_fmt(emergencyFund.remaining!)} more in emergency savings '
        'to reach your ${emergencyFund.targetMonths}-month target.',
      );
    }

    if (commitments.percentageOfIncome != null && commitments.percentageOfIncome! > 50) {
      actions.add(
        'Your fixed monthly commitments are ${commitments.percentageOfIncome!.round()}% '
        'of your income — consider reducing recurring costs.',
      );
    }

    final atRiskGoals = goalProjections.where((g) => g.status == GoalProjectionStatus.atRisk).toList()
      ..sort((a, b) => (b.contributionGap ?? 0).compareTo(a.contributionGap ?? 0));
    if (atRiskGoals.isNotEmpty) {
      final goal = atRiskGoals.first;
      final gap = goal.contributionGap;
      if (gap != null && gap > 0) {
        actions.add(
          'Increase your monthly contribution to "${goal.title}" by '
          '₹${_fmt(gap)} to reach it by ${_formatMonthYear(goal.targetDate)}.',
        );
      }
    }

    if (savingsPlan.monthlyGapToTarget != null && savingsPlan.monthlyGapToTarget! > 0) {
      actions.add(
        'Increase monthly savings by ₹${_fmt(savingsPlan.monthlyGapToTarget!)} '
        'to reach the ${recommendedSavingsRatePercent.round()}% savings benchmark.',
      );
    }

    if (actions.isEmpty) {
      return const ["You're on track. Keep maintaining your current savings rate."];
    }

    return actions.take(3).toList();
  }

  static String _fmt(double value) => value.round().toString();

  static String _formatMonthYear(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // ---- Component scores (0-100, documented banding, deterministic) ----

  static int _emergencyFundScore(EmergencyFundResult ef) {
    if (!ef.hasExpenseData || ef.target == null || ef.target == 0) {
      return 50; // Neutral: nothing to assess yet, not penalized.
    }
    final pct = (ef.current / ef.target! * 100).clamp(0, 100);
    return pct.round();
  }

  static int _savingsScore(SavingsPlan plan) {
    if (!plan.hasSufficientData || plan.currentSavingsRatePercent == null) {
      return 50;
    }
    // recommendedSavingsRatePercent (20%) or better scores 100; scales
    // linearly down to 0 at a 0% (or negative) savings rate.
    final rate = plan.currentSavingsRatePercent!;
    return (rate / recommendedSavingsRatePercent * 100).clamp(0, 100).round();
  }

  static int _debtBurdenScore(DebtOverview debt) {
    if (!debt.hasDebt) {
      return 100; // No debt is the best possible debt-readiness state.
    }
    if (!debt.hasIncomeData || debt.emiToIncomePercent == null) {
      return 50;
    }
    final burden = debt.emiToIncomePercent!;
    if (burden <= 20) return (100 - burden / 20 * 10).round(); // 100 -> 90
    if (burden <= 40) return (90 - (burden - 20) / 20 * 30).round(); // 90 -> 60
    if (burden <= 60) return (60 - (burden - 40) / 20 * 30).round(); // 60 -> 30
    return (30 - (burden - 60)).clamp(0, 30).round();
  }

  static int _goalsScore(List<GoalProjection> projections) {
    if (projections.isEmpty) {
      return 50;
    }
    final scored = projections.where((g) => g.status != GoalProjectionStatus.insufficientData).toList();
    if (scored.isEmpty) {
      return 50;
    }
    final onTrackOrDone = scored
        .where((g) => g.status == GoalProjectionStatus.onTrack || g.status == GoalProjectionStatus.completed)
        .length;
    return (onTrackOrDone / scored.length * 100).round();
  }

  static int _commitmentScore(CommitmentBreakdown commitments) {
    if (!commitments.hasIncomeData || commitments.percentageOfIncome == null) {
      return 50;
    }
    final pct = commitments.percentageOfIncome!;
    if (pct <= 30) return 100;
    if (pct <= 50) return (100 - (pct - 30) / 20 * 40).round(); // 100 -> 60
    if (pct <= 70) return (60 - (pct - 50) / 20 * 40).round(); // 60 -> 20
    return (20 - (pct - 70)).clamp(0, 20).round();
  }

  static int _cashFlowConsistencyScore(List<MonthlyTotal> monthlyTotals) {
    final withData = monthlyTotals.where((m) => m.income > 0 || m.expense > 0).toList();
    if (withData.isEmpty) {
      return 50;
    }
    final positiveMonths = withData.where((m) => m.income >= m.expense).length;
    return (positiveMonths / withData.length * 100).round();
  }

  static PlanningComponentStatus _statusFor(int score, {required bool hasData}) {
    if (!hasData) return PlanningComponentStatus.insufficientData;
    if (score >= 70) return PlanningComponentStatus.good;
    if (score >= 40) return PlanningComponentStatus.fair;
    return PlanningComponentStatus.needsAttention;
  }

  // ---- Date helpers ----

  static DateTime _addMonths(DateTime from, int months) {
    final totalMonths = from.month - 1 + months;
    final year = from.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = from.day > daysInTargetMonth ? daysInTargetMonth : from.day;
    return DateTime(year, month, day, from.hour, from.minute);
  }

  /// Whole months between [from] and [to] (>= 0), truncating partial months.
  static int _monthsBetween(DateTime from, DateTime to) {
    if (to.isBefore(from)) return 0;
    var months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months < 0 ? 0 : months;
  }
}
