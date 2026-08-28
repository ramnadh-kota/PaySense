import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/recurring_transaction.dart';
import '../utils/financial_action_engine.dart';
import '../utils/financial_health_calculator.dart';
import '../utils/fun_funds_calculator.dart';
import '../utils/reports_calculator.dart';
import '../utils/safe_to_spend_calculator.dart';
import 'budget_provider.dart';
import 'financial_action_provider.dart';
import 'financial_health_provider.dart';
import 'fun_funds_provider.dart';
import 'goal_provider.dart';
import 'recurring_transaction_provider.dart';
import 'reports_provider.dart';
import 'safe_to_spend_provider.dart';
import 'user_profile_provider.dart';

/// Everything a Financial Report (on-screen or PDF) needs for the selected
/// period — a pure composition of results every section already computes
/// elsewhere in the app (Reports, Budgets, Goals, Recurring, Financial
/// Health, Safe-to-Spend, Fun Funds, Financial Actions). No figure here is
/// recalculated; this only gathers existing, already-tested calculator
/// outputs into one object so the PDF generator and the Reports screen can
/// share a single source of truth.
///
/// Deliberately does NOT include a "Pain-of-Paying" section — no such
/// engine exists in this codebase, and this bundle never fabricates a
/// section it can't back with a real calculator.
@immutable
class FinancialReportBundle {
  const FinancialReportBundle({
    required this.userName,
    required this.currencyCode,
    required this.generatedAt,
    required this.reports,
    required this.budgetTotals,
    required this.goals,
    required this.upcomingRecurring,
    required this.financialHealth,
    required this.safeToSpend,
    required this.funFunds,
    required this.actionPlan,
  });

  final String userName;
  final String currencyCode;
  final DateTime generatedAt;

  final ReportsResult reports;
  final BudgetTotals budgetTotals;
  final List<Goal> goals;

  /// Active, non-expired recurring items due within the existing
  /// [upcomingPaymentsProvider] window — never a separate recomputation.
  final List<RecurringTransaction> upcomingRecurring;

  final FinancialHealthResult financialHealth;
  final SafeToSpendResult safeToSpend;
  final FunFundsResult funFunds;

  /// Top-priority, deterministic recommendations — the same
  /// [FinancialActionPlan] the Dashboard shows, reused rather than
  /// re-derived.
  final FinancialActionPlan actionPlan;
}

final financialReportBundleProvider = Provider<FinancialReportBundle>((ref) {
  final profile = ref.watch(userProfileProvider).value;

  return FinancialReportBundle(
    userName: profile?.fullName.isNotEmpty == true ? profile!.fullName : '',
    currencyCode: profile?.currency.isNotEmpty == true
        ? profile!.currency
        : 'INR',
    generatedAt: DateTime.now(),
    reports: ref.watch(reportsResultProvider),
    budgetTotals: ref.watch(budgetTotalsProvider),
    goals: ref.watch(goalsProvider).value ?? const <Goal>[],
    upcomingRecurring: ref.watch(upcomingPaymentsProvider),
    financialHealth: ref.watch(financialHealthProvider),
    safeToSpend: ref.watch(safeToSpendProvider),
    funFunds: ref.watch(funFundsProvider),
    actionPlan: ref.watch(financialActionPlanProvider),
  );
});
