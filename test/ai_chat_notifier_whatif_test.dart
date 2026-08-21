// Focused tests for the AI WHAT-IF INTELLIGENCE 2.0 wiring inside
// AiChatNotifier (PHASE 11/14/15/36) — the deterministic pre-step, the
// injected `whatIfScenario` context payload, and the "normal questions stay
// on the normal path" guarantee. Synthetic data only; AiService is faked so
// nothing here makes a real network call.
import 'dart:convert';
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
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

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

/// Captures every `financialContext` string it's asked with, so a test can
/// inspect exactly what was sent to "OpenAI" without a real network call.
class _CapturingAiService implements AiService {
  static const String response = 'Here you go.';

  final List<String> receivedContexts = [];
  final List<String> receivedMessages = [];

  @override
  Future<String> ask({required String message, required String financialContext}) async {
    receivedMessages.add(message);
    receivedContexts.add(financialContext);
    return response;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_ai_whatif_test');
    await _initHive(tempDir);

    await WalletRepository.instance.add(
      Wallet(
        id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
        openingBalance: 0, currentBalance: 100000, createdAt: DateTime(2026, 1, 1),
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 't1', title: 'Salary', amount: 50000, categoryId: 'Salary', accountId: 'w1',
        transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: DateTime.now(),
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 't2', title: 'Rent', amount: 15000, categoryId: 'Rent', accountId: 'w1',
        transactionType: 'Expense', paymentMethod: 'Bank', note: '', createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('34. Simulation label', () {
    test('a calculated what-if reply carries a WhatIfResult for the UI card to render', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('What if I save ₹5,000 more every month?');

      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.isUser, isFalse);
      expect(messages.last.whatIfResult, isNotNull);
      expect(messages.last.whatIfResult!.type.name, 'increaseSavings');
    });
  });

  group('35. AI explanation receives deterministic result', () {
    test('the injected financial_context carries the exact deterministic scenario numbers', () async {
      await LoanRepository.instance.add(
        Loan(
          id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Auto',
          principalAmount: 150000, interestRate: 10, tenureMonths: 15, emiAmount: 10000,
          outstandingAmount: 100000, paidAmount: 50000, accountId: 'w1',
          nextDueDate: DateTime(2026, 9, 1), startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2027, 4, 1), totalInterest: 15000, status: 'Active',
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final fakeService = _CapturingAiService();
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      await container
          .read(aiChatProvider.notifier)
          .sendMessage('What if I pay ₹20,000 extra toward my loan?');

      expect(fakeService.receivedContexts, hasLength(1));
      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('whatIfScenario'), isTrue);

      final scenario = contextMap['whatIfScenario'] as Map<String, dynamic>;
      expect(scenario['type'], 'extraLoanPayment');
      expect(scenario['currentValue'], 100000);
      expect(scenario['projectedValue'], 80000);
      expect(scenario['isSimulationOnly'], isTrue);

      // The AI reply carries the SAME deterministic figures the calculator
      // produced — the AI is only ever handed this to explain, never asked
      // to compute it itself.
      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.whatIfResult!.projectedValue, 80000);
    });

    test('a MEDIUM-confidence what-if never calls the AI backend at all', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('What if I save more every month?');

      expect(fakeService.receivedContexts, isEmpty);
      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.text, contains('How much'));
      expect(messages.last.whatIfResult, isNull);
    });
  });

  group('36. Normal non-what-if questions remain on the normal AI path', () {
    test('a definitional question never carries a whatIfScenario in the context or a result card', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('Why did my expenses increase?');

      expect(fakeService.receivedContexts, hasLength(1));
      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('whatIfScenario'), isFalse);

      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.whatIfResult, isNull);
    });

    test('a definitional "what is" question is never routed into a calculation', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('What is an emergency fund?');

      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('whatIfScenario'), isFalse);
    });
  });
}
