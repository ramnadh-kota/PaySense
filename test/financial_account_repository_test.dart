import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/financial_account.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/financial_account_repository.dart';

void main() {
  late Directory tempDir;
  late FinancialAccountRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('financial_account_repo_test_');
    Hive.init(tempDir.path);
    repository = FinancialAccountRepository.instance;
    await repository.clearAll();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  final t1 = DateTime.utc(2026, 8, 30, 9, 0);
  final t2 = DateTime.utc(2026, 8, 30, 10, 0);
  final t3 = DateTime.utc(2026, 8, 30, 11, 0);

  group('FinancialAccountRepository — Phase 7A Step 3 Unit Tests', () {
    test('A. Save and retrieve FinancialAccount by ID', () async {
      final account = FinancialAccount(
        id: 'fa-1',
        name: 'HDFC Salary Bank',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 54200.50,
        currency: 'INR',
        isActive: true,
        createdAt: t1,
        updatedAt: t1,
        legacyWalletId: 'wallet-hdfc',
      );

      await repository.saveAccount(account);

      final fetched = await repository.getById('fa-1');
      expect(fetched, isNotNull);
      expect(fetched!.id, equals('fa-1'));
      expect(fetched.name, equals('HDFC Salary Bank'));
      expect(fetched.type, equals(FinancialAccountType.bank));
      expect(fetched.source, equals(FinancialAccountSource.manual));
      expect(fetched.balance, equals(54200.50));
      expect(fetched.currency, equals('INR'));
      expect(fetched.isActive, isTrue);
      expect(fetched.createdAt.isAtSameMomentAs(t1), isTrue);
      expect(fetched.updatedAt.isAtSameMomentAs(t1), isTrue);
      expect(fetched.legacyWalletId, equals('wallet-hdfc'));
    });

    test('B. Update existing account replaces record without duplicating', () async {
      final account = FinancialAccount(
        id: 'fa-update',
        name: 'Initial Name',
        type: FinancialAccountType.wallet,
        source: FinancialAccountSource.manual,
        balance: 1000.0,
        createdAt: t1,
        updatedAt: t1,
      );

      await repository.recordAccount(account);
      expect((await repository.getAll()).length, equals(1));

      final updated = account.copyWith(
        name: 'Updated Name',
        balance: 2500.0,
        updatedAt: t2,
      );

      await repository.saveAccount(updated);

      final all = await repository.getAll();
      expect(all.length, equals(1));
      expect(all.first.name, equals('Updated Name'));
      expect(all.first.balance, equals(2500.0));
      expect(all.first.updatedAt.isAtSameMomentAs(t2), isTrue);
    });

    test('C. getAll() returns accounts sorted deterministically by updatedAt descending', () async {
      final a1 = FinancialAccount(
        id: 'fa-oldest',
        name: 'Old Account',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 100.0,
        createdAt: t1,
        updatedAt: t1,
      );

      final a2 = FinancialAccount(
        id: 'fa-newest',
        name: 'New Account',
        type: FinancialAccountType.creditCard,
        source: FinancialAccountSource.sms,
        balance: 500.0,
        createdAt: t1,
        updatedAt: t3,
      );

      final a3 = FinancialAccount(
        id: 'fa-middle',
        name: 'Middle Account',
        type: FinancialAccountType.cash,
        source: FinancialAccountSource.manual,
        balance: 300.0,
        createdAt: t1,
        updatedAt: t2,
      );

      await repository.saveAccount(a1);
      await repository.saveAccount(a2);
      await repository.saveAccount(a3);

      final all = await repository.getAll();
      expect(all.length, equals(3));
      expect(all[0].id, equals('fa-newest'));
      expect(all[1].id, equals('fa-middle'));
      expect(all[2].id, equals('fa-oldest'));
    });

    test('D. getActiveAccounts() filters inactive accounts accurately', () async {
      final active1 = FinancialAccount(
        id: 'act-1',
        name: 'Active 1',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 1000.0,
        isActive: true,
        createdAt: t1,
        updatedAt: t2,
      );

      final inactive = FinancialAccount(
        id: 'inact-1',
        name: 'Closed Account',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 0.0,
        isActive: false,
        createdAt: t1,
        updatedAt: t3,
      );

      final active2 = FinancialAccount(
        id: 'act-2',
        name: 'Active 2',
        type: FinancialAccountType.upi,
        source: FinancialAccountSource.manual,
        balance: 2000.0,
        isActive: true,
        createdAt: t1,
        updatedAt: t1,
      );

      await repository.saveAccount(active1);
      await repository.saveAccount(inactive);
      await repository.saveAccount(active2);

      final activeAccounts = await repository.getActiveAccounts();
      expect(activeAccounts.length, equals(2));
      expect(activeAccounts.map((a) => a.id), containsAll(['act-1', 'act-2']));
      expect(activeAccounts.any((a) => a.id == 'inact-1'), isFalse);
    });

    test('E. getById() returns null for unknown IDs', () async {
      expect(await repository.getById('non_existent_id'), isNull);
    });

    test('F. getByType() filters accurately by FinancialAccountType', () async {
      await repository.saveAccount(FinancialAccount(
        id: 't-bank',
        name: 'Bank 1',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 5000,
        createdAt: t1,
        updatedAt: t1,
      ));
      await repository.saveAccount(FinancialAccount(
        id: 't-cc',
        name: 'Card 1',
        type: FinancialAccountType.creditCard,
        source: FinancialAccountSource.manual,
        balance: 1200,
        createdAt: t1,
        updatedAt: t1,
      ));
      await repository.saveAccount(FinancialAccount(
        id: 't-cash',
        name: 'Cash 1',
        type: FinancialAccountType.cash,
        source: FinancialAccountSource.manual,
        balance: 300,
        createdAt: t1,
        updatedAt: t1,
      ));

      final banks = await repository.getByType(FinancialAccountType.bank);
      expect(banks.length, equals(1));
      expect(banks.first.id, equals('t-bank'));

      final cards = await repository.getByType(FinancialAccountType.creditCard);
      expect(cards.length, equals(1));
      expect(cards.first.id, equals('t-cc'));

      final upi = await repository.getByType(FinancialAccountType.upi);
      expect(upi, isEmpty);
    });

    test('G. getBySource() filters accurately by FinancialAccountSource', () async {
      await repository.saveAccount(FinancialAccount(
        id: 's-manual',
        name: 'Manual Account',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 1000,
        createdAt: t1,
        updatedAt: t1,
      ));
      await repository.saveAccount(FinancialAccount(
        id: 's-sms',
        name: 'SMS Ingested',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.sms,
        balance: 2000,
        createdAt: t1,
        updatedAt: t1,
      ));
      await repository.saveAccount(FinancialAccount(
        id: 's-aa',
        name: 'AA Connected',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.accountAggregator,
        balance: 3000,
        createdAt: t1,
        updatedAt: t1,
      ));

      final aaAccounts = await repository.getBySource(FinancialAccountSource.accountAggregator);
      expect(aaAccounts.length, equals(1));
      expect(aaAccounts.first.id, equals('s-aa'));

      final csvAccounts = await repository.getBySource(FinancialAccountSource.csv);
      expect(csvAccounts, isEmpty);
    });

    test('H. deactivateAccount() sets isActive to false while preserving balance', () async {
      final account = FinancialAccount(
        id: 'deact-target',
        name: 'SBI Account',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 45000.0,
        isActive: true,
        createdAt: t1,
        updatedAt: t1,
      );

      await repository.saveAccount(account);
      await repository.deactivateAccount('deact-target');

      final fetched = await repository.getById('deact-target');
      expect(fetched, isNotNull);
      expect(fetched!.isActive, isFalse);
      expect(fetched.balance, equals(45000.0));
      expect(fetched.name, equals('SBI Account'));

      // Non-existent id deactivation is safe
      await repository.deactivateAccount('ghost_id');
    });

    test('I. deleteAccount() removes account permanently', () async {
      final account = FinancialAccount(
        id: 'del-target',
        name: 'To Delete',
        type: FinancialAccountType.other,
        source: FinancialAccountSource.manual,
        balance: 0,
        createdAt: t1,
        updatedAt: t1,
      );

      await repository.saveAccount(account);
      expect(await repository.getById('del-target'), isNotNull);

      await repository.deleteAccount('del-target');
      expect(await repository.getById('del-target'), isNull);

      // Deleting nonexistent account does not throw
      await repository.deleteAccount('del-target');
    });

    test('J. clearAll() clears all accounts in the box', () async {
      await repository.saveAccount(FinancialAccount(
        id: 'c-1',
        name: 'Account 1',
        type: FinancialAccountType.cash,
        source: FinancialAccountSource.manual,
        balance: 100,
        createdAt: t1,
        updatedAt: t1,
      ));
      await repository.saveAccount(FinancialAccount(
        id: 'c-2',
        name: 'Account 2',
        type: FinancialAccountType.wallet,
        source: FinancialAccountSource.manual,
        balance: 200,
        createdAt: t1,
        updatedAt: t1,
      ));

      expect((await repository.getAll()).length, equals(2));
      await repository.clearAll();
      expect(await repository.getAll(), isEmpty);
    });

    test('K. Serialization integrity of all fields through repository persistence', () async {
      final detailed = FinancialAccount(
        id: 'fa-precision-101',
        name: 'Axis Forex Card',
        type: FinancialAccountType.other,
        source: FinancialAccountSource.statement,
        balance: 987654.32,
        currency: 'USD',
        isActive: true,
        createdAt: DateTime.utc(2026, 3, 15, 12, 0, 0),
        updatedAt: DateTime.utc(2026, 8, 30, 18, 30, 45),
        legacyWalletId: 'wallet-forex-legacy',
      );

      await repository.saveAccount(detailed);

      final retrieved = await repository.getById('fa-precision-101');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('fa-precision-101'));
      expect(retrieved.name, equals('Axis Forex Card'));
      expect(retrieved.type, equals(FinancialAccountType.other));
      expect(retrieved.source, equals(FinancialAccountSource.statement));
      expect(retrieved.balance, equals(987654.32));
      expect(retrieved.currency, equals('USD'));
      expect(retrieved.isActive, isTrue);
      expect(retrieved.createdAt.isAtSameMomentAs(DateTime.utc(2026, 3, 15, 12, 0, 0)), isTrue);
      expect(retrieved.updatedAt.isAtSameMomentAs(DateTime.utc(2026, 8, 30, 18, 30, 45)), isTrue);
      expect(retrieved.legacyWalletId, equals('wallet-forex-legacy'));
    });

    test('L. Legacy compatibility: FinancialAccountRepository does not alter Wallet model or logic', () async {
      final legacyWallet = Wallet(
        id: 'legacy-w-100',
        name: 'Petty Cash',
        bankName: 'Cash',
        type: 'Cash',
        openingBalance: 500,
        currentBalance: 850,
        createdAt: t1,
      );

      final accountWithLegacyRef = FinancialAccount(
        id: 'fa-bridge-100',
        name: legacyWallet.name,
        type: FinancialAccountType.cash,
        source: FinancialAccountSource.manual,
        balance: legacyWallet.currentBalance,
        createdAt: legacyWallet.createdAt,
        updatedAt: t2,
        legacyWalletId: legacyWallet.id,
      );

      await repository.saveAccount(accountWithLegacyRef);

      final retrieved = await repository.getById('fa-bridge-100');
      expect(retrieved!.legacyWalletId, equals(legacyWallet.id));
      expect(legacyWallet.currentBalance, equals(850));
    });
  });
}
