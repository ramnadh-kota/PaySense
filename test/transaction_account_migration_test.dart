import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/transaction_account_migration.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';

Wallet _wallet({required String id, required String name, String type = 'Bank'}) => Wallet(
  id: id,
  name: name,
  bankName: '',
  type: type,
  openingBalance: 0,
  currentBalance: 0,
  createdAt: DateTime(2026, 1, 1),
);

Transaction _tx({
  required String id,
  required String accountId,
  double amount = 999,
  String type = 'expense',
  DateTime? createdAt,
  String categoryId = 'Groceries',
  String note = 'a note',
}) => Transaction(
  id: id,
  title: 'Some transaction',
  amount: amount,
  categoryId: categoryId,
  accountId: accountId,
  transactionType: type,
  paymentMethod: 'manual',
  note: note,
  createdAt: createdAt ?? DateTime(2026, 6, 1, 10, 30),
);

void main() {
  group('resolveWalletIdForAccount', () {
    test('an accountId that already equals a real wallet id is returned unchanged', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      expect(resolveWalletIdForAccount('w1', wallets), 'w1');
    });

    test('exact single wallet-name match resolves to that wallet id', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank'), _wallet(id: 'w2', name: 'SBI Bank')];
      expect(resolveWalletIdForAccount('HDFC Bank', wallets), 'w1');
    });

    test('legacy label resolves via a single unambiguous type match', () {
      final wallets = [_wallet(id: 'w1', name: 'My Cash', type: 'Cash')];
      expect(resolveWalletIdForAccount('Cash', wallets), 'w1');
    });

    test('ambiguous type match across multiple wallets is never guessed', () {
      final wallets = [
        _wallet(id: 'w1', name: 'HDFC Bank', type: 'Checking'),
        _wallet(id: 'w2', name: 'SBI Bank', type: 'Checking'),
      ];
      expect(resolveWalletIdForAccount('Checking', wallets), isNull);
    });

    test('no matching wallet at all resolves to null, not a guess', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      expect(resolveWalletIdForAccount('Some Unrelated Label', wallets), isNull);
    });

    test('null/empty accountId resolves to null', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      expect(resolveWalletIdForAccount(null, wallets), isNull);
      expect(resolveWalletIdForAccount('', wallets), isNull);
    });
  });

  group('TransactionAccountMigration.plan', () {
    test('9. exact wallet-name match migrates to that wallet id', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 't1', accountId: 'HDFC Bank')],
        wallets: wallets,
      );

      expect(result.migratedCount, 1);
      expect(result.updatedTransactions.single.accountId, 'w1');
    });

    test('9b. known legacy label migrates when exactly one wallet type matches', () {
      final wallets = [_wallet(id: 'w1', name: 'My Cash', type: 'Cash')];
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 't1', accountId: 'Cash')],
        wallets: wallets,
      );

      expect(result.migratedCount, 1);
      expect(result.updatedTransactions.single.accountId, 'w1');
    });

    test('10. ambiguous legacy mapping is NOT guessed', () {
      final wallets = [
        _wallet(id: 'w1', name: 'HDFC Bank', type: 'Checking'),
        _wallet(id: 'w2', name: 'SBI Bank', type: 'Checking'),
      ];
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 't1', accountId: 'Checking')],
        wallets: wallets,
      );

      expect(result.migratedCount, 0);
      expect(result.unresolvedCount, 1);
      expect(result.updatedTransactions, isEmpty);
    });

    test('11. a legacy accountId matching no wallet is preserved unchanged', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final original = _tx(id: 't1', accountId: 'Some Old Label');
      final result = TransactionAccountMigration.plan(
        transactions: [original],
        wallets: wallets,
      );

      expect(result.unresolvedCount, 1);
      expect(result.updatedTransactions, isEmpty);
    });

    test('an already-correct accountId (real wallet id) needs no change', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 't1', accountId: 'w1')],
        wallets: wallets,
      );

      expect(result.alreadyCorrectCount, 1);
      expect(result.updatedTransactions, isEmpty);
    });

    test('12/13. running the plan again on already-migrated data makes no further changes', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final original = [_tx(id: 't1', accountId: 'HDFC Bank')];

      final firstPass = TransactionAccountMigration.plan(
        transactions: original,
        wallets: wallets,
      );
      expect(firstPass.migratedCount, 1);

      // Apply the first pass's result, then plan again against the new data.
      final afterFirstPass = firstPass.updatedTransactions;
      expect(afterFirstPass.single.accountId, 'w1');

      final secondPass = TransactionAccountMigration.plan(
        transactions: afterFirstPass,
        wallets: wallets,
      );

      expect(secondPass.migratedCount, 0);
      expect(secondPass.alreadyCorrectCount, 1);
      expect(secondPass.updatedTransactions, isEmpty);
    });

    test('17. migration never modifies the transaction amount', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 't1', accountId: 'HDFC Bank', amount: 4321.5)],
        wallets: wallets,
      );

      expect(result.updatedTransactions.single.amount, 4321.5);
    });

    test('18. migration never modifies the transaction date', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final date = DateTime(2025, 3, 14, 9, 15);
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 't1', accountId: 'HDFC Bank', createdAt: date)],
        wallets: wallets,
      );

      expect(result.updatedTransactions.single.createdAt, date);
    });

    test('19. migration never modifies the transaction id', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final result = TransactionAccountMigration.plan(
        transactions: [_tx(id: 'stable-id-123', accountId: 'HDFC Bank')],
        wallets: wallets,
      );

      expect(result.updatedTransactions.single.id, 'stable-id-123');
    });

    test('20. migration never modifies category, note, or transaction type', () {
      final wallets = [_wallet(id: 'w1', name: 'HDFC Bank')];
      final result = TransactionAccountMigration.plan(
        transactions: [
          _tx(
            id: 't1',
            accountId: 'HDFC Bank',
            categoryId: 'Travel',
            note: 'flight tickets',
            type: 'expense',
          ),
        ],
        wallets: wallets,
      );

      final migrated = result.updatedTransactions.single;
      expect(migrated.categoryId, 'Travel');
      expect(migrated.note, 'flight tickets');
      expect(migrated.transactionType, 'expense');
    });

    test('an empty transaction list produces no changes', () {
      final result = TransactionAccountMigration.plan(
        transactions: const [],
        wallets: [_wallet(id: 'w1', name: 'HDFC Bank')],
      );

      expect(result.updatedTransactions, isEmpty);
      expect(result.migratedCount, 0);
      expect(result.unresolvedCount, 0);
      expect(result.alreadyCorrectCount, 0);
    });
  });
}
