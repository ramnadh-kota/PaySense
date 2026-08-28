import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/utils/csv_amount_parser.dart';
import 'package:paysense/shared/utils/csv_date_parser.dart';

void main() {
  group('CsvAmountParser.parse', () {
    test('31. handles common currency formatting variants', () {
      expect(CsvAmountParser.parse('₹1,250.00'), 1250.00);
      expect(CsvAmountParser.parse('1,250.00'), 1250.00);
      expect(CsvAmountParser.parse('1250'), 1250.0);
      expect(CsvAmountParser.parse('1,250'), 1250.0);
    });

    test('12. a malformed amount is never silently reinterpreted', () {
      expect(CsvAmountParser.parse('abc'), isNull);
      expect(CsvAmountParser.parse('12,34,56x'), isNull);
      expect(CsvAmountParser.parse('₹--12'), isNull);
    });

    test('empty or missing cells return null, not zero', () {
      expect(CsvAmountParser.parse(null), isNull);
      expect(CsvAmountParser.parse(''), isNull);
      expect(CsvAmountParser.parse('   '), isNull);
    });

    test('negative amounts still parse (sign is preserved, not stripped)', () {
      expect(CsvAmountParser.parse('-500.00'), -500.0);
    });
  });

  group('CsvDateParser.parse', () {
    test('supports DD/MM/YYYY', () {
      expect(CsvDateParser.parse('01/02/2026'), DateTime(2026, 2, 1));
    });

    test('supports DD-MM-YYYY', () {
      expect(CsvDateParser.parse('15-08-2026'), DateTime(2026, 8, 15));
    });

    test('supports DD/MM/YY (2-digit year expands to 20YY)', () {
      expect(CsvDateParser.parse('01/02/26'), DateTime(2026, 2, 1));
    });

    test('supports ISO YYYY-MM-DD', () {
      expect(CsvDateParser.parse('2026-02-01'), DateTime(2026, 2, 1));
    });

    test('never turns February 1 into January 2 — day-first is applied consistently', () {
      final result = CsvDateParser.parse('01/02/2026');
      expect(result!.month, 2);
      expect(result.day, 1);
    });

    test('13. a malformed/unrecognized date string returns null, never guessed', () {
      expect(CsvDateParser.parse('yesterday'), isNull);
      expect(CsvDateParser.parse('Feb 1, 2026'), isNull);
      expect(CsvDateParser.parse(''), isNull);
      expect(CsvDateParser.parse(null), isNull);
    });

    test('14. an impossible calendar date is rejected, not rolled over', () {
      // 31 February does not exist — must not silently become March 3.
      expect(CsvDateParser.parse('31/02/2026'), isNull);
      expect(CsvDateParser.parse('2026-13-01'), isNull);
    });

    test('a date with a time component still parses to the correct day', () {
      final result = CsvDateParser.parse('15/08/2026 14:30');
      expect(result, DateTime(2026, 8, 15, 14, 30));
    });
  });
}
