// FUN FUNDS — account isolation and deletion scope. Mirrors
// multi_account_data_isolation_test.dart's exact pattern and its HONEST
// framing: PaySense's local financial repositories (Wallet/Transaction/
// etc.) are NOT partitioned by account — a documented, pre-existing
// limitation, not something Fun Funds could fix on its own without a
// larger, separate per-account-storage milestone. These tests prove Fun
// Funds groups/expenses/settlements behave IDENTICALLY to every other
// financial repository: visible to whichever account is signed in on this
// device (same known limitation, not a NEW regression), and fully removed
// by account deletion (verifying this milestone's wiring into
// AccountDeletionService actually works).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/fun_funds_expense.dart';
import 'package:paysense/shared/models/fun_funds_group.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/account_repository.dart';
import 'package:paysense/shared/repositories/auth_session_repository.dart';
import 'package:paysense/shared/repositories/fun_funds_expense_repository.dart';
import 'package:paysense/shared/repositories/fun_funds_group_repository.dart';
import 'package:paysense/shared/repositories/fun_funds_settlement_repository.dart';
import 'package:paysense/shared/services/account_deletion_service.dart';
import 'package:paysense/shared/utils/password_hasher.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WalletAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(RecurringTransactionAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(BillAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoanAdapter());
  if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(AccountAdapter());
  if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(AppNotificationAdapter());
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(SmsReviewItemAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(TaxSettingsAdapter());

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox('app_settings');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox<AppNotification>('app_notifications');
  await Hive.openBox<SmsReviewItem>('sms_review_items');
  await Hive.openBox('sms_processed_fingerprints');
  await Hive.openBox<TaxSettings>('tax_settings');
  await Hive.openBox(FunFundsGroupRepository.boxName);
  await Hive.openBox(FunFundsExpenseRepository.boxName);
  await Hive.openBox(FunFundsSettlementRepository.boxName);
}

Account _account(String email) => Account(
      id: AccountRepository.normalizeEmail(email),
      email: AccountRepository.normalizeEmail(email),
      fullName: 'Test User',
      passwordHash: PasswordHasher.hash('password123', 'salt'),
      passwordSalt: 'salt',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_fun_funds_scope_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('KNOWN LIMITATION (inherited, not new) — Fun Funds groups are not partitioned by account', () {
    test('a second account signed in on the same device sees the first account\'s Fun Funds groups', () async {
      await AccountRepository.instance.add(_account('userA@example.com'));
      await AuthSessionRepository.instance.setSession('userA@example.com');
      await FunFundsGroupRepository.instance.upsert(
        FunFundsGroup(id: 'g1', name: 'User A Trip', memberNames: const ['A', 'B'], createdAt: DateTime(2026, 1, 1)),
      );
      await AuthSessionRepository.instance.clearSession();

      await AccountRepository.instance.add(_account('userB@example.com'));
      await AuthSessionRepository.instance.setSession('userB@example.com');

      final groupsVisibleToUserB = await FunFundsGroupRepository.instance.getAll();
      expect(groupsVisibleToUserB.any((g) => g.name == 'User A Trip'), isTrue);
    });
  });

  group('Account deletion removes Fun Funds data', () {
    test('deleteEverythingLocally removes groups, expenses, and settlements', () async {
      await AccountRepository.instance.add(_account('userA@example.com'));
      await FunFundsGroupRepository.instance.upsert(
        FunFundsGroup(id: 'g1', name: 'Goa Trip', memberNames: const ['Ram', 'Priya'], createdAt: DateTime(2026, 1, 1)),
      );
      await FunFundsExpenseRepository.instance.upsert(
        FunFundsExpense(
          id: 'e1', groupId: 'g1', description: 'Hotel', totalAmount: 4000,
          payerName: 'Ram', participantNames: const ['Ram', 'Priya'], createdAt: DateTime(2026, 1, 2),
        ),
      );
      await FunFundsSettlementRepository.instance.markSettled(
        groupId: 'g1', expenseId: 'e1', debtorName: 'Priya', settledAt: DateTime(2026, 1, 3),
      );

      expect(await FunFundsGroupRepository.instance.getAll(), hasLength(1));
      expect(await FunFundsExpenseRepository.instance.getAll(), hasLength(1));
      expect(await FunFundsSettlementRepository.instance.getAll(), hasLength(1));

      await AccountDeletionService.deleteEverythingLocally('userA@example.com');

      expect(await FunFundsGroupRepository.instance.getAll(), isEmpty);
      expect(await FunFundsExpenseRepository.instance.getAll(), isEmpty);
      expect(await FunFundsSettlementRepository.instance.getAll(), isEmpty);
    });

    test('deleting one account also removes Fun Funds data belonging to every other account (same as every other financial repository)', () async {
      await AccountRepository.instance.add(_account('userA@example.com'));
      await AccountRepository.instance.add(_account('userB@example.com'));
      await FunFundsGroupRepository.instance.upsert(
        FunFundsGroup(id: 'g1', name: 'User A Group', memberNames: const ['A'], createdAt: DateTime(2026, 1, 1)),
      );
      await FunFundsGroupRepository.instance.upsert(
        FunFundsGroup(id: 'g2', name: 'User B Group', memberNames: const ['B'], createdAt: DateTime(2026, 1, 1)),
      );

      await AccountDeletionService.deleteEverythingLocally('userA@example.com');

      expect(await AccountRepository.instance.exists('userA@example.com'), isFalse);
      expect(await AccountRepository.instance.exists('userB@example.com'), isTrue);
      // Consistent with WalletRepository/TransactionRepository's own
      // documented cross-account deletion behavior — not a Fun-Funds-
      // specific regression.
      expect(await FunFundsGroupRepository.instance.getAll(), isEmpty);
    });
  });

  group('Group deletion cascades to its own expenses/settlements only', () {
    test('deleting one group does not remove another group\'s expenses', () async {
      await FunFundsExpenseRepository.instance.upsert(
        FunFundsExpense(
          id: 'e1', groupId: 'g1', description: 'Dinner', totalAmount: 1000,
          payerName: 'Ram', participantNames: const ['Ram', 'Priya'], createdAt: DateTime(2026, 1, 1),
        ),
      );
      await FunFundsExpenseRepository.instance.upsert(
        FunFundsExpense(
          id: 'e2', groupId: 'g2', description: 'Groceries', totalAmount: 500,
          payerName: 'Amit', participantNames: const ['Amit', 'Sara'], createdAt: DateTime(2026, 1, 1),
        ),
      );

      await FunFundsExpenseRepository.instance.deleteForGroup('g1');

      final remaining = await FunFundsExpenseRepository.instance.getAll();
      expect(remaining, hasLength(1));
      expect(remaining.single.groupId, 'g2');
    });
  });
}
