// Focused tests for the new Financial Report PDF export: it must never
// crash, must handle a brand-new account with zero data (every section
// shows "Not enough data yet" rather than fabricating a figure), and must
// handle long merchant/category/wallet names and a full set of sections
// without throwing.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/financial_report_bundle_provider.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_scope.dart';
import 'package:paysense/shared/utils/financial_report_pdf_generator.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WalletAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(BillAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoanAdapter());
  if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(AccountAdapter());
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SmsReviewItemAdapter());
  }
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(TaxSettingsAdapter());
  if (!Hive.isAdapterRegistered(12)) {
    Hive.registerAdapter(FunGroupExpenseAdapter());
  }
  if (!Hive.isAdapterRegistered(13)) {
    Hive.registerAdapter(FunGroupParticipantAdapter());
  }

  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox('app_settings');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'paysense_report_pdf_test',
    );
    await _initHive(tempDir);
    await AccountScope.instance.activate('pdf-test-account');
  });

  tearDown(() async {
    AccountScope.instance.deactivate();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'generates a valid PDF for a brand-new account with zero data — every '
    'section must handle emptiness without crashing or fabricating a value',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bundle = container.read(financialReportBundleProvider);
      expect(bundle.reports.hasAnyTransactions, isFalse);
      expect(bundle.financialHealth.hasSufficientData, isFalse);
      expect(bundle.safeToSpend.hasSufficientData, isFalse);
      expect(bundle.funFunds.hasSufficientData, isFalse);

      final bytes = await FinancialReportPdfGenerator.build(bundle);
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );

  test(
    'generates a valid PDF with real data across every section, including '
    'long merchant/category/wallet names and a shortfall scenario',
    () async {
      await WalletRepository.instance.add(
        Wallet(
          id: 'w1',
          name: 'A Wallet With An Extremely Long Display Name For Testing',
          bankName: 'Bank',
          type: 'bank',
          openingBalance: 100,
          currentBalance: 100,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final now = DateTime.now();
      await TransactionRepository.instance.add(
        Transaction(
          id: 't1',
          title:
              'A Very Long Merchant Name That Should Wrap Instead Of Overflowing The PDF Page',
          amount: 500,
          categoryId: 'A Long Category Name For Wrapping',
          accountId: 'w1',
          transactionType: 'expense',
          paymentMethod: 'card',
          note: '',
          createdAt: now,
        ),
      );
      await TransactionRepository.instance.add(
        Transaction(
          id: 't2',
          title: 'Salary',
          amount: 200,
          categoryId: 'Income',
          accountId: 'w1',
          transactionType: 'income',
          paymentMethod: 'card',
          note: '',
          createdAt: now,
        ),
      );
      await BudgetRepository.instance.add(
        Budget(
          id: 'b1',
          categoryId: 'food',
          categoryName: 'Food',
          allocatedAmount: 1000,
          spentAmount: 1200,
          remainingAmount: -200,
          percentageUsed: 120,
          month: _monthName(now.month),
          year: now.year,
          createdAt: now,
        ),
      );
      await GoalRepository.instance.add(
        Goal(
          id: 'g1',
          title: 'A Goal With A Fairly Long Descriptive Title',
          targetAmount: 5000,
          currentAmount: 1000,
          targetDate: now.add(const Duration(days: 180)),
          category: 'savings',
          icon: 'savings',
          color: 0,
          createdAt: now,
          updatedAt: now,
          isCompleted: false,
        ),
      );
      await RecurringTransactionRepository.instance.add(
        RecurringTransaction(
          id: 'r1',
          title: 'Netflix Subscription',
          amount: 500,
          categoryId: 'entertainment',
          accountId: 'w1',
          transactionType: 'expense',
          frequency: 'monthly',
          startDate: now,
          nextDueDate: now.add(const Duration(days: 2)),
          isActive: true,
          reminderDaysBefore: 1,
          note: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final bundle = container.read(financialReportBundleProvider);

      final bytes = await FinancialReportPdfGenerator.build(bundle);
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // A multi-section report with real data should be substantially
      // larger than the empty-state PDF — a cheap sanity check that
      // content actually rendered rather than silently producing a blank
      // document.
      expect(bytes.length, greaterThan(2000));
    },
  );
}

String _monthName(int month) {
  const names = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];
  return names[month - 1];
}
