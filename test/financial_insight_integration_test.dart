// PROACTIVE FINANCIAL INSIGHTS 1.0 — Phase 6 (AI context privacy) and
// Phase 7 (notification dedup + settings toggle) integration tests.
// Mirrors financial_health_trends_integration_test.dart's established
// pattern. Synthetic data only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/ai_question_router.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
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
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/settings_provider.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
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

void _assertNoSensitiveData(dynamic payload, {String path = r'$'}) {
  const forbiddenKeyFragments = [
    'password', 'pin', 'biometric', 'token', 'secret', 'apikey', 'credential',
    'sms', 'phone', 'accountnumber', 'cardnumber', 'otp',
  ];
  if (payload is Map) {
    for (final entry in payload.entries) {
      final key = entry.key.toString().toLowerCase().replaceAll('_', '').replaceAll('-', '');
      for (final fragment in forbiddenKeyFragments) {
        expect(key.contains(fragment), isFalse, reason: 'Forbidden key fragment "$fragment" at $path.${entry.key}');
      }
      _assertNoSensitiveData(entry.value, path: '$path.${entry.key}');
    }
  } else if (payload is List) {
    for (var i = 0; i < payload.length; i++) {
      _assertNoSensitiveData(payload[i], path: '$path[$i]');
    }
  }
}

void main() {
  group('Phase 6 — AI context privacy: financialInsightsContext', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paysense_insight_ai_test');
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
      await BudgetRepository.instance.add(
        Budget(
          id: 'b1', categoryId: 'Food', categoryName: 'Food', allocatedAmount: 5000,
          spentAmount: 6000, remainingAmount: -1000, percentageUsed: 120,
          month: 'August', year: 2026, createdAt: DateTime(2026, 8, 1),
        ),
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('is populated for a budget question with only permitted aggregated fields', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.budget},
      );
      expect(context.financialInsightsContext, isNotEmpty);
      expect(context.financialInsightsContext.containsKey('insights'), isTrue);
      _assertNoSensitiveData(context.financialInsightsContext);
    });

    test('is empty when the question category never asked for it', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.taxPlanning},
      );
      expect(context.financialInsightsContext, isEmpty);
    });

    test('the full serialized context round-trips through JSON with no sensitive fields', () async {
      final context = await FinancialContextBuilder.instance.build();
      final payload = jsonDecode(jsonEncode(context.toMap()));
      _assertNoSensitiveData(payload);
    });

    test('every insight entry only carries the permitted keys', () async {
      final context = await FinancialContextBuilder.instance.build();
      final insights = context.financialInsightsContext['insights'] as List;
      const permittedKeys = {
        'type', 'priority', 'title', 'explanation', 'recommendedAction',
        'amount', 'percentage', 'relatedEntityName',
      };
      for (final insight in insights) {
        for (final key in (insight as Map).keys) {
          expect(permittedKeys.contains(key), isTrue, reason: 'Unexpected key "$key" in insight entry');
        }
      }
    });
  });

  group('Phase 7 — Notification dedup and settings gating', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paysense_insight_notif_test');
      await _initHive(tempDir);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('addIfNotExists with the same insight id never creates a duplicate notification', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(notificationsProvider.future);

      final notifier = container.read(notificationsProvider.notifier);
      final insightNotification = AppNotification(
        id: 'budgetOverLimit:b1:2026-08',
        title: 'Over budget',
        message: 'You spent more than allocated in Food.',
        type: NotificationType.insight.name,
        createdAt: DateTime.now(),
        relatedRoute: '/budget',
      );

      await notifier.addIfNotExists(insightNotification);
      // Simulates a Dashboard rebuild firing the same ref.listen callback
      // again with the identical, coarse "type:entity:period" id.
      await notifier.addIfNotExists(insightNotification);

      final all = await container.read(notificationsProvider.future);
      expect(all.where((n) => n.id == insightNotification.id).length, 1);
    });

    test('insightNotifications setting defaults to true and persists when toggled off', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(settingsProvider.future);
      expect(initial.insightNotifications, isTrue);

      await container.read(settingsProvider.notifier).setInsightNotifications(false);
      final updated = container.read(settingsProvider).value!;
      expect(updated.insightNotifications, isFalse);

      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      final reloaded = await fresh.read(settingsProvider.future);
      expect(reloaded.insightNotifications, isFalse);
    });
  });
}
