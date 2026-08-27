import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/repositories/account_repository.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/notification_repository.dart';
import 'package:paysense/shared/repositories/sms_fingerprint_repository.dart';
import 'package:paysense/shared/repositories/sms_review_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_scope.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BudgetAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(GoalAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BillAdapter());
  }
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(LoanAdapter());
  }
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(AccountAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SmsReviewItemAdapter());
  }
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(TaxSettingsAdapter());
  }

  // Global boxes only — exactly what main.dart opens eagerly. Every
  // financial box is opened lazily, per account, by AccountScope.
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox('app_settings');
}

Wallet _wallet(String id, {double balance = 1000}) => Wallet(
  id: id,
  name: 'Wallet $id',
  bankName: 'Test Bank',
  type: 'bank',
  openingBalance: balance,
  currentBalance: balance,
  createdAt: DateTime(2026, 1, 1),
);

Transaction _transaction(String id, String walletId) => Transaction(
  id: id,
  title: 'Txn $id',
  amount: 100,
  categoryId: 'food',
  accountId: walletId,
  transactionType: 'expense',
  paymentMethod: 'card',
  note: '',
  createdAt: DateTime(2026, 1, 2),
);

Goal _goal(String id) => Goal(
  id: id,
  title: 'Goal $id',
  targetAmount: 5000,
  currentAmount: 0,
  targetDate: DateTime(2026, 12, 31),
  category: 'savings',
  icon: 'savings',
  color: 0,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  isCompleted: false,
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_isolation_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    AccountScope.instance.deactivate();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Account B starts with zero of Account A financial data, and switching '
    'back to A shows only A data (full workflow from the isolation spec)',
    () async {
      final containerA = ProviderContainer();
      await containerA.read(authProvider.notifier).signUp(
        fullName: 'Alice',
        email: 'alice@example.com',
        password: 'password123',
      );

      await WalletRepository.instance.add(_wallet('wallet-a'));
      await TransactionRepository.instance.add(_transaction('txn-a', 'wallet-a'));
      await GoalRepository.instance.add(_goal('goal-a'));
      await NotificationRepository.instance.add(
        AppNotification(
          id: 'notif-a',
          title: 'A notif',
          message: 'body',
          type: NotificationType.general.name,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await SmsReviewRepository.instance.addIfNotExists(
        SmsReviewItem.create(
          id: 'sms-a',
          amount: 100,
          direction: SmsReviewDirection.debit,
          sender: 'BANK',
          timestamp: DateTime(2026, 1, 1),
          confidence: 0.8,
          merchant: 'Shop',
        ),
      );
      await SmsFingerprintRepository.instance.markProcessed('fingerprint-a');

      expect((await WalletRepository.instance.getAll()).length, 1);
      expect((await TransactionRepository.instance.getAll()).length, 1);
      expect((await GoalRepository.instance.getAll()).length, 1);
      expect((await NotificationRepository.instance.getAll()).length, 1);
      expect((await SmsReviewRepository.instance.getAll()).length, 1);
      expect(SmsFingerprintRepository.instance.isProcessed('fingerprint-a'), isTrue);

      await containerA.read(authProvider.notifier).logout();
      containerA.dispose();

      // ---- Account B signs up on the same device ----
      final containerB = ProviderContainer();
      await containerB.read(authProvider.notifier).signUp(
        fullName: 'Bob',
        email: 'bob@example.com',
        password: 'password456',
      );

      expect(
        await WalletRepository.instance.getAll(),
        isEmpty,
        reason: "Account B must see zero of Account A's wallets",
      );
      expect(
        await TransactionRepository.instance.getAll(),
        isEmpty,
        reason: "Account B must see zero of Account A's transactions",
      );
      expect(await GoalRepository.instance.getAll(), isEmpty);
      expect(await NotificationRepository.instance.getAll(), isEmpty);
      expect(await SmsReviewRepository.instance.getAll(), isEmpty);
      expect(
        SmsFingerprintRepository.instance.isProcessed('fingerprint-a'),
        isFalse,
        reason: 'SMS fingerprint history must not leak across accounts',
      );

      await WalletRepository.instance.add(_wallet('wallet-b', balance: 500));
      await TransactionRepository.instance.add(_transaction('txn-b', 'wallet-b'));
      expect((await WalletRepository.instance.getAll()).length, 1);
      expect((await WalletRepository.instance.getAll()).first.id, 'wallet-b');

      await containerB.read(authProvider.notifier).logout();
      containerB.dispose();

      // ---- Switch back to Account A ----
      final containerA2 = ProviderContainer();
      await containerA2.read(authProvider.notifier).login(
        email: 'alice@example.com',
        password: 'password123',
      );

      final walletsForA = await WalletRepository.instance.getAll();
      expect(walletsForA.length, 1);
      expect(walletsForA.first.id, 'wallet-a');
      expect((await TransactionRepository.instance.getAll()).single.id, 'txn-a');
      expect((await GoalRepository.instance.getAll()).single.id, 'goal-a');
      expect(SmsFingerprintRepository.instance.isProcessed('fingerprint-a'), isTrue);

      // ---- Delete Account A ----
      await containerA2.read(authProvider.notifier).deleteAccount(
        password: 'password123',
      );
      expect(await AccountRepository.instance.exists('alice@example.com'), isFalse);
      containerA2.dispose();

      // ---- Account B's data must still be fully intact ----
      final containerB2 = ProviderContainer();
      addTearDown(containerB2.dispose);
      await containerB2.read(authProvider.notifier).login(
        email: 'bob@example.com',
        password: 'password456',
      );
      final walletsForB = await WalletRepository.instance.getAll();
      expect(walletsForB.length, 1);
      expect(walletsForB.first.id, 'wallet-b');
      expect((await TransactionRepository.instance.getAll()).single.id, 'txn-b');
      expect(await AccountRepository.instance.exists('bob@example.com'), isTrue);
    },
  );

  test('App Lock / device settings stay global by design (documented '
      'trade-off), so they are unaffected by account switches', () async {
    await AppSettingsRepository.instance.setAppLockEnabled(true);

    final containerA = ProviderContainer();
    await containerA.read(authProvider.notifier).signUp(
      fullName: 'Alice',
      email: 'alice@example.com',
      password: 'password123',
    );
    expect((await AppSettingsRepository.instance.getAppLockSettings()).enabled, isTrue);
    containerA.dispose();
  });

  test('legacy pre-isolation data migrates to the first account that logs '
      'in after the update, and is not exposed to a second account', () async {
    // Simulate a pre-update install: data sitting in the old, unscoped
    // 'wallets' box before AccountScope existed.
    final legacyWallets = await Hive.openBox<Wallet>('wallets');
    await legacyWallets.put('legacy-wallet', _wallet('legacy-wallet'));

    final containerA = ProviderContainer();
    await containerA.read(authProvider.notifier).signUp(
      fullName: 'Alice',
      email: 'alice@example.com',
      password: 'password123',
    );

    final aliceWallets = await WalletRepository.instance.getAll();
    expect(aliceWallets.length, 1);
    expect(aliceWallets.first.id, 'legacy-wallet');
    containerA.dispose();

    final containerB = ProviderContainer();
    addTearDown(containerB.dispose);
    await containerB.read(authProvider.notifier).signUp(
      fullName: 'Bob',
      email: 'bob@example.com',
      password: 'password456',
    );

    expect(
      await WalletRepository.instance.getAll(),
      isEmpty,
      reason: 'Legacy data must be claimed by exactly one account, never a '
          'later one',
    );
  });
}
