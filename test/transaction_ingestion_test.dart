// TRANSACTION INGESTION 1.0 — PHASE 9. Comprehensive pure-Dart tests for
// the normalization/validation/fingerprinting/deduplication foundation.
// No repository, no Hive, no widget — every test constructs synthetic
// TransactionIngestionRecord/Transaction fixtures directly.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/transaction_ingestion_record.dart';
import 'package:paysense/shared/models/transaction_ingestion_result.dart';
import 'package:paysense/shared/utils/transaction_deduplicator.dart';
import 'package:paysense/shared/utils/transaction_fingerprint_calculator.dart';
import 'package:paysense/shared/utils/transaction_normalizer.dart';

// `walletId` defaults via a plain string literal (a real compile-time
// constant, safe with `= 'w1'`). `DateTime` is NOT const-constructible in
// Dart, so its default can't live in the parameter list the same way —
// `includeDate: false` is the explicit opt-out a test uses to construct a
// record with a genuinely missing date, rather than relying on `??`
// (which would silently replace an intentional null with the default).
TransactionIngestionRecord _record({
  TransactionSource source = TransactionSource.manual,
  IngestionTransactionType type = IngestionTransactionType.expense,
  double amount = 500,
  String? sourceTransactionId,
  DateTime? dateTime,
  bool includeDate = true,
  String? merchant,
  String? description,
  String? categoryId,
  String? walletId = 'w1',
  String? currencyCode,
  String? referenceId,
  double? confidence,
  Map<String, dynamic> metadata = const {},
}) {
  return TransactionIngestionRecord(
    source: source,
    type: type,
    amount: amount,
    sourceTransactionId: sourceTransactionId,
    dateTime: includeDate ? (dateTime ?? DateTime(2026, 8, 15, 10, 30)) : null,
    merchant: merchant,
    description: description,
    categoryId: categoryId,
    walletId: walletId,
    currencyCode: currencyCode,
    referenceId: referenceId,
    confidence: confidence,
    metadata: metadata,
  );
}

Transaction _existingTransaction({
  required String id,
  String title = 'Amazon',
  double amount = 500,
  String categoryId = 'Shopping',
  String accountId = 'w1',
  String transactionType = 'expense',
  DateTime? createdAt,
}) {
  return Transaction(
    id: id, title: title, amount: amount, categoryId: categoryId, accountId: accountId,
    transactionType: transactionType, paymentMethod: 'card', note: '',
    createdAt: createdAt ?? DateTime(2026, 8, 15, 10, 30),
  );
}

List<TransactionIngestionResult> _run(List<TransactionIngestionRecord> incoming, {List<Transaction> existing = const []}) {
  return TransactionDeduplicator.deduplicate(incoming: incoming, existing: existing);
}

void main() {
  group('A/B. Manual expense/income', () {
    test('A. a manual expense normalizes and validates cleanly as new', () {
      final results = _run([
        _record(source: TransactionSource.manual, type: IngestionTransactionType.expense, amount: 500, merchant: 'Amazon'),
      ]);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
      expect(results.single.validationErrors, isEmpty);
    });

    test('B. a manual income normalizes and validates cleanly as new', () {
      final results = _run([
        _record(source: TransactionSource.manual, type: IngestionTransactionType.income, amount: 50000, merchant: 'Salary'),
      ]);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });
  });

  group('C/D. SMS/CSV expense', () {
    test('C. an SMS-sourced expense is a normal new record', () {
      final results = _run([
        _record(source: TransactionSource.sms, type: IngestionTransactionType.expense, amount: 1200, merchant: 'Swiggy', confidence: 0.9),
      ]);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });

    test('D. a CSV-sourced expense is a normal new record', () {
      final results = _run([
        _record(source: TransactionSource.csv, type: IngestionTransactionType.expense, amount: 1200, merchant: 'Swiggy'),
      ]);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });
  });

  group('E. Same SMS + CSV transaction → duplicate', () {
    test('when both carry the same bank reference, the second is a confident duplicate', () {
      final results = _run([
        _record(source: TransactionSource.sms, type: IngestionTransactionType.expense, amount: 899, merchant: 'Amazon', referenceId: 'UTR12345'),
        _record(source: TransactionSource.csv, type: IngestionTransactionType.expense, amount: 899, merchant: 'Amazon Pay', referenceId: 'utr12345'),
      ]);
      expect(results[0].status, TransactionIngestionStatus.newRecord);
      expect(results[1].status, TransactionIngestionStatus.duplicate);
      expect(results[1].fingerprint.isStrong, isTrue);
    });

    test('honest limitation: without any shared strong identifier (today\'s real SMS parser extracts '
        'no reference number), the SAME transaction from SMS and CSV lands in needsReview, never a '
        'silent auto-duplicate', () {
      final results = _run([
        _record(source: TransactionSource.sms, type: IngestionTransactionType.expense, amount: 899, merchant: 'Amazon'),
        _record(source: TransactionSource.csv, type: IngestionTransactionType.expense, amount: 899, merchant: 'Amazon'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.needsReview);
    });
  });

  group('F. Same CSV + manual transaction → duplicate/needsReview depending on identifiers', () {
    test('with a shared source transaction id, classified as duplicate', () {
      final results = _run([
        _record(source: TransactionSource.csv, type: IngestionTransactionType.expense, amount: 300, merchant: 'Coffee', sourceTransactionId: 'row-42'),
        _record(source: TransactionSource.manual, type: IngestionTransactionType.expense, amount: 300, merchant: 'Coffee', sourceTransactionId: 'row-42'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.duplicate);
    });

    test('without any strong identifier, classified as needsReview, never silently dropped', () {
      final results = _run([
        _record(source: TransactionSource.csv, type: IngestionTransactionType.expense, amount: 300, merchant: 'Coffee'),
        _record(source: TransactionSource.manual, type: IngestionTransactionType.expense, amount: 300, merchant: 'Coffee'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.needsReview);
    });
  });

  group('G. Same merchant + amount + day, genuinely different transactions', () {
    test('two same-day, same-merchant, same-amount records with distinguishing reference ids stay separate', () {
      final results = _run([
        _record(type: IngestionTransactionType.expense, amount: 200, merchant: 'Starbucks', referenceId: 'REF-A'),
        _record(type: IngestionTransactionType.expense, amount: 200, merchant: 'Starbucks', referenceId: 'REF-B'),
      ]);
      expect(results[0].status, TransactionIngestionStatus.newRecord);
      expect(results[1].status, TransactionIngestionStatus.newRecord);
    });

    test('without any distinguishing evidence, ambiguous same-day duplicates are flagged for review, '
        'never silently collapsed into one', () {
      final results = _run([
        _record(type: IngestionTransactionType.expense, amount: 200, merchant: 'Starbucks'),
        _record(type: IngestionTransactionType.expense, amount: 200, merchant: 'Starbucks'),
      ]);
      expect(results[0].status, TransactionIngestionStatus.newRecord);
      expect(results[1].status, TransactionIngestionStatus.needsReview);
      // Critically: NOT silently dropped — both results are still present.
      expect(results.length, 2);
    });
  });

  group('H. Refund', () {
    test('a refund never deduplicates against the original expense purchase', () {
      final results = _run(
        [_record(type: IngestionTransactionType.refund, amount: 899, merchant: 'Amazon')],
        existing: [_existingTransaction(id: 'e1', title: 'Amazon', amount: 899, transactionType: 'expense')],
      );
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });

    test('a refund maps to the existing "income" transactionType string when eventually persisted', () {
      expect(IngestionTransactionType.refund.toTransactionTypeString(), 'income');
    });
  });

  group('I. Transfer', () {
    test('a transfer never deduplicates against an expense or income of the same amount/date/merchant', () {
      final results = _run(
        [_record(type: IngestionTransactionType.transfer, amount: 5000, merchant: 'Own Account')],
        existing: [
          _existingTransaction(id: 'e1', title: 'Own Account', amount: 5000, transactionType: 'expense'),
          _existingTransaction(id: 'e2', title: 'Own Account', amount: 5000, transactionType: 'income'),
        ],
      );
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });

    test('transfer maps to the existing "transfer" transactionType string', () {
      expect(IngestionTransactionType.transfer.toTransactionTypeString(), 'transfer');
    });
  });

  group('J/K. Different dates and amounts', () {
    test('J. the same merchant on different dates never deduplicates', () {
      final results = _run([
        _record(amount: 500, merchant: 'Amazon', dateTime: DateTime(2026, 8, 1)),
        _record(amount: 500, merchant: 'Amazon', dateTime: DateTime(2026, 8, 2)),
      ]);
      expect(results[1].status, TransactionIngestionStatus.newRecord);
    });

    test('K. the same merchant on the same date but a different amount never deduplicates', () {
      final results = _run([
        _record(amount: 500, merchant: 'Amazon'),
        _record(amount: 700, merchant: 'Amazon'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.newRecord);
    });
  });

  group('L/M. Formatting differences', () {
    test('L. merchant formatting differences ("Amazon-Pay" vs "amazon pay") still deduplicate', () {
      final results = _run([
        _record(amount: 250, merchant: 'Amazon-Pay', referenceId: 'REF-X'),
        _record(amount: 250, merchant: '  amazon   pay  ', referenceId: 'ref-x'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.duplicate);
    });

    test('M. currency formatting differences ("inr" vs "INR") normalize identically', () {
      final normalizedA = TransactionNormalizer.normalizeCurrency('inr');
      final normalizedB = TransactionNormalizer.normalizeCurrency(' INR ');
      expect(normalizedA, normalizedB);
      expect(normalizedA, 'INR');
    });
  });

  group('N/O. Missing reference/merchant', () {
    test('N. a missing reference falls back to the weak fingerprint without crashing', () {
      final results = _run([_record(referenceId: null, sourceTransactionId: null)]);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
      expect(results.single.fingerprint.isStrong, isFalse);
    });

    test('O. a missing merchant is handled safely, never fabricated', () {
      final results = _run([_record(merchant: null)]);
      expect(results.single.record.merchant, isNull);
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });
  });

  group('P/Q/R. Invalid data', () {
    test('P. a zero or negative amount is invalid, never crashes the batch', () {
      final results = _run([_record(amount: 0), _record(amount: -50), _record(amount: 100)]);
      expect(results[0].status, TransactionIngestionStatus.invalid);
      expect(results[1].status, TransactionIngestionStatus.invalid);
      expect(results[2].status, TransactionIngestionStatus.newRecord);
      expect(results[0].validationErrors, isNotEmpty);
    });

    test('Q. a missing date is invalid, never defaulted to DateTime.now()', () {
      final results = _run([_record(includeDate: false)]);
      expect(results.single.status, TransactionIngestionStatus.invalid);
      expect(results.single.validationErrors.any((e) => e.contains('date')), isTrue);
    });

    test('R. an empty-string merchant normalizes to null rather than an empty string', () {
      final normalized = TransactionNormalizer.normalizeMerchant('   ');
      expect(normalized, isNull);
    });

    test('NaN/Infinity amounts are rejected as invalid, never silently accepted', () {
      final results = _run([_record(amount: double.nan), _record(amount: double.infinity)]);
      expect(results[0].status, TransactionIngestionStatus.invalid);
      expect(results[1].status, TransactionIngestionStatus.invalid);
    });

    test('an unsupported currency is invalid', () {
      final results = _run([_record(currencyCode: 'XYZ')]);
      expect(results.single.status, TransactionIngestionStatus.invalid);
      expect(results.single.validationErrors.any((e) => e.contains('currency')), isTrue);
    });
  });

  group('S. Multiple transactions in one day', () {
    test('several distinct transactions on the same day, each with its own reference, all stay new', () {
      final results = _run([
        _record(amount: 100, merchant: 'Cafe', referenceId: 'R1'),
        _record(amount: 200, merchant: 'Cafe', referenceId: 'R2'),
        _record(amount: 300, merchant: 'Cafe', referenceId: 'R3'),
      ]);
      expect(results.every((r) => r.status == TransactionIngestionStatus.newRecord), isTrue);
    });
  });

  group('T. Recurring subscription payments', () {
    test('the same subscription merchant/amount on different months never deduplicates', () {
      final results = _run(
        [_record(amount: 499, merchant: 'Netflix', dateTime: DateTime(2026, 8, 5))],
        existing: [_existingTransaction(id: 'e1', title: 'Netflix', amount: 499, createdAt: DateTime(2026, 7, 5))],
      );
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });
  });

  group('U. Income transactions', () {
    test('income never deduplicates against an expense of the same amount/date/merchant', () {
      final results = _run(
        [_record(type: IngestionTransactionType.income, amount: 1000, merchant: 'Refund Co')],
        existing: [_existingTransaction(id: 'e1', title: 'Refund Co', amount: 1000, transactionType: 'expense')],
      );
      expect(results.single.status, TransactionIngestionStatus.newRecord);
    });
  });

  group('V. Wallet/account differences', () {
    test('the same date/amount/merchant on two DIFFERENT wallets stays separate', () {
      final results = _run([
        _record(amount: 500, merchant: 'Rent', walletId: 'w1'),
        _record(amount: 500, merchant: 'Rent', walletId: 'w2'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.newRecord);
    });

    test('the same date/amount/merchant on the SAME wallet is flagged for review', () {
      final results = _run([
        _record(amount: 500, merchant: 'Rent', walletId: 'w1'),
        _record(amount: 500, merchant: 'Rent', walletId: 'w1'),
      ]);
      expect(results[1].status, TransactionIngestionStatus.needsReview);
    });
  });

  group('Fingerprint determinism', () {
    test('the same normalized input always produces the same fingerprint across multiple runs', () {
      final record = _record(amount: 500, merchant: 'Amazon', referenceId: 'REF-1');
      final normalized = TransactionNormalizer.normalizeRecord(record);
      final first = TransactionFingerprintCalculator.compute(normalized);
      final second = TransactionFingerprintCalculator.compute(normalized);
      final third = TransactionFingerprintCalculator.compute(normalized);
      expect(first.hash, second.hash);
      expect(second.hash, third.hash);
    });

    test('equivalent SMS/CSV representations of the same stable data produce the same fingerprint', () {
      final smsRecord = TransactionNormalizer.normalizeRecord(
        _record(source: TransactionSource.sms, amount: 899, merchant: 'AMAZON-PAY', referenceId: 'utr999'),
      );
      final csvRecord = TransactionNormalizer.normalizeRecord(
        _record(source: TransactionSource.csv, amount: 899.00, merchant: '  amazon pay ', referenceId: 'UTR999'),
      );
      expect(
        TransactionFingerprintCalculator.compute(smsRecord).hash,
        TransactionFingerprintCalculator.compute(csvRecord).hash,
      );
    });

    test('the weak fingerprint is stable across repeated calls with no strong id present', () {
      final normalized = TransactionNormalizer.normalizeRecord(_record(merchant: 'Cafe', amount: 150));
      final a = TransactionFingerprintCalculator.computeWeak(normalized);
      final b = TransactionFingerprintCalculator.computeWeak(normalized);
      expect(a.hash, b.hash);
      expect(a.isStrong, isFalse);
    });
  });

  group('Simulation safety — no mutation', () {
    test('deduplicate() never mutates its input lists or the existing Transaction objects', () {
      final incoming = [_record(amount: 500, merchant: 'Amazon')];
      final existing = [_existingTransaction(id: 'e1')];
      final incomingBefore = List.of(incoming);
      final existingBefore = List.of(existing);

      TransactionDeduplicator.deduplicate(incoming: incoming, existing: existing);

      expect(incoming, incomingBefore);
      expect(existing, existingBefore);
    });
  });
}
