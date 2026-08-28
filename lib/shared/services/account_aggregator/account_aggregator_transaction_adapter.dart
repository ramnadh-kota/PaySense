import '../../models/transaction_ingestion_record.dart';
import 'account_aggregator_models.dart';

/// ACCOUNT AGGREGATOR — PART C. The ONE place an
/// [AccountAggregatorTransaction] (raw, vendor-shaped) becomes a
/// [TransactionIngestionRecord] — the existing Phase 1 ingestion
/// pipeline's own input type. Nothing else in the AA feature is allowed
/// to construct a `Transaction` directly from AA data; everything must
/// pass through here first, then through the UNMODIFIED
/// `TransactionNormalizer` → `TransactionValidator` →
/// `TransactionFingerprintCalculator` → `TransactionDeduplicator` chain
/// (see `AccountAggregatorSyncService`, which is the only caller of this
/// adapter).
class AccountAggregatorTransactionAdapter {
  AccountAggregatorTransactionAdapter._();

  /// [walletId] must be a REAL PaySense `Wallet.id` the account has
  /// already been mapped to (PART D) — never the raw AA account id, and
  /// never null (callers must skip unmapped/liability accounts entirely
  /// rather than call this with a placeholder).
  static TransactionIngestionRecord toIngestionRecord({
    required AccountAggregatorTransaction transaction,
    required String walletId,
  }) {
    final type = transaction.direction == AccountAggregatorTransactionDirection.credit
        ? IngestionTransactionType.income
        : IngestionTransactionType.expense;

    return TransactionIngestionRecord(
      source: TransactionSource.accountAggregator,
      type: type,
      amount: transaction.amount,
      // The AA provider's own transaction id — lets a strong fingerprint
      // form even when [referenceNumber] is absent, exactly like a CSV
      // row's `sourceTransactionId` fallback.
      sourceTransactionId: transaction.id,
      dateTime: transaction.transactionDate,
      merchant: transaction.narration,
      description: transaction.narration,
      walletId: walletId,
      currencyCode: transaction.currencyCode,
      referenceId: transaction.referenceNumber,
      // `mode` (e.g. "UPI"/"NEFT") is informational payment-rail data,
      // never a credential — safe under TransactionValidator's forbidden
      // metadata-key scan (mirrors the CSV adapter's `csvRowNumber`
      // pattern of only ever putting safe, non-sensitive bookkeeping into
      // metadata).
      metadata: {
        if (transaction.mode != null) 'aaPaymentMode': transaction.mode,
        'aaAccountId': transaction.accountId,
      },
    );
  }
}
