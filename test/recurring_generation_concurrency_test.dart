import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

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
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox('app_settings');
  await Hive.openBox<AppNotification>('app_notifications');
}

Future<Wallet> _addWallet(String id, String name, {double balance = 10000}) async {
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

RecurringTransaction _dueItem(String id, String walletId, {double amount = 500}) {
  return RecurringTransaction.create(
    id: id,
    title: 'Test recurring $id',
    amount: amount,
    categoryId: 'Subscriptions',
    accountId: walletId,
    transactionType: 'expense',
    frequency: 'Monthly',
    startDate: DateTime.now().subtract(const Duration(days: 1)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_recurring_concurrency_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    // Reopen anything a failure-injection test may have left closed, so
    // Hive.deleteFromDisk() below can clean up every box.
    if (!Hive.isBoxOpen('transactions')) {
      await Hive.openBox<Transaction>('transactions');
    }
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('1. a due recurring transaction generates exactly once', () async {
    final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
    await RecurringTransactionRepository.instance.add(_dueItem('r1', wallet.id));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(recurringTransactionsProvider.future);

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 500);
  });

  test(
    '2. two simultaneous generation calls produce exactly one transaction, '
    'and 3. the wallet balance changes exactly once',
    () async {
      final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
      await RecurringTransactionRepository.instance.add(_dueItem('r1', wallet.id));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Prime the provider once so both reload() calls below race against
      // an already-built notifier, not against build() itself.
      await container.read(recurringTransactionsProvider.future);

      // Reset back to "due" so there's something for the race to actually
      // contend over, then fire two reloads without awaiting the first —
      // Dart's synchronous-until-first-await execution means the second
      // call's guard check runs after the first call has already set the
      // in-flight flag, exactly like two rapid taps would.
      await TransactionRepository.instance.delete(
        (await TransactionRepository.instance.getAll()).single.id,
      );
      await RecurringTransactionRepository.instance.update(
        _dueItem('r1', wallet.id),
      );
      await WalletRepository.instance.add(wallet); // restore balance to 5000

      final notifier = container.read(recurringTransactionsProvider.notifier);
      final f1 = notifier.reload();
      final f2 = notifier.reload();
      await Future.wait([f1, f2]);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));

      final updatedWallet = await WalletRepository.instance.getById(wallet.id);
      expect(updatedWallet!.currentBalance, 4500); // decreased exactly once
    },
  );

  test('4. nextDueDate advances exactly once even under a concurrent race', () async {
    final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
    final original = _dueItem('r1', wallet.id);
    await RecurringTransactionRepository.instance.add(original);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Prime once so the two reload() calls below race against each other
    // on an already-built notifier, not against build() itself.
    await container.read(recurringTransactionsProvider.future);

    // Reset back to the same due state so there's something to race over.
    await TransactionRepository.instance.delete(
      (await TransactionRepository.instance.getAll()).single.id,
    );
    await RecurringTransactionRepository.instance.update(original);

    final notifier = container.read(recurringTransactionsProvider.notifier);
    final f1 = notifier.reload();
    final f2 = notifier.reload();
    await Future.wait([f1, f2]);

    final stored = await RecurringTransactionRepository.instance.getById('r1');
    // Advanced exactly one cycle forward from the original due date, not
    // two (which a double-generation would have produced).
    expect(
      stored!.nextDueDate,
      RecurringTransaction.computeNextDueDate(original.nextDueDate, 'Monthly'),
    );
  });

  test('5. sequential generation still works normally', () async {
    final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
    await RecurringTransactionRepository.instance.add(_dueItem('r1', wallet.id));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recurringTransactionsProvider.notifier);

    await container.read(recurringTransactionsProvider.future);
    await notifier.reload(); // fully awaited, sequential — not due again
    await notifier.reload();

    final transactions = await TransactionRepository.instance.getAll();
    expect(transactions, hasLength(1)); // still only the one due occurrence
  });

  test(
    '6. a failed generation releases the in-flight guard, and 7. a later '
    'valid generation can then run',
    () async {
      final wallet = await _addWallet('w1', 'Wallet 1', balance: 5000);
      await RecurringTransactionRepository.instance.add(_dueItem('r1', wallet.id));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force the transactions box closed so the in-flight generation
      // throws partway through (at transactionRepository.add) instead of
      // succeeding — a controlled failure injection, not a code change.
      await Hive.box<Transaction>('transactions').close();

      await expectLater(
        container.read(recurringTransactionsProvider.future),
        throwsA(anything),
      );

      await Hive.openBox<Transaction>('transactions');

      // If the guard hadn't been released in a `finally`, this would hang
      // forever returning stale data instead of actually generating.
      await container.read(recurringTransactionsProvider.notifier).reload();

      final state = container.read(recurringTransactionsProvider);
      expect(state.hasValue, isTrue);
      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
    },
  );

  test(
    '8. multiple independent due recurring transactions are all generated '
    'within a single (non-concurrent) pass — the guard only blocks '
    'concurrent calls, never legitimate multi-item processing',
    () async {
      final walletA = await _addWallet('w-a', 'Wallet A', balance: 5000);
      final walletB = await _addWallet('w-b', 'Wallet B', balance: 5000);
      await RecurringTransactionRepository.instance.add(
        _dueItem('r1', walletA.id, amount: 300),
      );
      await RecurringTransactionRepository.instance.add(
        _dueItem('r2', walletB.id, amount: 700),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(recurringTransactionsProvider.future);

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(2));
      expect(transactions.map((t) => t.amount), containsAll([300.0, 700.0]));

      final aAfter = await WalletRepository.instance.getById(walletA.id);
      final bAfter = await WalletRepository.instance.getById(walletB.id);
      expect(aAfter!.currentBalance, 4700);
      expect(bAfter!.currentBalance, 4300);
    },
  );
}
