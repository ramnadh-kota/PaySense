import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/csv_import_session.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/transaction_ingestion_record.dart';
import 'package:paysense/shared/models/transaction_ingestion_result.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/csv_import_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/analytics_service.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
}

const _debitCreditCsv = 'Date,Description,Debit,Credit,Ref\r\n'
    '15/08/2026,Coffee Shop,250.00,,REF1\r\n'
    '16/08/2026,Salary,,50000.00,REF2\r\n';

void main() {
  late Directory tempDir;
  late ProviderContainer container;
  late Wallet wallet;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_csv_import_test');
    await _initHive(tempDir);

    wallet = Wallet(
      id: 'w1',
      name: 'HDFC Salary Account',
      bankName: 'HDFC',
      type: 'bank',
      openingBalance: 1000,
      currentBalance: 1000,
      createdAt: DateTime(2026, 1, 1),
    );
    await WalletRepository.instance.add(wallet);

    container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('preview never writes to the database', () async {
    await container
        .read(csvImportProvider.notifier)
        .loadCsvText(fileName: 'statement.csv', csvText: _debitCreditCsv);

    final session = container.read(csvImportProvider);
    expect(session.status, CsvImportStatus.previewReady);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
  });

  test('27. cancelling before confirmation leaves the database unchanged', () async {
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'statement.csv', csvText: _debitCreditCsv);
    await notifier.selectWallet('w1');
    // Simulate the user backing out here — never call confirmImport.
    notifier.reset();

    expect(await TransactionRepository.instance.getAll(), isEmpty);
    expect(container.read(csvImportProvider).status, CsvImportStatus.selecting);
  });

  test('26. confirming without a selected wallet writes nothing and reports the error', () async {
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'statement.csv', csvText: _debitCreditCsv);

    final result = await notifier.confirmImport();

    expect(result.importedCount, 0);
    expect(result.errors, isNotEmpty);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
  });

  test('34/import — only confirmed new rows are written, with wallet balances updated', () async {
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'statement.csv', csvText: _debitCreditCsv);
    await notifier.selectWallet('w1');

    final result = await notifier.confirmImport();

    expect(result.importedCount, 2);
    expect(result.failedCount, 0);

    final stored = await TransactionRepository.instance.getAll();
    expect(stored.length, 2);
    expect(stored.any((t) => t.transactionType == 'expense' && t.amount == 250.0), isTrue);
    expect(stored.any((t) => t.transactionType == 'income' && t.amount == 50000.0), isTrue);
    expect(stored.every((t) => t.paymentMethod == 'csv'), isTrue);
    expect(stored.every((t) => t.accountId == 'w1'), isTrue);

    final updatedWallet = await WalletRepository.instance.getById('w1');
    // opening 1000 - 250 (expense) + 50000 (income) = 50750
    expect(updatedWallet!.currentBalance, 50750.0);
  });

  test('29. an import consisting entirely of duplicates writes nothing new', () async {
    // Seed an existing transaction identical (by weak fingerprint) to the
    // one row this CSV contains. The CSV row carries its OWN reference id
    // — an existing `Transaction` can never itself produce a strong
    // fingerprint (it has no reference field), but an INCOMING record
    // with a reference id is still confidently matched against the
    // existing weak fingerprint (Phase 1 rule 2). A row with no
    // reference at all would only ever reach `needsReview`, never a
    // confident `duplicate` — see the un-referenced case covered by the
    // "zero ready-to-import rows" test below.
    await TransactionRepository.instance.add(
      Transaction(
        id: 'existing-1',
        title: 'Coffee Shop',
        amount: 250.0,
        categoryId: 'Shopping',
        accountId: 'w1',
        transactionType: 'expense',
        paymentMethod: 'card',
        note: '',
        createdAt: DateTime(2026, 8, 15),
      ),
    );

    const csv = 'Date,Description,Debit,Credit,UTR\r\n15/08/2026,Coffee Shop,250.00,,UTR999\r\n';
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'dup.csv', csvText: csv);
    await notifier.selectWallet('w1');

    expect(container.read(csvImportProvider).duplicateCount, 1);

    final result = await notifier.confirmImport();
    expect(result.importedCount, 0);
    expect(result.duplicateCount, 1);

    final stored = await TransactionRepository.instance.getAll();
    expect(stored.length, 1); // only the pre-seeded one — nothing new written
  });

  test('30. a partially malformed file still imports every well-formed row', () async {
    const csv = 'Date,Description,Debit,Credit\r\n'
        '15/08/2026,Good row one,100.00,\r\n'
        'not-a-date,Bad date row,50.00,\r\n'
        '16/08/2026,Bad amount row,notanumber,\r\n'
        '17/08/2026,Good row two,,200.00\r\n';

    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'partial.csv', csvText: csv);
    final session = container.read(csvImportProvider);

    // "bad date" row becomes needsReview (metadata-flagged), "bad amount"
    // row becomes a structural row issue — neither blocks the two good
    // rows from parsing.
    expect(session.validCount, 2);
    expect(session.rowIssues.length, 1);
    expect(session.needsReviewCount, 1);

    await notifier.selectWallet('w1');
    final result = await notifier.confirmImport();
    expect(result.importedCount, 2);

    final stored = await TransactionRepository.instance.getAll();
    expect(stored.length, 2);
  });

  test('28. an empty (header-only) file fails clearly instead of importing nothing silently', () async {
    const csv = 'Date,Description,Debit,Credit\r\n';
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'empty.csv', csvText: csv);

    final session = container.read(csvImportProvider);
    expect(session.status, CsvImportStatus.failed);
    expect(session.errorMessage, isNotNull);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
  });

  test('a file where every row resolves to zero ready-to-import rows still confirms cleanly', () async {
    await TransactionRepository.instance.add(
      Transaction(
        id: 'existing-1',
        title: 'Coffee Shop',
        amount: 250.0,
        categoryId: 'Shopping',
        accountId: 'w1',
        transactionType: 'expense',
        paymentMethod: 'card',
        note: '',
        createdAt: DateTime(2026, 8, 15),
      ),
    );
    const csv = 'Date,Description,Debit,Credit\r\n15/08/2026,Coffee Shop,250.00,\r\n';
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'all_dupes.csv', csvText: csv);
    await notifier.selectWallet('w1');

    expect(container.read(csvImportProvider).readyToImportCount, 0);

    final result = await notifier.confirmImport();
    expect(result.importedCount, 0);
    expect(result.failedCount, 0);
  });

  test('25. manual column mapping: unrecognized headers require mapping, then parse correctly', () async {
    const csv = 'TxDate,Details,Deb,Cred\r\n15/08/2026,Manual mapping row,300.00,\r\n';
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'manual.csv', csvText: csv);

    expect(container.read(csvImportProvider).status, CsvImportStatus.mappingRequired);

    notifier.updateColumnMapping(
      const CsvColumnMapping(dateColumn: 'TxDate', descriptionColumn: 'Details', debitColumn: 'Deb', creditColumn: 'Cred'),
    );
    await notifier.confirmColumnMapping();

    final session = container.read(csvImportProvider);
    expect(session.status, CsvImportStatus.previewReady);
    expect(session.validCount, 1);
    expect(session.pipelineResults.single.record.amount, 300.0);
  });

  test('32. a large CSV (500 rows) imports completely without error', () async {
    final buffer = StringBuffer('Date,Description,Debit,Credit,Ref\r\n');
    for (var i = 0; i < 500; i++) {
      final day = (i % 27) + 1;
      buffer.writeln('${day.toString().padLeft(2, '0')}/08/2026,Merchant $i,${(10 + i).toStringAsFixed(2)},,REF$i');
    }

    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'large.csv', csvText: buffer.toString());
    await notifier.selectWallet('w1');

    final session = container.read(csvImportProvider);
    expect(session.totalRows, 500);
    expect(session.validCount, 500);

    final result = await notifier.confirmImport();
    expect(result.importedCount, 500);

    final stored = await TransactionRepository.instance.getAll();
    expect(stored.length, 500);
  });

  test('Phase 9 review: marking a direction-ambiguous row as income resolves and imports it', () async {
    const csv = 'Date,Description,Amount\r\n15/08/2026,Unclear direction,777.00\r\n';
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'ambiguous.csv', csvText: csv);

    var session = container.read(csvImportProvider);
    expect(session.needsReviewCount, 1);

    await notifier.applyRowDecision(0, CsvRowDecision.markIncome);
    session = container.read(csvImportProvider);
    expect(session.pipelineResults.single.status, TransactionIngestionStatus.newRecord);
    expect(session.pipelineResults.single.record.type, IngestionTransactionType.income);

    await notifier.selectWallet('w1');
    final result = await notifier.confirmImport();
    expect(result.importedCount, 1);

    final stored = await TransactionRepository.instance.getAll();
    expect(stored.single.transactionType, 'income');
    expect(stored.single.amount, 777.0);
  });

  test('Phase 9 review: skipping a row excludes it from import even though it is otherwise valid', () async {
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'statement.csv', csvText: _debitCreditCsv);
    await notifier.selectWallet('w1');

    // Skip the first (Coffee Shop, expense) row explicitly.
    await notifier.applyRowDecision(0, CsvRowDecision.skip);
    expect(container.read(csvImportProvider).readyToImportCount, 1);

    final result = await notifier.confirmImport();
    expect(result.importedCount, 1);

    final stored = await TransactionRepository.instance.getAll();
    expect(stored.length, 1);
    expect(stored.single.transactionType, 'income'); // the Salary row, not the skipped Coffee Shop one
  });

  test('33. privacy — CSV row content never reaches AnalyticsService', () async {
    final beforeCount = AnalyticsService.instance.debugLog.length;

    const csv = 'Date,Description,Debit,Credit\r\n'
        '15/08/2026,"Secret OTP 123456 do not share",250.00,\r\n';
    final notifier = container.read(csvImportProvider.notifier);
    await notifier.loadCsvText(fileName: 'sensitive.csv', csvText: csv);
    await notifier.selectWallet('w1');
    await notifier.confirmImport();

    // Nothing about this flow logs through the analytics seam at all —
    // proving CSV content (including something that looks like an OTP)
    // never reaches it.
    expect(AnalyticsService.instance.debugLog.length, beforeCount);
  });
}
