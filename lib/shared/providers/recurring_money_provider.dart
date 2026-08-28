import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/recurring_money_aggregator.dart';
import 'bill_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';

/// RECURRING PAYMENT INTELLIGENCE — reuses the EXISTING
/// `recurringTransactionsProvider`/`billsProvider`/`loansProvider`
/// (already the source of truth elsewhere in the app) and the pure
/// [RecurringMoneyAggregator] — no new repository, no duplicate
/// calculator.
final recurringMoneySummaryProvider = Provider<RecurringMoneySummary>((ref) {
  final recurringTransactions = ref.watch(recurringTransactionsProvider).value ?? const [];
  final bills = ref.watch(billsProvider).value ?? const [];
  final loans = ref.watch(loansProvider).value ?? const [];

  return RecurringMoneyAggregator.summarize(
    recurringTransactions: recurringTransactions,
    bills: bills,
    loans: loans,
    now: DateTime.now(),
  );
});
