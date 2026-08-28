import '../models/transaction.dart';
import '../models/transaction_ingestion_record.dart';
import '../models/transaction_ingestion_result.dart';
import 'transaction_deduplicator.dart';
import 'transaction_fingerprint_calculator.dart';
import 'transaction_normalizer.dart';
import 'transaction_validator.dart';

/// CSV BANK STATEMENT IMPORT — PHASE 7. The single place CSV-parsed
/// records enter the EXISTING Phase 1 ingestion pipeline:
///
/// ```
/// TransactionIngestionRecord -> TransactionNormalizer -> TransactionValidator
///   -> TransactionFingerprintCalculator -> TransactionDeduplicator -> preview result
/// ```
///
/// Nothing here bypasses that pipeline. The only CSV-specific behavior is
/// the ambiguity override below, applied AFTER deduplication — never
/// instead of it.
class CsvImportPipeline {
  CsvImportPipeline._();

  /// Runs [records] through the full Phase 1 pipeline against [existing]
  /// transactions, then applies one CSV-specific safety rule: a record
  /// [CsvTransactionParser] flagged as direction-ambiguous
  /// (`metadata['directionAmbiguous']`) or date-ambiguous
  /// (`metadata['unparseableDateText']`) is ALWAYS forced to
  /// `needsReview`, regardless of what the deduplicator concluded —
  /// because that conclusion was computed from a guessed/placeholder
  /// value (an assumed expense direction, or a null date), never a
  /// confidently-known one. This never happens for SMS/manual/other
  /// sources — the deduplicator itself is untouched.
  static List<TransactionIngestionResult> run({
    required List<TransactionIngestionRecord> records,
    required List<Transaction> existing,
  }) {
    final results = TransactionDeduplicator.deduplicate(incoming: records, existing: existing);
    return results.map(_applyCsvAmbiguityOverride).toList();
  }

  static TransactionIngestionResult _applyCsvAmbiguityOverride(TransactionIngestionResult result) {
    final metadata = result.record.metadata;
    final directionAmbiguous = metadata['directionAmbiguous'] == true;
    final dateAmbiguous = metadata.containsKey('unparseableDateText');

    if (!directionAmbiguous && !dateAmbiguous) return result;
    if (result.status == TransactionIngestionStatus.needsReview) return result;

    final reason = directionAmbiguous && dateAmbiguous
        ? 'Could not determine whether this was income or expense, and could not confidently '
            'parse the transaction date.'
        : directionAmbiguous
            ? 'Could not determine whether this was income or expense.'
            : 'Could not confidently parse the transaction date on this row.';

    return TransactionIngestionResult(
      record: result.record,
      status: TransactionIngestionStatus.needsReview,
      fingerprint: result.fingerprint,
      duplicateReason: reason,
      validationErrors: result.validationErrors,
      warnings: result.warnings,
    );
  }

  /// Re-runs a SINGLE record through the pipeline — used after a PHASE 9
  /// review correction (the user picked income/expense for one row) or
  /// after PHASE 10 wallet selection changes a record's `walletId`. Takes
  /// the other already-decided incoming records into account too, so a
  /// freshly-corrected row can still be caught as a duplicate of another
  /// row in the same batch.
  static TransactionIngestionResult runOne({
    required TransactionIngestionRecord record,
    required List<TransactionIngestionRecord> otherIncoming,
    required List<Transaction> existing,
  }) {
    final normalized = TransactionNormalizer.normalizeRecord(record);
    final validation = TransactionValidator.validate(normalized);
    if (!validation.isValid) {
      return TransactionIngestionResult(
        record: normalized,
        status: TransactionIngestionStatus.invalid,
        fingerprint: TransactionFingerprintCalculator.computeWeak(normalized),
        validationErrors: validation.errors,
      );
    }

    final batchResults = TransactionDeduplicator.deduplicate(
      incoming: [...otherIncoming, record],
      existing: existing,
    );
    return _applyCsvAmbiguityOverride(batchResults.last);
  }
}
