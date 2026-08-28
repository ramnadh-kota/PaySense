import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/financial_report.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../utils/financial_report_engine.dart';
import 'bill_provider.dart';
import 'budget_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';
import 'wallet_provider.dart';

/// MILESTONE 3/7 — the user's selected report period. Defaults to
/// monthly (the richer of the two, matching the milestone's own default
/// framing "Weekly / Monthly").
final selectedFinancialReportPeriodProvider = StateProvider<FinancialReportPeriod>(
  (ref) => FinancialReportPeriod.monthly,
);

/// A single derived, on-demand computation — this provider is watched
/// ONLY by the Financial Report screen (never by the Dashboard), so it
/// never runs on every Dashboard rebuild. Riverpod's own `Provider`
/// caching means it only recomputes when the selected period or one of
/// the underlying repositories actually changes, not on every widget
/// rebuild.
final financialReportProvider = Provider<FinancialReport>((ref) {
  final period = ref.watch(selectedFinancialReportPeriodProvider);
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final recurringTransactions = ref.watch(recurringTransactionsProvider).value ?? const <RecurringTransaction>[];
  final profileMonthlyIncome = ref.watch(userProfileProvider).value?.monthlyIncome ?? 0.0;

  return FinancialReportEngine.generate(
    period: period,
    transactions: transactions,
    wallets: wallets,
    budgets: budgets,
    goals: goals,
    loans: loans,
    bills: bills,
    recurringTransactions: recurringTransactions,
    now: DateTime.now(),
    profileMonthlyIncome: profileMonthlyIncome,
  );
});
