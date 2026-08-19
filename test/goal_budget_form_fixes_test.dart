import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/budget/presentation/widgets/budget_form_sheet.dart';
import 'package:paysense/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';

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

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
}

/// Pumps [sheet] via a real `showModalBottomSheet` route inside an
/// enlarged viewport — a bare/small host causes `DraggableScrollableSheet`'s
/// sliver list to never realize children past roughly its halfway point
/// (see wallet_form_selection_test.dart for the same fix applied there).
Future<void> _pumpFormSheet(WidgetTester tester, Widget sheet) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => sheet,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_goal_budget_fix_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Budget form fixes', () {
    testWidgets(
      'categoryId matches the raw category label, not a lowercase-dashed '
      'transform of it',
      (tester) async {
        Budget? saved;
        await _pumpFormSheet(
          tester,
          BudgetFormSheet(onSave: (budget) async => saved = budget),
        );

        await tester.enterText(find.byType(TextFormField).at(0), 'Groceries');
        await tester.enterText(find.byType(TextFormField).at(1), '5000');
        await tester.enterText(find.byType(TextFormField).at(2), 'August');
        await tester.enterText(find.byType(TextFormField).at(3), '2026');

        await tester.tap(find.text('Save budget'));
        await tester.pumpAndSettle();

        expect(saved, isNotNull);
        expect(saved!.categoryId, 'Groceries');
        expect(saved!.categoryId, isNot('groceries'));
      },
    );

    testWidgets('an unrecognized month name is rejected, not silently saved', (
      tester,
    ) async {
      Budget? saved;
      await _pumpFormSheet(
        tester,
        BudgetFormSheet(onSave: (budget) async => saved = budget),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Groceries');
      await tester.enterText(find.byType(TextFormField).at(1), '5000');
      await tester.enterText(find.byType(TextFormField).at(2), 'Aug'); // typo/abbreviation
      await tester.enterText(find.byType(TextFormField).at(3), '2026');

      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();

      expect(saved, isNull);
      expect(find.text('Enter a full month name, e.g. March'), findsOneWidget);
    });

    testWidgets('double-tapping Save calls onSave exactly once', (tester) async {
      var saveCount = 0;
      await _pumpFormSheet(
        tester,
        BudgetFormSheet(
          onSave: (budget) async {
            saveCount++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Groceries');
      await tester.enterText(find.byType(TextFormField).at(1), '5000');
      await tester.enterText(find.byType(TextFormField).at(2), 'August');
      await tester.enterText(find.byType(TextFormField).at(3), '2026');

      await tester.tap(find.text('Save budget'));
      await tester.tap(find.text('Save budget'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(saveCount, 1);
    });

    test(
      'end-to-end: a budget created via the (fixed) form now actually '
      'tracks matching expense spend, instead of staying at ₹0',
      () async {
        await TransactionRepository.instance.add(
          Transaction(
            id: 't1',
            title: 'Weekly shop',
            amount: 1200,
            categoryId: 'Groceries', // exactly what AddExpenseScreen stores
            accountId: 'wallet-1',
            transactionType: 'expense',
            paymentMethod: 'card',
            note: '',
            createdAt: DateTime(2026, 8, 10),
          ),
        );

        // categoryId as the fixed BudgetFormSheet now produces: the raw
        // category label, not a lowercase-dashed transform of it.
        final budget = Budget.create(
          id: 'b1',
          categoryId: 'Groceries',
          categoryName: 'Groceries',
          allocatedAmount: 5000,
          month: 'August',
          year: 2026,
          createdAt: DateTime.now(),
        );
        await BudgetRepository.instance.add(budget);

        final transactions = await TransactionRepository.instance.getAll();
        await BudgetRepository.instance.refreshBudgets(transactions);

        final refreshed = await BudgetRepository.instance.getById('b1');
        expect(refreshed!.spentAmount, 1200.0);
        expect(refreshed.remainingAmount, 3800.0);
      },
    );
  });

  group('Goal form fixes', () {
    testWidgets(
      'editing a goal with an emptied "Current savings" field preserves '
      'the existing saved amount instead of zeroing it',
      (tester) async {
        final existing = Goal.create(
          id: 'g1',
          title: 'New laptop',
          targetAmount: 50000,
          currentAmount: 20000,
          targetDate: DateTime(2026, 12, 31),
          category: 'Electronics',
          icon: 'laptop',
          color: 0xFF5B4CF8,
          createdAt: DateTime.now(),
        );
        Goal? saved;

        await _pumpFormSheet(
          tester,
          GoalFormSheet(goal: existing, onSave: (goal) async => saved = goal),
        );

        // "Current savings" is the 3rd TextFormField (Title, Target, Current).
        await tester.enterText(find.byType(TextFormField).at(2), '');

        await tester.tap(find.text('Save goal'));
        await tester.pumpAndSettle();

        expect(saved, isNotNull);
        expect(saved!.currentAmount, 20000.0);
      },
    );

    testWidgets('a brand-new goal with no "Current savings" entered defaults to 0', (
      tester,
    ) async {
      Goal? saved;
      await _pumpFormSheet(
        tester,
        GoalFormSheet(onSave: (goal) async => saved = goal),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Vacation');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');
      // Current savings left blank.

      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.currentAmount, 0.0);
    });

    testWidgets('double-tapping Save calls onSave exactly once', (tester) async {
      var saveCount = 0;
      await _pumpFormSheet(
        tester,
        GoalFormSheet(
          onSave: (goal) async {
            saveCount++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Vacation');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');

      await tester.tap(find.text('Save goal'));
      await tester.tap(find.text('Save goal'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(saveCount, 1);
    });
  });
}
