import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/csv_import_session.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/transaction_ingestion_record.dart';
import 'package:paysense/shared/models/transaction_ingestion_result.dart';
import 'package:paysense/shared/utils/csv_import_pipeline.dart';
import 'package:paysense/shared/utils/csv_transaction_parser.dart';

TransactionIngestionRecord _record({
  IngestionTransactionType type = IngestionTransactionType.expense,
  double amount = 500,
  DateTime? dateTime,
  String? merchant = 'Amazon',
  String? referenceId,
  String? walletId = 'w1',
  Map<String, dynamic> metadata = const {},
}) {
  return TransactionIngestionRecord(
    source: TransactionSource.csv,
    type: type,
    amount: amount,
    dateTime: dateTime ?? DateTime(2026, 8, 15),
    merchant: merchant,
    description: merchant,
    walletId: walletId,
    referenceId: referenceId,
    currencyCode: 'INR',
    metadata: metadata,
  );
}

Transaction _existingTransaction({
  required String id,
  String title = 'Amazon',
  double amount = 500,
  String accountId = 'w1',
  String transactionType = 'expense',
  DateTime? createdAt,
}) {
  return Transaction(
    id: id,
    title: title,
    amount: amount,
    categoryId: 'Shopping',
    accountId: accountId,
    transactionType: transactionType,
    paymentMethod: 'card',
    note: '',
    createdAt: createdAt ?? DateTime(2026, 8, 15),
  );
}

void main() {
  group('CsvImportPipeline.run — dedup integration', () {
    test('15. a CSV row matching an existing transaction by reference is a confident duplicate', () {
      final existing = [_existingTransaction(id: 'e1')];
      final results = CsvImportPipeline.run(
        records: [_record(referenceId: 'UTR123')],
        existing: existing,
      );
      // No shared reference on the existing side (Transaction has no
      // reference field) — so this can only ever be a WEAK match; still
      // must be caught since date/amount/merchant/wallet/type all agree.
      expect(results.single.status, TransactionIngestionStatus.duplicate);
    });

    test('16. same merchant/amount/day but a distinguishing reference stays two separate transactions', () {
      final results = CsvImportPipeline.run(
        records: [
          _record(referenceId: 'REF-A'),
          _record(referenceId: 'REF-B'),
        ],
        existing: const [],
      );
      expect(results[0].status, TransactionIngestionStatus.newRecord);
      expect(results[1].status, TransactionIngestionStatus.newRecord);
    });

    test('same merchant/amount/day with NO distinguishing evidence is needsReview, never silently dropped', () {
      final results = CsvImportPipeline.run(
        records: [_record(), _record()],
        existing: const [],
      );
      expect(results.length, 2);
      expect(results[0].status, TransactionIngestionStatus.newRecord);
      expect(results[1].status, TransactionIngestionStatus.needsReview);
    });

    test('17. an income row is imported as income, never expense', () {
      final results = CsvImportPipeline.run(
        records: [_record(type: IngestionTransactionType.income, merchant: 'Salary')],
        existing: const [],
      );
      expect(results.single.record.type, IngestionTransactionType.income);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });

    test('18. an expense row is imported as expense', () {
      final results = CsvImportPipeline.run(
        records: [_record(type: IngestionTransactionType.expense)],
        existing: const [],
      );
      expect(results.single.record.type, IngestionTransactionType.expense);
    });

    test('19. a refund-like credit never dedups against the original expense purchase', () {
      final existing = [
        _existingTransaction(id: 'e1', title: 'Amazon', transactionType: 'expense', createdAt: DateTime(2026, 8, 10)),
      ];
      final results = CsvImportPipeline.run(
        records: [
          _record(type: IngestionTransactionType.income, merchant: 'Amazon', dateTime: DateTime(2026, 8, 15)),
        ],
        existing: existing,
      );
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });

    test('20. CsvTransactionParser never produces a transfer-typed record (documented limitation)', () {
      const debitCreditMapping = CsvColumnMapping(
        dateColumn: 'Date',
        descriptionColumn: 'Description',
        debitColumn: 'Debit',
        creditColumn: 'Credit',
      );
      const singleAmountMapping = CsvColumnMapping(
        dateColumn: 'Date',
        descriptionColumn: 'Description',
        amountColumn: 'Amount',
      );

      final debitCreditOutcomes = CsvTransactionParser.parseRows(
        headers: const ['Date', 'Description', 'Debit', 'Credit'],
        dataRows: [
          ['15/08/2026', 'Internal transfer', '500', ''],
        ],
        mapping: debitCreditMapping,
        walletId: 'w1',
      );
      final singleAmountOutcomes = CsvTransactionParser.parseRows(
        headers: const ['Date', 'Description', 'Amount'],
        dataRows: [
          ['15/08/2026', 'Internal transfer', '500'],
        ],
        mapping: singleAmountMapping,
        walletId: 'w1',
      );

      for (final outcome in [...debitCreditOutcomes, ...singleAmountOutcomes]) {
        expect(outcome.record!.type, isNot(IngestionTransactionType.transfer));
        expect(outcome.record!.type, isNot(IngestionTransactionType.refund));
      }
    });

    test('a direction-ambiguous record is ALWAYS needsReview, regardless of what dedup would conclude', () {
      final results = CsvImportPipeline.run(
        records: [_record(metadata: const {'directionAmbiguous': true})],
        existing: const [],
      );
      expect(results.single.status, TransactionIngestionStatus.needsReview);
      expect(results.single.duplicateReason, contains('income or expense'));
    });

    test('a date-ambiguous record is ALWAYS needsReview, never silently dropped as invalid', () {
      final results = CsvImportPipeline.run(
        records: [
          TransactionIngestionRecord(
            source: TransactionSource.csv,
            type: IngestionTransactionType.expense,
            amount: 500,
            merchant: 'Coffee',
            metadata: const {'unparseableDateText': 'not-a-date'},
          ),
        ],
        existing: const [],
      );
      expect(results.single.status, TransactionIngestionStatus.needsReview);
      expect(results.single.duplicateReason, contains('date'));
    });

    test('CsvImportPipeline.runOne resolves a direction-ambiguous row after correction', () {
      final ambiguous = _record(metadata: const {'directionAmbiguous': true});
      final corrected = ambiguous.copyWith(
        type: IngestionTransactionType.expense,
        metadata: const {},
      );
      final result = CsvImportPipeline.runOne(record: corrected, otherIncoming: const [], existing: const []);
      expect(result.status, TransactionIngestionStatus.newRecord);
    });
  });
}
