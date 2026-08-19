import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';
import '../utils/reports_calculator.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

final selectedReportPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.thisMonth,
);

/// A single derived, synchronous calculation reused by every section of
/// [ReportsScreen] — never re-filters the full transaction list per widget.
/// Recomputes only when the selected period, transactions, or wallets
/// actually change (standard Riverpod `Provider` dependency tracking).
/// Purely read-only: never creates/modifies a transaction, wallet, budget,
/// goal, or recurring transaction.
final reportsResultProvider = Provider<ReportsResult>((ref) {
  final transactions =
      ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final period = ref.watch(selectedReportPeriodProvider);

  return ReportsCalculator.calculate(
    transactions: transactions,
    wallets: wallets,
    period: period,
    now: DateTime.now(),
  );
});
