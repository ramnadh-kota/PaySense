// TASK GROUP C — MULTI-USER DATA ISOLATION.
//
// These tests document ACTUAL current behavior, verified against the
// real repositories — not a desired/assumed behavior. Recon for this
// milestone established that PaySense's local financial repositories
// (TransactionRepository, WalletRepository, BudgetRepository, etc.) use
// a single FIXED Hive box name each (e.g. 'transactions'), never derived
// from the signed-in account. AccountSessionRepository only swaps which
// email string is "current" — it does not partition or clear any
// financial box.
//
// KNOWN LIMITATION (not fixed in this milestone — see the final report):
// a full fix requires namespacing every local repository by account id,
// a separate architectural milestone, not a targeted defect fix. These
// tests exist so this behavior is documented and regression-tracked
// rather than silently assumed, and so the account-deletion screen's
// updated warning copy (see account_deletion_screen.dart) is verified
// to reflect what the code actually does.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
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
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_deletion_service.dart';
import 'package:paysense/shared/utils/password_hasher.dart';

// Mirrors test/account_deletion_test.dart's full box/adapter setup —
// AccountDeletionService.deleteEverythingLocally touches every one of
// these boxes, so the second test below needs them all open, not just
// the two boxes the first test exercises.
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
}

// Mirrors AuthNotifier.signUp's own behavior of normalizing the email
// BEFORE constructing the Account — AccountRepository.add() itself does
// NOT normalize on write (only exists()/delete()/getByEmail() do on
// read), so a non-normalized email here would silently create a key
// mismatch, exactly as production code avoids by normalizing first.
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
    tempDir = await Directory.systemTemp.createTemp('paysense_isolation_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('KNOWN LIMITATION — local financial data is not partitioned by account', () {
    test('a second account signed in on the same device sees the first account\'s wallets/transactions', () async {
      // User A signs up (in this local-only model, "signing up" just adds
      // an Account record + a session) and adds financial data.
      await AccountRepository.instance.add(_account('userA@example.com'));
      await AuthSessionRepository.instance.setSession('userA@example.com');
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'User A Cash', bankName: '', type: 'cash', openingBalance: 5000, currentBalance: 5000, createdAt: DateTime(2026, 1, 1)),
      );
      await TransactionRepository.instance.add(
        Transaction(id: 't1', title: 'User A Salary', amount: 50000, categoryId: 'Salary', accountId: 'w1', transactionType: 'income', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, 1, 1)),
      );

      // User A logs out (session cleared — financial data untouched, this
      // part IS correctly scoped, see auth_provider_test.dart).
      await AuthSessionRepository.instance.clearSession();

      // User B signs up with a DIFFERENT email on the same device/install.
      await AccountRepository.instance.add(_account('userB@example.com'));
      await AuthSessionRepository.instance.setSession('userB@example.com');

      // User B has never added anything — but WalletRepository/
      // TransactionRepository read from the SAME global Hive boxes
      // regardless of which account is signed in.
      final walletsVisibleToUserB = await WalletRepository.instance.getAll();
      final transactionsVisibleToUserB = await TransactionRepository.instance.getAll();

      expect(walletsVisibleToUserB.any((w) => w.name == 'User A Cash'), isTrue);
      expect(transactionsVisibleToUserB.any((t) => t.title == 'User A Salary'), isTrue);
    });
  });

  group('Account deletion — cross-account impact (matches the updated warning copy)', () {
    test('deleteEverythingLocally for one account also removes financial data belonging to every other account', () async {
      await AccountRepository.instance.add(_account('userA@example.com'));
      await AccountRepository.instance.add(_account('userB@example.com'));
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'User A Cash', bankName: '', type: 'cash', openingBalance: 1000, currentBalance: 1000, createdAt: DateTime(2026, 1, 1)),
      );
      await WalletRepository.instance.add(
        Wallet(id: 'w2', name: 'User B Cash', bankName: '', type: 'cash', openingBalance: 2000, currentBalance: 2000, createdAt: DateTime(2026, 1, 1)),
      );

      // User A deletes "their" account.
      await AccountDeletionService.deleteEverythingLocally('userA@example.com');

      // Only User A's Account record is scoped/removed correctly...
      expect(await AccountRepository.instance.exists('userA@example.com'), isFalse);
      expect(await AccountRepository.instance.exists('userB@example.com'), isTrue);

      // ...but ALL wallets are gone, including User B's, because
      // WalletRepository has no concept of ownership to filter by. This
      // is the exact behavior the account-deletion screen's warning copy
      // was updated to disclose plainly.
      final remainingWallets = await WalletRepository.instance.getAll();
      expect(remainingWallets, isEmpty);
    });
  });
}
