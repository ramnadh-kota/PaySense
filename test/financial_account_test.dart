import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/financial_account.dart';
import 'package:paysense/shared/models/wallet.dart';

void main() {
  group('FinancialAccount — Phase 7A Step 2 Domain Tests', () {
    test('A. Every FinancialAccountType value exists and serializes correctly', () {
      expect(FinancialAccountType.values, containsAll([
        FinancialAccountType.bank,
        FinancialAccountType.creditCard,
        FinancialAccountType.upi,
        FinancialAccountType.cash,
        FinancialAccountType.wallet,
        FinancialAccountType.other,
      ]));

      for (final type in FinancialAccountType.values) {
        final parsed = FinancialAccountTypeExt.fromString(type.name);
        expect(parsed, equals(type));
      }

      // Edge cases & aliases
      expect(FinancialAccountTypeExt.fromString('credit_card'), equals(FinancialAccountType.creditCard));
      expect(FinancialAccountTypeExt.fromString('unknown_value'), equals(FinancialAccountType.other));
      expect(FinancialAccountTypeExt.fromString(null), equals(FinancialAccountType.other));
    });

    test('B. Every FinancialAccountSource value exists and serializes correctly', () {
      expect(FinancialAccountSource.values, containsAll([
        FinancialAccountSource.manual,
        FinancialAccountSource.sms,
        FinancialAccountSource.csv,
        FinancialAccountSource.statement,
        FinancialAccountSource.accountAggregator,
      ]));

      for (final source in FinancialAccountSource.values) {
        final parsed = FinancialAccountSourceExt.fromString(source.name);
        expect(parsed, equals(source));
      }

      // Edge cases & aliases
      expect(FinancialAccountSourceExt.fromString('account_aggregator'), equals(FinancialAccountSource.accountAggregator));
      expect(FinancialAccountSourceExt.fromString('unknown_source'), equals(FinancialAccountSource.manual));
      expect(FinancialAccountSourceExt.fromString(null), equals(FinancialAccountSource.manual));
    });

    test('C. Full FinancialAccount creation with expected properties', () {
      final now = DateTime.utc(2026, 8, 30, 10, 0, 0);
      final account = FinancialAccount(
        id: 'acc_001',
        name: 'HDFC Salary Account',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 42850.50,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        legacyWalletId: 'wallet_hdfc_1',
      );

      expect(account.id, equals('acc_001'));
      expect(account.name, equals('HDFC Salary Account'));
      expect(account.type, equals(FinancialAccountType.bank));
      expect(account.source, equals(FinancialAccountSource.manual));
      expect(account.balance, equals(42850.50));
      expect(account.currency, equals('INR'));
      expect(account.isActive, isTrue);
      expect(account.isAsset, isTrue);
      expect(account.isLiability, isFalse);
      expect(account.legacyWalletId, equals('wallet_hdfc_1'));
    });

    test('D. toMap() contains all expected fields', () {
      final now = DateTime.utc(2026, 8, 30, 12, 30, 0);
      final account = FinancialAccount(
        id: 'acc_cc_01',
        name: 'ICICI Amazon Pay Card',
        type: FinancialAccountType.creditCard,
        source: FinancialAccountSource.sms,
        balance: 8450.75,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        legacyWalletId: null,
      );

      final map = account.toMap();
      expect(map['id'], equals('acc_cc_01'));
      expect(map['name'], equals('ICICI Amazon Pay Card'));
      expect(map['type'], equals('creditCard'));
      expect(map['source'], equals('sms'));
      expect(map['balance'], equals(8450.75));
      expect(map['currency'], equals('INR'));
      expect(map['isActive'], isTrue);
      expect(map['createdAt'], equals(now.toIso8601String()));
      expect(map['updatedAt'], equals(now.toIso8601String()));
      expect(map.containsKey('legacyWalletId'), isFalse);
    });

    test('E. fromMap() reconstructs the model correctly', () {
      final map = {
        'id': 'acc_upi_01',
        'name': 'GPay UPI',
        'type': 'upi',
        'source': 'manual',
        'balance': 1500.0,
        'currency': 'INR',
        'isActive': true,
        'createdAt': '2026-08-30T09:00:00.000Z',
        'updatedAt': '2026-08-30T09:00:00.000Z',
        'legacyWalletId': 'wallet_gpay',
      };

      final account = FinancialAccount.fromMap(map);
      expect(account.id, equals('acc_upi_01'));
      expect(account.name, equals('GPay UPI'));
      expect(account.type, equals(FinancialAccountType.upi));
      expect(account.source, equals(FinancialAccountSource.manual));
      expect(account.balance, equals(1500.0));
      expect(account.legacyWalletId, equals('wallet_gpay'));
    });

    test('F. toMap → fromMap round-trip equality', () {
      final now = DateTime.utc(2026, 8, 30, 14, 0, 0);
      final original = FinancialAccount(
        id: 'acc_test_roundtrip',
        name: 'Cash in Hand',
        type: FinancialAccountType.cash,
        source: FinancialAccountSource.manual,
        balance: 3200.00,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        legacyWalletId: 'wallet_cash_01',
      );

      final map = original.toMap();
      final reconstructed = FinancialAccount.fromMap(map);

      expect(reconstructed, equals(original));
      expect(reconstructed.hashCode, equals(original.hashCode));
    });

    test('G. null legacyWalletId round-trip', () {
      final now = DateTime.utc(2026, 8, 30, 8, 0, 0);
      final account = FinancialAccount(
        id: 'acc_aa_01',
        name: 'SBI Savings (AA Synced)',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.accountAggregator,
        balance: 95400.0,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        legacyWalletId: null,
      );

      final map = account.toMap();
      expect(map.containsKey('legacyWalletId'), isFalse);

      final reconstructed = FinancialAccount.fromMap(map);
      expect(reconstructed.legacyWalletId, isNull);
      expect(reconstructed, equals(account));
    });

    test('H. non-null legacyWalletId round-trip', () {
      final now = DateTime.utc(2026, 8, 30, 8, 0, 0);
      final account = FinancialAccount(
        id: 'acc_migrated',
        name: 'Primary Wallet',
        type: FinancialAccountType.wallet,
        source: FinancialAccountSource.manual,
        balance: 5000.0,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        legacyWalletId: 'legacy_w_123',
      );

      final map = account.toMap();
      expect(map['legacyWalletId'], equals('legacy_w_123'));

      final reconstructed = FinancialAccount.fromMap(map);
      expect(reconstructed.legacyWalletId, equals('legacy_w_123'));
      expect(reconstructed, equals(account));
    });

    test('I. decimal balance preservation', () {
      final now = DateTime.utc(2026, 8, 30, 8, 0, 0);
      final account = FinancialAccount(
        id: 'acc_precise',
        name: 'Precision Test',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.csv,
        balance: 12345.67,
        currency: 'INR',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = account.toMap();
      final reconstructed = FinancialAccount.fromMap(map);
      expect(reconstructed.balance, equals(12345.67));
    });

    test('J. DateTime serialization/deserialization', () {
      final created = DateTime.utc(2026, 1, 15, 10, 20, 30);
      final updated = DateTime.utc(2026, 8, 30, 15, 45, 0);
      final account = FinancialAccount(
        id: 'acc_dt',
        name: 'Date Time Test',
        type: FinancialAccountType.other,
        source: FinancialAccountSource.statement,
        balance: 100.0,
        currency: 'INR',
        isActive: true,
        createdAt: created,
        updatedAt: updated,
      );

      final map = account.toMap();
      final reconstructed = FinancialAccount.fromMap(map);

      expect(reconstructed.createdAt.isAtSameMomentAs(created), isTrue);
      expect(reconstructed.updatedAt.isAtSameMomentAs(updated), isTrue);
    });

    test('K. inactive account preservation', () {
      final now = DateTime.utc(2026, 8, 30, 8, 0, 0);
      final account = FinancialAccount(
        id: 'acc_inactive',
        name: 'Old Closed Account',
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: 0.0,
        currency: 'INR',
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = account.toMap();
      expect(map['isActive'], isFalse);

      final reconstructed = FinancialAccount.fromMap(map);
      expect(reconstructed.isActive, isFalse);
    });

    test('L. legacy wallet compatibility: Wallet model untouched and references linkable', () {
      final walletCreationTime = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final existingWallet = Wallet(
        id: 'legacy_wallet_abc',
        name: 'Main Checking',
        bankName: 'HDFC',
        type: 'Bank',
        openingBalance: 10000.0,
        currentBalance: 25000.0,
        createdAt: walletCreationTime,
      );

      final bridgingAccount = FinancialAccount(
        id: 'fin_acc_bridge_1',
        name: existingWallet.name,
        type: FinancialAccountType.bank,
        source: FinancialAccountSource.manual,
        balance: existingWallet.currentBalance,
        currency: 'INR',
        isActive: !existingWallet.isArchived,
        createdAt: existingWallet.createdAt,
        updatedAt: DateTime.now(),
        legacyWalletId: existingWallet.id,
      );

      expect(bridgingAccount.legacyWalletId, equals(existingWallet.id));
      expect(bridgingAccount.balance, equals(existingWallet.currentBalance));
      expect(bridgingAccount.name, equals(existingWallet.name));
      // Confirms existing Wallet remains valid and unchanged
      expect(existingWallet.id, equals('legacy_wallet_abc'));
    });
  });
}
