import 'package:flutter/foundation.dart';

import 'transaction_ingestion_record.dart';

/// TRANSACTION INGESTION 1.0 — PHASE 3. Pure Dart result-side models.
///
/// `new` is a reserved keyword in Dart and cannot be an enum value name —
/// [newRecord] is the closest safe equivalent.
enum TransactionIngestionStatus { newRecord, duplicate, needsReview, invalid }

/// A computed fingerprint plus whether it was built from a STRONG
/// identifier (a bank reference/UTR or a source's own transaction id) or
/// only the WEAK fallback (normalized date+amount+type+merchant+wallet).
/// See `TransactionFingerprintCalculator` for exactly how each is built,
/// and `TransactionDeduplicator` for why the distinction changes how a
/// match is classified (a strong match is a confident [duplicate]; a
/// weak-only match is [TransactionIngestionStatus.needsReview], never a
/// silent auto-duplicate).
@immutable
class TransactionFingerprint {
  const TransactionFingerprint({required this.hash, required this.isStrong});

  final String hash;
  final bool isStrong;
}

@immutable
class TransactionValidationResult {
  const TransactionValidationResult({required this.isValid, required this.errors});

  final bool isValid;
  final List<String> errors;
}

/// The full outcome for one incoming [TransactionIngestionRecord] after
/// normalization, validation, fingerprinting, and deduplication.
@immutable
class TransactionIngestionResult {
  const TransactionIngestionResult({
    required this.record,
    required this.status,
    required this.fingerprint,
    this.duplicateReason,
    this.validationErrors = const [],
    this.warnings = const [],
  });

  /// The NORMALIZED record (post `TransactionNormalizer.normalizeRecord`) —
  /// never the raw, as-provided record.
  final TransactionIngestionRecord record;

  final TransactionIngestionStatus status;
  final TransactionFingerprint fingerprint;

  /// Set only when [status] is [TransactionIngestionStatus.duplicate] or
  /// [TransactionIngestionStatus.needsReview] — a short, human-readable
  /// explanation of why.
  final String? duplicateReason;

  /// Set only when [status] is [TransactionIngestionStatus.invalid].
  final List<String> validationErrors;

  final List<String> warnings;
}
