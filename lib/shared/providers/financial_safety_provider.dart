import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/financial_safety_alert.dart';
import '../repositories/financial_safety_dismissed_repository.dart';
import '../utils/financial_safety_engine.dart';
import 'bill_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

/// FINANCIAL SAFETY ENGINE — computes deterministic alerts from the SAME
/// repositories the rest of the app already watches (never a duplicate
/// data source), then filters out anything the user has dismissed,
/// resolved, or actively snoozed (FINANCIAL SAFETY 2.0 — see
/// [FinancialSafetyAlertState.isSnoozeActive]; an EXPIRED snooze lets the
/// alert reappear automatically, with no separate "reopen" step needed).
final financialSafetyAlertsProvider =
    AsyncNotifierProvider<FinancialSafetyAlertsNotifier, List<FinancialSafetyAlert>>(
  FinancialSafetyAlertsNotifier.new,
);

/// FINANCIAL SAFETY 2.0 — default snooze duration for [FinancialSafetyAlertsNotifier.snooze].
const Duration financialSafetyDefaultSnoozeDuration = Duration(days: 3);

class FinancialSafetyAlertsNotifier extends AsyncNotifier<List<FinancialSafetyAlert>> {
  @override
  Future<List<FinancialSafetyAlert>> build() async {
    final transactions = ref.watch(transactionsProvider).value ?? const [];
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final bills = ref.watch(billsProvider).value ?? const [];
    final loans = ref.watch(loansProvider).value ?? const [];
    final recurringTransactions = ref.watch(recurringTransactionsProvider).value ?? const [];
    final now = DateTime.now();

    final alerts = FinancialSafetyEngine.generate(
      transactions: transactions,
      wallets: wallets,
      bills: bills,
      loans: loans,
      recurringTransactions: recurringTransactions,
      now: now,
    );

    final states = await FinancialSafetyDismissedRepository.instance.getStates();
    return alerts.where((a) {
      final state = states[a.id];
      if (state == null) return true;
      switch (state.status) {
        case FinancialSafetyAlertLifecycle.active:
          return true;
        case FinancialSafetyAlertLifecycle.dismissed:
        case FinancialSafetyAlertLifecycle.resolved:
          return false;
        case FinancialSafetyAlertLifecycle.snoozed:
          return !state.isSnoozeActive(now);
      }
    }).toList();
  }

  Future<void> dismiss(String alertId) async {
    await FinancialSafetyDismissedRepository.instance.dismiss(alertId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> snooze(String alertId, {Duration duration = financialSafetyDefaultSnoozeDuration}) async {
    await FinancialSafetyDismissedRepository.instance.snooze(alertId, DateTime.now().add(duration));
    ref.invalidateSelf();
    await future;
  }

  Future<void> resolve(String alertId) async {
    await FinancialSafetyDismissedRepository.instance.resolve(alertId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> reopen(String alertId) async {
    await FinancialSafetyDismissedRepository.instance.reopen(alertId);
    ref.invalidateSelf();
    await future;
  }
}

/// FINANCIAL SAFETY 2.0 — the alert history view (dismissed/snoozed/
/// resolved), newest first.
final financialSafetyHistoryProvider = FutureProvider<List<FinancialSafetyAlertState>>((ref) async {
  return FinancialSafetyDismissedRepository.instance.getHistory();
});
