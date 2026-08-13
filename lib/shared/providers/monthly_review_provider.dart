import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../utils/monthly_review_calculator.dart';
import 'bill_provider.dart';
import 'budget_provider.dart';
import 'financial_health_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'transaction_provider.dart';

/// The month currently selected in the Monthly Review screen — any date
/// within the target month (only year/month are used). Defaults to the
/// current month.
final monthlyReviewSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Last 6 months (current first), matching the same trailing window already
/// used by [analyticsSummaryProvider] — a simple, consistent range rather
/// than scanning for the earliest transaction.
final availableReviewMonthsProvider = Provider<List<DateTime>>((ref) {
  final now = DateTime.now();
  return List.generate(6, (i) => DateTime(now.year, now.month - i, 1));
});

/// Derived, in-memory Monthly Review for the currently selected month — no
/// persistence, no duplicated calculations. Recomputes whenever any
/// underlying provider or the selected month changes.
final monthlyReviewProvider = Provider<MonthlyReviewResult>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final loanSummary = ref.watch(loanSummaryProvider);
  final financialHealth = ref.watch(financialHealthProvider);
  final targetMonth = ref.watch(monthlyReviewSelectedMonthProvider);

  return MonthlyReviewCalculator.calculate(
    transactions: transactions,
    budgets: budgets,
    goals: goals,
    bills: bills,
    loanSummary: loanSummary,
    financialHealth: financialHealth,
    targetMonth: targetMonth,
  );
});
