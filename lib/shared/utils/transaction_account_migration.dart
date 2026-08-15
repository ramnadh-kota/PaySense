import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';
import 'wallet_account_resolver.dart';

/// Result of planning (not applying) a [TransactionAccountMigration.plan]
/// pass.
@immutable
class TransactionAccountMigrationResult {
  const TransactionAccountMigrationResult({
    required this.updatedTransactions,
    required this.migratedCount,
    required this.unresolvedCount,
    required this.alreadyCorrectCount,
  });

  /// Only the transactions whose `accountId` actually changed — every other
  /// field (id, amount, createdAt, categoryId, note, transactionType) is
  /// copied through unchanged. Callers should persist only these, leaving
  /// every other record in the box untouched.
  final List<Transaction> updatedTransactions;

  /// How many transactions were migrated (had a legacy label rewritten to a
  /// resolved wallet id).
  final int migratedCount;

  /// How many transactions have an `accountId` that couldn't be resolved to
  /// exactly one wallet (either no match, or an ambiguous match across
  /// multiple wallets) — left exactly as recorded, never guessed.
  final int unresolvedCount;

  /// How many transactions already had a valid wallet id and needed no
  /// change.
  final int alreadyCorrectCount;

  bool get hasChanges => updatedTransactions.isNotEmpty;
}

/// Pure, one-time historical data-integrity correction: rewrites
/// [Transaction.accountId] from a legacy display label ('Cash'/'Checking'/
/// 'Savings'/'Credit Card') to the real [Wallet.id] it refers to, wherever
/// that can be determined without guessing.
///
/// This is deliberately narrow — it NEVER touches id, amount, createdAt,
/// categoryId, note, or transactionType, and it NEVER invents a wallet
/// association: an ambiguous or unmatched `accountId` is left exactly as
/// recorded (see [resolveWalletIdForAccount], the same centralized resolver
/// used by every live transaction-creation path). Calling [plan] again on
/// already-migrated data is a no-op — every previously-migrated record's
/// `accountId` now equals a real wallet id, so it is classified as already
/// correct and left alone. This makes the migration naturally idempotent
/// and safe to re-run after an interruption, with no separate "in progress"
/// state to track.
class TransactionAccountMigration {
  TransactionAccountMigration._();

  static TransactionAccountMigrationResult plan({
    required List<Transaction> transactions,
    required List<Wallet> wallets,
  }) {
    final updated = <Transaction>[];
    var migrated = 0;
    var unresolved = 0;
    var alreadyCorrect = 0;

    for (final transaction in transactions) {
      if (wallets.any((wallet) => wallet.id == transaction.accountId)) {
        alreadyCorrect++;
        continue;
      }

      final resolvedWalletId = resolveWalletIdForAccount(transaction.accountId, wallets);
      if (resolvedWalletId == null) {
        unresolved++;
        continue;
      }

      updated.add(transaction.copyWith(accountId: resolvedWalletId));
      migrated++;
    }

    return TransactionAccountMigrationResult(
      updatedTransactions: updated,
      migratedCount: migrated,
      unresolvedCount: unresolved,
      alreadyCorrectCount: alreadyCorrect,
    );
  }
}

/// Applies [TransactionAccountMigration.plan] against real storage,
/// gated by the `app_settings` completion flag so it only does real work
/// once. Safe to call on every app start: if interrupted partway through
/// (e.g. the app is killed mid-loop, before the flag is set), the next call
/// re-plans from the current data — already-migrated records are now
/// recognized as already correct (their `accountId` equals a real wallet
/// id) and are not touched again, so nothing is double-applied.
class TransactionAccountMigrationRunner {
  TransactionAccountMigrationRunner._();

  static const _noOpResult = TransactionAccountMigrationResult(
    updatedTransactions: [],
    migratedCount: 0,
    unresolvedCount: 0,
    alreadyCorrectCount: 0,
  );

  static Future<TransactionAccountMigrationResult> runIfNeeded() async {
    final alreadyComplete =
        await AppSettingsRepository.instance.isWalletTransactionAccountMigrationV1Complete();
    if (alreadyComplete) {
      return _noOpResult;
    }

    final transactions = await TransactionRepository.instance.getAll();
    final wallets = await WalletRepository.instance.getAll();
    final result = TransactionAccountMigration.plan(
      transactions: transactions,
      wallets: wallets,
    );

    for (final transaction in result.updatedTransactions) {
      await TransactionRepository.instance.update(transaction);
    }

    await AppSettingsRepository.instance.completeWalletTransactionAccountMigrationV1();
    return result;
  }
}
