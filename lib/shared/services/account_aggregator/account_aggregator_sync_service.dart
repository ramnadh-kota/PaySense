import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/transaction.dart';
import '../../models/transaction_ingestion_record.dart';
import '../../models/transaction_ingestion_result.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../utils/transaction_deduplicator.dart';
import 'account_aggregator_models.dart';
import 'account_aggregator_service.dart';
import 'account_aggregator_transaction_adapter.dart';

/// The outcome of one [AccountAggregatorSyncService.syncAndIngest] call —
/// what the UI (PART E's sync progress/summary screen) actually shows the
/// user, and what PART G's AI context reads from.
@immutable
class AaSyncSummary {
  const AaSyncSummary({
    required this.syncResult,
    required this.importedCount,
    required this.duplicateCount,
    required this.needsReviewCount,
    required this.invalidCount,
    required this.failedCount,
    required this.skippedUnmappedCount,
    this.errors = const [],
  });

  final AccountAggregatorSyncResult syncResult;

  /// Genuinely new `Transaction`s written this call — see the class doc
  /// on [AccountAggregatorSyncService.syncAndIngest] for the idempotency
  /// guarantee that makes this `0` on a repeat sync of the same data.
  final int importedCount;
  final int duplicateCount;
  final int needsReviewCount;
  final int invalidCount;
  final int failedCount;

  /// Transactions belonging to an AA account that has no
  /// [AccountAggregatorAccount.linkedWalletId] yet (PART D — never
  /// silently guessed) — counted separately from `invalidCount` because
  /// nothing was wrong with the data itself, the user just hasn't mapped
  /// that account to a wallet yet.
  final int skippedUnmappedCount;

  final List<String> errors;

  int get totalConsidered =>
      importedCount + duplicateCount + needsReviewCount + invalidCount + failedCount + skippedUnmappedCount;
}

/// ACCOUNT AGGREGATOR — PART C. Orchestrates one sync: fetches raw AA
/// data, converts it via [AccountAggregatorTransactionAdapter], and runs
/// it through the EXISTING, UNMODIFIED `TransactionDeduplicator` (which
/// itself runs Normalize -> Validate -> Fingerprint internally) before
/// writing anything. This is the only place in the AA feature that calls
/// `TransactionRepository.add` / `WalletRepository.increase/decreaseBalance`.
///
/// IDEMPOTENCY GUARANTEE: every mock (and future real) AA transaction
/// carries its own `id` and, where available, a bank reference number —
/// both flow into `TransactionIngestionRecord.sourceTransactionId`/
/// `.referenceId`, giving every AA-sourced record a STRONG fingerprint on
/// the incoming side. A strong incoming record whose weak fields (date +
/// amount + merchant + wallet + type) match an already-persisted
/// `Transaction` is classified `duplicate` by the existing deduplicator
/// (Phase 1 rule 2) — so re-syncing identical data a second time reduces
/// to 100% duplicates and writes nothing, mutates no wallet balance a
/// second time, and double-counts nothing.
///
/// ONLY bank/deposit accounts are ever ingested here. Credit-card/loan
/// (liability) accounts are deliberately never passed to this method by
/// callers — see PART D's wallet-mapping UI, which never offers a wallet
/// mapping action for a liability account in the first place. Mapping a
/// liability account's own transaction feed onto a cash `Wallet` would
/// risk exactly the double-counting this class exists to prevent (e.g. a
/// credit-card purchase and the bank-account payment that later settles
/// it are two economically related but NOT equivalent cash events) — that
/// reconciliation is out of scope for this pass and is called out as a
/// known limitation rather than guessed at.
class AccountAggregatorSyncService {
  AccountAggregatorSyncService._();

  /// [walletIdByAaAccountId] should contain an entry ONLY for accounts
  /// the user has actually mapped to a wallet (PART D) — any AA account
  /// present in the sync result but absent from this map is counted in
  /// [AaSyncSummary.skippedUnmappedCount], never guessed at.
  ///
  /// Takes [AccountAggregatorService] (never a concrete provider) so
  /// every caller — the wizard notifier, the "Sync now" action, tests —
  /// stays swappable to a real AA/TSP provider with zero code changes,
  /// exactly like every other consumer of the AA architecture.
  static Future<AaSyncSummary> syncAndIngest({
    required AccountAggregatorService service,
    required String connectionId,
    required Map<String, String> walletIdByAaAccountId,
    DateTime? since,
  }) async {
    final syncResult = await service.syncFinancialData(connectionId: connectionId, since: since);

    final records = <TransactionIngestionRecord>[];
    var skippedUnmapped = 0;

    for (final entry in syncResult.transactionsByAccountId.entries) {
      final walletId = walletIdByAaAccountId[entry.key];
      if (walletId == null) {
        skippedUnmapped += entry.value.length;
        continue;
      }
      for (final transaction in entry.value) {
        records.add(AccountAggregatorTransactionAdapter.toIngestionRecord(transaction: transaction, walletId: walletId));
      }
    }

    final existing = await TransactionRepository.instance.getAll();
    final results = TransactionDeduplicator.deduplicate(incoming: records, existing: existing);

    var imported = 0;
    var duplicates = 0;
    var needsReview = 0;
    var invalid = 0;
    var failed = 0;
    final errors = <String>[];

    for (final result in results) {
      switch (result.status) {
        case TransactionIngestionStatus.newRecord:
          try {
            await _persist(result.record);
            imported++;
          } catch (e) {
            failed++;
            errors.add('A transaction could not be saved: $e');
          }
        case TransactionIngestionStatus.duplicate:
          duplicates++;
        case TransactionIngestionStatus.needsReview:
          needsReview++;
        case TransactionIngestionStatus.invalid:
          invalid++;
      }
    }

    return AaSyncSummary(
      syncResult: syncResult,
      importedCount: imported,
      duplicateCount: duplicates,
      needsReviewCount: needsReview,
      invalidCount: invalid,
      failedCount: failed,
      skippedUnmappedCount: skippedUnmapped,
      errors: errors,
    );
  }

  static Future<void> _persist(TransactionIngestionRecord record) async {
    final walletId = record.walletId!;
    final transaction = Transaction(
      id: const Uuid().v4(),
      title: (record.merchant?.trim().isNotEmpty ?? false) ? record.merchant! : 'Account Aggregator transaction',
      amount: record.amount.abs(),
      categoryId: record.categoryId ?? 'Imported',
      accountId: walletId,
      transactionType: record.type.toTransactionTypeString(),
      paymentMethod: 'account_aggregator',
      note: record.description ?? '',
      createdAt: record.dateTime!,
    );

    await TransactionRepository.instance.add(transaction);

    if (record.type == IngestionTransactionType.income) {
      await WalletRepository.instance.increaseBalance(walletId, transaction.amount);
    } else {
      await WalletRepository.instance.decreaseBalance(walletId, transaction.amount);
    }
  }
}
