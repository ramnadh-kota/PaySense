import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/transaction_ingestion_record.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_service.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_sync_service.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_transaction_adapter.dart';
import 'package:paysense/shared/services/account_aggregator/mock_account_aggregator_provider.dart';

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

final _referenceDate = DateTime(2026, 8, 26);
const _userId = 'ingestion-test-user';
const _bankOnlyTypes = [FinancialInstitutionType.bank];
const _allTypes = [
  FinancialInstitutionType.bank,
  FinancialInstitutionType.creditCard,
  FinancialInstitutionType.loan,
];

void main() {
  group('AccountAggregatorTransactionAdapter', () {
    test('AA → ingestion record: credit becomes income, debit becomes expense', () {
      final credit = AccountAggregatorTransaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 500,
        direction: AccountAggregatorTransactionDirection.credit,
        transactionDate: _referenceDate,
        narration: 'Salary',
        referenceNumber: 'REF-1',
        mode: 'NEFT',
      );
      final debit = AccountAggregatorTransaction(
        id: 'tx-2',
        accountId: 'acc-1',
        amount: 200,
        direction: AccountAggregatorTransactionDirection.debit,
        transactionDate: _referenceDate,
        narration: 'Rent',
        referenceNumber: 'REF-2',
      );

      final creditRecord = AccountAggregatorTransactionAdapter.toIngestionRecord(transaction: credit, walletId: 'w1');
      final debitRecord = AccountAggregatorTransactionAdapter.toIngestionRecord(transaction: debit, walletId: 'w1');

      expect(creditRecord.type, IngestionTransactionType.income);
      expect(debitRecord.type, IngestionTransactionType.expense);
      expect(creditRecord.source, TransactionSource.accountAggregator);
      expect(creditRecord.sourceTransactionId, 'tx-1');
      expect(creditRecord.referenceId, 'REF-1');
      expect(creditRecord.walletId, 'w1');
      expect(creditRecord.merchant, 'Salary');
    });

    test('metadata never contains a forbidden fragment', () {
      final transaction = AccountAggregatorTransaction(
        id: 'tx-3',
        accountId: 'acc-1',
        amount: 100,
        direction: AccountAggregatorTransactionDirection.debit,
        transactionDate: _referenceDate,
        mode: 'UPI',
      );
      final record = AccountAggregatorTransactionAdapter.toIngestionRecord(transaction: transaction, walletId: 'w1');
      for (final key in record.metadata.keys) {
        final normalized = key.toLowerCase().replaceAll('_', '');
        for (final fragment in ['otp', 'pin', 'password', 'cvv', 'secret', 'token', 'credential']) {
          expect(normalized.contains(fragment), isFalse, reason: 'key "$key" looks unsafe');
        }
      }
    });
  });

  group('AccountAggregatorSyncService.syncAndIngest', () {
    late Directory tempDir;
    late Wallet hdfcWallet;
    late Wallet iciciWallet;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paysense_aa_ingestion_test');
      await _initHive(tempDir);

      hdfcWallet = Wallet(
        id: 'wallet-hdfc',
        name: 'HDFC Savings',
        bankName: 'HDFC',
        type: 'bank',
        openingBalance: 10000,
        currentBalance: 10000,
        createdAt: _referenceDate,
      );
      iciciWallet = Wallet(
        id: 'wallet-icici',
        name: 'ICICI Savings',
        bankName: 'ICICI',
        type: 'bank',
        openingBalance: 5000,
        currentBalance: 5000,
        createdAt: _referenceDate,
      );
      await WalletRepository.instance.add(hdfcWallet);
      await WalletRepository.instance.add(iciciWallet);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<String> connectAndApprove(
      MockAccountAggregatorProvider provider, {
      List<FinancialInstitutionType> types = _allTypes,
    }) async {
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: types,
        historyDuration: const Duration(days: 180),
      );
      provider.approveConsent(connection.connectionId);
      return connection.connectionId;
    }

    test('a first sync imports genuinely new transactions and updates wallet balances correctly', () async {
      final provider = MockAccountAggregatorProvider(referenceDate: _referenceDate);
      final connectionId = await connectAndApprove(provider, types: _bankOnlyTypes);

      final summary = await AccountAggregatorSyncService.syncAndIngest(
        service: AccountAggregatorService(provider),
        connectionId: connectionId,
        walletIdByAaAccountId: const {
          'MOCK-ACC-HDFC-SAVINGS': 'wallet-hdfc',
          'MOCK-ACC-ICICI-SAVINGS': 'wallet-icici',
        },
      );

      expect(summary.importedCount, greaterThan(0));
      expect(summary.failedCount, 0);
      expect(summary.skippedUnmappedCount, 0);

      final stored = await TransactionRepository.instance.getAll();
      expect(stored.length, summary.importedCount);

      final updatedHdfc = await WalletRepository.instance.getById('wallet-hdfc');
      final updatedIcici = await WalletRepository.instance.getById('wallet-icici');

      // Expected HDFC net effect: +72000*3 (salary) -18000*2 (rent)
      // -2340 (electricity) -680 -450 (swiggy) -2499 (amazon).
      const expectedHdfcNet = 72000 * 3 - 18000 * 2 - 2340 - 680 - 450 - 2499;
      expect(updatedHdfc!.currentBalance, 10000 + expectedHdfcNet);

      // Expected ICICI net effect: +15000 (freelance) -3200 (groceries).
      const expectedIciciNet = 15000 - 3200;
      expect(updatedIcici!.currentBalance, 5000 + expectedIciciNet);
    });

    test(
      'idempotency: syncing the SAME connection twice never double-imports, '
      'never double-counts, and never mutates wallet balance a second time',
      () async {
        final provider = MockAccountAggregatorProvider(referenceDate: _referenceDate);
        final connectionId = await connectAndApprove(provider, types: _bankOnlyTypes);
        final walletMap = const {
          'MOCK-ACC-HDFC-SAVINGS': 'wallet-hdfc',
          'MOCK-ACC-ICICI-SAVINGS': 'wallet-icici',
        };

        final firstSummary = await AccountAggregatorSyncService.syncAndIngest(
          service: AccountAggregatorService(provider),
          connectionId: connectionId,
          walletIdByAaAccountId: walletMap,
        );
        final balanceAfterFirstSync = (await WalletRepository.instance.getById('wallet-hdfc'))!.currentBalance;
        final countAfterFirstSync = (await TransactionRepository.instance.getAll()).length;

        final secondSummary = await AccountAggregatorSyncService.syncAndIngest(
          service: AccountAggregatorService(provider),
          connectionId: connectionId,
          walletIdByAaAccountId: walletMap,
        );

        expect(secondSummary.importedCount, 0);
        expect(secondSummary.duplicateCount, firstSummary.importedCount);

        final balanceAfterSecondSync = (await WalletRepository.instance.getById('wallet-hdfc'))!.currentBalance;
        final countAfterSecondSync = (await TransactionRepository.instance.getAll()).length;

        expect(balanceAfterSecondSync, balanceAfterFirstSync);
        expect(countAfterSecondSync, countAfterFirstSync);

        // A THIRD sync must be equally inert.
        final thirdSummary = await AccountAggregatorSyncService.syncAndIngest(
          service: AccountAggregatorService(provider),
          connectionId: connectionId,
          walletIdByAaAccountId: walletMap,
        );
        expect(thirdSummary.importedCount, 0);
        expect((await WalletRepository.instance.getById('wallet-hdfc'))!.currentBalance, balanceAfterFirstSync);
      },
    );

    test('unmapped accounts are skipped entirely — never guessed, never ingested', () async {
      final provider = MockAccountAggregatorProvider(referenceDate: _referenceDate);
      final connectionId = await connectAndApprove(provider, types: _bankOnlyTypes);

      final summary = await AccountAggregatorSyncService.syncAndIngest(
        service: AccountAggregatorService(provider),
        connectionId: connectionId,
        // Only HDFC mapped — ICICI is left unmapped on purpose.
        walletIdByAaAccountId: const {'MOCK-ACC-HDFC-SAVINGS': 'wallet-hdfc'},
      );

      expect(summary.skippedUnmappedCount, greaterThan(0));

      final iciciWalletAfter = await WalletRepository.instance.getById('wallet-icici');
      expect(iciciWalletAfter!.currentBalance, 5000); // untouched

      final stored = await TransactionRepository.instance.getAll();
      expect(stored.every((t) => t.accountId == 'wallet-hdfc'), isTrue);
    });

    test(
      'liability accounts (credit card / loan) never mutate a cash wallet balance '
      'when the caller correctly omits them from the wallet mapping',
      () async {
        final provider = MockAccountAggregatorProvider(referenceDate: _referenceDate);
        // Consent covers ALL institution types, including liabilities —
        // but the caller (PART D's UI) only ever maps bank/deposit
        // accounts to a wallet, exactly as production code must.
        final connectionId = await connectAndApprove(provider, types: _allTypes);

        final summary = await AccountAggregatorSyncService.syncAndIngest(
          service: AccountAggregatorService(provider),
          connectionId: connectionId,
          walletIdByAaAccountId: const {
            'MOCK-ACC-HDFC-SAVINGS': 'wallet-hdfc',
            'MOCK-ACC-ICICI-SAVINGS': 'wallet-icici',
            // MOCK-ACC-HDFC-CREDITCARD and MOCK-ACC-ICICI-PERSONALLOAN
            // deliberately absent.
          },
        );

        expect(summary.skippedUnmappedCount, greaterThan(0));
        final stored = await TransactionRepository.instance.getAll();
        expect(stored.any((t) => t.title.contains('Loan EMI')), isFalse);
        expect(stored.any((t) => t.title == 'Credit Card Payment'), isFalse);
      },
    );

    test('malformed/partial sync data is reflected in needsReview/invalid counts, never silently imported', () async {
      final provider = MockAccountAggregatorProvider(
        referenceDate: _referenceDate,
        failureMode: MockAccountAggregatorFailureMode.malformedTransactionData,
      );
      final connectionId = await connectAndApprove(provider, types: _bankOnlyTypes);

      final summary = await AccountAggregatorSyncService.syncAndIngest(
        service: AccountAggregatorService(provider),
        connectionId: connectionId,
        walletIdByAaAccountId: const {
          'MOCK-ACC-HDFC-SAVINGS': 'wallet-hdfc',
          'MOCK-ACC-ICICI-SAVINGS': 'wallet-icici',
        },
      );

      // The malformed row (amount=0) is rejected by TransactionValidator
      // ("Amount must be greater than zero.") -> invalid, never imported.
      expect(summary.invalidCount, greaterThan(0));
    });

    test('empty transaction history is a valid, successful sync with zero imports and zero errors', () async {
      final provider = MockAccountAggregatorProvider(
        referenceDate: _referenceDate,
        failureMode: MockAccountAggregatorFailureMode.emptyTransactionHistory,
      );
      final connectionId = await connectAndApprove(provider, types: _bankOnlyTypes);

      final summary = await AccountAggregatorSyncService.syncAndIngest(
        service: AccountAggregatorService(provider),
        connectionId: connectionId,
        walletIdByAaAccountId: const {
          'MOCK-ACC-HDFC-SAVINGS': 'wallet-hdfc',
          'MOCK-ACC-ICICI-SAVINGS': 'wallet-icici',
        },
      );

      expect(summary.importedCount, 0);
      expect(summary.failedCount, 0);
      expect(summary.errors, isEmpty);
    });
  });
}
