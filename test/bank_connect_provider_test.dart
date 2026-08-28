import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/bank_connect_session.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/account_aggregator_connections_provider.dart';
import 'package:paysense/shared/providers/account_aggregator_provider.dart';
import 'package:paysense/shared/providers/bank_connect_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/account_aggregator_connection_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
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

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_bank_connect_test');
    await _initHive(tempDir);

    container = ProviderContainer(
      overrides: [
        accountAggregatorProviderImplProvider.overrideWithValue(
          MockAccountAggregatorProvider(referenceDate: _referenceDate),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('connection creation moves the wizard to awaitingConsent, never auto-approves', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');

    final session = container.read(bankConnectProvider);
    expect(session.step, BankConnectStep.awaitingConsent);
    expect(session.connection!.consentStatus, ConsentStatus.pending);
  });

  test('simulated approval advances through fetchingAccounts to mappingAccounts', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');
    await notifier.simulateApproveConsent();

    final session = container.read(bankConnectProvider);
    expect(session.step, BankConnectStep.mappingAccounts);
    expect(session.mappableAccounts, isNotEmpty);
  });

  test('simulated rejection lands the wizard in failed with a human-readable message', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');
    await notifier.simulateRejectConsent();

    final session = container.read(bankConnectProvider);
    expect(session.step, BankConnectStep.failed);
    expect(session.errorMessage, isNotNull);
    expect(session.errorMessage, isNot(contains('Exception')));
  });

  test('a rejected consent leaves the database completely untouched', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');
    await notifier.simulateRejectConsent();

    expect(await TransactionRepository.instance.getAll(), isEmpty);
    expect(await WalletRepository.instance.getAll(), isEmpty);
  });

  test('creating a new wallet for a mapped account persists the wallet and ingests its transactions', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');
    await notifier.simulateApproveConsent();

    final hdfcAccount = container
        .read(bankConnectProvider)
        .mappableAccounts
        .firstWhere((a) => a.id == 'MOCK-ACC-HDFC-SAVINGS');
    notifier.setMappingDecision(hdfcAccount.id, AccountMappingDecision.createNewWallet);

    final iciciAccount = container
        .read(bankConnectProvider)
        .mappableAccounts
        .firstWhere((a) => a.id == 'MOCK-ACC-ICICI-SAVINGS');
    notifier.setMappingDecision(iciciAccount.id, AccountMappingDecision.ignore);

    await notifier.confirmMappingAndSync();

    final session = container.read(bankConnectProvider);
    expect(session.step, BankConnectStep.completed);
    expect(session.syncSummary!.importedCount, greaterThan(0));

    final wallets = await WalletRepository.instance.getAll();
    expect(wallets.length, 1);
    expect(wallets.single.name, 'HDFC Savings');
    expect(wallets.single.currentBalance, isNot(0));

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, isNotEmpty);
    expect(transactions.every((t) => t.accountId == wallets.single.id), isTrue);
  });

  test('mapping to an existing wallet reuses it rather than creating a new one', () async {
    final existingWallet = Wallet(
      id: 'existing-wallet-1',
      name: 'My HDFC Account',
      bankName: 'HDFC',
      type: 'bank',
      openingBalance: 1000,
      currentBalance: 1000,
      createdAt: _referenceDate,
    );
    await WalletRepository.instance.add(existingWallet);
    await container.read(walletsProvider.notifier).reload();

    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');
    await notifier.simulateApproveConsent();

    notifier.setExistingWalletChoice('MOCK-ACC-HDFC-SAVINGS', 'existing-wallet-1');
    notifier.setMappingDecision('MOCK-ACC-ICICI-SAVINGS', AccountMappingDecision.ignore);

    await notifier.confirmMappingAndSync();

    final wallets = await WalletRepository.instance.getAll();
    expect(wallets.length, 1); // no NEW wallet created
    expect(wallets.single.id, 'existing-wallet-1');

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions.every((t) => t.accountId == 'existing-wallet-1'), isTrue);
  });

  test('liability accounts are never offered a wallet mapping and never affect a cash wallet', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [
      FinancialInstitutionType.bank,
      FinancialInstitutionType.creditCard,
      FinancialInstitutionType.loan,
    ]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');
    await notifier.simulateApproveConsent();

    final session = container.read(bankConnectProvider);
    expect(session.liabilityAccounts.length, 2);
    expect(session.mappableAccounts.any((a) => a.institutionType.isLiability), isFalse);

    notifier.setMappingDecision('MOCK-ACC-HDFC-SAVINGS', AccountMappingDecision.createNewWallet);
    notifier.setMappingDecision('MOCK-ACC-ICICI-SAVINGS', AccountMappingDecision.ignore);
    await notifier.confirmMappingAndSync();

    final wallets = await WalletRepository.instance.getAll();
    expect(wallets.length, 1); // only the mapped bank account, never the liabilities

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions.any((t) => t.title.contains('Loan EMI')), isFalse);
    expect(transactions.any((t) => t.title == 'Credit Card Payment'), isFalse);
  });

  test('reset returns the wizard to selectingInstitutions and clears prior connection data', () async {
    final notifier = container.read(bankConnectProvider.notifier);
    notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
    notifier.proceedToConsentExplanation();
    await notifier.startConsent('user-1');

    notifier.reset();
    final session = container.read(bankConnectProvider);
    expect(session.step, BankConnectStep.selectingInstitutions);
    expect(session.connection, isNull);
  });

  group('AccountAggregatorConnectionsNotifier — persistence and sync-now', () {
    Future<String> completeAConnection(ProviderContainer c) async {
      final notifier = c.read(bankConnectProvider.notifier);
      notifier.selectInstitutionTypes(const [FinancialInstitutionType.bank]);
      notifier.proceedToConsentExplanation();
      await notifier.startConsent('user-1');
      await notifier.simulateApproveConsent();
      notifier.setMappingDecision('MOCK-ACC-HDFC-SAVINGS', AccountMappingDecision.createNewWallet);
      notifier.setMappingDecision('MOCK-ACC-ICICI-SAVINGS', AccountMappingDecision.ignore);
      await notifier.confirmMappingAndSync();
      return c.read(bankConnectProvider).connection!.connectionId;
    }

    test('a completed connection is persisted and reloadable', () async {
      final connectionId = await completeAConnection(container);
      final connections = await container.read(accountAggregatorConnectionsProvider.future);
      expect(connections.any((c) => c.connectionId == connectionId), isTrue);
    });

    test('syncNow on an already-synced connection is idempotent (no new transactions, no balance change)', () async {
      final connectionId = await completeAConnection(container);
      final walletBefore = (await WalletRepository.instance.getAll()).single;
      final countBefore = (await TransactionRepository.instance.getAll()).length;

      final summary = await container.read(accountAggregatorConnectionsProvider.notifier).syncNow(connectionId);

      expect(summary.importedCount, 0);
      final walletAfter = (await WalletRepository.instance.getAll()).single;
      final countAfter = (await TransactionRepository.instance.getAll()).length;
      expect(walletAfter.currentBalance, walletBefore.currentBalance);
      expect(countAfter, countBefore);
    });

    test('revoke updates the persisted connection state without deleting historical transactions', () async {
      final connectionId = await completeAConnection(container);
      final countBefore = (await TransactionRepository.instance.getAll()).length;

      await container.read(accountAggregatorConnectionsProvider.notifier).revoke(connectionId);

      final connection = await AccountAggregatorConnectionRepository.instance.getById(connectionId);
      expect(connection!.status, ConnectionStatus.revoked);
      expect(connection.consentStatus, ConsentStatus.revoked);

      final countAfter = (await TransactionRepository.instance.getAll()).length;
      expect(countAfter, countBefore); // historical data untouched
    });

    test('disconnect removes the connection record entirely', () async {
      final connectionId = await completeAConnection(container);
      await container.read(accountAggregatorConnectionsProvider.notifier).disconnect(connectionId);

      final connection = await AccountAggregatorConnectionRepository.instance.getById(connectionId);
      expect(connection, isNull);
    });
  });
}
