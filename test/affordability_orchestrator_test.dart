// Focused tests for AffordabilityOrchestrator (PHASE 6/7) — Stage B
// resolution against real (synthetic, Hive-backed) financial data, wired
// to SafeToSpendCalculator/FinancialPlanningCalculator/
// AffordabilityCalculator. Synthetic data only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/models/affordability_outcome.dart';
import 'package:paysense/features/ai/services/affordability_intent_parser.dart';
import 'package:paysense/features/ai/services/affordability_orchestrator.dart';
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
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';

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

final _now = DateTime(2026, 8, 20);

Future<void> seedFinances() async {
  await WalletRepository.instance.add(
    Wallet(
      id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
      openingBalance: 0, currentBalance: 200000, createdAt: DateTime(2026, 1, 1),
    ),
  );
  for (final month in [6, 7, 8]) {
    await TransactionRepository.instance.add(
      Transaction(
        id: 't$month', title: 'Salary', amount: 50000, categoryId: 'Salary', accountId: 'w1',
        transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, month, 5),
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 'e$month', title: 'Rent', amount: 30000, categoryId: 'Rent', accountId: 'w1',
        transactionType: 'Expense', paymentMethod: 'Bank', note: '', createdAt: DateTime(2026, month, 3),
      ),
    );
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_afford_orch_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Comfortable / possible / not-recommended (orchestrator-level)', () {
    test('a small purchase against a healthy balance is comfortable', () async {
      await seedFinances();
      final intent = AffordabilityIntentParser.parse('Can I afford a ₹5,000 phone case?');
      final outcome = await AffordabilityOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, AffordabilityOutcomeKind.calculated);
      expect(outcome.result!.status, AffordabilityStatus.comfortable);
      expect(outcome.itemDescription, 'phone case');
    });

    test('a purchase larger than the wallet balance is not recommended', () async {
      await seedFinances();
      final intent = AffordabilityIntentParser.parse('Can I afford a ₹5,00,000 car?');
      final outcome = await AffordabilityOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, AffordabilityOutcomeKind.calculated);
      expect(outcome.result!.status, AffordabilityStatus.notRecommended);
    });
  });

  group('17/21. Insufficient data (orchestrator-level)', () {
    test('no wallets at all is reported honestly, never a fabricated verdict', () async {
      final intent = AffordabilityIntentParser.parse('Can I afford a ₹5,000 phone case?');
      final outcome = await AffordabilityOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, AffordabilityOutcomeKind.notFound);
      expect(outcome.message, contains("don't have enough information"));
    });
  });

  group('35. Medium-confidence clarification (orchestrator-level)', () {
    test('an ambiguous small number asks a direct clarification, no calculation attempted', () async {
      await seedFinances();
      final intent = AffordabilityIntentParser.parse('Can I afford this for 5?');
      final outcome = await AffordabilityOrchestrator.instance.resolve(intent, now: _now);

      expect(outcome.kind, AffordabilityOutcomeKind.clarification);
      expect(outcome.message, contains('How much'));
    });
  });

  group('36. Normal questions unchanged (orchestrator-level)', () {
    test('a non-affordability question resolves to none without touching any repository logic', () async {
      final intent = AffordabilityIntentParser.parse('Why did my expenses increase?');
      final outcome = await AffordabilityOrchestrator.instance.resolve(intent, now: _now);
      expect(outcome.kind, AffordabilityOutcomeKind.none);
    });
  });

  group('25. No mutation of persisted data (orchestrator-level)', () {
    test('resolving several affordability scenarios never writes to wallets/transactions/goals', () async {
      await seedFinances();
      await GoalRepository.instance.add(
        Goal(
          id: 'g1', title: 'Vacation', targetAmount: 100000, currentAmount: 40000,
          targetDate: DateTime(2027, 8, 1), category: 'Savings', icon: 'star', color: 0,
          createdAt: DateTime(2026, 2, 1), updatedAt: DateTime(2026, 2, 1), isCompleted: false,
        ),
      );

      final walletBefore = (await WalletRepository.instance.getById('w1'))!.currentBalance;
      final transactionCountBefore = (await TransactionRepository.instance.getAll()).length;
      final goalBefore = (await GoalRepository.instance.getById('g1'))!;

      for (final question in [
        'Can I afford a ₹5,000 phone case?',
        'Can I afford a ₹5,00,000 car?',
        'Should I spend ₹30,000 on a phone?',
      ]) {
        await AffordabilityOrchestrator.instance.resolve(
          AffordabilityIntentParser.parse(question),
          now: _now,
        );
      }

      expect((await WalletRepository.instance.getById('w1'))!.currentBalance, walletBefore);
      expect((await TransactionRepository.instance.getAll()).length, transactionCountBefore);
      final goalAfter = (await GoalRepository.instance.getById('g1'))!;
      expect(goalAfter.currentAmount, goalBefore.currentAmount);
    });
  });
}
