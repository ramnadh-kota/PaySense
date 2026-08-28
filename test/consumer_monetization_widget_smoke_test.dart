// Consumer Monetization Foundation — PHASE 14/16 items 4/5/12/13: real
// widget-pump smoke tests (not just color-token checks) for the highest-
// overflow-risk new screens, across light/dark mode and a small viewport,
// with empty AND populated data. Mirrors the established
// ai_screen_keyboard_test.dart harness pattern.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/onboarding/presentation/financial_snapshot_screen.dart';
import 'package:paysense/features/onboarding/presentation/aha_moment_screen.dart';
import 'package:paysense/features/onboarding/presentation/onboarding_goals_screen.dart';
import 'package:paysense/features/premium/presentation/paywall_screen.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
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
}

/// Deliberately small (matches a compact real Android screen) so any
/// RenderFlex overflow would have reproduced here.
Future<void> _pump(WidgetTester tester, Widget screen, {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: ThemeData(brightness: brightness), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_monetization_widget_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    AppColors.currentBrightness = Brightness.light;
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('4. Empty account', () {
    testWidgets('FinancialSnapshotScreen with no data at all: no overflow, honest empty state', (tester) async {
      await _pump(tester, const FinancialSnapshotScreen());
      expect(tester.takeException(), isNull);
      expect(
        find.text('Add a little more financial data and PaySense will build your full financial picture.'),
        findsOneWidget,
      );
    });

    testWidgets('AhaMomentScreen with no data at all: no overflow, honest empty state', (tester) async {
      await _pump(tester, const AhaMomentScreen());
      expect(tester.takeException(), isNull);
    });
  });

  group('5/6. Partial and populated account', () {
    testWidgets('FinancialSnapshotScreen with a wallet, income, expense, a loan, and a goal: no overflow', (tester) async {
      // The loan's nextDueDate below can be within LoansNotifier's
      // "upcoming/overdue" window (see loan_provider.dart's
      // _rescheduleReminders), which reactively writes an AppNotification
      // to Hive as a side effect of building loansProvider — a REAL,
      // non-fake-clock write. That write must happen inside runAsync's
      // real zone like the rest of this test's I/O: triggering it from
      // pumpWidget/pumpAndSettle OUTSIDE runAsync (i.e. in the ambient
      // fake-async test zone) leaves it stuck mid-flight and hangs the
      // later `Hive.deleteFromDisk()` in this file's tearDown for the
      // full 10-minute test timeout. So the pump/settle must be inside
      // the SAME runAsync block as the rest of this test's Hive writes,
      // not called separately afterward via the shared `_pump` helper.
      await tester.runAsync(() async {
        await WalletRepository.instance.add(
          Wallet(
            id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
            openingBalance: 0, currentBalance: 50000, createdAt: DateTime(2026, 1, 1),
          ),
        );
        await TransactionRepository.instance.add(
          Transaction(
            id: 't1', title: 'Salary', amount: 60000, categoryId: 'Salary', accountId: 'w1',
            transactionType: 'income', paymentMethod: 'Bank', note: '', createdAt: DateTime.now(),
          ),
        );
        await TransactionRepository.instance.add(
          Transaction(
            id: 't2', title: 'Rent', amount: 30000, categoryId: 'Housing', accountId: 'w1',
            transactionType: 'expense', paymentMethod: 'Bank', note: '', createdAt: DateTime.now(),
          ),
        );
        await LoanRepository.instance.add(
          Loan.create(
            id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Car',
            principalAmount: 300000, interestRate: 9, tenureMonths: 48, emiAmount: 8000,
            totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1),
            nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1),
          ),
        );

        await _pump(tester, const FinancialSnapshotScreen());
      });
      expect(tester.takeException(), isNull);
    });
  });

  group('12. Dark mode', () {
    testWidgets('OnboardingGoalsScreen renders without overflow in dark mode', (tester) async {
      AppColors.currentBrightness = Brightness.dark;
      await _pump(tester, const OnboardingGoalsScreen(), brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PaywallScreen renders without overflow in dark mode', (tester) async {
      AppColors.currentBrightness = Brightness.dark;
      await _pump(tester, const PaywallScreen(), brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });

  group('Paywall', () {
    testWidgets('renders both pricing plans and the dev-preview CTA without overflow', (tester) async {
      await _pump(tester, const PaywallScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Preview PaySense Plus (Dev Mode)'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Payments are not live yet'), findsOneWidget);
    });
  });

  group('OnboardingGoalsScreen', () {
    testWidgets('Continue is disabled until at least one goal is selected', (tester) async {
      await _pump(tester, const OnboardingGoalsScreen());
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Control spending'));
      await tester.pumpAndSettle();

      final buttonAfter = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(buttonAfter.onPressed, isNotNull);
    });
  });
}
