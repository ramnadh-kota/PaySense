import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/utils/csv_column_detector.dart';

void main() {
  group('CsvColumnDetector.normalizeHeader', () {
    test('lowercases and strips punctuation/whitespace', () {
      expect(CsvColumnDetector.normalizeHeader('Txn Date'), 'txndate');
      expect(CsvColumnDetector.normalizeHeader('txn-date'), 'txndate');
      expect(CsvColumnDetector.normalizeHeader('Txn_Date'), 'txndate');
      expect(CsvColumnDetector.normalizeHeader('  TXN DATE  '), 'txndate');
    });
  });

  group('CsvColumnDetector.detectColumns', () {
    test('recognizes common date column variants', () {
      for (final header in ['Date', 'Transaction Date', 'Txn Date', 'Value Date']) {
        final mapping = CsvColumnDetector.detectColumns([header, 'Description', 'Amount']);
        expect(mapping.dateColumn, header, reason: 'failed for "$header"');
      }
    });

    test('recognizes common description column variants', () {
      for (final header in ['Description', 'Narration', 'Transaction Details', 'Remarks']) {
        final mapping = CsvColumnDetector.detectColumns(['Date', header, 'Amount']);
        expect(mapping.descriptionColumn, header, reason: 'failed for "$header"');
      }
    });

    test('recognizes common debit column variants', () {
      for (final header in ['Debit', 'Withdrawal', 'Debit Amount', 'Withdrawal Amount']) {
        final mapping = CsvColumnDetector.detectColumns(['Date', header, 'Credit']);
        expect(mapping.debitColumn, header, reason: 'failed for "$header"');
      }
    });

    test('recognizes common credit column variants', () {
      for (final header in ['Credit', 'Deposit', 'Credit Amount', 'Deposit Amount']) {
        final mapping = CsvColumnDetector.detectColumns(['Date', 'Debit', header]);
        expect(mapping.creditColumn, header, reason: 'failed for "$header"');
      }
    });

    test('recognizes amount, balance, and reference variants', () {
      final mapping = CsvColumnDetector.detectColumns([
        'Date',
        'Amount',
        'Closing Balance',
        'UTR',
      ]);
      expect(mapping.amountColumn, 'Amount');
      expect(mapping.balanceColumn, 'Closing Balance');
      expect(mapping.referenceColumn, 'UTR');
    });

    test('an unrecognized header is left unmapped rather than guessed', () {
      final mapping = CsvColumnDetector.detectColumns(['Date', 'Some Weird Column', 'Amount']);
      expect(mapping.descriptionColumn, isNull);
      expect(mapping.referenceColumn, isNull);
    });

    test('a header with no exact alias match is never fuzzy-matched to the wrong field', () {
      // "Balance" must map to balance, never be mistaken for "amount" or
      // "credit" just because it sounds financially related.
      final mapping = CsvColumnDetector.detectColumns(['Date', 'Balance', 'Amount']);
      expect(mapping.balanceColumn, 'Balance');
      expect(mapping.creditColumn, isNull);
    });
  });
}
