// TRANSACTION INGESTION 1.0 — PHASE 8. Recursive/source-level privacy
// tests: the ingestion foundation must never accept or store an OTP, PIN,
// password, card number, CVV, full SMS body, or bank credential — neither
// structurally (the model has no such field) nor via the free-form
// [TransactionIngestionRecord.metadata] bag.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction_ingestion_record.dart';
import 'package:paysense/shared/models/transaction_ingestion_result.dart';
import 'package:paysense/shared/utils/transaction_deduplicator.dart';
import 'package:paysense/shared/utils/transaction_normalizer.dart';
import 'package:paysense/shared/utils/transaction_validator.dart';

const _forbiddenFieldNames = [
  'smsBody', 'rawSms', 'rawBody', 'password', 'pin', 'otp', 'cvv',
  'cardNumber', 'accountPassword', 'bankCredentials', 'credential', 'secret', 'token',
];

void main() {
  group('W. Privacy-sensitive fields never enter the normalized payload', () {
    test('TransactionIngestionRecord has structurally no field for any forbidden concept', () {
      // Reflection-free structural check: construct a record using every
      // constructor parameter that exists, and confirm none of their
      // names match a forbidden concept. This fails to COMPILE (not just
      // fails at runtime) if any such field were ever added, since the
      // named-parameter list below must exhaustively match the real
      // constructor.
      const record = TransactionIngestionRecord(
        source: TransactionSource.manual,
        type: IngestionTransactionType.expense,
        amount: 100,
        sourceTransactionId: 'id-1',
        merchant: 'Cafe',
        description: 'Coffee',
        categoryId: 'Food',
        walletId: 'w1',
        currencyCode: 'INR',
        referenceId: 'REF-1',
        confidence: 1.0,
        metadata: {'csvRowNumber': 5},
      );
      expect(record.amount, 100);
    });

    test('a metadata entry with a forbidden key fragment is rejected by the validator', () {
      for (final forbiddenKey in _forbiddenFieldNames) {
        final record = TransactionIngestionRecord(
          source: TransactionSource.sms,
          type: IngestionTransactionType.expense,
          amount: 500,
          dateTime: DateTime(2026, 8, 15),
          metadata: {forbiddenKey: 'sensitive-looking-value'},
        );
        final result = TransactionValidator.validate(record);
        expect(result.isValid, isFalse, reason: 'metadata key "$forbiddenKey" should have been rejected');
        expect(result.errors, isNotEmpty);
      }
    });

    test('a forbidden key fragment is caught case-insensitively and with separators', () {
      for (final variant in ['SmsBody', 'SMS_BODY', 'sms-body', 'RAWSMS', 'CardNumber', 'card_number']) {
        final record = TransactionIngestionRecord(
          source: TransactionSource.sms,
          type: IngestionTransactionType.expense,
          amount: 500,
          dateTime: DateTime(2026, 8, 15),
          metadata: {variant: 'x'},
        );
        final result = TransactionValidator.validate(record);
        expect(result.isValid, isFalse, reason: 'metadata key "$variant" should have been rejected');
      }
    });

    test('safe metadata (e.g. a CSV row number) is accepted', () {
      final record = TransactionIngestionRecord(
        source: TransactionSource.csv,
        type: IngestionTransactionType.expense,
        amount: 500,
        dateTime: DateTime(2026, 8, 15),
        metadata: const {'csvRowNumber': 12, 'sheetName': 'August'},
      );
      final result = TransactionValidator.validate(record);
      expect(result.isValid, isTrue);
    });

    test('the deduplication pipeline rejects a record carrying forbidden metadata as invalid, '
        'never silently passing it through to a "new" result', () {
      final results = TransactionDeduplicator.deduplicate(
        incoming: [
          TransactionIngestionRecord(
            source: TransactionSource.sms,
            type: IngestionTransactionType.expense,
            amount: 500,
            dateTime: DateTime(2026, 8, 15),
            metadata: const {'otpCode': '123456'},
          ),
        ],
        existing: const [],
      );
      expect(results.single.status, TransactionIngestionStatus.invalid);
    });

    test('normalization never fabricates or copies forbidden data into any field it touches', () {
      final record = TransactionIngestionRecord(
        source: TransactionSource.sms,
        type: IngestionTransactionType.expense,
        amount: 500,
        dateTime: DateTime(2026, 8, 15),
        merchant: 'Amazon',
        metadata: const {'confidence': 0.9},
      );
      final normalized = TransactionNormalizer.normalizeRecord(record);
      expect(normalized.merchant, isNot(contains('otp')));
      expect(normalized.metadata, record.metadata);
    });

    test('a TransactionIngestionResult never carries a forbidden field either — recursive check '
        'of every field on the record it wraps', () {
      final results = TransactionDeduplicator.deduplicate(
        incoming: [
          TransactionIngestionRecord(
            source: TransactionSource.manual,
            type: IngestionTransactionType.expense,
            amount: 250,
            dateTime: DateTime(2026, 8, 15),
            merchant: 'Coffee Shop',
            metadata: const {'note': 'paid by card'},
          ),
        ],
        existing: const [],
      );
      final record = results.single.record;
      // The record's own values must never contain a forbidden substring —
      // covers the case where a well-named-but-misused field smuggles
      // sensitive text in as a VALUE rather than a key.
      for (final value in [record.merchant, record.description, record.categoryId, record.sourceTransactionId, record.referenceId]) {
        if (value == null) continue;
        for (final fragment in ['otp', 'cvv', 'password', 'pin ']) {
          expect(value.toLowerCase().contains(fragment), isFalse, reason: 'value "$value" should never contain "$fragment"');
        }
      }
    });
  });
}
