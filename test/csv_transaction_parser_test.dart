import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/csv_import_session.dart';
import 'package:paysense/shared/models/transaction_ingestion_record.dart';
import 'package:paysense/shared/utils/csv_transaction_parser.dart';

void main() {
  group('CsvTransactionParser.readRows', () {
    test('9. quoted descriptions containing commas are parsed as a single field', () {
      const csv = 'Date,Description,Amount\r\n15/08/2026,"Amazon, Pay India",500\r\n';
      final rows = CsvTransactionParser.readRows(csv);
      expect(rows.length, 2);
      expect(rows[1], ['15/08/2026', 'Amazon, Pay India', '500']);
    });

    test('10. fully empty rows are skipped', () {
      const csv = 'Date,Description,Amount\r\n15/08/2026,Coffee,100\r\n\r\n,,\r\n16/08/2026,Tea,50\r\n';
      final rows = CsvTransactionParser.readRows(csv);
      // header + 2 real data rows only.
      expect(rows.length, 3);
    });

    test('handles Unix-style (\\n only) line endings', () {
      const csv = 'Date,Description,Amount\n15/08/2026,Coffee,100\n';
      final rows = CsvTransactionParser.readRows(csv);
      expect(rows.length, 2);
    });
  });

  group('CsvTransactionParser.parseRows — debit/credit columns', () {
    const mapping = CsvColumnMapping(
      dateColumn: 'Date',
      descriptionColumn: 'Description',
      debitColumn: 'Debit',
      creditColumn: 'Credit',
      referenceColumn: 'Ref',
    );
    const headers = ['Date', 'Description', 'Debit', 'Credit', 'Ref'];

    test('7. a debit-only row becomes an expense; a credit-only row becomes income', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Coffee Shop', '250.00', '', 'REF1'],
          ['16/08/2026', 'Salary', '', '50000.00', 'REF2'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );

      expect(outcomes.length, 2);
      expect(outcomes[0].record!.type, IngestionTransactionType.expense);
      expect(outcomes[0].record!.amount, 250.00);
      expect(outcomes[1].record!.type, IngestionTransactionType.income);
      expect(outcomes[1].record!.amount, 50000.00);
    });

    test('23. a row missing BOTH debit and credit values is a structural row issue, not a guess', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Mystery row', '', '', 'REF1'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes.single.record, isNull);
      expect(outcomes.single.issue, isNotNull);
    });

    test('a row with BOTH debit and credit populated is a structural row issue, never guessed', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Conflicting row', '100', '100', 'REF1'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes.single.record, isNull);
      expect(outcomes.single.issue, isNotNull);
    });

    test('21. a row with no description still parses (description/merchant are simply null)', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', '', '250.00', '', 'REF1'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes.single.record!.description, isNull);
      expect(outcomes.single.record!.merchant, isNull);
    });

    test('22. a row with no reference still parses (referenceId is simply null)', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Coffee', '250.00', '', ''],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes.single.record!.referenceId, isNull);
    });

    test('11. a row missing its date is a structural row issue, parsing continues for later rows', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['', 'No date', '100', '', 'REF1'],
          ['16/08/2026', 'Has date', '200', '', 'REF2'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes[0].issue, isNotNull);
      expect(outcomes[0].record, isNull);
      expect(outcomes[1].record, isNotNull);
      expect(outcomes[1].issue, isNull);
    });

    test('12. a malformed amount produces a row issue, not a crash', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Bad amount', 'not-a-number', '', 'REF1'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes.single.record, isNull);
      expect(outcomes.single.issue, isNotNull);
    });

    test('13. a malformed date still produces a record (needsReview later), never a crash', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['not-a-date', 'Weird date', '100', '', 'REF1'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      expect(outcomes.single.record, isNotNull);
      expect(outcomes.single.record!.dateTime, isNull);
      expect(outcomes.single.record!.metadata['unparseableDateText'], 'not-a-date');
    });
  });

  group('CsvTransactionParser.parseRows — single amount column', () {
    const mapping = CsvColumnMapping(dateColumn: 'Date', descriptionColumn: 'Description', amountColumn: 'Amount');
    const headers = ['Date', 'Description', 'Amount'];

    test('8. a single amount column always produces a direction-ambiguous record', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Unclear direction', '500'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      final record = outcomes.single.record!;
      expect(record.amount, 500.0);
      expect(record.metadata['directionAmbiguous'], isTrue);
    });

    test('never infers negative = expense from sign alone', () {
      final outcomes = CsvTransactionParser.parseRows(
        headers: headers,
        dataRows: [
          ['15/08/2026', 'Negative amount', '-500'],
        ],
        mapping: mapping,
        walletId: 'w1',
      );
      final record = outcomes.single.record!;
      // Amount is stored as a magnitude; direction is still marked
      // ambiguous rather than derived from the sign.
      expect(record.amount, 500.0);
      expect(record.metadata['directionAmbiguous'], isTrue);
    });
  });
}
