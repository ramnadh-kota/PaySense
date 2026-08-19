import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/sms_review_provider.dart';
import 'package:paysense/shared/repositories/notification_repository.dart';
import 'package:paysense/shared/repositories/sms_review_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SmsReviewItemAdapter());
  }

  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<AppNotification>('app_notifications');
  await Hive.openBox<SmsReviewItem>('sms_review_items');
}

Future<Wallet> _addWallet(String id, String name, {double balance = 5000}) async {
  final wallet = Wallet(
    id: id,
    name: name,
    bankName: '',
    type: 'Bank',
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
  await WalletRepository.instance.add(wallet);
  return wallet;
}

SmsReviewItem _pendingItem(String id, {double amount = 500}) {
  return SmsReviewItem.create(
    id: id,
    amount: amount,
    direction: SmsReviewDirection.debit,
    sender: 'HDFCBK',
    timestamp: DateTime(2026, 8, 12, 10, 30),
    confidence: 0.4,
    merchant: 'AMAZON',
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_sms_review_concurrency_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    if (!Hive.isBoxOpen('transactions')) {
      await Hive.openBox<Transaction>('transactions');
    }
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    '1. accept creates exactly one transaction, and 2. the wallet balance '
    'changes exactly once',
    () async {
      final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
      await SmsReviewRepository.instance.addIfNotExists(_pendingItem('item1'));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(smsReviewItemsProvider.notifier)
          .acceptItem('item1', walletId: wallet.id);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.amount, 500);
      expect(transactions.single.accountId, wallet.id);

      final updatedWallet = await WalletRepository.instance.getById(wallet.id);
      expect(updatedWallet!.currentBalance, 4500);

      final stored = await SmsReviewRepository.instance.getById('item1');
      expect(stored!.status, SmsReviewStatus.accepted);
    },
  );

  test(
    '3. two simultaneous accept calls on the same item create exactly one '
    'transaction, and 4. mutate the wallet balance exactly once',
    () async {
      final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
      await SmsReviewRepository.instance.addIfNotExists(_pendingItem('item1'));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(smsReviewItemsProvider.notifier);

      // Unawaited back-to-back calls: Dart runs each synchronously up to
      // its first `await`, so the second call's `_pendingAccepts.add(id)`
      // check runs after the first call has already claimed the guard —
      // exactly like two rapid taps on "Add Transaction" would.
      final f1 = notifier.acceptItem('item1', walletId: wallet.id);
      final f2 = notifier.acceptItem('item1', walletId: wallet.id);
      await Future.wait([f1, f2]);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));

      final updatedWallet = await WalletRepository.instance.getById(wallet.id);
      expect(updatedWallet!.currentBalance, 4500); // decreased exactly once
    },
  );

  test('5. exactly one notification is created for an accepted item', () async {
    final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
    await SmsReviewRepository.instance.addIfNotExists(_pendingItem('item1'));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(smsReviewItemsProvider.notifier);

    final f1 = notifier.acceptItem('item1', walletId: wallet.id);
    final f2 = notifier.acceptItem('item1', walletId: wallet.id);
    await Future.wait([f1, f2]);

    final notifications = await NotificationRepository.instance.getAll();
    expect(notifications, hasLength(1));
    expect(notifications.single.type, NotificationType.smsTransaction.name);
  });

  test(
    '6. a failed acceptance releases the guard, and 7. a later valid '
    'acceptance can then succeed',
    () async {
      final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
      await SmsReviewRepository.instance.addIfNotExists(_pendingItem('item1'));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(smsReviewItemsProvider.notifier);

      // Force the transactions box closed so the accept attempt throws
      // partway through (at transactionRepository.add) instead of
      // succeeding — a controlled failure injection, not a code change.
      await Hive.box<Transaction>('transactions').close();

      await expectLater(
        notifier.acceptItem('item1', walletId: wallet.id),
        throwsA(anything),
      );

      await Hive.openBox<Transaction>('transactions');

      // The item is still pending (the failure happened before the
      // status write) — if the guard hadn't been released in a `finally`,
      // this would silently no-op forever instead of actually accepting.
      await notifier.acceptItem('item1', walletId: wallet.id);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      final stored = await SmsReviewRepository.instance.getById('item1');
      expect(stored!.status, SmsReviewStatus.accepted);
    },
  );

  test(
    '8. an already-accepted item stays protected — a later accept call on '
    'it creates no second transaction or balance mutation',
    () async {
      final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
      await SmsReviewRepository.instance.addIfNotExists(_pendingItem('item1'));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(smsReviewItemsProvider.notifier);

      await notifier.acceptItem('item1', walletId: wallet.id);
      // Fully sequential — the in-flight guard has already been released
      // by the time this second, later call runs; only the pre-existing
      // `item.status != pending` check protects it here.
      await notifier.acceptItem('item1', walletId: wallet.id);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      final updatedWallet = await WalletRepository.instance.getById(wallet.id);
      expect(updatedWallet!.currentBalance, 4500);
    },
  );

  test('an ignored item stays protected from a later accept call', () async {
    final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
    await SmsReviewRepository.instance.addIfNotExists(_pendingItem('item1'));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(smsReviewItemsProvider.notifier);

    await notifier.ignoreItem('item1');
    await notifier.acceptItem('item1', walletId: wallet.id);

    expect(await TransactionRepository.instance.getAll(), isEmpty);
    final updatedWallet = await WalletRepository.instance.getById(wallet.id);
    expect(updatedWallet!.currentBalance, 5000);
    final stored = await SmsReviewRepository.instance.getById('item1');
    expect(stored!.status, SmsReviewStatus.ignored);
  });
}
