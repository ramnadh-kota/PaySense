// Focused visual QA pass for the new Fun Funds screen (Phase 6): render
// overflow, small-screen behavior, large text scaling, and dark mode.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/core/theme/app_theme.dart';
import 'package:paysense/features/fun_funds/presentation/fun_funds_screen.dart';
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
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/repositories/fun_group_expense_repository.dart';
import 'package:paysense/shared/services/account_scope.dart';

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

Future<void> _seedRepresentativeData() async {
  await WalletRepository.instance.add(
    Wallet(
      id: 'w1',
      name: 'Everyday Checking Account With A Fairly Long Bank Name',
      bankName: 'Long National Bank of Testing',
      type: 'bank',
      openingBalance: 50000,
      currentBalance: 42500,
      createdAt: DateTime(2026, 1, 1),
    ),
  );
  final now = DateTime.now();
  await TransactionRepository.instance.add(
    Transaction(
      id: 't1',
      title: 'Groceries at a supermarket with a very long merchant name indeed',
      amount: 1250,
      categoryId: 'food',
      accountId: 'w1',
      transactionType: 'expense',
      paymentMethod: 'card',
      note: '',
      createdAt: now,
    ),
  );
  await FunGroupExpenseRepository.instance.add(
    FunGroupExpense(
      id: 'e1',
      title: 'Dinner with a large group of friends at a fancy restaurant',
      categoryKey: FunGroupExpenseCategory.dinner.name,
      totalAmount: 4800,
      date: now,
      paidByParticipantId: funGroupExpenseMeParticipantId,
      participants: [
        const FunGroupParticipant(
          id: funGroupExpenseMeParticipantId,
          name: 'Me',
          shareAmount: 1200,
          isSettled: true,
        ),
        const FunGroupParticipant(
          id: 'p2',
          name: 'A friend with a fairly long display name',
          shareAmount: 1200,
        ),
        const FunGroupParticipant(id: 'p3', name: 'Sam', shareAmount: 1200),
        const FunGroupParticipant(id: 'p4', name: 'Alex', shareAmount: 1200),
      ],
      createdAt: now,
    ),
  );
}

Widget _wrap(Widget child, {bool dark = false, double textScale = 1.0}) {
  return ProviderScope(
    child: MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: child,
    ),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_fun_funds_ui_test');
    await _initHive(tempDir);
    await AccountScope.instance.activate('qa-account');
    await _seedRepresentativeData();
  });

  tearDown(() async {
    AccountScope.instance.deactivate();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> setSmallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'FunFundsScreen renders without overflow on a small screen',
    (tester) async {
      await setSmallScreen(tester);
      await tester.pumpWidget(_wrap(const FunFundsScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Fun Funds'), findsOneWidget);
    },
  );

  testWidgets('FunFundsScreen renders without overflow in dark mode', (
    tester,
  ) async {
    await setSmallScreen(tester);
    await tester.pumpWidget(_wrap(const FunFundsScreen(), dark: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FunFundsScreen renders without overflow at 1.6x text scaling '
    '(large-text accessibility setting)',
    (tester) async {
      await setSmallScreen(tester);
      await tester.pumpWidget(_wrap(const FunFundsScreen(), textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
