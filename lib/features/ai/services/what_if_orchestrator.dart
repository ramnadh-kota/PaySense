import 'package:paysense/features/ai/models/what_if_result.dart';
import 'package:paysense/features/ai/services/what_if_intent_parser.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/subscription_summary.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart' show buildAnalyticsSummary;
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/reports_calculator.dart';
import 'package:paysense/shared/utils/subscription_calculator.dart';
import 'package:paysense/shared/utils/what_if_calculator.dart';

/// Stage B of the what-if pipeline (PHASE 5/6/7/8/9) — takes a
/// [WhatIfIntent] (pure text parsing, no data access — see
/// [WhatIfIntentParser]) and resolves its raw candidate text against real
/// financial data, then hands off to the appropriate existing calculator.
/// This is the ONLY layer allowed to turn a text candidate into a real
/// Loan/Category/Subscription/Goal match — mirrors the app's existing
/// "pure calculator vs data-access layer" separation (e.g.
/// `FinancialPlanningCalculator` vs `financial_planning_provider.dart`).
///
/// Every branch here only ever calls an existing calculator for the actual
/// arithmetic (`WhatIfCalculator`/`FinancialPlanningCalculator`) — this
/// class does resolution and wiring only, never its own financial math.
class WhatIfOrchestrator {
  WhatIfOrchestrator._();

  static final WhatIfOrchestrator instance = WhatIfOrchestrator._();

  Future<WhatIfOutcome> resolve(WhatIfIntent intent, {DateTime? now}) async {
    if (intent.confidence == WhatIfConfidence.medium) {
      return WhatIfOutcome.clarification(
        intent.clarificationPrompt ?? 'Could you share a bit more detail?',
      );
    }
    if (!intent.isActionable) {
      return WhatIfOutcome.none();
    }

    final referenceNow = now ?? DateTime.now();
    final wallets = await WalletRepository.instance.getAll();
    final transactions = await TransactionRepository.instance.getAll();
    final goals = await GoalRepository.instance.getAll();
    final loans = await LoanRepository.instance.getAll();
    final bills = await BillRepository.instance.getAll();
    final recurringTransactions = await RecurringTransactionRepository.instance.getAll();

    final settings = AppSettingsRepository.instance;
    final planning = FinancialPlanningCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      goals: goals,
      loans: loans,
      bills: bills,
      recurringTransactions: recurringTransactions,
      analytics: buildAnalyticsSummary(transactions, referenceNow),
      emergencyFundEligibleWalletIds: settings.emergencyFundEligibleWalletIds(),
      emergencyFundTargetMonths: settings.emergencyFundTargetMonths(),
      now: referenceNow,
    );

    switch (intent.type) {
      case WhatIfIntentType.increaseSavings:
        return _resolveIncreaseSavings(intent, planning, referenceNow);
      case WhatIfIntentType.decreaseExpenses:
        return _resolveDecreaseExpenses(intent, planning);
      case WhatIfIntentType.reduceCategorySpending:
        return _resolveReduceCategorySpending(intent, planning, transactions, wallets, referenceNow);
      case WhatIfIntentType.extraLoanPayment:
        return _resolveExtraLoanPayment(intent, loans);
      case WhatIfIntentType.stopSubscription:
        return _resolveStopSubscription(intent, recurringTransactions, planning, referenceNow);
      case WhatIfIntentType.reachGoal:
        return _resolveReachGoal(intent, planning, referenceNow);
      case WhatIfIntentType.reachEmergencyFund:
        return _resolveReachEmergencyFund(intent, planning, referenceNow);
      case WhatIfIntentType.none:
        return WhatIfOutcome.none();
    }
  }

  // ---------------------------------------------------------------------
  // increaseSavings
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveIncreaseSavings(
    WhatIfIntent intent,
    FinancialPlanningResult planning,
    DateTime now,
  ) {
    final amount = intent.amount;
    if (amount == null) {
      return WhatIfOutcome.clarification('How much would you like to save each month?');
    }

    final currentSavings = planning.overview.monthlySavings;
    final hypothetical = currentSavings + amount;
    final projection = FinancialPlanningCalculator.whatIf(
      result: planning,
      hypotheticalMonthlySavings: hypothetical,
      now: now,
    );

    final hasGoal = projection.goalId != null;
    final result = WhatIfResult(
      type: WhatIfIntentType.increaseSavings,
      currentValue: currentSavings,
      projectedValue: hypothetical,
      difference: amount,
      monthlyChange: amount,
      monthsBefore: hasGoal ? projection.goalMonthsBefore : projection.emergencyFundMonthsBefore,
      monthsAfter: hasGoal ? projection.goalMonthsAfter : projection.emergencyFundMonthsAfter,
      completionDateBefore: hasGoal ? projection.goalDateBefore : projection.emergencyFundDateBefore,
      completionDateAfter: hasGoal ? projection.goalDateAfter : projection.emergencyFundDateAfter,
      entityName: hasGoal
          ? planning.goalProjections
              .where((g) => g.goalId == projection.goalId)
              .map((g) => g.title)
              .firstOrNull
          : null,
      descriptionKey: WhatIfIntentType.increaseSavings.name,
    );
    return WhatIfOutcome.calculated(result);
  }

  // ---------------------------------------------------------------------
  // decreaseExpenses
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveDecreaseExpenses(WhatIfIntent intent, FinancialPlanningResult planning) {
    final overview = planning.overview;
    var deltaAmount = intent.amount;
    if (deltaAmount == null && intent.percentage != null) {
      // The parser already signs the percentage (negative = decrease).
      deltaAmount = overview.monthlyExpenses * intent.percentage! / 100;
    }
    if (deltaAmount == null) {
      return WhatIfOutcome.clarification('By how much (₹ or %) would your expenses change?');
    }

    final projection = WhatIfCalculator.whatIfExpenseChange(
      overview: overview,
      deltaAmount: deltaAmount,
    );

    final result = WhatIfResult(
      type: WhatIfIntentType.decreaseExpenses,
      currentValue: overview.monthlyExpenses,
      projectedValue: (overview.monthlyExpenses + deltaAmount).clamp(0.0, double.infinity),
      difference: deltaAmount,
      monthlyChange: projection.monthlySavingsAfter - projection.monthlySavingsBefore,
      descriptionKey: WhatIfIntentType.decreaseExpenses.name,
    );
    return WhatIfOutcome.calculated(result);
  }

  // ---------------------------------------------------------------------
  // reduceCategorySpending (PHASE 5)
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveReduceCategorySpending(
    WhatIfIntent intent,
    FinancialPlanningResult planning,
    List<Transaction> transactions,
    List<Wallet> wallets,
    DateTime now,
  ) {
    final candidate = intent.categoryText;
    if (candidate == null) {
      return WhatIfOutcome.clarification('Which spending category would you like to reduce?');
    }

    final reports = ReportsCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      period: ReportPeriod.thisMonth,
      now: now,
    );

    final lower = candidate.toLowerCase();
    final matches = reports.categoryBreakdown
        .where((c) =>
            c.categoryId.toLowerCase().contains(lower) || lower.contains(c.categoryId.toLowerCase()))
        .toList();

    if (matches.isEmpty) {
      return WhatIfOutcome.notFound("I don't have enough spending data for that category yet.");
    }
    if (matches.length > 1) {
      final names = matches.map((c) => c.categoryId).join(', ');
      return WhatIfOutcome.clarification('Which category did you mean: $names?');
    }

    final match = matches.first;
    if (match.amount <= 0) {
      return WhatIfOutcome.notFound("I don't have enough spending data for that category yet.");
    }

    var percentage = intent.percentage;
    if (percentage == null && intent.amount != null) {
      percentage = (intent.amount! / match.amount * 100).clamp(0.0, 100.0);
    }
    if (percentage == null) {
      return WhatIfOutcome.clarification(
        'By how much (₹ or %) would you like to reduce ${match.categoryId} spending?',
      );
    }

    final projection = WhatIfCalculator.whatIfReduceCategorySpending(
      overview: planning.overview,
      categoryName: match.categoryId,
      currentCategoryAmount: match.amount,
      percentReduction: percentage,
    );

    final result = WhatIfResult(
      type: WhatIfIntentType.reduceCategorySpending,
      currentValue: planning.overview.monthlySavings,
      projectedValue: projection.monthlySavingsAfter,
      difference: projection.monthlyAmountSaved,
      monthlyChange: projection.monthlyAmountSaved,
      entityName: match.categoryId,
      descriptionKey: WhatIfIntentType.reduceCategorySpending.name,
    );
    return WhatIfOutcome.calculated(result);
  }

  // ---------------------------------------------------------------------
  // extraLoanPayment (PHASE 6)
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveExtraLoanPayment(WhatIfIntent intent, List<Loan> loans) {
    final amount = intent.amount;
    if (amount == null) {
      return WhatIfOutcome.clarification('How much extra would you like to pay toward the loan?');
    }

    final activeLoans = loans.where((l) => l.isActive).toList();
    if (activeLoans.isEmpty) {
      return WhatIfOutcome.notFound("You don't have any active loans to simulate this against.");
    }

    Loan loan;
    if (intent.loanText != null) {
      final candidate = intent.loanText!.toLowerCase();
      final matches = activeLoans
          .where((l) =>
              l.loanName.toLowerCase().contains(candidate) ||
              l.loanType.toLowerCase().contains(candidate))
          .toList();
      if (matches.isEmpty) {
        return WhatIfOutcome.notFound('I couldn\'t find a loan matching "${intent.loanText}".');
      }
      if (matches.length > 1) {
        final names = matches.map((l) => l.loanName).join(', ');
        return WhatIfOutcome.clarification('Which loan do you mean: $names?');
      }
      loan = matches.first;
    } else if (activeLoans.length == 1) {
      loan = activeLoans.first;
    } else {
      final names = activeLoans.map((l) => l.loanName).join(', ');
      return WhatIfOutcome.clarification('Which loan do you mean: $names?');
    }

    final remainingMonthsBefore =
        loan.emiAmount > 0 ? (loan.outstandingAmount / loan.emiAmount).ceil() : null;
    final projection = WhatIfCalculator.whatIfExtraLoanPayment(
      outstandingAmount: loan.outstandingAmount,
      emiAmount: loan.emiAmount,
      remainingMonthsBefore: remainingMonthsBefore,
      extraAmount: amount,
    );

    final result = WhatIfResult(
      type: WhatIfIntentType.extraLoanPayment,
      currentValue: projection.outstandingBefore,
      projectedValue: projection.outstandingAfter,
      difference: projection.outstandingAfter - projection.outstandingBefore,
      monthlyChange: 0,
      monthsBefore: projection.remainingMonthsBefore,
      monthsAfter: projection.remainingMonthsAfter,
      entityName: loan.loanName,
      descriptionKey: WhatIfIntentType.extraLoanPayment.name,
    );
    return WhatIfOutcome.calculated(result);
  }

  // ---------------------------------------------------------------------
  // stopSubscription (PHASE 7)
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveStopSubscription(
    WhatIfIntent intent,
    List<RecurringTransaction> recurringTransactions,
    FinancialPlanningResult planning,
    DateTime now,
  ) {
    final candidate = intent.subscriptionText;
    if (candidate == null) {
      return WhatIfOutcome.clarification('Which subscription would you like to simulate stopping?');
    }

    final subscriptions = SubscriptionCalculator.eligibleSubscriptions(
      recurringTransactions: recurringTransactions,
      now: now,
    ).where((s) => s.status == SubscriptionStatus.active).toList();

    if (subscriptions.isEmpty) {
      return WhatIfOutcome.notFound("I don't see any active subscriptions to simulate stopping.");
    }

    final lower = candidate.toLowerCase();
    final matches = subscriptions
        .where((s) => s.name.toLowerCase().contains(lower) || lower.contains(s.name.toLowerCase()))
        .toList();

    if (matches.isEmpty) {
      return WhatIfOutcome.notFound('I couldn\'t find a subscription named "$candidate".');
    }
    if (matches.length > 1) {
      final names = matches.map((s) => s.name).join(', ');
      return WhatIfOutcome.clarification('Which subscription do you mean: $names?');
    }

    final subscription = matches.first;
    final incompleteGoals = planning.goalProjections
        .where((g) => g.status != GoalProjectionStatus.completed)
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final efRemaining = planning.emergencyFund.remaining;
    final currentMonthlyContribution = planning.overview.monthlySavings.clamp(0.0, double.infinity);

    double? remainingTarget;
    String? targetLabel;
    if (incompleteGoals.isNotEmpty) {
      remainingTarget = incompleteGoals.first.remainingAmount;
      targetLabel = incompleteGoals.first.title;
    } else if (efRemaining != null && efRemaining > 0) {
      remainingTarget = efRemaining;
      targetLabel = 'your Emergency Fund';
    }

    // No goal/emergency-fund target to project against — report the freed
    // monthly amount only, without a misleading "0 months" timeline.
    if (remainingTarget == null || remainingTarget <= 0) {
      final result = WhatIfResult(
        type: WhatIfIntentType.stopSubscription,
        currentValue: 0,
        projectedValue: subscription.monthlyEquivalent,
        difference: subscription.monthlyEquivalent,
        monthlyChange: subscription.monthlyEquivalent,
        entityName: subscription.name,
        descriptionKey: WhatIfIntentType.stopSubscription.name,
      );
      return WhatIfOutcome.calculated(result);
    }

    final projection = WhatIfCalculator.whatIfStopSubscription(
      subscription: subscription,
      currentMonthlyContribution: currentMonthlyContribution,
      remainingTarget: remainingTarget,
      now: now,
    );

    final result = WhatIfResult(
      type: WhatIfIntentType.stopSubscription,
      currentValue: currentMonthlyContribution,
      projectedValue: currentMonthlyContribution + projection.monthlySavingsFreed,
      difference: projection.monthlySavingsFreed,
      monthlyChange: projection.monthlySavingsFreed,
      monthsBefore: projection.monthsBefore,
      monthsAfter: projection.monthsAfter,
      completionDateBefore: projection.dateBefore,
      completionDateAfter: projection.dateAfter,
      entityName: '${subscription.name} → $targetLabel',
      descriptionKey: WhatIfIntentType.stopSubscription.name,
    );
    return WhatIfOutcome.calculated(result);
  }

  // ---------------------------------------------------------------------
  // reachGoal (PHASE 8)
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveReachGoal(WhatIfIntent intent, FinancialPlanningResult planning, DateTime now) {
    // See WhatIfIntentParser._matchReachGoal — the goal-name candidate is
    // carried in `categoryText`, not a dedicated field.
    final goalNameCandidate = intent.categoryText;
    final currentMonthlySavings = planning.overview.monthlySavings;

    if (goalNameCandidate != null) {
      final lower = goalNameCandidate.toLowerCase();
      final matches = planning.goalProjections
          .where((g) =>
              g.title.toLowerCase().contains(lower) || lower.contains(g.title.toLowerCase()))
          .toList();

      if (matches.isEmpty) {
        return WhatIfOutcome.notFound('I don\'t have a goal named "$goalNameCandidate" yet.');
      }
      if (matches.length > 1) {
        final names = matches.map((g) => g.title).join(', ');
        return WhatIfOutcome.clarification('Which goal do you mean: $names?');
      }
      final goal = matches.first;

      if (intent.amount != null) {
        final projection = WhatIfCalculator.whatIfGoalContribution(
          goal: goal,
          extraMonthlyAmount: intent.amount!,
          now: now,
        );
        final result = WhatIfResult(
          type: WhatIfIntentType.reachGoal,
          currentValue: goal.remainingAmount,
          projectedValue: goal.remainingAmount,
          difference: 0,
          monthlyChange: intent.amount,
          monthsBefore: projection.monthsBefore,
          monthsAfter: projection.monthsAfter,
          completionDateBefore: projection.dateBefore,
          completionDateAfter: projection.dateAfter,
          entityName: goal.title,
          descriptionKey: WhatIfIntentType.reachGoal.name,
        );
        return WhatIfOutcome.calculated(result);
      }

      // Named goal, no hypothetical rate — report the current-pace projection.
      final result = WhatIfResult(
        type: WhatIfIntentType.reachGoal,
        currentValue: goal.remainingAmount,
        projectedValue: goal.remainingAmount,
        difference: 0,
        monthsBefore: goal.estimatedMonths,
        monthsAfter: goal.estimatedMonths,
        completionDateBefore: goal.estimatedCompletionDate,
        completionDateAfter: goal.estimatedCompletionDate,
        entityName: goal.title,
        descriptionKey: WhatIfIntentType.reachGoal.name,
      );
      return WhatIfOutcome.calculated(result);
    }

    // No named goal — a pure hypothetical against a bare target amount.
    final target = intent.targetAmount;
    if (target == null) {
      return WhatIfOutcome.none();
    }
    final months = WhatIfCalculator.monthsToReachAmount(
      remaining: target,
      monthlyRate: currentMonthlySavings,
    );
    final result = WhatIfResult(
      type: WhatIfIntentType.reachGoal,
      currentValue: 0,
      projectedValue: target,
      difference: target,
      monthsAfter: months,
      completionDateAfter: months == null ? null : WhatIfCalculator.addMonths(now, months),
      descriptionKey: WhatIfIntentType.reachGoal.name,
    );
    return WhatIfOutcome.calculated(result);
  }

  // ---------------------------------------------------------------------
  // reachEmergencyFund (PHASE 9)
  // ---------------------------------------------------------------------

  WhatIfOutcome _resolveReachEmergencyFund(
    WhatIfIntent intent,
    FinancialPlanningResult planning,
    DateTime now,
  ) {
    final ef = planning.emergencyFund;
    if (!ef.isSourceConfigured) {
      return WhatIfOutcome.notFound(
        'Set up your Emergency Fund in Financial Planning first — no eligible wallets are configured yet.',
      );
    }

    if (intent.amount != null) {
      final currentSavings = planning.overview.monthlySavings;
      final hypothetical = currentSavings + intent.amount!;
      final projection = FinancialPlanningCalculator.whatIf(
        result: planning,
        hypotheticalMonthlySavings: hypothetical,
        now: now,
      );
      final result = WhatIfResult(
        type: WhatIfIntentType.reachEmergencyFund,
        currentValue: ef.current,
        projectedValue: ef.target ?? ef.current,
        difference: (ef.target ?? ef.current) - ef.current,
        monthlyChange: intent.amount,
        monthsBefore: projection.emergencyFundMonthsBefore,
        monthsAfter: projection.emergencyFundMonthsAfter,
        completionDateBefore: projection.emergencyFundDateBefore,
        completionDateAfter: projection.emergencyFundDateAfter,
        descriptionKey: WhatIfIntentType.reachEmergencyFund.name,
      );
      return WhatIfOutcome.calculated(result);
    }

    // No hypothetical amount — report the current trajectory only.
    final result = WhatIfResult(
      type: WhatIfIntentType.reachEmergencyFund,
      currentValue: ef.current,
      projectedValue: ef.target ?? ef.current,
      difference: (ef.target ?? ef.current) - ef.current,
      monthsBefore: ef.estimatedMonths,
      monthsAfter: ef.estimatedMonths,
      completionDateBefore: ef.estimatedCompletionDate,
      completionDateAfter: ef.estimatedCompletionDate,
      descriptionKey: WhatIfIntentType.reachEmergencyFund.name,
    );
    return WhatIfOutcome.calculated(result);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
