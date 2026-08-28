import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/csv_import_completion_result.dart';
import '../models/csv_import_session.dart';
import '../models/transaction.dart';
import '../models/transaction_ingestion_record.dart';
import '../models/transaction_ingestion_result.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';
import '../utils/csv_format_detector.dart';
import '../utils/csv_import_pipeline.dart';
import '../utils/csv_transaction_parser.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

final csvImportProvider = NotifierProvider<CsvImportNotifier, CsvImportSession>(CsvImportNotifier.new);

/// CSV BANK STATEMENT IMPORT — drives the whole flow described in PHASE
/// 15: pick file -> detect format -> map columns (if needed) -> preview
/// -> review -> select wallet -> confirm -> complete. Every method except
/// [confirmImport] is read-only with respect to the existing
/// `TransactionRepository`/`WalletRepository` — see PHASE 13 (import
/// safety): nothing is written until the user explicitly confirms.
class CsvImportNotifier extends Notifier<CsvImportSession> {
  @override
  CsvImportSession build() => const CsvImportSession();

  void reset() {
    state = const CsvImportSession();
  }

  /// PHASE 15 step 1 — opens the system file picker restricted to
  /// `.csv`, reads it fully into memory (never uploaded anywhere — see
  /// PHASE 16), and immediately runs format/column detection. Returns
  /// without changing state if the user cancels the picker.
  Future<void> pickAndReadFile() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (files.isEmpty) return;

    final file = files.single;
    late final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      state = state.copyWith(
        status: CsvImportStatus.failed,
        errorMessage: 'Could not read the selected file.',
      );
      return;
    }

    late final String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      state = state.copyWith(
        status: CsvImportStatus.failed,
        errorMessage: 'The selected file is not readable text.',
      );
      return;
    }

    await loadCsvText(fileName: file.name, csvText: text);
  }

  /// Split out from [pickAndReadFile] so tests (and any future alternate
  /// entry point) can drive the flow without going through the platform
  /// file picker.
  Future<void> loadCsvText({required String fileName, required String csvText}) async {
    state = CsvImportSession(status: CsvImportStatus.reading, fileName: fileName, rawCsvText: csvText);

    final rows = CsvTransactionParser.readRows(csvText);
    if (rows.isEmpty) {
      state = state.copyWith(status: CsvImportStatus.failed, errorMessage: 'The CSV file is empty.');
      return;
    }

    final headers = rows.first;
    final dataRowCount = rows.length - 1;
    if (dataRowCount <= 0) {
      state = state.copyWith(
        status: CsvImportStatus.failed,
        errorMessage: 'The CSV file has a header row but no transaction rows.',
        headers: headers,
        totalRows: 0,
      );
      return;
    }

    state = state.copyWith(status: CsvImportStatus.detecting, headers: headers, totalRows: dataRowCount);

    final detection = CsvFormatDetector.detect(headers);
    state = state.copyWith(detectionResult: detection, columnMapping: detection.detectedColumns);

    if (detection.requiresManualMapping) {
      state = state.copyWith(status: CsvImportStatus.mappingRequired);
      return;
    }

    await _parseAndPreview();
  }

  /// PHASE 15 step — user adjusted the column mapping manually (either
  /// because detection required it, or because they want to correct an
  /// auto-detected guess).
  void updateColumnMapping(CsvColumnMapping mapping) {
    state = state.copyWith(columnMapping: mapping);
  }

  /// Confirms the current [CsvImportSession.columnMapping] and proceeds
  /// to parse every row and build the PHASE 8 preview.
  Future<void> confirmColumnMapping() async {
    final mapping = state.columnMapping;
    if (mapping == null || !mapping.isUsable) {
      state = state.copyWith(
        status: CsvImportStatus.failed,
        errorMessage: 'At least a date column and an amount (or debit/credit) column are required.',
      );
      return;
    }
    await _parseAndPreview();
  }

  Future<void> _parseAndPreview() async {
    final csvText = state.rawCsvText;
    final mapping = state.columnMapping;
    if (csvText == null || mapping == null) return;

    final rows = CsvTransactionParser.readRows(csvText);
    final headers = rows.first;
    final dataRows = rows.skip(1).toList();

    final outcomes = CsvTransactionParser.parseRows(
      headers: headers,
      dataRows: dataRows,
      mapping: mapping,
      walletId: state.selectedWalletId,
    );

    final records = <TransactionIngestionRecord>[];
    final issues = <CsvRowIssue>[];
    for (final outcome in outcomes) {
      final record = outcome.record;
      final issue = outcome.issue;
      if (record != null) records.add(record);
      if (issue != null) issues.add(issue);
    }

    final existing = await ref.read(transactionRepositoryProvider).getAll();
    final pipelineResults = CsvImportPipeline.run(records: records, existing: existing);

    state = state.copyWith(
      status: CsvImportStatus.previewReady,
      totalRows: dataRows.length,
      parsedRecords: records,
      rowIssues: issues,
      pipelineResults: pipelineResults,
      rowDecisions: const {},
    );
  }

  /// PHASE 9 — user resolves a `needsReview` row (or chooses to skip any
  /// row). Marking income/expense re-runs JUST that row through the
  /// pipeline with the corrected type; if that fully resolves it (e.g.
  /// the direction was the only uncertainty), its status becomes
  /// `newRecord` directly — if not (e.g. the date was also unparseable,
  /// which has no available correction), it honestly stays
  /// `needsReview`.
  Future<void> applyRowDecision(int index, CsvRowDecision decision) async {
    final results = List<TransactionIngestionResult>.of(state.pipelineResults);
    if (index < 0 || index >= results.length) return;

    final decisions = Map<int, CsvRowDecision>.of(state.rowDecisions);
    decisions[index] = decision;

    if (decision == CsvRowDecision.markIncome || decision == CsvRowDecision.markExpense) {
      final original = results[index];
      final correctedMetadata = Map<String, dynamic>.of(original.record.metadata)
        ..remove('directionAmbiguous');
      final correctedRecord = original.record.copyWith(
        type: decision == CsvRowDecision.markIncome
            ? IngestionTransactionType.income
            : IngestionTransactionType.expense,
        metadata: correctedMetadata,
      );

      final otherIncoming = <TransactionIngestionRecord>[
        for (var i = 0; i < state.parsedRecords.length; i++)
          if (i != index) state.parsedRecords[i],
      ];
      final existing = await ref.read(transactionRepositoryProvider).getAll();

      final recomputed = CsvImportPipeline.runOne(
        record: correctedRecord,
        otherIncoming: otherIncoming,
        existing: existing,
      );

      results[index] = recomputed;

      final parsedRecords = List<TransactionIngestionRecord>.of(state.parsedRecords);
      parsedRecords[index] = correctedRecord;

      state = state.copyWith(pipelineResults: results, rowDecisions: decisions, parsedRecords: parsedRecords);
      return;
    }

    state = state.copyWith(rowDecisions: decisions);
  }

  /// PHASE 10 — applies the chosen wallet to every parsed record and
  /// re-runs the FULL pipeline (not just one row), since `walletId` is
  /// part of the weak fingerprint basis and can change duplicate
  /// classification now that the destination account is actually known.
  Future<void> selectWallet(String walletId) async {
    final existing = await ref.read(transactionRepositoryProvider).getAll();
    final updatedRecords = [
      for (final record in state.parsedRecords) record.copyWith(walletId: walletId),
    ];
    final pipelineResults = CsvImportPipeline.run(records: updatedRecords, existing: existing);

    state = state.copyWith(
      selectedWalletId: walletId,
      parsedRecords: updatedRecords,
      pipelineResults: pipelineResults,
      // Row decisions (skip / mark income/expense) are keyed by row
      // index, which is unchanged by a wallet swap, so they still apply
      // correctly to the re-run results — never reset here.
    );
  }

  /// PHASE 11/12/13 — the ONLY method in this file that writes to
  /// `TransactionRepository`/`WalletRepository`. Persists every
  /// `newRecord` row not marked [CsvRowDecision.skip], converting it into
  /// the EXISTING `Transaction` model exactly as the Add Income/Add
  /// Expense screens do. A per-row failure is recorded and does not stop
  /// the rest of the batch (PHASE 12).
  Future<CsvImportCompletionResult> confirmImport() async {
    final walletId = state.selectedWalletId;
    if (walletId == null) {
      return const CsvImportCompletionResult(
        importedCount: 0,
        duplicateCount: 0,
        skippedCount: 0,
        failedCount: 0,
        errors: ['No wallet was selected.'],
      );
    }

    state = state.copyWith(status: CsvImportStatus.importing);

    var imported = 0;
    var failed = 0;
    var skipped = 0;
    final errors = <String>[];
    final transactionRepository = TransactionRepository.instance;
    final walletRepository = WalletRepository.instance;

    for (var i = 0; i < state.pipelineResults.length; i++) {
      final result = state.pipelineResults[i];
      if (result.status != TransactionIngestionStatus.newRecord) continue;
      if (state.rowDecisions[i] == CsvRowDecision.skip) {
        skipped++;
        continue;
      }

      final record = result.record;
      try {
        final transaction = Transaction(
          id: const Uuid().v4(),
          title: (record.merchant?.trim().isNotEmpty ?? false) ? record.merchant! : 'Imported transaction',
          amount: record.amount.abs(),
          categoryId: record.categoryId ?? 'Imported',
          accountId: walletId,
          transactionType: record.type.toTransactionTypeString(),
          paymentMethod: 'csv',
          note: record.description ?? '',
          createdAt: record.dateTime!,
        );

        await transactionRepository.add(transaction);

        if (record.type == IngestionTransactionType.income) {
          await walletRepository.increaseBalance(walletId, transaction.amount);
        } else {
          await walletRepository.decreaseBalance(walletId, transaction.amount);
        }

        imported++;
      } catch (e) {
        failed++;
        errors.add('Row could not be imported: $e');
      }
    }

    await ref.read(walletsProvider.notifier).reload();
    await ref.read(transactionsProvider.notifier).reload();

    final completion = CsvImportCompletionResult(
      importedCount: imported,
      duplicateCount: state.duplicateCount,
      skippedCount: skipped + state.needsReviewCount + state.invalidCount,
      failedCount: failed,
      errors: errors,
    );

    state = state.copyWith(status: CsvImportStatus.completed);
    return completion;
  }
}
