import 'package:csv/csv.dart';

import '../models/csv_import_session.dart';
import '../models/transaction_ingestion_record.dart';
import 'csv_amount_parser.dart';
import 'csv_date_parser.dart';

/// The direction (income/expense) is required to build a
/// [TransactionIngestionRecord] but the CSV format sometimes doesn't
/// unambiguously establish it (PHASE 5). This carries both the best-effort
/// [IngestionTransactionType] AND whether that choice is actually
/// trustworthy — [CsvImportPipeline] uses [isAmbiguous] to force such rows
/// to `needsReview` regardless of what deduplication concludes.
class _RowDirection {
  const _RowDirection(this.type, this.amount, {this.isAmbiguous = false});
  final IngestionTransactionType type;
  final double amount;
  final bool isAmbiguous;
}

/// One data row's outcome: either a record ready for the PHASE 7
/// pipeline, or a structural failure.
class CsvParseRowOutcome {
  const CsvParseRowOutcome.record(this.record) : issue = null;
  const CsvParseRowOutcome.issue(this.issue) : record = null;
  final TransactionIngestionRecord? record;
  final CsvRowIssue? issue;
}

/// CSV BANK STATEMENT IMPORT — PHASE 4. Turns raw CSV text into
/// [TransactionIngestionRecord]s using RFC 4180 parsing (via the `csv`
/// package — handles quoted fields, embedded commas, and escaped quotes
/// correctly) plus the [CsvColumnMapping] chosen in PHASE 2/3.
///
/// A malformed row NEVER throws or aborts the whole import — it produces
/// a [CsvRowIssue] and parsing continues with the next row (PHASE 4's own
/// instruction).
class CsvTransactionParser {
  CsvTransactionParser._();

  // `eol` is pinned to `'\n'` (rather than the package default `'\r\n'`,
  // which requires that EXACT two-character sequence to match) after
  // normalizing all line-ending conventions below — a bank export saved
  // with Unix-style `\n`-only line endings would otherwise never split
  // into separate rows at all.
  static const _converter = CsvToListConverter(shouldParseNumbers: false, eol: '\n');

  /// Splits raw CSV text into rows of string cells. Blank trailing rows
  /// (a common trailing-newline artifact) are dropped. The first
  /// non-blank row is assumed to be the header row — callers should pass
  /// only the data rows (everything after the header) to [parseRows].
  static List<List<String>> readRows(String csvText) {
    final normalized = csvText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawRows = _converter.convert<dynamic>(normalized);
    final rows = <List<String>>[];
    for (final row in rawRows) {
      final cells = row.map((cell) => (cell as Object?)?.toString() ?? '').toList();
      if (cells.every((c) => c.trim().isEmpty)) continue;
      rows.add(cells);
    }
    return rows;
  }

  /// Parses every data row (i.e. everything in [dataRows], NOT including
  /// the header) against [headers] + [mapping], tagging each successfully
  /// parsed row with [walletId] (nullable — wallet may not be chosen yet,
  /// see PHASE 10) and `TransactionSource.csv`.
  ///
  /// [startingRowNumber] is the 1-based file row number of the first
  /// entry in [dataRows] (i.e. 2, since row 1 is the header) — used only
  /// to build user-facing [CsvRowIssue.rowNumber] values.
  static List<CsvParseRowOutcome> parseRows({
    required List<String> headers,
    required List<List<String>> dataRows,
    required CsvColumnMapping mapping,
    required String? walletId,
    int startingRowNumber = 2,
  }) {
    final headerIndex = <String, int>{
      for (var i = 0; i < headers.length; i++) headers[i]: i,
    };

    String? cellFor(List<String> row, String? column) {
      if (column == null) return null;
      final index = headerIndex[column];
      if (index == null || index >= row.length) return null;
      final value = row[index].trim();
      return value.isEmpty ? null : value;
    }

    final outcomes = <CsvParseRowOutcome>[];

    for (var i = 0; i < dataRows.length; i++) {
      final rowNumber = startingRowNumber + i;
      final row = dataRows[i];

      if (row.every((c) => c.trim().isEmpty)) continue;

      final dateCell = cellFor(row, mapping.dateColumn);
      final descriptionCell = cellFor(row, mapping.descriptionColumn);
      final debitCell = cellFor(row, mapping.debitColumn);
      final creditCell = cellFor(row, mapping.creditColumn);
      final amountCell = cellFor(row, mapping.amountColumn);
      final referenceCell = cellFor(row, mapping.referenceColumn);

      if (dateCell == null) {
        outcomes.add(CsvParseRowOutcome.issue(
          CsvRowIssue(rowNumber: rowNumber, message: 'Missing transaction date.', rawSnippet: row.join(', ')),
        ));
        continue;
      }

      final directionResult = _resolveDirection(
        mapping: mapping,
        debitCell: debitCell,
        creditCell: creditCell,
        amountCell: amountCell,
      );
      if (directionResult == null) {
        outcomes.add(CsvParseRowOutcome.issue(
          CsvRowIssue(
            rowNumber: rowNumber,
            message: 'Could not determine a valid transaction amount from this row.',
            rawSnippet: row.join(', '),
          ),
        ));
        continue;
      }

      final metadata = <String, dynamic>{'csvRowNumber': rowNumber};
      if (directionResult.isAmbiguous) metadata['directionAmbiguous'] = true;

      final parsedDate = CsvDateParser.parse(dateCell);
      if (parsedDate == null) {
        // A value IS present but couldn't be confidently parsed — PHASE 6:
        // this is a "needsReview" ambiguity, not a hard parse failure, so
        // it still becomes a record (with a null dateTime) rather than a
        // CsvRowIssue; CsvImportPipeline forces such records to
        // needsReview so the row stays visible and correctable-by-skip
        // rather than silently vanishing.
        metadata['unparseableDateText'] = dateCell;
      }

      outcomes.add(CsvParseRowOutcome.record(
        TransactionIngestionRecord(
          source: TransactionSource.csv,
          type: directionResult.type,
          amount: directionResult.amount,
          dateTime: parsedDate,
          merchant: descriptionCell,
          description: descriptionCell,
          walletId: walletId,
          currencyCode: 'INR',
          referenceId: referenceCell,
          metadata: metadata,
        ),
      ));
    }

    return outcomes;
  }

  /// PHASE 5 — direction is resolved as follows:
  /// - debit/credit columns present: exactly one populated with a
  ///   positive amount -> that direction. Both populated, or neither ->
  ///   the row can't be trusted, returns null (becomes a [CsvRowIssue]).
  /// - single amount column only: the amount is used, but direction is
  ///   ALWAYS marked ambiguous — sign is never treated as a debit/expense
  ///   convention (per PHASE 5's explicit "never infer" rule).
  static _RowDirection? _resolveDirection({
    required CsvColumnMapping mapping,
    required String? debitCell,
    required String? creditCell,
    required String? amountCell,
  }) {
    if (mapping.hasExplicitDirectionColumns) {
      final debit = CsvAmountParser.parse(debitCell);
      final credit = CsvAmountParser.parse(creditCell);
      final debitPresent = CsvAmountParser.hasContent(debitCell);
      final creditPresent = CsvAmountParser.hasContent(creditCell);

      final debitValid = debitPresent && debit != null && debit > 0;
      final creditValid = creditPresent && credit != null && credit > 0;

      if (debitValid && !creditValid) {
        return _RowDirection(IngestionTransactionType.expense, debit.abs());
      }
      if (creditValid && !debitValid) {
        return _RowDirection(IngestionTransactionType.income, credit.abs());
      }
      // Neither populated, both populated, or a populated cell that
      // failed to parse as a number — never guess.
      return null;
    }

    if (mapping.amountColumn != null) {
      final amount = CsvAmountParser.parse(amountCell);
      if (amount == null) return null;
      return _RowDirection(IngestionTransactionType.expense, amount.abs(), isAmbiguous: true);
    }

    return null;
  }
}
