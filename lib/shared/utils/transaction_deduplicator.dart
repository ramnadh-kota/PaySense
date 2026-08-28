import '../models/transaction.dart';
import '../models/transaction_ingestion_record.dart';
import '../models/transaction_ingestion_result.dart';
import 'transaction_fingerprint_calculator.dart';
import 'transaction_normalizer.dart';
import 'transaction_validator.dart';

/// TRANSACTION INGESTION 1.0 — PHASE 6/10. Pure Dart, deterministic. The
/// single pipeline entry point, matching the architecture diagram exactly:
///
/// ```
/// TransactionIngestionRecord -> Normalization -> Validation ->
///   Fingerprinting -> Deduplication -> new / duplicate / needsReview / invalid
/// ```
///
/// This is READ-ONLY: it never writes to any repository, never mutates
/// [existing], never mutates its inputs. Nothing is persisted in this
/// phase (per this milestone's explicit scope).
///
/// Classification rules (deliberately safety-first — see class-level
/// rationale on each branch below):
/// 1. Two INCOMING records sharing the same strong reference/source id →
///    the later one is a confident [TransactionIngestionStatus.duplicate].
/// 2. An incoming record with a strong id whose WEAK fallback also matches
///    an EXISTING transaction → confident [TransactionIngestionStatus.duplicate].
/// 3. A weak-fingerprint-only match (no strong id available, against
///    either existing data or another incoming record) → NEVER a silent
///    duplicate — always [TransactionIngestionStatus.needsReview], so a
///    human confirms rather than the pipeline guessing.
/// 4. No match at all → [TransactionIngestionStatus.newRecord].
///
/// Because the weak fingerprint's basis always includes
/// [IngestionTransactionType] (income/expense/transfer/refund), a refund
/// can never weak-match its original purchase (a refund is `refund`→
/// hashed as `'refund'`, the purchase is `expense`), a transfer can never
/// collapse into an income/expense, and income can never collapse into
/// expense — this falls out of the fingerprint basis itself, not extra
/// special-case code.
class TransactionDeduplicator {
  TransactionDeduplicator._();

  static List<TransactionIngestionResult> deduplicate({
    required List<TransactionIngestionRecord> incoming,
    required List<Transaction> existing,
  }) {
    final existingWeakHashes = existing
        .map(
          (t) => TransactionFingerprintCalculator.computeWeak(
            TransactionFingerprintCalculator.recordFromExistingTransaction(t),
          ).hash,
        )
        .toSet();

    final results = <TransactionIngestionResult>[];
    final seenStrongHashesThisBatch = <String>{};
    final seenWeakHashesThisBatch = <String>{};

    for (final raw in incoming) {
      final normalized = TransactionNormalizer.normalizeRecord(raw);
      final validation = TransactionValidator.validate(normalized);

      if (!validation.isValid) {
        results.add(
          TransactionIngestionResult(
            record: normalized,
            status: TransactionIngestionStatus.invalid,
            fingerprint: TransactionFingerprintCalculator.computeWeak(normalized),
            validationErrors: validation.errors,
          ),
        );
        continue;
      }

      final primary = TransactionFingerprintCalculator.compute(normalized);
      final weak = primary.isStrong ? TransactionFingerprintCalculator.computeWeak(normalized) : primary;

      TransactionIngestionStatus status;
      String? reason;

      if (primary.isStrong) {
        // A record with its OWN distinct strong id is trusted as authoritative
        // — it must never be downgraded to needsReview just because its weak
        // (date+amount+merchant+wallet) fields happen to collide with some
        // OTHER record that also carries a different strong id (see PHASE 9
        // test G: two same-day/merchant/amount records with DIFFERENT
        // reference ids must both stay `newRecord`).
        if (seenStrongHashesThisBatch.contains(primary.hash)) {
          status = TransactionIngestionStatus.duplicate;
          reason = 'Matches another record in this import by the same reference/source id.';
        } else if (existingWeakHashes.contains(weak.hash)) {
          status = TransactionIngestionStatus.duplicate;
          reason = 'Matches an existing transaction — same reference id, date, amount, and merchant.';
        } else {
          status = TransactionIngestionStatus.newRecord;
        }
      } else if (existingWeakHashes.contains(weak.hash) || seenWeakHashesThisBatch.contains(weak.hash)) {
        status = TransactionIngestionStatus.needsReview;
        reason = 'Same date, amount, merchant, and direction as another transaction — no strong '
            'identifier available to confirm this is really the same transaction.';
      } else {
        status = TransactionIngestionStatus.newRecord;
      }

      if (primary.isStrong) seenStrongHashesThisBatch.add(primary.hash);
      // Always tracked (even for a confidently-distinct strong record) so a
      // LATER weak-only record with no identifier of its own can still be
      // flagged for review against it.
      seenWeakHashesThisBatch.add(weak.hash);

      results.add(
        TransactionIngestionResult(
          record: normalized,
          status: status,
          fingerprint: primary,
          duplicateReason: reason,
        ),
      );
    }

    return results;
  }
}
