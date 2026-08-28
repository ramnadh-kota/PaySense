import 'package:flutter/foundation.dart';

/// CSV BANK STATEMENT IMPORT — PHASE 12. The result of the ONE moment in
/// this whole feature that writes to the existing `TransactionRepository`
/// — everything before this (parsing, preview, review) is read-only. See
/// `CsvImportNotifier.confirmImport` for the code that produces this.
@immutable
class CsvImportCompletionResult {
  const CsvImportCompletionResult({
    required this.importedCount,
    required this.duplicateCount,
    required this.skippedCount,
    required this.failedCount,
    this.errors = const [],
  });

  final int importedCount;
  final int duplicateCount;
  final int skippedCount;
  final int failedCount;

  /// Privacy-safe failure descriptions only (no raw row content) — see
  /// PHASE 16.
  final List<String> errors;
}
