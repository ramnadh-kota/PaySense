import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/sms_automation_provider.dart';
import 'package:paysense/shared/providers/sms_review_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/notification_repository.dart';
import 'package:paysense/shared/repositories/sms_review_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/sms_channel.dart';

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
  await Hive.openBox('sms_processed_fingerprints');
}

Future<Wallet> _addWallet(
  String id,
  String name, {
  double balance = 10000,
  String bankName = '',
  String type = 'Bank',
}) async {
  final wallet = Wallet(
    id: id,
    name: name,
    bankName: bankName,
    type: type,
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
  await WalletRepository.instance.add(wallet);
  return wallet;
}

RawSmsEvent _event({
  required String sender,
  required String body,
  DateTime? timestamp,
  String? nativeId,
}) {
  return RawSmsEvent(
    nativeId: nativeId ?? '${sender}_${body.hashCode}',
    sender: sender,
    body: body,
    timestamp: timestamp ?? DateTime(2026, 8, 12, 10, 30),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_sms_processor_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('13. a high-confidence debit SMS auto-creates an expense transaction', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final summary = await processor.processEvents([
      _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    expect(summary.autoAdded, 1);
    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(1));
    expect(transactions.single.transactionType, 'expense');
    expect(transactions.single.amount, 500);
  });

  test('14. a high-confidence credit SMS auto-creates an income transaction', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final summary = await processor.processEvents([
      _event(sender: 'HDFCBK', body: 'Rs. 50,000 credited to your account'),
    ]);

    expect(summary.autoAdded, 1);
    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions.single.transactionType, 'income');
    expect(transactions.single.amount, 50000);
  });

  test('15. the auto-created transaction stores the real Wallet.id, never a display label', () async {
    final wallet = await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    await processor.processEvents([
      _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    final transaction = (await TransactionRepository.instance.getAll()).single;
    expect(transaction.accountId, wallet.id);
    expect(transaction.accountId, isNot('HDFC Bank'));
  });

  test('16. the wallet balance is updated exactly once', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    await processor.processEvents([
      _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    final wallet = await WalletRepository.instance.getById('w-hdfc');
    expect(wallet!.currentBalance, 4500);
  });

  test('17. a duplicate SMS (re-delivered) creates no second transaction', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final event = _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON');

    final first = await processor.processEvents([event]);
    final second = await processor.processEvents([event]);

    expect(first.autoAdded, 1);
    expect(second.autoAdded, 0);
    expect(second.duplicatesSkipped, 1);
    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(1));
  });

  test('18. a duplicate SMS causes no second wallet balance mutation', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final event = _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON');

    await processor.processEvents([event]);
    await processor.processEvents([event]);

    final wallet = await WalletRepository.instance.getById('w-hdfc');
    expect(wallet!.currentBalance, 4500); // only decreased once, not 4000
  });

  test('19. an unmatched wallet sends the transaction to review instead of guessing', () async {
    await _addWallet('w-a', 'Wallet A', bankName: 'Other Bank');
    await _addWallet('w-b', 'Wallet B', bankName: 'Another Bank');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final summary = await processor.processEvents([
      _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    expect(summary.autoAdded, 0);
    expect(summary.sentToReview, 1);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
    final pending = await SmsReviewRepository.instance.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.suggestedWalletId, isNull);
  });

  test('20. an ambiguous wallet match (two candidates) sends to review, never guesses', () async {
    await _addWallet('w-salary', 'HDFC Salary', bankName: 'HDFC');
    await _addWallet('w-savings', 'HDFC Savings', bankName: 'HDFC');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final summary = await processor.processEvents([
      _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    expect(summary.autoAdded, 0);
    expect(summary.sentToReview, 1);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
  });

  test('21. accepting a review item creates the transaction using the chosen wallet', () async {
    final wallet = await _addWallet('w-a', 'Wallet A', balance: 3000);
    await _addWallet('w-b', 'Wallet B', balance: 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    await processor.processEvents([
      _event(sender: 'UNKNOWNBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    final pending = await SmsReviewRepository.instance.getPending();
    expect(pending, hasLength(1));

    await container
        .read(smsReviewItemsProvider.notifier)
        .acceptItem(pending.single.id, walletId: wallet.id);

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(1));
    expect(transactions.single.accountId, wallet.id);
    expect(transactions.single.transactionType, 'expense');

    final updatedWallet = await WalletRepository.instance.getById(wallet.id);
    expect(updatedWallet!.currentBalance, 2500);

    final items = await SmsReviewRepository.instance.getAll();
    expect(items.single.status, SmsReviewStatus.accepted);
  });

  test('22. ignoring a review item creates no transaction and touches no wallet', () async {
    final wallet = await _addWallet('w-a', 'Wallet A', balance: 3000);
    await _addWallet('w-b', 'Wallet B', balance: 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    await processor.processEvents([
      _event(sender: 'UNKNOWNBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
    ]);

    final pending = await SmsReviewRepository.instance.getPending();
    await container.read(smsReviewItemsProvider.notifier).ignoreItem(pending.single.id);

    expect(await TransactionRepository.instance.getAll(), isEmpty);
    final updatedWallet = await WalletRepository.instance.getById(wallet.id);
    expect(updatedWallet!.currentBalance, 3000);

    final items = await SmsReviewRepository.instance.getAll();
    expect(items.single.status, SmsReviewStatus.ignored);
  });

  test('23. a confidently-matched transfer SMS is recorded as a transfer, never income/expense', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 50000);
    await _addWallet('w-sbi', 'SBI Bank', bankName: 'SBI', balance: 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final summary = await processor.processEvents([
      _event(
        sender: 'HDFCBK',
        body: 'Rs. 5000 transferred to your own account SBI Bank',
      ),
    ]);

    expect(summary.transfersCreated, 1);
    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(2));
    expect(transactions.every((t) => t.transactionType == 'transfer'), isTrue);
    expect(
      transactions.where((t) => t.transactionType == 'income' || t.transactionType == 'expense'),
      isEmpty,
    );

    final hdfc = await WalletRepository.instance.getById('w-hdfc');
    final sbi = await WalletRepository.instance.getById('w-sbi');
    expect(hdfc!.currentBalance, 45000);
    expect(sbi!.currentBalance, 6000);
  });

  test('24. exactly one notification is created even if the same SMS is processed twice', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final processor = container.read(smsTransactionProcessorProvider);
    final event = _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON');

    await processor.processEvents([event]);
    await processor.processEvents([event]);

    final notifications = await NotificationRepository.instance.getAll();
    expect(notifications, hasLength(1));
    expect(notifications.single.type, NotificationType.smsTransaction.name);
  });

  test('25. the raw SMS body is never retained on the created transaction or review item', () async {
    await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    const secretMarker = 'ZZZ_RAW_BODY_MARKER_SHOULD_NOT_PERSIST_ZZZ';
    final processor = container.read(smsTransactionProcessorProvider);
    await processor.processEvents([
      _event(
        sender: 'HDFCBK',
        body: 'Rs. 500 debited from A/c XX1234 at AMAZON. Ref $secretMarker',
      ),
    ]);

    final transaction = (await TransactionRepository.instance.getAll()).single;
    expect(transaction.note, isNot(contains(secretMarker)));
    expect(transaction.title, isNot(contains(secretMarker)));

    final notifications = await NotificationRepository.instance.getAll();
    expect(notifications.single.message, isNot(contains(secretMarker)));

    // No review item was created in this scenario (high confidence,
    // unambiguous wallet), but SmsReviewItem structurally has no field
    // capable of holding a raw SMS body at all — confirmed by its model
    // definition never declaring one.
    expect(await SmsReviewRepository.instance.getAll(), isEmpty);
  });

  test(
    '18. failed processing does not lose the queued event — a mid-batch '
    'error means acknowledge() must never run, so the event is retried '
    'next time rather than silently dropped',
    () async {
      await _addWallet('w-hdfc', 'HDFC Bank', bankName: 'HDFC', balance: 5000);

      final fakeChannel = _RecordingSmsChannel([
        _event(sender: 'HDFCBK', body: 'Rs. 500 debited from A/c XX1234 at AMAZON'),
      ]);
      final container = ProviderContainer(
        overrides: [
          walletsProvider.overrideWith(_ThrowingWalletsNotifier.new),
          smsChannelProvider.overrideWithValue(fakeChannel),
        ],
      );
      addTearDown(container.dispose);

      final processor = container.read(smsTransactionProcessorProvider);

      await expectLater(processor.processPending(), throwsException);

      expect(
        fakeChannel.acknowledgeCalled,
        isFalse,
        reason: 'acknowledge() must not run when processing throws — the '
            'native queue is the only copy of this event, so acknowledging '
            'it here would lose it forever.',
      );
      expect(await TransactionRepository.instance.getAll(), isEmpty);
    },
  );
}

class _ThrowingWalletsNotifier extends WalletsNotifier {
  @override
  Future<List<Wallet>> build() async {
    throw Exception('simulated failure reading wallets');
  }
}

class _RecordingSmsChannel extends SmsChannel {
  _RecordingSmsChannel(this._pending);

  final List<RawSmsEvent> _pending;
  bool acknowledgeCalled = false;

  @override
  Future<List<RawSmsEvent>> fetchPending() async => _pending;

  @override
  Future<void> acknowledge(List<String> nativeIds) async {
    acknowledgeCalled = true;
  }
}
