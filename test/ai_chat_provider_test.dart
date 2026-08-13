import 'dart:async';
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
import 'package:paysense/features/ai/providers/ai_provider.dart';
import 'package:paysense/features/ai/services/ai_service.dart';

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

/// An [AiService] double whose response can be released on demand, so tests
/// can reliably observe notifier behaviour while a "request" is in flight.
class _ControlledAiService implements AiService {
  int callCount = 0;
  final List<Completer<String>> _pending = [];

  @override
  Future<String> ask({
    required String message,
    required String financialContext,
  }) {
    callCount++;
    final completer = Completer<String>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(String response) {
    _pending.removeAt(0).complete(response);
  }

  void failNext(Object error) {
    _pending.removeAt(0).completeError(error);
  }
}

class _ThrowingAiService implements AiService {
  _ThrowingAiService(this.error);
  final Object error;

  @override
  Future<String> ask({
    required String message,
    required String financialContext,
  }) async {
    throw error;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_ai_provider_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('prevents a duplicate in-flight request from firing a second AI call', () async {
    final fake = _ControlledAiService();
    final container = ProviderContainer(
      overrides: [aiServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(aiChatProvider.future);

    final notifier = container.read(aiChatProvider.notifier);
    final first = notifier.sendMessage('How am I doing?');
    // Let the first call's async gap (context build + ask()) start.
    await Future<void>.delayed(Duration.zero);

    await notifier.sendMessage('Second message while first is in flight');
    expect(fake.callCount, 1);

    fake.completeNext('You are doing well.');
    await first;

    final messages = container.read(aiChatProvider).value!;
    expect(messages.where((m) => m.isUser).length, 1);
    expect(messages.last.text, 'You are doing well.');
  });

  test('allows a new request once the previous one has completed', () async {
    final fake = _ControlledAiService();
    final container = ProviderContainer(
      overrides: [aiServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(aiChatProvider.future);

    final notifier = container.read(aiChatProvider.notifier);
    final first = notifier.sendMessage('First question');
    await Future<void>.delayed(Duration.zero);
    fake.completeNext('First answer');
    await first;

    final second = notifier.sendMessage('Second question');
    await Future<void>.delayed(Duration.zero);
    fake.completeNext('Second answer');
    await second;

    expect(fake.callCount, 2);
    final messages = container.read(aiChatProvider).value!;
    expect(messages.where((m) => m.isUser).length, 2);
  });

  test('falls back to a local Financial Health insight when the AI service throws', () async {
    final container = ProviderContainer(
      overrides: [
        aiServiceProvider.overrideWithValue(
          _ThrowingAiService(
            const AiServiceException('No internet connection. Your local financial insights are still available.'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(aiChatProvider.future);

    await container.read(aiChatProvider.notifier).sendMessage('How am I doing?');

    final messages = container.read(aiChatProvider).value!;
    expect(messages, hasLength(2));
    final reply = messages.last;
    expect(reply.isUser, isFalse);
    expect(reply.text, contains('No internet connection'));
    expect(reply.text, contains('Financial Health'));
  });

  test('falls back gracefully for an unexpected (non-AiServiceException) error', () async {
    final container = ProviderContainer(
      overrides: [
        aiServiceProvider.overrideWithValue(_ThrowingAiService(Exception('boom'))),
      ],
    );
    addTearDown(container.dispose);
    await container.read(aiChatProvider.future);

    await container.read(aiChatProvider.notifier).sendMessage('How am I doing?');

    final messages = container.read(aiChatProvider).value!;
    expect(messages.last.text, contains('temporarily unavailable'));
  });

  test('ignores a blank message without calling the AI service', () async {
    final fake = _ControlledAiService();
    final container = ProviderContainer(
      overrides: [aiServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(aiChatProvider.future);

    await container.read(aiChatProvider.notifier).sendMessage('   ');

    expect(fake.callCount, 0);
    expect(container.read(aiChatProvider).value, isEmpty);
  });
}
