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
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/notification_repository.dart';
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
}

AppNotification _sample({
  required String id,
  String title = 'Test',
  String message = 'Test message',
  NotificationType type = NotificationType.general,
  DateTime? createdAt,
  bool isRead = false,
}) {
  return AppNotification(
    id: id,
    title: title,
    message: message,
    type: type.name,
    createdAt: createdAt ?? DateTime.now(),
    isRead: isRead,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_notification_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('add creates a notification retrievable via getAll', () async {
    await NotificationRepository.instance.add(_sample(id: 'n1'));
    final all = await NotificationRepository.instance.getAll();
    expect(all, hasLength(1));
    expect(all.first.id, 'n1');
  });

  test('getAll returns newest first', () async {
    final now = DateTime(2026, 8, 13, 12, 0);
    await NotificationRepository.instance.add(
      _sample(id: 'old', createdAt: now.subtract(const Duration(days: 2))),
    );
    await NotificationRepository.instance.add(
      _sample(id: 'newest', createdAt: now),
    );
    await NotificationRepository.instance.add(
      _sample(id: 'middle', createdAt: now.subtract(const Duration(days: 1))),
    );

    final all = await NotificationRepository.instance.getAll();
    expect(all.map((n) => n.id).toList(), ['newest', 'middle', 'old']);
  });

  test('unreadCount reflects only unread notifications', () async {
    await NotificationRepository.instance.add(_sample(id: 'n1', isRead: false));
    await NotificationRepository.instance.add(_sample(id: 'n2', isRead: false));
    await NotificationRepository.instance.add(_sample(id: 'n3', isRead: true));

    expect(await NotificationRepository.instance.unreadCount(), 2);
  });

  test('markAsRead flips a single notification to read', () async {
    await NotificationRepository.instance.add(_sample(id: 'n1', isRead: false));
    await NotificationRepository.instance.markAsRead('n1');

    final all = await NotificationRepository.instance.getAll();
    expect(all.single.isRead, isTrue);
  });

  test('markAllAsRead flips every notification to read', () async {
    await NotificationRepository.instance.add(_sample(id: 'n1', isRead: false));
    await NotificationRepository.instance.add(_sample(id: 'n2', isRead: false));
    await NotificationRepository.instance.markAllAsRead();

    final all = await NotificationRepository.instance.getAll();
    expect(all.every((n) => n.isRead), isTrue);
  });

  test('delete removes a single notification', () async {
    await NotificationRepository.instance.add(_sample(id: 'n1'));
    await NotificationRepository.instance.add(_sample(id: 'n2'));
    await NotificationRepository.instance.delete('n1');

    final all = await NotificationRepository.instance.getAll();
    expect(all.map((n) => n.id), ['n2']);
  });

  test('clearAll removes the entire notification history', () async {
    await NotificationRepository.instance.add(_sample(id: 'n1'));
    await NotificationRepository.instance.add(_sample(id: 'n2'));
    await NotificationRepository.instance.clearAll();

    expect(await NotificationRepository.instance.getAll(), isEmpty);
  });

  test('addIfNotExists prevents duplicates for the same stable id', () async {
    final first = await NotificationRepository.instance.addIfNotExists(
      _sample(id: 'bill:b1:2026-08-20', title: 'Electricity'),
    );
    final second = await NotificationRepository.instance.addIfNotExists(
      _sample(id: 'bill:b1:2026-08-20', title: 'Electricity (rescheduled)'),
    );

    expect(first, isTrue);
    expect(second, isFalse);
    final all = await NotificationRepository.instance.getAll();
    expect(all, hasLength(1));
    // The original record is preserved, not overwritten by the second call.
    expect(all.single.title, 'Electricity');
  });

  test('notification history persists across a fresh provider container', () async {
    final firstContainer = ProviderContainer();
    await firstContainer.read(notificationsProvider.notifier).addIfNotExists(
      _sample(id: 'n1', title: 'Persisted'),
    );
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    final notifications = await secondContainer.read(notificationsProvider.future);
    expect(notifications, hasLength(1));
    expect(notifications.single.title, 'Persisted');
  });

  test('unreadNotificationCountProvider reflects unread notifications reactively', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(notificationsProvider.future);
    expect(container.read(unreadNotificationCountProvider), 0);

    await container.read(notificationsProvider.notifier).addIfNotExists(
      _sample(id: 'n1'),
    );
    expect(container.read(unreadNotificationCountProvider), 1);

    await container.read(notificationsProvider.notifier).markAsRead('n1');
    expect(container.read(unreadNotificationCountProvider), 0);
  });

  test('bill reminders respect the existing notification preference toggle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await WalletRepository.instance.add(
      Wallet(
        id: 'wallet-cash',
        name: 'Cash',
        bankName: '',
        type: 'cash',
        openingBalance: 1000,
        currentBalance: 1000,
        createdAt: DateTime.now(),
      ),
    );

    // Disabled: adding an upcoming bill must not create in-app history.
    await AppSettingsRepository.instance.setBillReminders(false);
    await container.read(billsProvider.notifier).addBill(
      Bill.create(
        id: 'bill-disabled',
        title: 'Internet',
        amount: 999,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
      ),
    );
    expect(await NotificationRepository.instance.getAll(), isEmpty);

    // Enabled: the same kind of bill should now create in-app history.
    await AppSettingsRepository.instance.setBillReminders(true);
    await container.read(billsProvider.notifier).addBill(
      Bill.create(
        id: 'bill-enabled',
        title: 'Electricity',
        amount: 1200,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
      ),
    );
    final all = await NotificationRepository.instance.getAll();
    expect(all.any((n) => n.title == 'Electricity'), isTrue);
  });
}
