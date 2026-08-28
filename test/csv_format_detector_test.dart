import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/csv_import_session.dart';
import 'package:paysense/shared/utils/csv_format_detector.dart';

void main() {
  group('CsvFormatDetector.detect — supported bank layouts', () {
    test('1. HDFC-style headers are detected with high confidence', () {
      final result = CsvFormatDetector.detect([
        'Date',
        'Narration',
        'Chq/Ref No.',
        'Value Date',
        'Withdrawal Amt.',
        'Deposit Amt.',
        'Closing Balance',
      ]);
      expect(result.detectedBank, DetectedBankFormat.hdfc);
      expect(result.confidence, greaterThanOrEqualTo(0.6));
      expect(result.requiresManualMapping, isFalse);
    });

    test('2. ICICI-style headers are detected with high confidence', () {
      final result = CsvFormatDetector.detect([
        'Transaction Date',
        'Transaction Remarks',
        'Withdrawal Amount (INR)',
        'Deposit Amount (INR)',
        'Balance (INR)',
      ]);
      expect(result.detectedBank, DetectedBankFormat.icici);
      expect(result.confidence, greaterThanOrEqualTo(0.6));
    });

    test('3. SBI-style headers are detected with high confidence', () {
      final result = CsvFormatDetector.detect([
        'Txn Date',
        'Value Date',
        'Debit',
        'Credit',
        'Ref No./Cheque No.',
      ]);
      expect(result.detectedBank, DetectedBankFormat.sbi);
      expect(result.confidence, greaterThanOrEqualTo(0.6));
    });

    test('4. Axis-style headers are detected with high confidence', () {
      final result = CsvFormatDetector.detect(['Tran Date', 'Particulars', 'Chq No', 'Debit', 'Credit']);
      expect(result.detectedBank, DetectedBankFormat.axis);
      expect(result.confidence, greaterThanOrEqualTo(0.6));
    });

    test('5. Kotak-style headers are detected with high confidence', () {
      final result = CsvFormatDetector.detect([
        'Transaction Date',
        'Description',
        'Withdrawal (Dr)',
        'Deposit (Cr)',
      ]);
      expect(result.detectedBank, DetectedBankFormat.kotak);
      expect(result.confidence, greaterThanOrEqualTo(0.6));
    });

    test('6. a clearly generic layout is reported as generic, not guessed', () {
      final result = CsvFormatDetector.detect(['Date', 'Description', 'Amount']);
      expect(result.detectedBank, DetectedBankFormat.generic);
      expect(result.requiresManualMapping, isFalse); // date+amount is enough to parse
    });

    test('24. an unrecognizable/foreign-language header set never fabricates a bank name', () {
      final result = CsvFormatDetector.detect(['Fecha', 'Descripcion', 'Importe']);
      expect(result.detectedBank, DetectedBankFormat.generic);
      expect(result.confidence, lessThan(0.6));
      expect(result.requiresManualMapping, isTrue);
    });

    test('confidence is never reported high for a generic/unmatched file', () {
      final result = CsvFormatDetector.detect(['Date', 'Notes', 'Value']);
      expect(result.detectedBank, DetectedBankFormat.generic);
      expect(result.confidence, lessThan(0.6));
    });
  });
}
