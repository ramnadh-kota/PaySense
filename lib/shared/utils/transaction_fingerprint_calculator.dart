import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/transaction.dart';
import '../models/transaction_ingestion_record.dart';
import '../models/transaction_ingestion_result.dart';
import 'transaction_normalizer.dart';

/// TRANSACTION INGESTION 1.0 — PHASE 5. Pure Dart, deterministic,
/// source-independent fingerprinting. Reuses the SAME `crypto: ^3.0.7`
/// dependency and `sha256.convert(utf8.encode(...)).toString()` call
/// pattern already used by `password_hasher.dart` and the existing SMS
/// parser's own fingerprint — no new dependency added.
///
/// Two fingerprints are computed, deliberately kept distinct (see
/// [TransactionFingerprint.isStrong]):
///
/// - [compute] — the BEST available fingerprint: a strong bank
///   reference/UTR or source transaction id when present, else the same
///   weak fallback as [computeWeak]. Meaningful for comparing INCOMING
///   records against each OTHER within one import batch (e.g. the SAME
///   UTR appearing in both an SMS-derived and a CSV-derived record).
/// - [computeWeak] — ALWAYS the fallback (normalized date + amount +
///   direction + merchant + wallet), regardless of whether a strong id is
///   available. This is the ONLY fingerprint an EXISTING, already-persisted
///   [Transaction] can ever produce, since the current `Transaction` model
///   has no field to persist a source reference id — so any comparison
///   against already-stored data must always use this, never [compute]'s
///   strong path (a strong match there would be reference-less and
///   therefore never actually reachable against real existing rows).
class TransactionFingerprintCalculator {
  TransactionFingerprintCalculator._();

  static TransactionFingerprint compute(TransactionIngestionRecord normalized) {
    final strongId = _strongIdentifier(normalized);
    if (strongId != null) {
      final basis = 'ref|$strongId|${normalized.type.name}|${_amountKey(normalized.amount)}';
      return TransactionFingerprint(hash: _hash(basis), isStrong: true);
    }
    return computeWeak(normalized);
  }

  static TransactionFingerprint computeWeak(TransactionIngestionRecord normalized) {
    final dateKey = normalized.dateTime?.toIso8601String() ?? 'unknown-date';
    final basis = 'std|$dateKey|${_amountKey(normalized.amount)}|${normalized.type.name}|'
        '${normalized.merchant ?? ''}|${normalized.walletId ?? ''}';
    return TransactionFingerprint(hash: _hash(basis), isStrong: false);
  }

  static String? _strongIdentifier(TransactionIngestionRecord record) {
    final ref = record.referenceId;
    if (ref != null && ref.isNotEmpty) return ref;
    final sourceId = record.sourceTransactionId;
    if (sourceId != null && sourceId.isNotEmpty) return sourceId;
    return null;
  }

  static String _amountKey(double amount) => amount.toStringAsFixed(2);

  static String _hash(String basis) => sha256.convert(utf8.encode(basis)).toString();

  /// Builds a weak-fingerprint-comparable [TransactionIngestionRecord]
  /// from an EXISTING, already-persisted [Transaction] — the only bridge
  /// available today, since `Transaction` carries no source/reference
  /// field and its `title` is the closest existing analogue to a
  /// merchant/payee label. Never persisted; purely an in-memory
  /// comparison shim used by `TransactionDeduplicator`.
  static TransactionIngestionRecord recordFromExistingTransaction(Transaction transaction) {
    return TransactionNormalizer.normalizeRecord(
      TransactionIngestionRecord(
        // Provenance is unknown/irrelevant here — only the weak-fingerprint
        // fields below are ever read from this shim record.
        source: TransactionSource.manual,
        type: _typeFromExistingTransactionType(transaction.transactionType),
        amount: transaction.amount,
        dateTime: transaction.createdAt,
        merchant: transaction.title,
        walletId: transaction.accountId,
      ),
    );
  }

  static IngestionTransactionType _typeFromExistingTransactionType(String raw) {
    switch (raw.toLowerCase()) {
      case 'income':
        return IngestionTransactionType.income;
      case 'transfer':
        return IngestionTransactionType.transfer;
      default:
        return IngestionTransactionType.expense;
    }
  }
}
