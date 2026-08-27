import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/providers/fun_group_expense_provider.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/utils/fun_funds_calculator.dart';

/// Derived, in-memory Fun Funds result — no separate persistence, mirroring
/// [safeToSpendProvider]'s pattern. Recomputes whenever any underlying
/// provider (Safe-to-Spend, Budgets, Goals, or logged group expenses)
/// changes.
final funFundsProvider = Provider<FunFundsResult>((ref) {
  final safeToSpend = ref.watch(safeToSpendProvider);
  final budgetTotals = ref.watch(budgetTotalsProvider);
  final goalProjections = ref.watch(financialPlanningProvider).goalProjections;
  final groupExpenses =
      ref.watch(funGroupExpensesProvider).value ?? const <FunGroupExpense>[];

  return FunFundsCalculator.calculate(
    safeToSpend: safeToSpend,
    budgetTotals: budgetTotals,
    goalProjections: goalProjections,
    groupExpenses: groupExpenses,
    now: DateTime.now(),
  );
});
