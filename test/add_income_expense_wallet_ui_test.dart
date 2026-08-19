// Focused UI regression tests for the Add Income / Add Expense wallet
// selection flow (P0 Issue 5): the label must clearly ask the user to pick
// a real Wallet ("Deposit into" / "Pay from"), the value saved must always
// be Wallet.id (never a display label), and a no-wallets state must offer
// an actual "Add Wallet" action rather than a dead end.
//
// Note: any real Hive write (WalletRepository.add, or the transaction
// writes triggered by tapping Save) has to run inside `tester.runAsync` —
// Box.put() resolves via a real Timer/event-loop callback that
// TestWidgetsFlutterBinding's virtual clock never advances on its own, so
// calling it directly inside a `testWidgets` body (or via a tap that
// triggers it) hangs forever without runAsync. Reads don't have this
// problem (they resolve on a plain microtask).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/transactions/presentation/add_expense_screen.dart';
import 'package:paysense/features/transactions/presentation/add_income_screen.dart';
import 'package:paysense/features/wallet/presentation/add_edit_wallet_screen.dart';
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
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BudgetAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(GoalAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BillAdapter());
  }
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(LoanAdapter());
  }
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(AccountAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }

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

Future<Wallet> _addWallet(
  WidgetTester tester,
  String id,
  String name, {
  double balance = 10000,
}) async {
  final wallet = Wallet(
    id: id,
    name: name,
    bankName: '',
    type: 'Bank',
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
  await tester.runAsync(() => WalletRepository.instance.add(wallet));
  return wallet;
}

/// Same enlarged-viewport fix as wallet_form_selection_test.dart's
/// `_pumpFormSheet` — flutter test's default 800x600 surface is too short
/// for these screens' full content (amount card + dropdowns + note field +
/// save button, or the DecisionCoachDialog) to lay out without overflowing.
///
/// Pushes [screen] via a real `Navigator.push` from a placeholder root route
/// rather than setting it as `MaterialApp.home` directly — both
/// AddIncomeScreen/AddExpenseScreen call `Navigator.of(context).pop()` after
/// saving, same as they do in production (opened via `Navigator.push` from
/// the Dashboard); as `home` with nothing beneath it, that pop has no route
/// to return to and throws, which (being inside a fire-and-forget
/// `onPressed` handler) surfaces as an uncaught async error later and
/// spuriously fails a *different* test.
Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Same deterministic-callback approach as wallet_form_selection_test.dart's
/// `_selectWallet` — invokes `onChanged` directly rather than driving the
/// actual Material dropdown overlay, which is unreliable in a bare harness.
Future<void> _selectWallet(WidgetTester tester, String walletId) async {
  final finder = find.byType(DropdownButtonFormField<String>).last;
  final dropdown = tester.widget<DropdownButtonFormField<String>>(finder);
  dropdown.onChanged!(walletId);
  await tester.pumpAndSettle();
}

/// Taps [finder] and settles inside `runAsync`, for taps whose `onPressed`
/// callback performs real Hive writes (see file-level note). `onPressed` is
/// fire-and-forget from the framework's perspective, so `pumpAndSettle`
/// alone can race ahead of the handler's own await chain (two Hive writes
/// + two provider reloads + a Navigator.pop) — the extra real-time delay
/// gives that chain a full event-loop turn to actually finish before the
/// test (and its tearDown, which deletes the Hive boxes) moves on.
Future<void> _tapAndSettleAsync(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_add_income_expense_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('24. Add Income wallet selection', () {
    testWidgets('shows a "Deposit into" wallet selector, not a generic "Choose account" prompt', (
      tester,
    ) async {
      await _addWallet(tester, 'w-salary', 'HDFC Salary');
      await _pumpScreen(tester, const AddIncomeScreen());

      expect(find.text('Deposit into'), findsOneWidget);
      expect(find.textContaining('Choose income account'), findsNothing);
    });

    testWidgets('saving stores the selected Wallet.id, never the wallet name', (tester) async {
      final wallet = await _addWallet(tester, 'w-salary', 'HDFC Salary');
      await _pumpScreen(tester, const AddIncomeScreen());

      await tester.enterText(find.byType(TextField).first, '50000');
      await _selectWallet(tester, wallet.id);
      await _tapAndSettleAsync(tester, find.text('Save Income'));

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, hasLength(1));
      expect(transactions.single.accountId, wallet.id);
      expect(transactions.single.accountId, isNot('HDFC Salary'));
      expect(transactions.single.transactionType, 'income');
    });
  });

  group('25. Add Expense wallet selection', () {
    testWidgets('shows a "Pay from" wallet selector', (tester) async {
      await _addWallet(tester, 'w-savings', 'SBI Savings');
      await _pumpScreen(tester, const AddExpenseScreen());

      expect(find.text('Pay from'), findsOneWidget);
    });

    testWidgets('a wallet must be selected before the decision-coach dialog appears', (
      tester,
    ) async {
      await _addWallet(tester, 'w-savings', 'SBI Savings');
      await _pumpScreen(tester, const AddExpenseScreen());

      await tester.enterText(find.byType(TextField).first, '500');
      // No wallet selected — Save should stop at the validation snackbar,
      // never reaching the decision-coach dialog.
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Spend Anyway'), findsNothing);
      expect(find.text('Please choose an account.'), findsOneWidget);
    });

    testWidgets('cancelling the decision-coach dialog saves nothing', (tester) async {
      final wallet = await _addWallet(tester, 'w-savings', 'SBI Savings');
      await _pumpScreen(tester, const AddExpenseScreen());

      await tester.enterText(find.byType(TextField).first, '500');
      await _selectWallet(tester, wallet.id);
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Spend Anyway'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final transactions = await TransactionRepository.instance.getAll();
      expect(transactions, isEmpty);
    });
  });

  group('26. No-wallet income state', () {
    testWidgets('shows "No wallets yet" with a clear Add Wallet action, no dropdown', (
      tester,
    ) async {
      await _pumpScreen(tester, const AddIncomeScreen());

      expect(find.text('No wallets yet'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add Wallet'), findsOneWidget);
      // "Income Source" also renders a DropdownButtonFormField<String>, so
      // this checks specifically for the wallet selector (by its label)
      // rather than the presence of any dropdown on the screen.
      expect(find.text('Deposit into'), findsNothing);
    });

    testWidgets('tapping Add Wallet navigates to the wallet creation screen', (tester) async {
      await _pumpScreen(tester, const AddIncomeScreen());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditWalletScreen), findsOneWidget);
    });

    testWidgets('the same no-wallet Add Wallet action is offered on Add Expense too', (
      tester,
    ) async {
      await _pumpScreen(tester, const AddExpenseScreen());

      expect(find.text('No wallets yet'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add Wallet'), findsOneWidget);
    });
  });
}
