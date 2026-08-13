import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/cash_flow_event.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../utils/cash_flow_calculator.dart';
import 'bill_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'transaction_provider.dart';

/// The month currently shown on the Cash Flow calendar — any date within
/// the target month (only year/month are used). Defaults to the current
/// month. Update via `.notifier.state`, clamped to
/// +/-[cashFlowMonthRangeInMonths] of today by the screen's navigation
/// controls.
final selectedCashFlowMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// The day currently selected within [selectedCashFlowMonthProvider].
/// Defaults to today.
final selectedCashFlowDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Derived, in-memory Cash Flow events for the selected month — no
/// persistence, no second transaction/payment system. Recomputes whenever
/// any underlying provider or the selected month changes.
final cashFlowEventsProvider = Provider<List<CashFlowEvent>>((ref) {
  final transactions =
      ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ??
      const <RecurringTransaction>[];
  final month = ref.watch(selectedCashFlowMonthProvider);

  return CashFlowCalculator.eventsForMonth(
    transactions: transactions,
    bills: bills,
    loans: loans,
    recurringTransactions: recurringTransactions,
    month: month,
    now: DateTime.now(),
  );
});

/// Recorded-vs-upcoming income/expense totals for the selected month.
final cashFlowMonthSummaryProvider = Provider<CashFlowMonthSummary>((ref) {
  final events = ref.watch(cashFlowEventsProvider);
  return CashFlowCalculator.summarizeMonth(events);
});

/// The next few upcoming/overdue obligations, independent of which month is
/// currently being viewed — powers the "Upcoming" section and the compact
/// Dashboard card.
final cashFlowUpcomingEventsProvider = Provider<List<CashFlowEvent>>((ref) {
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ??
      const <RecurringTransaction>[];

  return CashFlowCalculator.upcomingEvents(
    bills: bills,
    loans: loans,
    recurringTransactions: recurringTransactions,
    now: DateTime.now(),
  );
});

/// Fixed "next 30 days" incoming/outgoing totals — powers the compact
/// Dashboard card, independent of [selectedCashFlowMonthProvider].
final cashFlowNext30DaysSummaryProvider = Provider<CashFlowMonthSummary>((ref) {
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ??
      const <RecurringTransaction>[];

  return CashFlowCalculator.summarizeUpcomingWindow(
    bills: bills,
    loans: loans,
    recurringTransactions: recurringTransactions,
    now: DateTime.now(),
  );
});
