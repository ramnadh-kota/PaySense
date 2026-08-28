import '../models/transaction_ingestion_record.dart';

/// TRANSACTION INGESTION 1.0 — PHASE 4. Pure Dart, deterministic. Produces
/// a NEW, cleaned-up [TransactionIngestionRecord] from whatever a
/// (future, not-yet-built) source adapter constructed — never mutates its
/// input (the model is immutable anyway).
///
/// Deliberately conservative: this only collapses formatting NOISE
/// (whitespace, casing, separator punctuation) — it never strips or
/// rewrites meaningful merchant text, and it never performs fuzzy
/// matching (that's explicitly out of scope for this phase).
class TransactionNormalizer {
  TransactionNormalizer._();

  static String normalizeWhitespace(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// `"  AMAZON PAY  "` → `"amazon pay"`; `"Amazon-Pay"` → `"amazon pay"` —
  /// separator punctuation (`-`/`_`) is treated as whitespace, everything
  /// else (letters, digits, `&`, `.`, etc.) is preserved so real merchant
  /// identity is never lost.
  static String? normalizeMerchant(String? raw) {
    if (raw == null) return null;
    final withSeparatorsAsSpaces = raw.replaceAll(RegExp(r'[-_]+'), ' ');
    final collapsed = normalizeWhitespace(withSeparatorsAsSpaces);
    if (collapsed.isEmpty) return null;
    return collapsed.toLowerCase();
  }

  /// Bank reference/UTR numbers are conventionally uppercase alphanumeric
  /// — normalized to uppercase with surrounding whitespace trimmed so the
  /// SAME reference from two different sources compares equal regardless
  /// of case.
  static String? normalizeReference(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed.toUpperCase();
  }

  /// Defaults to `'INR'` (matching `UserProfile.currency`'s own default —
  /// PaySense has no per-transaction currency field today) only when a
  /// source genuinely provided nothing; never silently overrides an
  /// explicit different currency.
  static String normalizeCurrency(String? raw) {
    final trimmed = raw?.trim().toUpperCase() ?? '';
    return trimmed.isEmpty ? 'INR' : trimmed;
  }

  /// Truncates to minute-level precision — the same granularity the
  /// existing SMS fingerprint already uses (independently reimplemented
  /// here, not imported, per this phase's SMS boundary) — so two records
  /// of the SAME real transaction that differ by a few seconds of clock
  /// skew across sources still normalize identically.
  static DateTime? normalizeDateTime(DateTime? raw) {
    if (raw == null) return null;
    return DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute);
  }

  /// Rounds to 2 decimal places to remove floating-point noise — but
  /// deliberately does NOT take the absolute value. A negative/zero
  /// amount is malformed source data (Phase 7's own example), and
  /// `TransactionValidator` needs to see the ORIGINAL sign to catch it;
  /// silently flipping it positive here would make that check
  /// unreachable. A future (not-yet-built) persistence step is
  /// responsible for taking `.abs()` when finally constructing the
  /// existing `Transaction.amount` (which is always stored positive,
  /// direction encoded via `transactionType`), AFTER validation has
  /// already rejected anything <= 0.
  static double normalizeAmount(double amount) => double.parse(amount.toStringAsFixed(2));

  static String? _normalizedOrNull(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Runs every field-level normalizer over [record] and returns a NEW
  /// record. This is the single entry point every downstream step
  /// (validation, fingerprinting, deduplication) operates on — never the
  /// raw, as-provided record.
  static TransactionIngestionRecord normalizeRecord(TransactionIngestionRecord record) {
    final normalizedDescription =
        record.description == null ? null : _normalizedOrNull(normalizeWhitespace(record.description!));

    return TransactionIngestionRecord(
      source: record.source,
      type: record.type,
      amount: normalizeAmount(record.amount),
      sourceTransactionId: _normalizedOrNull(record.sourceTransactionId),
      dateTime: normalizeDateTime(record.dateTime),
      merchant: normalizeMerchant(record.merchant),
      description: normalizedDescription,
      categoryId: _normalizedOrNull(record.categoryId),
      walletId: _normalizedOrNull(record.walletId),
      currencyCode: normalizeCurrency(record.currencyCode),
      referenceId: normalizeReference(record.referenceId),
      confidence: record.confidence,
      metadata: record.metadata,
    );
  }
}
