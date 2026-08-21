import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../repositories/app_settings_repository.dart';
import '../utils/financial_planning_calculator.dart';
import 'analytics_provider.dart';
import 'bill_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

final appSettingsRepositoryForPlanningProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository.instance;
});

/// The user's explicit emergency-fund-eligible wallet selection — null means
/// "never configured", matching [AppSettingsRepository.emergencyFundEligibleWalletIds].
final emergencyFundEligibleWalletIdsProvider =
    AsyncNotifierProvider<EmergencyFundWalletSelectionNotifier, List<String>?>(
  EmergencyFundWalletSelectionNotifier.new,
);

class EmergencyFundWalletSelectionNotifier extends AsyncNotifier<List<String>?> {
  @override
  Future<List<String>?> build() async {
    return ref.watch(appSettingsRepositoryForPlanningProvider).emergencyFundEligibleWalletIds();
  }

  Future<void> setEligibleWallets(List<String> walletIds) async {
    final repo = ref.read(appSettingsRepositoryForPlanningProvider);
    await repo.setEmergencyFundEligibleWalletIds(walletIds);
    state = AsyncData(walletIds);
  }
}

final emergencyFundTargetMonthsProvider =
    AsyncNotifierProvider<EmergencyFundTargetMonthsNotifier, int>(
  EmergencyFundTargetMonthsNotifier.new,
);

class EmergencyFundTargetMonthsNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    return ref.watch(appSettingsRepositoryForPlanningProvider).emergencyFundTargetMonths();
  }

  Future<void> setTargetMonths(int months) async {
    final repo = ref.read(appSettingsRepositoryForPlanningProvider);
    await repo.setEmergencyFundTargetMonths(months);
    state = AsyncData(months);
  }
}

/// The whole Financial Planning result — a plain [Provider] (not a
/// Notifier), since it holds no state of its own; it just recomputes
/// whenever any of its upstream data providers change. Read-only against
/// every underlying repository, exactly like ReportsCalculator/
/// BudgetCalculator/FinancialHealthCalculator's own provider wiring.
final financialPlanningProvider = Provider<FinancialPlanningResult>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ?? const <RecurringTransaction>[];
  final analytics = ref.watch(analyticsSummaryProvider);
  final eligibleWalletIds = ref.watch(emergencyFundEligibleWalletIdsProvider).value;
  final targetMonths = ref.watch(emergencyFundTargetMonthsProvider).value ??
      defaultEmergencyFundTargetMonths;

  return FinancialPlanningCalculator.calculate(
    transactions: transactions,
    wallets: wallets,
    goals: goals,
    loans: loans,
    bills: bills,
    recurringTransactions: recurringTransactions,
    analytics: analytics,
    emergencyFundEligibleWalletIds: eligibleWalletIds,
    emergencyFundTargetMonths: targetMonths,
  );
});
