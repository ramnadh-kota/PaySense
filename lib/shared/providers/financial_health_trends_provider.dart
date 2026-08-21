import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../utils/financial_health_trends_calculator.dart';
import '../utils/financial_planning_calculator.dart' show defaultEmergencyFundTargetMonths;
import 'bill_provider.dart';
import 'budget_provider.dart';
import 'financial_planning_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';
import 'wallet_provider.dart';

/// The user's selected time range on the Financial Health Trends screen
/// (PHASE 15's [1M][3M][6M][12M] toggle) — defaults to 3 months, a
/// reasonable middle ground between "too little history" and "too slow to
/// load".
final financialHealthTrendsPeriodProvider = StateProvider<TrendPeriod>((ref) {
  return TrendPeriod.threeMonths;
});

/// Derived, in-memory trend snapshot — no persistence, no second data
/// store. Recomputes whenever any underlying provider (or the selected
/// period) changes. Reuses the SAME emergency-fund settings providers
/// [emergencyFundEligibleWalletIdsProvider]/[emergencyFundTargetMonthsProvider]
/// Financial Planning already established, rather than a second
/// settings read.
final financialHealthTrendsProvider = Provider<FinancialHealthTrendResult>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final profileMonthlyIncome = ref.watch(userProfileProvider).value?.monthlyIncome ?? 0.0;
  final period = ref.watch(financialHealthTrendsPeriodProvider);
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
    period: period,
    emergencyFundEligibleWalletIds: eligibleWalletIds,
    emergencyFundTargetMonths: targetMonths,
  );
});
