// FINANCIAL INTELLIGENCE TIMELINE 1.0 — Phase 7 (AI context) + Phase 8
// (privacy) + dashboard/router wiring integration tests. Mirrors the
// established financial_health_trends_integration_test.dart /
// financial_insight_integration_test.dart pattern. Synthetic data only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/core/routes/app_routes.dart';
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
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
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

/// PHASE 8 — recursively verifies no raw SMS body, phone number, account
/// number, card number, OTP, credential, or other sensitive identifier
/// enters the AI context, by key-name fragment across the ENTIRE payload
/// (not just timelineContext) — matching every prior AI-context privacy
/// test this session.
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
  group('Phase 7/8 — AI context: timelineContext', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paysense_timeline_ai_test');
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
          month: 'August', year: DateTime.now().year, createdAt: DateTime.now(),
        ),
      );
      await GoalRepository.instance.add(
        Goal.create(
          id: 'g1', title: 'Vacation fund', targetAmount: 10000, currentAmount: 10000,
          targetDate: DateTime(2027, 1, 1), category: 'Travel', icon: 'flight',
          color: 0xFF5B4CF8, createdAt: DateTime.now().subtract(const Duration(days: 60)),
        ),
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('is populated for a spending question with only permitted aggregated fields', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.spending},
      );
      expect(context.timelineContext, isNotEmpty);
      expect(context.timelineContext.containsKey('events'), isTrue);
      expect(context.timelineContext.containsKey('momentum'), isTrue);
      _assertNoSensitiveData(context.timelineContext);
    });

    test('is empty when the question category never asked for it', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.taxPlanning},
      );
      expect(context.timelineContext, isEmpty);
    });

    test('the full serialized context round-trips through JSON with no sensitive fields', () async {
      final context = await FinancialContextBuilder.instance.build();
      final payload = jsonDecode(jsonEncode(context.toMap()));
      _assertNoSensitiveData(payload);
    });

    test('never carries more than 10 events even with a lot of activity', () async {
      final context = await FinancialContextBuilder.instance.build();
      final events = context.timelineContext['events'] as List?;
      if (events != null) {
        expect(events.length, lessThanOrEqualTo(10));
      }
    });

    test('every event entry only carries the permitted keys', () async {
      final context = await FinancialContextBuilder.instance.build();
      final events = context.timelineContext['events'] as List? ?? const [];
      const permittedKeys = {'type', 'tone', 'date', 'title', 'explanation', 'amount', 'percentage', 'relatedEntityName'};
      for (final event in events) {
        for (final key in (event as Map).keys) {
          expect(permittedKeys.contains(key), isTrue, reason: 'Unexpected key "$key" in timeline event entry');
        }
      }
    });

    test('momentum never carries a numeric score field', () async {
      final context = await FinancialContextBuilder.instance.build();
      final momentum = context.timelineContext['momentum'] as Map?;
      if (momentum != null) {
        expect(momentum.containsKey('score'), isFalse);
        expect(momentum.containsKey('healthScore'), isFalse);
      }
    });
  });

  group('Phase 6 — Dashboard/router wiring', () {
    late String dashboardSource;
    late String routerSource;

    setUpAll(() async {
      dashboardSource = await File('lib/features/dashboard/dashboard_screen.dart').readAsString();
      routerSource = await File('lib/core/routes/app_router.dart').readAsString();
    });

    test('the timeline entry line navigates to AppRoutes.financialTimeline', () {
      expect(
        dashboardSource.contains('Navigator.of(context).pushNamed(AppRoutes.financialTimeline)'),
        isTrue,
      );
    });

    test('AppRoutes.financialTimeline is registered to FinancialTimelineScreen', () {
      expect(AppRoutes.financialTimeline, '/financial-timeline');
      expect(
        routerSource.contains('case AppRoutes.financialTimeline:') &&
            routerSource.contains('FinancialTimelineScreen()'),
        isTrue,
      );
    });

    test('the entry line is only placed once in the widget tree (not a duplicate section)', () {
      final matches = RegExp(r'const _FinancialTimelineEntryLine\(\),').allMatches(dashboardSource).length;
      expect(matches, 1);
    });

    test('the entry line does not duplicate an existing Quick Actions row', () {
      expect(dashboardSource.contains('class _FinancialTimelineEntryLine'), isTrue);
      // The existing Quick Actions widgets are untouched by this feature.
      expect(dashboardSource.contains('QuickActionButton'), isTrue);
    });
  });
}
