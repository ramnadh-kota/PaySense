// PHASE 21 items 30/32 — AI context privacy for financialHealthTrendsContext
// and dashboard navigation into the Financial Health Trends screen.
// Synthetic data only.
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
  group('30. AI context privacy — financialHealthTrendsContext', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paysense_trends_ai_test');
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
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('is populated for a financial-health question with only permitted aggregated fields', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.financialHealth},
      );
      expect(context.financialHealthTrendsContext, isNotEmpty);
      expect(context.financialHealthTrendsContext.containsKey('trajectory'), isTrue);
      expect(context.financialHealthTrendsContext.containsKey('scoreTrend'), isTrue);
      _assertNoSensitiveData(context.financialHealthTrendsContext);
    });

    test('is empty when the question category never asked for it', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.bills},
      );
      expect(context.financialHealthTrendsContext, isEmpty);
    });

    test('the full serialized context round-trips through JSON with no sensitive fields', () async {
      final context = await FinancialContextBuilder.instance.build();
      final payload = jsonDecode(jsonEncode(context.toMap()));
      _assertNoSensitiveData(payload);
    });
  });

  group('32. Dashboard navigation', () {
    // DashboardScreen depends on a dozen+ providers (budgets, transactions,
    // wallets, financial health, cash flow, safe-to-spend, subscriptions,
    // notifications...) — dashboard_quick_actions_test.dart already
    // establishes that fully mounting it in a test is impractical and
    // asserts fixes at the source level instead. Following that same
    // convention here: confirm the entry point actually navigates to the
    // registered route, and that the route is wired up end-to-end,
    // without mounting the full dashboard widget tree.
    late String dashboardSource;
    late String routerSource;

    setUpAll(() async {
      dashboardSource = await File('lib/features/dashboard/dashboard_screen.dart').readAsString();
      routerSource = await File('lib/core/routes/app_router.dart').readAsString();
    });

    test('the trend entry line navigates to AppRoutes.financialHealthTrends', () {
      expect(
        dashboardSource.contains('Navigator.of(context).pushNamed(AppRoutes.financialHealthTrends)'),
        isTrue,
      );
    });

    test('AppRoutes.financialHealthTrends is registered to FinancialHealthTrendsScreen', () {
      expect(AppRoutes.financialHealthTrends, '/financial-health-trends');
      expect(
        routerSource.contains('case AppRoutes.financialHealthTrends:') &&
            routerSource.contains('FinancialHealthTrendsScreen()'),
        isTrue,
      );
    });

    test('the entry line is only placed once in the widget tree (not a duplicate section)', () {
      // Matches the call-site usage ("const _FinancialTrendEntryLine(),")
      // specifically, not the class's own constructor declaration ("const
      // _FinancialTrendEntryLine();").
      final matches = RegExp(r'const _FinancialTrendEntryLine\(\),').allMatches(dashboardSource).length;
      expect(matches, 1);
    });
  });
}
