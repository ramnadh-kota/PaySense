import '../models/csv_import_session.dart';

/// CSV BANK STATEMENT IMPORT — PHASE 3. Deterministic column matching
/// only — every header is compared against a FIXED alias list after
/// case/whitespace/punctuation normalization. This deliberately does NOT
/// do fuzzy/similarity matching: a header that isn't an exact normalized
/// match to a known alias is left unmapped rather than guessed, so a
/// wrong column is never silently assigned (per this phase's own
/// instruction).
class CsvColumnDetector {
  CsvColumnDetector._();

  static const List<String> dateAliases = [
    'date',
    'transactiondate',
    'txndate',
    'valuedate',
    'trandate',
    'postdate',
  ];

  static const List<String> descriptionAliases = [
    'description',
    'narration',
    'transactiondetails',
    'remarks',
    'particulars',
    'transactionremarks',
  ];

  static const List<String> debitAliases = [
    'debit',
    'withdrawal',
    'debitamount',
    'withdrawalamount',
    'withdrawalamt',
    'debitamt',
  ];

  static const List<String> creditAliases = [
    'credit',
    'deposit',
    'creditamount',
    'depositamount',
    'depositamt',
    'creditamt',
  ];

  static const List<String> amountAliases = ['amount', 'transactionamount', 'amountinr'];

  static const List<String> balanceAliases = ['balance', 'closingbalance', 'availablebalance'];

  static const List<String> referenceAliases = [
    'reference',
    'refno',
    'refnumber',
    'utr',
    'transactionid',
    'chqrefno',
    'chequerefno',
    'chequenumber',
  ];

  /// Lowercases, strips everything but letters/digits — turns
  /// `"Txn Date"`, `"txn-date"`, `"Txn_Date"` and `"TXN DATE"` all into
  /// the same comparable key: `"txndate"`.
  static String normalizeHeader(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _firstMatch(List<String> headers, List<String> aliases) {
    for (final header in headers) {
      if (aliases.contains(normalizeHeader(header))) return header;
    }
    return null;
  }

  /// Builds the best-effort [CsvColumnMapping] purely from header text —
  /// no row content is inspected here (that's [CsvFormatDetector]'s job
  /// for bank identification; this is column identification only).
  static CsvColumnMapping detectColumns(List<String> headers) {
    return CsvColumnMapping(
      dateColumn: _firstMatch(headers, dateAliases),
      descriptionColumn: _firstMatch(headers, descriptionAliases),
      debitColumn: _firstMatch(headers, debitAliases),
      creditColumn: _firstMatch(headers, creditAliases),
      amountColumn: _firstMatch(headers, amountAliases),
      balanceColumn: _firstMatch(headers, balanceAliases),
      referenceColumn: _firstMatch(headers, referenceAliases),
    );
  }
}
