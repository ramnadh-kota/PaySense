import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../utils/financial_health_trends_calculator.dart';
import '../utils/financial_planning_calculator.dart' show defaultEmergencyFundTargetMonths;
import '../utils/financial_timeline_calculator.dart';
import '../utils/financial_momentum_calculator.dart';
import 'bill_provider.dart';
import 'budget_provider.dart';
import 'financial_planning_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'subscription_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';
import 'wallet_provider.dart';

/// The user's selected time range on the Financial Intelligence Timeline
/// screen — independent of [financialHealthTrendsPeriodProvider] (that
/// screen's own [1M][3M][6M][12M] toggle) since the two screens should be
/// free to show different windows at once. Defaults to 3 months, matching
/// the same "reasonable middle ground" default already established there.
final financialTimelinePeriodProvider = StateProvider<TimelinePeriod>((ref) {
  return TimelinePeriod.threeMonths;
});

/// FINANCIAL INTELLIGENCE TIMELINE 1.0 (PHASE 2/3) — derived, in-memory
/// only. Reuses the SAME already-computed [financialPlanningProvider] and
/// [eligibleSubscriptionsProvider] [financialActionPlanProvider] already
/// depends on; only `trends` is freshly computed here (with THIS screen's
/// own [financialTimelinePeriodProvider] selection) since
/// [financialHealthTrendsProvider] is hardwired to the OTHER screen's
/// period state.
final financialTimelineProvider = Provider<FinancialTimelineResult>((ref) {
  final period = ref.watch(financialTimelinePeriodProvider);
  final trends = _watchTrends(ref, period.underlyingTrendPeriod);
  final planning = ref.watch(financialPlanningProvider);
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ?? const <RecurringTransaction>[];
  final subscriptions = ref.watch(eligibleSubscriptionsProvider);

  return FinancialTimelineCalculator.calculate(
    trends: trends,
    planning: planning,
    budgets: budgets,
    goals: goals,
    loans: loans,
    transactions: transactions,
    recurringTransactions: recurringTransactions,
    subscriptions: subscriptions,
    period: period,
    now: DateTime.now(),
  );
});

/// PHASE 3 — a thin, explainable wrapper over the SAME [trends] this
/// screen already computes; never a second, divergent trend calculation.
final financialMomentumProvider = Provider<FinancialMomentum>((ref) {
  final period = ref.watch(financialTimelinePeriodProvider);
  final trends = _watchTrends(ref, period.underlyingTrendPeriod);
  return FinancialMomentumCalculator.calculate(trends);
});

FinancialHealthTrendResult _watchTrends(Ref ref, TrendPeriod trendPeriod) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final profileMonthlyIncome = ref.watch(userProfileProvider).value?.monthlyIncome ?? 0.0;
  final eligibleWalletIds = ref.watch(emergencyFundEligibleWalletIdsProvider).value;
  final targetMonths =
      ref.watch(emergencyFundTargetMonthsProvider).value ?? defaultEmergencyFundTargetMonths;

  return FinancialHealthTrendsCalculator.calculate(
    transactions: transactions,
    budgets: budgets,
    goals: goals,
    loans: loans,
    bills: bills,
    wallets: wallets,
    profileMonthlyIncome: profileMonthlyIncome,
    period: trendPeriod,
    emergencyFundEligibleWalletIds: eligibleWalletIds,
    emergencyFundTargetMonths: targetMonths,
  );
}
