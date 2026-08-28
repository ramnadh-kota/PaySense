import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/entitlement.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/account_aggregator_connection_repository.dart';
import 'package:paysense/shared/repositories/account_repository.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/auth_session_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/entitlement_repository.dart';
import 'package:paysense/shared/repositories/financial_safety_dismissed_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/notification_repository.dart';
import 'package:paysense/shared/repositories/recent_search_repository.dart';
import 'package:paysense/shared/repositories/sms_fingerprint_repository.dart';
import 'package:paysense/shared/repositories/sms_review_repository.dart';
import 'package:paysense/shared/repositories/tax_settings_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/user_profile_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/services/account_deletion_service.dart';
import 'package:paysense/shared/utils/password_hasher.dart';

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

void main() {
  late Directory tempDir;
  const email = 'user@example.com';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_account_deletion_test');
    await _initHive(tempDir);

    await AccountRepository.instance.add(
      Account(
        id: 'acc-1',
        email: email,
        fullName: 'Test User',
        passwordHash: PasswordHasher.hash('password123', 'salt'),
        passwordSalt: 'salt',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await AuthSessionRepository.instance.setSession(email);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('deletes all financial data', () async {
    await WalletRepository.instance.add(
      Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 100, currentBalance: 100, createdAt: DateTime(2026, 1, 1)),
    );
    await TransactionRepository.instance.add(
      Transaction(id: 't1', title: 'Coffee', amount: 100, categoryId: 'Food', accountId: 'w1', transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 1, 1)),
    );
    await BudgetRepository.instance.add(Budget.create(id: 'b1', categoryId: 'Food', categoryName: 'Food', allocatedAmount: 1000, month: 'January', year: 2026, createdAt: DateTime(2026, 1, 1)));
    await GoalRepository.instance.add(Goal.create(id: 'g1', title: 'Trip', targetAmount: 10000, targetDate: DateTime(2027, 1, 1), category: 'Travel', icon: '', color: 0, createdAt: DateTime(2026, 1, 1)));
    await LoanRepository.instance.add(
      Loan(id: 'l1', loanName: 'Loan', lenderName: 'Bank', loanType: 'Personal', principalAmount: 1000, interestRate: 1, tenureMonths: 12, emiAmount: 100, outstandingAmount: 500, paidAmount: 500, accountId: 'w1', nextDueDate: DateTime(2026, 2, 1), startDate: DateTime(2026, 1, 1), endDate: DateTime(2027, 1, 1), totalInterest: 100, status: 'Active', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    );

    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await WalletRepository.instance.getAll(), isEmpty);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
    expect(await BudgetRepository.instance.getAll(), isEmpty);
    expect(await GoalRepository.instance.getAll(), isEmpty);
    expect(await LoanRepository.instance.getAll(), isEmpty);
  });

  test('deletes AA connection metadata', () async {
    await AccountAggregatorConnectionRepository.instance.upsert(
      AccountAggregatorConnection(
        connectionId: 'conn-1',
        providerId: 'mock',
        providerName: 'Mock',
        status: ConnectionStatus.connected,
        consentStatus: ConsentStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await AccountAggregatorConnectionRepository.instance.getAll(), isEmpty);
  });

  test('deletes local login credentials and auth session', () async {
    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await AccountRepository.instance.exists(email), isFalse);
    expect(AuthSessionRepository.instance.currentEmail(), isNull);
  });

  test('clears the cached user profile', () async {
    await UserProfileRepository.instance.saveProfile(
      UserProfile(id: 'u1', fullName: 'Test', email: email, phone: '', dateOfBirth: DateTime(1990, 1, 1), gender: '', occupation: '', monthlyIncome: 0, currency: 'INR', country: 'IN', monthlyEmi: 0, savingsGoal: 0, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    );

    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await UserProfileRepository.instance.getProfile(), isNull);
  });

  test('resets cached entitlement to free', () async {
    await EntitlementRepository.instance.setPlanTier(PlanTier.plus);
    await EntitlementRepository.instance.setFoundingUser(true);

    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await EntitlementRepository.instance.getPlanTier(), PlanTier.free);
    expect(await EntitlementRepository.instance.isFoundingUser(), isFalse);
  });

  test('clears dismissed financial-safety-alert state', () async {
    await FinancialSafetyDismissedRepository.instance.dismiss('spendingSpike');

    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await FinancialSafetyDismissedRepository.instance.getDismissedIds(), isEmpty);
  });

  test('a fully empty account still deletes cleanly without crashing', () async {
    await AccountDeletionService.deleteEverythingLocally(email);
    expect(await AccountRepository.instance.exists(email), isFalse);
  });

  test('clears notification history, search history, SMS review data, tax settings, and the app lock PIN', () async {
    await NotificationRepository.instance.add(
      AppNotification(id: 'n1', title: 'Alert', message: 'Body', type: 'insight', createdAt: DateTime(2026, 1, 1)),
    );
    await RecentSearchRepository.instance.record('swiggy');
    await SmsReviewRepository.instance.addIfNotExists(
      SmsReviewItem.create(
        id: 'sms-1',
        amount: 500,
        direction: SmsReviewDirection.debit,
        sender: 'HDFCBK',
        timestamp: DateTime(2026, 1, 1),
        confidence: 0.6,
        merchant: 'Amazon',
      ),
    );
    await SmsFingerprintRepository.instance.markProcessed('fingerprint-1');
    await TaxSettingsRepository.instance.save(
      TaxSettings(
        annualGrossIncome: 1200000,
        otherIncome: 0,
        regime: 'newRegime',
        ageBand: 'below60',
        section80C: 0,
        section80D: 0,
        homeLoanInterest: 0,
        hraExemption: 0,
        otherEligibleDeductions: 0,
        tdsAlreadyDeducted: 0,
        isIncomeEstimated: false,
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await AppSettingsRepository.instance.setPin('1234');

    await AccountDeletionService.deleteEverythingLocally(email);

    expect(await NotificationRepository.instance.getAll(), isEmpty);
    expect(await RecentSearchRepository.instance.getRecent(), isEmpty);
    expect(await SmsReviewRepository.instance.getAll(), isEmpty);
    expect(SmsFingerprintRepository.instance.isProcessed('fingerprint-1'), isFalse);
    expect(await TaxSettingsRepository.instance.get(), isNull);
    expect(AppSettingsRepository.instance.hasPin(), isFalse);
  });
}
