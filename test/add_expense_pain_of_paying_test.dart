// PAIN-OF-PAYING AUDIT — Add Expense save-flow regression coverage.
//
// Traces the real trigger sequence: amount/wallet validation -> Decision
// Coach dialog (blocking, pre-save) -> save -> Pain-of-Paying sheet
// (non-blocking, post-save, only when level != low) -> screen closes.
// Before this milestone, "Save Expense" had NO re-entrancy guard — two
// onPressed calls landing in the same synchronous tick (a genuine rapid
// double-tap/double-touch) could open two Decision Coach dialogs and, if
// both got confirmed, create two transactions for one user action. These
// tests prove the fix: exactly one save per user action.
//
// NOTE: after tapping Save, the button shows an indeterminate
// CircularProgressIndicator while `_isSaving` is true (awaiting the
// Decision Coach dialog) — an animation that schedules a new frame
// forever. `pumpAndSettle()` never returns while that's on screen, so
// every step between tapping Save and the dialog appearing uses a
// bounded `pump()` instead.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/transactions/presentation/add_expense_screen.dart';
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

/// Mirrors wallet_form_selection_test.dart's `_selectWallet` helper:
/// invokes WalletSelectorField's `onChanged` directly rather than driving
/// the DropdownButtonFormField's popup overlay, which is unreliable in a
/// bare test harness.
Future<void> _selectWallet(WidgetTester tester, String walletId) async {
  final finder = find.byType(DropdownButtonFormField<String>).last;
  final dropdown = tester.widget<DropdownButtonFormField<String>>(finder);
  dropdown.onChanged!(walletId);
  await tester.pump();
}

/// Pumps a bounded number of frames instead of pumpAndSettle — see the
/// file header for why pumpAndSettle can't be used while the Save
/// button's indeterminate spinner is on screen.
Future<void> _pumpUntilDialogAppears(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_add_expense_pop_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('1. valid amount + wallet: Save shows the Decision Coach dialog exactly once', (tester) async {
    await tester.runAsync(() async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'Cash', openingBalance: 5000, currentBalance: 5000, createdAt: DateTime(2026, 1, 1)),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AddExpenseScreen())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '200');
      await _selectWallet(tester, 'w1');
      await tester.tap(find.text('Save Expense'));
      await _pumpUntilDialogAppears(tester);

      expect(find.text('Think Before You Pay'), findsOneWidget);
      expect(await TransactionRepository.instance.getAll(), isEmpty);
    });
  });

  testWidgets('2. Cancel on Decision Coach: no transaction is created, screen stays open', (tester) async {
    await tester.runAsync(() async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'Cash', openingBalance: 5000, currentBalance: 5000, createdAt: DateTime(2026, 1, 1)),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AddExpenseScreen())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '200');
      await _selectWallet(tester, 'w1');
      await tester.tap(find.text('Save Expense'));
      await _pumpUntilDialogAppears(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await TransactionRepository.instance.getAll(), isEmpty);
      expect(await WalletRepository.instance.getById('w1').then((w) => w!.currentBalance), 5000);
      // The screen itself is still open (Cancel only closes the dialog),
      // and the button is back to its normal (non-spinner) state.
      expect(find.text('Save Expense'), findsOneWidget);
    });
  });

  testWidgets('3. Spend Anyway on Decision Coach: exactly one transaction is created, wallet debited once', (tester) async {
    await tester.runAsync(() async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'Cash', openingBalance: 5000, currentBalance: 5000, createdAt: DateTime(2026, 1, 1)),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AddExpenseScreen())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '200');
      await _selectWallet(tester, 'w1');
      await tester.tap(find.text('Save Expense'));
      await _pumpUntilDialogAppears(tester);

      await tester.tap(find.text('Spend Anyway'));
      // The Hive writes and provider reloads after the dialog closes are
      // real I/O (running in runAsync's real zone) not tied to any pumped
      // frame. Give it a real moment to complete before asserting.
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.amount, 200);
      final wallet = await WalletRepository.instance.getById('w1');
      expect(wallet!.currentBalance, 4800);
    });
  });

  testWidgets('4. two onPressed calls in the same synchronous tick: only ONE Decision Coach dialog opens', (tester) async {
    await tester.runAsync(() async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'Cash', openingBalance: 5000, currentBalance: 5000, createdAt: DateTime(2026, 1, 1)),
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AddExpenseScreen())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '200');
      await _selectWallet(tester, 'w1');

      // Two ordinary tester.tap() calls with no pump between them do NOT
      // reproduce the real race: Flutter's gesture routing resolves each
      // tap's onPressed callback to completion before the next event is
      // even dispatched. The actual race the guard defends against is two
      // pointer-down events landing in the SAME synchronous tick, before
      // either callback's setState has run — reproduced faithfully here
      // by invoking the button's onPressed twice back-to-back with no
      // await between them.
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Save Expense'), matching: find.byType(FilledButton)),
      );
      button.onPressed!();
      button.onPressed!();
      await _pumpUntilDialogAppears(tester);

      expect(find.text('Think Before You Pay'), findsOneWidget);
    });
  });
}
