import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/wallet.dart';
import '../utils/safe_to_spend_calculator.dart';
import 'bill_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'wallet_provider.dart';

/// Derived, in-memory Safe-to-Spend result — no persistence, no second
/// wallet/balance system. Recomputes whenever any underlying provider
/// changes, mirroring [monthlyReviewProvider]'s pattern.
final safeToSpendProvider = Provider<SafeToSpendResult>((ref) {
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final bills = ref.watch(billsProvider).value ?? const <Bill>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ??
      const <RecurringTransaction>[];

  return SafeToSpendCalculator.calculate(
    wallets: wallets,
    bills: bills,
    loans: loans,
    recurringTransactions: recurringTransactions,
    now: DateTime.now(),
  );
});
