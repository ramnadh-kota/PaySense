// PHASE 12 — privacy regression tests for the two new FinancialContext
// sections (financialActionsContext / affordabilityContext), plus basic
// inclusion checks. Follows the exact same synthetic-data pattern as
// financial_context_builder_test.dart.
import 'dart:convert';
import 'dart:io';

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

/// Recursively asserts no key/value anywhere in [payload] looks like a
/// secret, SMS body, phone number, or account/card number — the same
/// forbidden-fragment check the AI backend itself enforces, run here as an
/// app-side regression guard.
void _assertNoSensitiveData(dynamic payload, {String path = r'$'}) {
  const forbiddenKeyFragments = [
    'password', 'pin', 'biometric', 'token', 'secret', 'apikey', 'credential',
    'sms', 'phone', 'accountnumber', 'cardnumber', 'otp',
  ];
  if (payload is Map) {
    for (final entry in payload.entries) {
      final key = entry.key.toString().toLowerCase().replaceAll('_', '').replaceAll('-', '');
      for (final fragment in forbiddenKeyFragments) {
        expect(
          key.contains(fragment),
          isFalse,
          reason: 'Forbidden key fragment "$fragment" found at $path.${entry.key}',
        );
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
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_action_context_test');
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

  group('financialActionsContext', () {
    test('is populated for a budget/planning question and carries a real over-budget action', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.budget},
      );
      expect(context.financialActionsContext, isNotEmpty);
      final actions = context.financialActionsContext['actions'] as List;
      expect(actions, isNotEmpty);
      expect(actions.first['category'], 'overspending');
    });

    test('is empty when the question category never asked for it', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.bills},
      );
      expect(context.financialActionsContext, isEmpty);
    });
  });

  group('affordabilityContext', () {
    test('is populated alongside safeToSpendContext with reused (not recomputed) figures', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.safeToSpend},
      );
      expect(context.affordabilityContext, isNotEmpty);
      expect(context.affordabilityContext['availableMoney'], context.safeToSpendContext['availableMoney']);
    });
  });

  group('Privacy regression', () {
    test('the full serialized context (including the two new sections) never contains sensitive fields', () async {
      final context = await FinancialContextBuilder.instance.build();
      final payload = jsonDecode(jsonEncode(context.toMap()));
      _assertNoSensitiveData(payload);
    });

    test('financialActionsContext alone never contains sensitive fields', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.budget},
      );
      _assertNoSensitiveData(context.financialActionsContext);
    });

    test('affordabilityContext alone never contains sensitive fields', () async {
      final context = await FinancialContextBuilder.instance.build(
        relevantCategories: {FinancialQuestionCategory.safeToSpend},
      );
      _assertNoSensitiveData(context.affordabilityContext);
    });
  });
}
