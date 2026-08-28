import 'package:flutter/foundation.dart';

import 'transaction_ingestion_record.dart';
import 'transaction_ingestion_result.dart';

/// CSV BANK STATEMENT IMPORT — PHASE 1. Pure Dart, no Flutter widgets, no
/// Hive, no Riverpod — this is the domain model layer only. Everything
/// here is a plain immutable value; the [CsvImportNotifier]
/// (`lib/shared/providers/csv_import_provider.dart`) is the only place
/// that mutates state, by producing a NEW [CsvImportSession].
///
/// State machine driving the whole import flow (see [CsvImportStatus] for
/// the full list): a fresh session starts at [CsvImportStatus.selecting]
/// and only ever reaches [CsvImportStatus.completed] after the user's
/// explicit confirmation — see PHASE 13 (import safety) on
/// [CsvImportPipeline]/[CsvImportNotifier] for why nothing is persisted
/// before that point.
enum CsvImportStatus {
  selecting,
  reading,
  detecting,
  mappingRequired,
  previewReady,
  importing,
  completed,
  failed,
}

/// The bank statement layouts this phase recognizes with real confidence.
/// [generic] is not a failure state — it is the deliberately honest
/// fallback whenever the evidence for a specific bank isn't strong enough
/// (see `CsvFormatDetector` — PHASE 2's own instruction: "Do not pretend a
/// bank is detected when confidence is low").
enum DetectedBankFormat { hdfc, icici, sbi, axis, kotak, generic }

extension DetectedBankFormatLabel on DetectedBankFormat {
  String get label {
    switch (this) {
      case DetectedBankFormat.hdfc:
        return 'HDFC Bank';
      case DetectedBankFormat.icici:
        return 'ICICI Bank';
      case DetectedBankFormat.sbi:
        return 'State Bank of India';
      case DetectedBankFormat.axis:
        return 'Axis Bank';
      case DetectedBankFormat.kotak:
        return 'Kotak Mahindra Bank';
      case DetectedBankFormat.generic:
        return 'Generic bank statement';
    }
  }
}

/// Which CSV column (by header name, verbatim as it appears in the file)
/// supplies each normalized field. Every field is nullable — different
/// banks expose different columns, and a user may need to fill some of
/// these in manually when auto-detection isn't confident enough.
@immutable
class CsvColumnMapping {
  const CsvColumnMapping({
    this.dateColumn,
    this.descriptionColumn,
    this.debitColumn,
    this.creditColumn,
    this.amountColumn,
    this.balanceColumn,
    this.referenceColumn,
  });

  final String? dateColumn;
  final String? descriptionColumn;
  final String? debitColumn;
  final String? creditColumn;
  final String? amountColumn;
  final String? balanceColumn;
  final String? referenceColumn;

  /// A mapping is usable for parsing once it has a date column AND some
  /// way to determine an amount (either a debit/credit pair or a single
  /// amount column). Without this, manual mapping is required.
  bool get isUsable =>
      dateColumn != null && (debitColumn != null || creditColumn != null || amountColumn != null);

  /// True only when the mapping can determine transaction DIRECTION
  /// (income vs expense) from column structure alone — i.e. distinct
  /// debit/credit columns. A single amount column, by itself, is never
  /// enough (see PHASE 5 — direction is never inferred from sign).
  bool get hasExplicitDirectionColumns => debitColumn != null || creditColumn != null;

  CsvColumnMapping copyWith({
    String? dateColumn,
    String? descriptionColumn,
    String? debitColumn,
    String? creditColumn,
    String? amountColumn,
    String? balanceColumn,
    String? referenceColumn,
  }) {
    return CsvColumnMapping(
      dateColumn: dateColumn ?? this.dateColumn,
      descriptionColumn: descriptionColumn ?? this.descriptionColumn,
      debitColumn: debitColumn ?? this.debitColumn,
      creditColumn: creditColumn ?? this.creditColumn,
      amountColumn: amountColumn ?? this.amountColumn,
      balanceColumn: balanceColumn ?? this.balanceColumn,
      referenceColumn: referenceColumn ?? this.referenceColumn,
    );
  }
}

/// Result of PHASE 2/3 (format + column detection), before any row is
/// parsed.
@immutable
class CsvDetectionResult {
  const CsvDetectionResult({
    required this.detectedBank,
    required this.confidence,
    required this.detectedColumns,
    required this.requiresManualMapping,
    this.warnings = const [],
  });

  final DetectedBankFormat detectedBank;

  /// 0.0–1.0. Only ever high when the header signature strongly and
  /// unambiguously matches one bank's known layout.
  final double confidence;
  final CsvColumnMapping detectedColumns;
  final bool requiresManualMapping;
  final List<String> warnings;
}

/// A single row that could not be turned into a [TransactionIngestionRecord]
/// at all (PHASE 4) — a structural parse failure, not a validation/dedup
/// outcome. `rawSnippet` is the user's OWN CSV row, shown back to them for
/// review only; it is never sent anywhere (see PHASE 16 — privacy).
@immutable
class CsvRowIssue {
  const CsvRowIssue({required this.rowNumber, required this.message, this.rawSnippet});

  /// 1-based row number as it appears in the file (header row is row 1).
  final int rowNumber;
  final String message;
  final String? rawSnippet;
}

/// What the user chose for a `needsReview` row (PHASE 9). `pending` means
/// no decision has been made yet — such rows are excluded from import by
/// default until the user acts, never imported by omission.
enum CsvRowDecision { pending, markIncome, markExpense, skip }

/// The single source of truth for one in-progress (or completed) CSV
/// import, threaded through every step of the flow. Never persisted to
/// Hive — this is in-memory only and is discarded once the flow ends.
@immutable
class CsvImportSession {
  const CsvImportSession({
    this.status = CsvImportStatus.selecting,
    this.fileName,
    this.rawCsvText,
    this.headers = const [],
    this.detectionResult,
    this.columnMapping,
    this.selectedWalletId,
    this.totalRows = 0,
    this.parsedRecords = const [],
    this.rowIssues = const [],
    this.pipelineResults = const [],
    this.rowDecisions = const {},
    this.errorMessage,
  });

  final CsvImportStatus status;
  final String? fileName;

  /// Held only in memory for the duration of the import flow so the
  /// pipeline can be re-run (e.g. after wallet selection or a column
  /// mapping change) without re-picking the file. Never written to disk
  /// by any code in this feature.
  final String? rawCsvText;

  /// Column headers exactly as they appear in row 1 of the file — used to
  /// populate the manual column-mapping dropdowns (PHASE 3/15).
  final List<String> headers;
  final CsvDetectionResult? detectionResult;
  final CsvColumnMapping? columnMapping;
  final String? selectedWalletId;

  /// Total data rows in the file (excludes the header row).
  final int totalRows;

  /// Rows that parsed into a [TransactionIngestionRecord] successfully —
  /// this is the input to the PHASE 7 pipeline, in the same order as
  /// [pipelineResults].
  final List<TransactionIngestionRecord> parsedRecords;

  /// Rows that could not be parsed at all (PHASE 4) — always excluded
  /// from import.
  final List<CsvRowIssue> rowIssues;

  /// One [TransactionIngestionResult] per entry in [parsedRecords], same
  /// order/index — the output of PHASE 7's normalize → validate →
  /// fingerprint → dedupe pipeline (plus the CSV-specific ambiguity
  /// overrides described in `CsvImportPipeline`).
  final List<TransactionIngestionResult> pipelineResults;

  /// User corrections for `needsReview` rows, keyed by index into
  /// [pipelineResults]. A row with no entry here is treated as
  /// [CsvRowDecision.pending] — i.e. NOT imported (see PHASE 9 — never
  /// auto-correct uncertain financial data).
  final Map<int, CsvRowDecision> rowDecisions;

  final String? errorMessage;

  CsvImportSession copyWith({
    CsvImportStatus? status,
    String? fileName,
    String? rawCsvText,
    List<String>? headers,
    CsvDetectionResult? detectionResult,
    CsvColumnMapping? columnMapping,
    String? selectedWalletId,
    int? totalRows,
    List<TransactionIngestionRecord>? parsedRecords,
    List<CsvRowIssue>? rowIssues,
    List<TransactionIngestionResult>? pipelineResults,
    Map<int, CsvRowDecision>? rowDecisions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CsvImportSession(
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      rawCsvText: rawCsvText ?? this.rawCsvText,
      headers: headers ?? this.headers,
      detectionResult: detectionResult ?? this.detectionResult,
      columnMapping: columnMapping ?? this.columnMapping,
      selectedWalletId: selectedWalletId ?? this.selectedWalletId,
      totalRows: totalRows ?? this.totalRows,
      parsedRecords: parsedRecords ?? this.parsedRecords,
      rowIssues: rowIssues ?? this.rowIssues,
      pipelineResults: pipelineResults ?? this.pipelineResults,
      rowDecisions: rowDecisions ?? this.rowDecisions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<TransactionIngestionResult> get newRecordResults =>
      pipelineResults.where((r) => r.status == TransactionIngestionStatus.newRecord).toList();

  List<TransactionIngestionResult> get duplicateResults =>
      pipelineResults.where((r) => r.status == TransactionIngestionStatus.duplicate).toList();

  List<TransactionIngestionResult> get needsReviewResults =>
      pipelineResults.where((r) => r.status == TransactionIngestionStatus.needsReview).toList();

  List<TransactionIngestionResult> get invalidResults =>
      pipelineResults.where((r) => r.status == TransactionIngestionStatus.invalid).toList();

  int get validCount => newRecordResults.length;
  int get duplicateCount => duplicateResults.length;
  int get needsReviewCount => needsReviewResults.length;

  /// Structural parse failures (PHASE 4) plus semantically-invalid parsed
  /// rows (PHASE 7) — both are never importable.
  int get invalidCount => rowIssues.length + invalidResults.length;

  /// Rows that will actually be written on confirmation. A `needsReview`
  /// row the user resolves via [CsvRowDecision.markIncome]/[markExpense]
  /// is re-run through the pipeline immediately (see
  /// `CsvImportNotifier.applyRowDecision`) and, if that resolves it, its
  /// stored [TransactionIngestionResult.status] becomes `newRecord`
  /// directly — so this only needs to check status plus the explicit
  /// skip flag (a user can skip ANY row, including an already-`newRecord`
  /// one, to exclude it from import).
  int get readyToImportCount {
    var count = 0;
    for (var i = 0; i < pipelineResults.length; i++) {
      if (pipelineResults[i].status != TransactionIngestionStatus.newRecord) continue;
      if (rowDecisions[i] == CsvRowDecision.skip) continue;
      count++;
    }
    return count;
  }

  DateTime? get earliestDate {
    final dates = pipelineResults.map((r) => r.record.dateTime).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get latestDate {
    final dates = pipelineResults.map((r) => r.record.dateTime).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  double get incomeTotal => _sumFor(IngestionTransactionType.income);
  double get expenseTotal => _sumFor(IngestionTransactionType.expense);

  /// Sums only rows that will actually be imported (see
  /// [readyToImportCount]) — a row's [TransactionIngestionRecord.type] is
  /// already the corrected value by the time it's `newRecord`, so no
  /// extra decision-based lookup is needed here.
  double _sumFor(IngestionTransactionType type) {
    var total = 0.0;
    for (var i = 0; i < pipelineResults.length; i++) {
      final result = pipelineResults[i];
      if (result.status != TransactionIngestionStatus.newRecord) continue;
      if (rowDecisions[i] == CsvRowDecision.skip) continue;
      if (result.record.type == type) total += result.record.amount;
    }
    return total;
  }
}
