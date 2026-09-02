import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/financial_account.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/financial_account_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/financial_account_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late FinancialAccountRepository accountRepository;
  late WalletRepository walletRepository;
  late FinancialAccountSyncService syncService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_sync_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WalletAdapter());
    }
    await Hive.openBox<Wallet>('wallets');
    await Hive.openBox('financial_accounts');

    accountRepository = FinancialAccountRepository.instance;
    walletRepository = WalletRepository.instance;
    syncService = FinancialAccountSyncService(
      walletRepository: walletRepository,
      accountRepository: accountRepository,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FinancialAccountSyncService — Phase 7A Step 6 Unit Tests', () {
    final now = DateTime.utc(2026, 2, 1, 12, 0, 0);

    test('1. First-time sync creates financial accounts for all existing wallets', () async {
      final w1 = Wallet(
        id: 'w-hdfc',
        name: 'HDFC Savings',
        bankName: 'HDFC',
        type: 'Bank',
        openingBalance: 10000.0,
        currentBalance: 25000.0,
        createdAt: now,
      );
      final w2 = Wallet(
        id: 'w-cash',
        name: 'Pocket Cash',
        bankName: '',
        type: 'Cash',
        openingBalance: 2000.0,
        currentBalance: 1500.0,
        createdAt: now,
      );
      await walletRepository.add(w1);
      await walletRepository.add(w2);

      final result = await syncService.syncWalletsToFinancialAccounts();

      expect(result.totalWallets, equals(2));
      expect(result.accountsCreated, equals(2));
      expect(result.accountsUpdated, equals(0));
      expect(result.accountsUnchanged, equals(0));
      expect(result.untouchedNonWalletAccounts, equals(0));

      final accounts = await accountRepository.getAll();
      expect(accounts.length, equals(2));

      final hdfc = accounts.firstWhere((a) => a.legacyWalletId == 'w-hdfc');
      expect(hdfc.name, equals('HDFC Savings'));
      expect(hdfc.balance, equals(25000.0));
      expect(hdfc.type, equals(FinancialAccountType.bank));
      expect(hdfc.source, equals(FinancialAccountSource.manual));
      expect(hdfc.isActive, isTrue);

      final cash = accounts.firstWhere((a) => a.legacyWalletId == 'w-cash');
      expect(cash.name, equals('Pocket Cash'));
      expect(cash.balance, equals(1500.0));
      expect(cash.type, equals(FinancialAccountType.cash));
    });

    test('2. Repeated sync without changes is idempotent (0 created, 0 updated, all unchanged)', () async {
      final w1 = Wallet(
        id: 'w-sbi',
        name: 'SBI Account',
        bankName: 'SBI',
        type: 'Bank',
        openingBalance: 5000.0,
        currentBalance: 12000.0,
        createdAt: now,
      );
      await walletRepository.add(w1);

      final firstResult = await syncService.syncWalletsToFinancialAccounts();
      expect(firstResult.accountsCreated, equals(1));

      final secondResult = await syncService.syncWalletsToFinancialAccounts();
      expect(secondResult.totalWallets, equals(1));
      expect(secondResult.accountsCreated, equals(0));
      expect(secondResult.accountsUpdated, equals(0));
      expect(secondResult.accountsUnchanged, equals(1));
    });

    test('3. Modifying wallet balance and name updates matching financial account', () async {
      final w1 = Wallet(
        id: 'w-icici',
        name: 'ICICI Salary',
        bankName: 'ICICI',
        type: 'Bank',
        openingBalance: 10000.0,
        currentBalance: 20000.0,
        createdAt: now,
      );
      await walletRepository.add(w1);
      await syncService.syncWalletsToFinancialAccounts();

      // Mutate wallet
      final updatedWallet = w1.copyWith(
        name: 'ICICI Main Primary',
        currentBalance: 28500.0,
      );
      await walletRepository.update(updatedWallet);

      final syncResult = await syncService.syncWalletsToFinancialAccounts();
      expect(syncResult.accountsUpdated, equals(1));
      expect(syncResult.accountsCreated, equals(0));
      expect(syncResult.accountsUnchanged, equals(0));

      final updatedAcc = await accountRepository.getById('wallet_w-icici');
      expect(updatedAcc, isNotNull);
      expect(updatedAcc!.name, equals('ICICI Main Primary'));
      expect(updatedAcc.balance, equals(28500.0));
      expect(updatedAcc.legacyWalletId, equals('w-icici'));
      expect(updatedAcc.createdAt, equals(now));
    });

    test('4. Existing non-wallet financial accounts are never overwritten or deleted', () async {
      // Create a standalone financial account (e.g., imported or future feed)
      final standaloneAcc = FinancialAccount(
        id: 'external-custom-acc-1',
        name: 'External Demat Account',
        type: FinancialAccountType.other,
        source: FinancialAccountSource.statement,
        balance: 500000.0,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        legacyWalletId: null,
      );
      await accountRepository.saveAccount(standaloneAcc);

      // Add a wallet
      final wallet = Wallet(
        id: 'w-axis',
        name: 'Axis Bank',
        bankName: 'Axis',
        type: 'Bank',
        openingBalance: 1000.0,
        currentBalance: 5000.0,
        createdAt: now,
      );
      await walletRepository.add(wallet);

      final result = await syncService.syncWalletsToFinancialAccounts();
      expect(result.accountsCreated, equals(1));
      expect(result.untouchedNonWalletAccounts, equals(1));

      final allAccounts = await accountRepository.getAll();
      expect(allAccounts.length, equals(2));

      // Standalone account remains completely untouched
      final retrievedStandalone = await accountRepository.getById('external-custom-acc-1');
      expect(retrievedStandalone, isNotNull);
      expect(retrievedStandalone!.name, equals('External Demat Account'));
      expect(retrievedStandalone.balance, equals(500000.0));
      expect(retrievedStandalone.source, equals(FinancialAccountSource.statement));
      expect(retrievedStandalone.legacyWalletId, isNull);
    });

    test('5. Archiving a wallet syncs isActive: false to matching financial account', () async {
      final wallet = Wallet(
        id: 'w-arch-test',
        name: 'Closing Soon',
        bankName: 'HDFC',
        type: 'Bank',
        openingBalance: 1000.0,
        currentBalance: 0.0,
        createdAt: now,
        isArchived: false,
      );
      await walletRepository.add(wallet);
      await syncService.syncWalletsToFinancialAccounts();

      final activeAcc = await accountRepository.getById('wallet_w-arch-test');
      expect(activeAcc!.isActive, isTrue);

      // Archive wallet
      await walletRepository.archive('w-arch-test');

      final result = await syncService.syncWalletsToFinancialAccounts();
      expect(result.accountsUpdated, equals(1));

      final archivedAcc = await accountRepository.getById('wallet_w-arch-test');
      expect(archivedAcc!.isActive, isFalse);
    });

    test('6. Wallet model and records are never modified by sync service', () async {
      final originalWallet = Wallet(
        id: 'w-immutable',
        name: 'Untouched Wallet',
        bankName: 'Canara Bank',
        type: 'Savings',
        openingBalance: 7000.0,
        currentBalance: 15432.10,
        createdAt: now,
        isArchived: false,
      );
      await walletRepository.add(originalWallet);

      await syncService.syncWalletsToFinancialAccounts();

      final storedWallet = await walletRepository.getById('w-immutable');
      expect(storedWallet, isNotNull);
      expect(storedWallet!.id, equals(originalWallet.id));
      expect(storedWallet.name, equals(originalWallet.name));
      expect(storedWallet.bankName, equals(originalWallet.bankName));
      expect(storedWallet.type, equals(originalWallet.type));
      expect(storedWallet.openingBalance, equals(originalWallet.openingBalance));
      expect(storedWallet.currentBalance, equals(originalWallet.currentBalance));
      expect(storedWallet.createdAt, equals(originalWallet.createdAt));
      expect(storedWallet.isArchived, equals(originalWallet.isArchived));
    });

    test('7. Mixed sync with new, updated, and unchanged wallets', () async {
      final w1 = Wallet(
        id: 'w-1',
        name: 'W1',
        bankName: '',
        type: 'Cash',
        openingBalance: 100,
        currentBalance: 100,
        createdAt: now,
      );
      final w2 = Wallet(
        id: 'w-2',
        name: 'W2',
        bankName: '',
        type: 'Bank',
        openingBalance: 200,
        currentBalance: 200,
        createdAt: now,
      );
      await walletRepository.add(w1);
      await walletRepository.add(w2);
      await syncService.syncWalletsToFinancialAccounts();

      // Update w2, keep w1 unchanged, add w3
      await walletRepository.update(w2.copyWith(currentBalance: 350));
      final w3 = Wallet(
        id: 'w-3',
        name: 'W3',
        bankName: '',
        type: 'Credit Card',
        openingBalance: 0,
        currentBalance: 500,
        createdAt: now,
      );
      await walletRepository.add(w3);

      final result = await syncService.syncWalletsToFinancialAccounts();
      expect(result.totalWallets, equals(3));
      expect(result.accountsCreated, equals(1)); // w3
      expect(result.accountsUpdated, equals(1)); // w2
      expect(result.accountsUnchanged, equals(1)); // w1
    });
  });
}
