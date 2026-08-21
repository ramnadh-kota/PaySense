// Focused tests for AiChatNotifier — error/loading handling and the
// execution boundary (PHASE 13/16). Synthetic data only; no real network
// calls (AiService is faked).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/providers/ai_provider.dart';
import 'package:paysense/features/ai/services/ai_service.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
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
}

class _FakeAiService implements AiService {
  _FakeAiService({this.response, this.error});

  final String? response;
  final Object? error;

  @override
  Future<String> ask({required String message, required String financialContext}) async {
    if (error != null) throw error!;
    return response ?? '';
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_ai_chat_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('25. AI cannot execute transactions', () {
    test('processing a chat exchange never creates a Transaction, regardless of reply content', () async {
      await WalletRepository.instance.add(
        Wallet(
          id: 'w1', name: 'w1', bankName: '', type: 'Bank',
          openingBalance: 10000, currentBalance: 10000, createdAt: DateTime(2026, 1, 1),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(
            _FakeAiService(response: 'I have transferred ₹5,000 to your SBI account for you.'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(aiChatProvider.notifier)
          .sendMessage('Transfer ₹5,000 to SBI');

      // Even though the (fake, adversarial) AI reply CLAIMS an action was
      // taken, no transaction-creating code path exists in AiChatNotifier —
      // this proves it structurally, not just by trusting the prompt.
      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, isEmpty);

      final wallet = await WalletRepository.instance.getById('w1');
      expect(wallet!.currentBalance, 10000); // untouched
    });
  });

  group('26. API failure handling', () {
    test('an AiServiceException produces a safe, non-empty fallback reply', () async {
      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(
            _FakeAiService(error: const AiServiceException('No internet connection.')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('How am I doing?');

      final messages = container.read(aiChatProvider).value!;
      expect(messages, hasLength(2)); // user message + fallback reply
      expect(messages.last.isUser, isFalse);
      expect(messages.last.text, isNotEmpty);
      expect(messages.last.text, contains('No internet connection'));
    });

    test('an unexpected exception (not AiServiceException) also degrades gracefully', () async {
      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(_FakeAiService(error: Exception('boom'))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('How am I doing?');

      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.isUser, isFalse);
      expect(messages.last.text, isNotEmpty);
      // Never leaks the raw exception text ("boom") to the user.
      expect(messages.last.text, isNot(contains('boom')));
    });
  });

  group('27. Empty AI response', () {
    test('a blank reply from AiService never renders as an empty chat bubble', () async {
      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(_FakeAiService(response: '   ')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('How am I doing?');

      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.text.trim(), isNotEmpty);
    });
  });

  group('28. Loading state completion', () {
    test('sendMessage always resolves to AsyncData, never leaves the state stuck loading', () async {
      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(_FakeAiService(response: 'All good!')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('How am I doing?');

      final state = container.read(aiChatProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(2));
    });

    test('a duplicate send while one is already in flight is ignored, not queued twice', () async {
      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(_FakeAiService(response: 'Reply')),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      final first = notifier.sendMessage('First question');
      final second = notifier.sendMessage('Second question'); // should be a no-op
      await Future.wait([first, second]);

      final messages = container.read(aiChatProvider).value!;
      // Exactly one user message + one reply, not two of each.
      expect(messages.where((m) => m.isUser).length, 1);
    });
  });

  group('29. Quick-question flow', () {
    test('a quick-question prompt flows through the exact same pipeline as typed text', () async {
      final container = ProviderContainer(
        overrides: [
          aiServiceProvider.overrideWithValue(_FakeAiService(response: 'Here is your answer.')),
        ],
      );
      addTearDown(container.dispose);

      const quickQuestion = 'Can I afford to spend today?';
      await container.read(aiChatProvider.notifier).sendMessage(quickQuestion);

      final messages = container.read(aiChatProvider).value!;
      expect(messages.first.text, quickQuestion);
      expect(messages.first.isUser, isTrue);
      expect(messages.last.isUser, isFalse);
    });
  });
}
