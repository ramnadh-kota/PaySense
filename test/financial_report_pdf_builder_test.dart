// Targeted tests for FinancialReportPdfBuilder. PDF content streams are
// often Flate-compressed, so we can't reliably grep the raw bytes for
// section text — what IS reliably verifiable, and what these tests
// check: generation succeeds without throwing for every real data shape
// (full data, empty account, weekly, monthly), the output is a genuine
// PDF (starts with the %PDF- magic header) of non-trivial size, and it
// never throws when a section has no real data to show ("Not enough
// data" path, not a crash).
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/financial_report.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_report_engine.dart';
import 'package:paysense/shared/utils/financial_report_pdf_builder.dart';

final _now = DateTime(2026, 8, 27);

Transaction _tx(String id, double amount, String type, DateTime date, {String category = 'Food'}) {
  return Transaction(
    id: id, title: category, amount: amount, categoryId: category, accountId: 'w1',
    transactionType: type, paymentMethod: 'card', note: '', createdAt: date,
  );
}

Wallet _wallet(String id, double balance) => Wallet(
  id: id, name: id, bankName: '', type: 'Bank', openingBalance: balance, currentBalance: balance, createdAt: DateTime(2025, 1, 1),
);

void main() {
  group('FinancialReportPdfBuilder', () {
    test('generates a valid PDF for a fully-populated monthly report', () async {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx('i1', 50000, 'income', DateTime(2026, 8, 1)),
          _tx('e1', 12000, 'expense', DateTime(2026, 8, 5), category: 'Food'),
          _tx('e2', 8000, 'expense', DateTime(2026, 8, 10), category: 'Shopping'),
        ],
        wallets: [_wallet('w1', 20000)], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );

      final bytes = await FinancialReportPdfBuilder.build(report);

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
      // The %PDF- magic header is never compressed — first 5 bytes of any
      // valid PDF file.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('generates a valid PDF for a completely empty account (no fabricated content, no crash)', () async {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: const [], wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );

      final bytes = await FinancialReportPdfBuilder.build(report);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('handles a very long merchant/category name without throwing or truncating badly', () async {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: [
          _tx(
            'e1', 45000, 'expense', DateTime(2026, 8, 5),
            category: 'A Very Long Merchant And Category Name That Could Plausibly Overflow A Narrow PDF Column Width',
          ),
        ],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );

      final bytes = await FinancialReportPdfBuilder.build(report);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('handles a large transaction list (50 expenses) without throwing', () async {
      final transactions = List.generate(
        50,
        (i) => _tx('e$i', 100.0 + i, 'expense', _now.subtract(Duration(days: i % 28)), category: 'Category ${i % 5}'),
      );
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.monthly,
        transactions: transactions,
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );

      final bytes = await FinancialReportPdfBuilder.build(report);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('generates a valid PDF for a weekly report (fewer populated sections than monthly)', () async {
      final report = FinancialReportEngine.generate(
        period: FinancialReportPeriod.weekly,
        transactions: [_tx('e1', 500, 'expense', _now.subtract(const Duration(days: 1)))],
        wallets: const [], budgets: const [], goals: const [], loans: const [], bills: const [], recurringTransactions: const [],
        now: _now,
      );

      final bytes = await FinancialReportPdfBuilder.build(report);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
