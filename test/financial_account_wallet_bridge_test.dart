import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/financial_account.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_account_wallet_bridge.dart';

void main() {
  group('FinancialAccountWalletBridge — Phase 7A Step 6 Unit Tests', () {
    final testCreatedAt = DateTime.utc(2026, 1, 15, 10, 30, 0);

    test('1. wallet -> financial account mapping preserves core properties', () {
      final wallet = Wallet(
        id: 'w-hdfc-01',
        name: 'HDFC Salary Account',
        bankName: 'HDFC Bank',
        type: 'Bank',
        openingBalance: 10000.0,
        currentBalance: 35450.75,
        createdAt: testCreatedAt,
      );

      final account = FinancialAccountWalletBridge.fromWallet(wallet);

      expect(account.id, equals('wallet_w-hdfc-01'));
      expect(account.legacyWalletId, equals('w-hdfc-01'));
      expect(account.name, equals('HDFC Salary Account'));
      expect(account.balance, equals(35450.75));
      expect(account.currency, equals('INR'));
      expect(account.source, equals(FinancialAccountSource.manual));
      expect(account.type, equals(FinancialAccountType.bank));
      expect(account.isActive, isTrue);
      expect(account.createdAt, equals(testCreatedAt));
      expect(account.updatedAt, equals(testCreatedAt));
      expect(account.isAsset, isTrue);
      expect(account.isLiability, isFalse);
    });

    test('2. ID is deterministic across repeated calls', () {
      final wallet = Wallet(
        id: 'w-cash-99',
        name: 'Emergency Cash',
        bankName: '',
        type: 'Cash',
        openingBalance: 5000.0,
        currentBalance: 5000.0,
        createdAt: testCreatedAt,
      );

      final account1 = FinancialAccountWalletBridge.fromWallet(wallet);
      final account2 = FinancialAccountWalletBridge.fromWallet(wallet);

      expect(account1.id, equals(account2.id));
      expect(account1.id, equals('wallet_w-cash-99'));
      expect(account1, equals(account2));
    });

    test('3. legacyWalletId exactly matches original wallet.id', () {
      final wallet = Wallet(
        id: 'uuid-1234-5678-abcd',
        name: 'ICICI Savings',
        bankName: 'ICICI',
        type: 'Savings',
        openingBalance: 0.0,
        currentBalance: 12500.0,
        createdAt: testCreatedAt,
      );

      final account = FinancialAccountWalletBridge.fromWallet(wallet);
      expect(account.legacyWalletId, equals('uuid-1234-5678-abcd'));
      expect(wallet.id, equals('uuid-1234-5678-abcd'));
    });

    test('4. Balance preservation supports positive, negative, zero, and high precision', () {
      final zeroWallet = Wallet(
        id: 'w-zero',
        name: 'Zero Balance',
        bankName: '',
        type: 'Cash',
        openingBalance: 0.0,
        currentBalance: 0.0,
        createdAt: testCreatedAt,
      );
      final decimalWallet = Wallet(
        id: 'w-dec',
        name: 'Decimal Precision',
        bankName: 'SBI',
        type: 'Bank',
        openingBalance: 100.123,
        currentBalance: 987654.321,
        createdAt: testCreatedAt,
      );
      final negativeWallet = Wallet(
        id: 'w-neg',
        name: 'Overdrawn',
        bankName: 'Axis',
        type: 'Bank',
        openingBalance: 0.0,
        currentBalance: -1500.50,
        createdAt: testCreatedAt,
      );

      expect(FinancialAccountWalletBridge.fromWallet(zeroWallet).balance, equals(0.0));
      expect(FinancialAccountWalletBridge.fromWallet(decimalWallet).balance, equals(987654.321));
      expect(FinancialAccountWalletBridge.fromWallet(negativeWallet).balance, equals(-1500.50));
    });

    test('5. Source is always FinancialAccountSource.manual', () {
      final wallet = Wallet(
        id: 'w-src',
        name: 'Manual Wallet',
        bankName: '',
        type: 'Cash',
        openingBalance: 500.0,
        currentBalance: 500.0,
        createdAt: testCreatedAt,
      );

      final account = FinancialAccountWalletBridge.fromWallet(wallet);
      expect(account.source, equals(FinancialAccountSource.manual));
    });

    group('6. Account type mapping and asset/liability semantics', () {
      test('Bank variants map to bank (asset)', () {
        for (final type in ['Bank', 'bank', 'BANK', 'Savings', 'savings', 'Checking', 'Current', 'Salary', 'Fixed Deposit']) {
          final wallet = Wallet(
            id: 'w-$type',
            name: 'Test Bank',
            bankName: 'HDFC',
            type: type,
            openingBalance: 1000.0,
            currentBalance: 1000.0,
            createdAt: testCreatedAt,
          );
          final account = FinancialAccountWalletBridge.fromWallet(wallet);
          expect(account.type, equals(FinancialAccountType.bank), reason: 'Failed for type: $type');
          expect(account.isAsset, isTrue);
          expect(account.isLiability, isFalse);
        }
      });

      test('Cash variants map to cash (asset)', () {
        for (final type in ['Cash', 'cash', 'CASH', 'Petty Cash']) {
          final wallet = Wallet(
            id: 'w-$type',
            name: 'Test Cash',
            bankName: '',
            type: type,
            openingBalance: 500.0,
            currentBalance: 500.0,
            createdAt: testCreatedAt,
          );
          final account = FinancialAccountWalletBridge.fromWallet(wallet);
          expect(account.type, equals(FinancialAccountType.cash), reason: 'Failed for type: $type');
          expect(account.isAsset, isTrue);
          expect(account.isLiability, isFalse);
        }
      });

      test('Credit Card variants map to creditCard (liability)', () {
        for (final type in ['Credit Card', 'credit card', 'CreditCard', 'credit_card', 'CREDIT CARD', 'Axis Credit']) {
          final wallet = Wallet(
            id: 'w-$type',
            name: 'Test CC',
            bankName: 'Axis',
            type: type,
            openingBalance: 0.0,
            currentBalance: 5000.0,
            createdAt: testCreatedAt,
          );
          final account = FinancialAccountWalletBridge.fromWallet(wallet);
          expect(account.type, equals(FinancialAccountType.creditCard), reason: 'Failed for type: $type');
          expect(account.isLiability, isTrue);
          expect(account.isAsset, isFalse);
        }
      });

      test('UPI and digital wallet variants map accurately', () {
        final upiWallet = Wallet(
          id: 'w-upi',
          name: 'GPay UPI',
          bankName: '',
          type: 'UPI',
          openingBalance: 0.0,
          currentBalance: 2000.0,
          createdAt: testCreatedAt,
        );
        final walletOption = Wallet(
          id: 'w-combo',
          name: 'Paytm Wallet',
          bankName: '',
          type: 'UPI/Wallet',
          openingBalance: 0.0,
          currentBalance: 1500.0,
          createdAt: testCreatedAt,
        );
        final digitalWallet = Wallet(
          id: 'w-digi',
          name: 'Amazon Pay',
          bankName: '',
          type: 'Wallet',
          openingBalance: 0.0,
          currentBalance: 800.0,
          createdAt: testCreatedAt,
        );

        expect(FinancialAccountWalletBridge.fromWallet(upiWallet).type, equals(FinancialAccountType.upi));
        expect(FinancialAccountWalletBridge.fromWallet(walletOption).type, equals(FinancialAccountType.wallet));
        expect(FinancialAccountWalletBridge.fromWallet(digitalWallet).type, equals(FinancialAccountType.wallet));
      });

      test('Unknown or empty types fall back to other safely', () {
        for (final type in ['', '   ', 'Custom Token', 'Voucher', 'Unknown']) {
          final wallet = Wallet(
            id: 'w-other',
            name: 'Unknown Type',
            bankName: '',
            type: type,
            openingBalance: 0.0,
            currentBalance: 100.0,
            createdAt: testCreatedAt,
          );
          final account = FinancialAccountWalletBridge.fromWallet(wallet);
          expect(account.type, equals(FinancialAccountType.other));
        }
      });
    });

    test('7. Archived status maps to isActive correctly', () {
      final activeWallet = Wallet(
        id: 'w-act',
        name: 'Active Checking',
        bankName: 'HDFC',
        type: 'Bank',
        openingBalance: 1000.0,
        currentBalance: 1000.0,
        createdAt: testCreatedAt,
        isArchived: false,
      );
      final archivedWallet = Wallet(
        id: 'w-arch',
        name: 'Old Closed Account',
        bankName: 'HDFC',
        type: 'Bank',
        openingBalance: 1000.0,
        currentBalance: 0.0,
        createdAt: testCreatedAt,
        isArchived: true,
      );

      final activeAcc = FinancialAccountWalletBridge.fromWallet(activeWallet);
      final archivedAcc = FinancialAccountWalletBridge.fromWallet(archivedWallet);

      expect(activeAcc.isActive, isTrue);
      expect(archivedAcc.isActive, isFalse);
    });

    test('8. Timestamp preservation and optional custom updatedAt', () {
      final wallet = Wallet(
        id: 'w-time',
        name: 'Timestamp Test',
        bankName: 'SBI',
        type: 'Bank',
        openingBalance: 100.0,
        currentBalance: 200.0,
        createdAt: testCreatedAt,
      );

      final defaultAcc = FinancialAccountWalletBridge.fromWallet(wallet);
      expect(defaultAcc.createdAt, equals(testCreatedAt));
      expect(defaultAcc.updatedAt, equals(testCreatedAt));

      final customUpdated = DateTime.utc(2026, 6, 1, 12, 0, 0);
      final customAcc = FinancialAccountWalletBridge.fromWallet(wallet, updatedAt: customUpdated);
      expect(customAcc.createdAt, equals(testCreatedAt));
      expect(customAcc.updatedAt, equals(customUpdated));
    });

    test('9. fromWallets batch conversion converts list deterministically', () {
      final wallets = [
        Wallet(
          id: 'w-1',
          name: 'Account 1',
          bankName: 'HDFC',
          type: 'Bank',
          openingBalance: 1000.0,
          currentBalance: 1500.0,
          createdAt: testCreatedAt,
        ),
        Wallet(
          id: 'w-2',
          name: 'Account 2',
          bankName: 'ICICI',
          type: 'Credit Card',
          openingBalance: 0.0,
          currentBalance: 2500.0,
          createdAt: testCreatedAt,
        ),
        Wallet(
          id: 'w-3',
          name: 'Account 3',
          bankName: '',
          type: 'Cash',
          openingBalance: 500.0,
          currentBalance: 500.0,
          createdAt: testCreatedAt,
          isArchived: true,
        ),
      ];

      final accounts = FinancialAccountWalletBridge.fromWallets(wallets);

      expect(accounts.length, equals(3));
      expect(accounts[0].id, equals('wallet_w-1'));
      expect(accounts[0].type, equals(FinancialAccountType.bank));
      expect(accounts[0].isActive, isTrue);

      expect(accounts[1].id, equals('wallet_w-2'));
      expect(accounts[1].type, equals(FinancialAccountType.creditCard));
      expect(accounts[1].isLiability, isTrue);

      expect(accounts[2].id, equals('wallet_w-3'));
      expect(accounts[2].type, equals(FinancialAccountType.cash));
      expect(accounts[2].isActive, isFalse);
    });

    test('10. fromWallets with empty list returns empty unmodifiable list', () {
      final accounts = FinancialAccountWalletBridge.fromWallets(const []);
      expect(accounts, isEmpty);
      expect(() => (accounts as dynamic).add(FinancialAccountWalletBridge.fromWallet(Wallet(
        id: 'x',
        name: 'x',
        bankName: '',
        type: 'Cash',
        openingBalance: 0,
        currentBalance: 0,
        createdAt: DateTime.now(),
      ))), throwsUnsupportedError);
    });

    test('11. fromWallet does not mutate original Wallet instance', () {
      final originalWallet = Wallet(
        id: 'w-orig',
        name: 'Original Wallet',
        bankName: 'HDFC Bank',
        type: 'Bank',
        openingBalance: 10000.0,
        currentBalance: 25000.0,
        createdAt: testCreatedAt,
        isArchived: false,
      );

      final _ = FinancialAccountWalletBridge.fromWallet(originalWallet);

      expect(originalWallet.id, equals('w-orig'));
      expect(originalWallet.name, equals('Original Wallet'));
      expect(originalWallet.bankName, equals('HDFC Bank'));
      expect(originalWallet.type, equals('Bank'));
      expect(originalWallet.openingBalance, equals(10000.0));
      expect(originalWallet.currentBalance, equals(25000.0));
      expect(originalWallet.createdAt, equals(testCreatedAt));
      expect(originalWallet.isArchived, isFalse);
    });

    test('12. Top-level function aliases (fromWallet, fromWallets) work identically', () {
      final wallet = Wallet(
        id: 'w-alias',
        name: 'Alias Test',
        bankName: 'SBI',
        type: 'Bank',
        openingBalance: 500.0,
        currentBalance: 750.0,
        createdAt: testCreatedAt,
      );

      final acc1 = fromWallet(wallet);
      final acc2 = FinancialAccountWalletBridge.fromWallet(wallet);
      expect(acc1, equals(acc2));

      final list1 = fromWallets([wallet]);
      final list2 = FinancialAccountWalletBridge.fromWallets([wallet]);
      expect(list1, equals(list2));
    });
  });
}
