// Focused tests for the "Can I Afford This?" AI integration (PHASE 7) —
// the deterministic pre-step inside AiChatNotifier, the injected
// affordabilityScenario context payload, and the "AI cannot mutate
// finances" guarantee. Synthetic data only; AiService is faked.
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
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
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

class _CapturingAiService implements AiService {
  static const String response = 'Here is your affordability assessment.';
  final List<String> receivedContexts = [];

  @override
  Future<String> ask({required String message, required String financialContext}) async {
    receivedContexts.add(financialContext);
    return response;
  }
}

/// An adversarial fake that CLAIMS to have executed a purchase, to prove
/// structurally (not just by trusting the prompt) that no such action is
/// ever actually performed.
class _AdversarialAiService implements AiService {
  @override
  Future<String> ask({required String message, required String financialContext}) async {
    return 'Done! I have gone ahead and bought the phone for you and updated your wallet balance.';
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_afford_ai_test');
    await _initHive(tempDir);

    await WalletRepository.instance.add(
      Wallet(
        id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
        openingBalance: 0, currentBalance: 200000, createdAt: DateTime(2026, 1, 1),
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 't1', title: 'Salary', amount: 50000, categoryId: 'Salary', accountId: 'w1',
        transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('34. Deterministic affordability result reaches AI context', () {
    test('the injected financial_context carries the exact AffordabilityCalculator figures', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(overrides: [aiServiceProvider.overrideWithValue(fakeService)]);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('Can I afford a ₹5,000 phone case?');

      expect(fakeService.receivedContexts, hasLength(1));
      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('affordabilityScenario'), isTrue);

      final scenario = contextMap['affordabilityScenario'] as Map<String, dynamic>;
      expect(scenario['purchaseAmount'], 5000);
      expect(scenario['itemDescription'], 'phone case');
      expect(scenario['isSimulationOnly'], isTrue);

      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.affordabilityOutcome, isNotNull);
      expect(messages.last.affordabilityOutcome!.result!.purchaseAmount, 5000);
    });
  });

  group('35. Medium-confidence clarification', () {
    test('an ambiguous small amount never calls the AI backend at all', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(overrides: [aiServiceProvider.overrideWithValue(fakeService)]);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('Can I afford this for 5?');

      expect(fakeService.receivedContexts, isEmpty);
      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.text, contains('How much'));
      expect(messages.last.affordabilityOutcome, isNull);
    });
  });

  group('36. Normal questions unchanged', () {
    test('a normal question never carries an affordabilityScenario in the context', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(overrides: [aiServiceProvider.overrideWithValue(fakeService)]);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('Why did my expenses increase?');

      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('affordabilityScenario'), isFalse);
    });

    test('the existing "Can I afford to spend today?" quick question is never hijacked', () async {
      final fakeService = _CapturingAiService();
      final container = ProviderContainer(overrides: [aiServiceProvider.overrideWithValue(fakeService)]);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('Can I afford to spend today?');

      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('affordabilityScenario'), isFalse);
      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.affordabilityOutcome, isNull);
    });
  });

  group('37. Adversarial AI response cannot mutate finances', () {
    test('a reply claiming a purchase was made never actually changes the wallet or creates a transaction', () async {
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(_AdversarialAiService())],
      );
      addTearDown(container.dispose);

      final walletBefore = (await WalletRepository.instance.getById('w1'))!.currentBalance;
      final transactionCountBefore = (await TransactionRepository.instance.getAll()).length;

      await container.read(aiChatProvider.notifier).sendMessage('Can I afford a ₹5,000 phone case?');

      final walletAfter = (await WalletRepository.instance.getById('w1'))!.currentBalance;
      final transactionCountAfter = (await TransactionRepository.instance.getAll()).length;

      expect(walletAfter, walletBefore);
      expect(transactionCountAfter, transactionCountBefore);
    });
  });
}
