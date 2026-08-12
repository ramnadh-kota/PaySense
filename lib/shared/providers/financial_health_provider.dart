import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../utils/financial_health_calculator.dart';
import 'bill_provider.dart';
import 'budget_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';
import 'wallet_provider.dart';

/// Derived, in-memory Financial Health snapshot — no persistence, no second
/// data store. Recomputes whenever any underlying provider changes.
final financialHealthProvider = Provider<FinancialHealthResult>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final profileMonthlyIncome = ref.watch(userProfileProvider).value?.monthlyIncome ?? 0.0;

  return FinancialHealthCalculator.calculate(
    transactions: transactions,
    budgets: budgets,
    goals: goals,
    loans: loans,
    bills: bills,
    wallets: wallets,
    profileMonthlyIncome: profileMonthlyIncome,
  );
});
