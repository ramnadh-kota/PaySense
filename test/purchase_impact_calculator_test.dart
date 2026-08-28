// BUG FIX regression tests: "Think Before You Pay" previously received
// hardcoded literals (emiPercentage: 18, savingsGoalPercentage: 3, a fixed
// "two days of groceries" string) that never reflected the amount actually
// entered. PurchaseImpactCalculator replaces those with real, deterministic
// figures. Pure calculator — no Flutter/BuildContext/repository dependency.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/purchase_impact_calculator.dart';

final _now = DateTime(2026, 8, 20);

Goal _goal({required String id, required double target, required double current}) {
  return Goal.create(
    id: id, title: id, targetAmount: target, currentAmount: current,
    targetDate: DateTime(2027, 1, 1), category: 'Other', icon: 'star',
    color: 0xFF000000, createdAt: DateTime(2025, 1, 1),
  );
}

Transaction _tx({required String category, required double amount, required DateTime date}) {
  return Transaction(
    id: 't-$category-$amount-${date.millisecondsSinceEpoch}', title: category, amount: amount,
    categoryId: category, accountId: 'w1', transactionType: 'expense',
    paymentMethod: 'card', note: '', createdAt: date,
  );
}

/// Weekly grocery spend of ~₹1,750 spread across the 90-day lookback
/// window (13 weeks x ₹1,750 ≈ ₹22,750), all real dated transactions.
List<Transaction> _groceryHistory() {
  final transactions = <Transaction>[];
  for (var i = 0; i < 13; i++) {
    transactions.add(_tx(category: 'Groceries', amount: 1750, date: _now.subtract(Duration(days: i * 7))));
  }
  return transactions;
}

void main() {
  group('EMI Impact', () {
    test('₹5,362 against a ₹30,000 EMI burden is ~17.9%, never hardcoded 18%', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5362, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, closeTo(17.87, 0.1));
    });

    test('₹10,000 against a ₹30,000 EMI burden is 33.3%', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 10000, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, closeTo(33.33, 0.1));
    });

    test('₹20,000 against a ₹30,000 EMI burden is 66.7%', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 20000, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, closeTo(66.67, 0.1));
    });

    test('no active loans / zero EMI burden → emiPercentage is null, never fabricated', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, isNull);
    });

    test('a large purchase can exceed 100% of monthly EMI — never artificially capped', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 500000, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, greaterThan(100));
    });

    test('decimal amounts compute a decimal-accurate percentage', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 1234.56, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, closeTo(4.1152, 0.01));
    });

    test('zero amount never crashes and produces 0%', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 0, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
      );
      expect(result.emiPercentage, 0);
    });
  });

  group('Savings Goal Impact', () {
    test('₹5,000 against a ₹1,00,000 remaining goal is 5%', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0,
        goals: [_goal(id: 'g1', target: 100000, current: 0)],
        transactions: const [], now: _now,
      );
      expect(result.savingsGoalPercentage, closeTo(5, 0.01));
    });

    test('₹25,000 against a ₹1,00,000 remaining goal is 25%', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 25000, monthlyEmiBurden: 0,
        goals: [_goal(id: 'g1', target: 100000, current: 0)],
        transactions: const [], now: _now,
      );
      expect(result.savingsGoalPercentage, closeTo(25, 0.01));
    });

    test('no goals at all → savingsGoalPercentage is null, never fabricated', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: const [], transactions: const [], now: _now,
      );
      expect(result.savingsGoalPercentage, isNull);
    });

    test('every goal already completed → savingsGoalPercentage is null, not 0/fabricated', () {
      final completed = _goal(id: 'g1', target: 10000, current: 10000);
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: [completed], transactions: const [], now: _now,
      );
      expect(result.savingsGoalPercentage, isNull);
    });

    test('multiple incomplete goals sum their remaining amounts', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 20000, monthlyEmiBurden: 0,
        goals: [
          _goal(id: 'g1', target: 80000, current: 20000), // remaining 60000
          _goal(id: 'g2', target: 50000, current: 10000), // remaining 40000
        ],
        // total remaining = 100000 -> 20000/100000 = 20%
        transactions: const [], now: _now,
      );
      expect(result.savingsGoalPercentage, closeTo(20, 0.01));
    });

    test('a completed goal never contributes to the remaining amount alongside an incomplete one', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 10000, monthlyEmiBurden: 0,
        goals: [
          _goal(id: 'g1', target: 50000, current: 50000), // completed, contributes 0
          _goal(id: 'g2', target: 100000, current: 0), // remaining 100000
        ],
        transactions: const [], now: _now,
      );
      expect(result.savingsGoalPercentage, closeTo(10, 0.01));
    });
  });

  group('Perspective', () {
    test('real category spending history produces a real week-count comparison', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: const [],
        transactions: _groceryHistory(), category: 'Groceries', now: _now,
      );
      expect(result.perspectiveMessage, contains('groceries'));
      expect(result.perspectiveMessage, isNot(contains('two days')));
    });

    test('no spending history at all → an honest "not enough history" message, never a fabricated average', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: const [], transactions: const [],
        category: 'Groceries', now: _now,
      );
      expect(result.perspectiveMessage, contains('Not enough spending history'));
    });

    test('no history for the selected category falls back to a category that has history', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: const [],
        transactions: _groceryHistory(), category: 'Travel', now: _now,
      );
      expect(result.perspectiveMessage, contains('groceries'));
    });

    test('a null category still falls back to whichever category has the most history', () {
      final result = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 0, goals: const [],
        transactions: _groceryHistory(), category: null, now: _now,
      );
      expect(result.perspectiveMessage, contains('groceries'));
    });
  });

  group('Live amount consistency — different amounts MUST produce different results', () {
    test('₹5,362 → ₹10,000 → ₹20,000 → ₹1,000 each produce a distinct EMI percentage', () {
      final amounts = [5362.0, 10000.0, 20000.0, 1000.0];
      final percentages = amounts
          .map((a) => PurchaseImpactCalculator.calculate(
                amount: a, monthlyEmiBurden: 30000, goals: const [], transactions: const [], now: _now,
              ).emiPercentage)
          .toList();
      expect(percentages.toSet().length, amounts.length);
    });

    test('₹5,362 → ₹10,000 → ₹20,000 → ₹1,000 each produce a distinct savings-goal percentage', () {
      final amounts = [5362.0, 10000.0, 20000.0, 1000.0];
      final goals = [_goal(id: 'g1', target: 100000, current: 0)];
      final percentages = amounts
          .map((a) => PurchaseImpactCalculator.calculate(
                amount: a, monthlyEmiBurden: 0, goals: goals, transactions: const [], now: _now,
              ).savingsGoalPercentage)
          .toList();
      expect(percentages.toSet().length, amounts.length);
    });

    test('₹5,362 → ₹10,000 → ₹20,000 each produce a distinct perspective message', () {
      final amounts = [5362.0, 10000.0, 20000.0];
      final messages = amounts
          .map((a) => PurchaseImpactCalculator.calculate(
                amount: a, monthlyEmiBurden: 0, goals: const [],
                transactions: _groceryHistory(), category: 'Groceries', now: _now,
              ).perspectiveMessage)
          .toSet();
      expect(messages.length, amounts.length);
    });

    test('the header amount always equals the amount every calculation used', () {
      const amount = 12345.0;
      final result = PurchaseImpactCalculator.calculate(
        amount: amount, monthlyEmiBurden: 30000,
        goals: [_goal(id: 'g1', target: 100000, current: 0)],
        transactions: _groceryHistory(), category: 'Groceries', now: _now,
      );
      expect(result.amount, amount);
      // Reconstructing the EMI% from the SAME amount must match exactly —
      // proves the calculator didn't silently use a different figure.
      expect(result.emiPercentage, closeTo(amount / 30000 * 100, 0.001));
    });
  });

  group('Simulation safety — the calculator is read-only', () {
    test('calling calculate() repeatedly with identical inputs is idempotent (no hidden state/mutation)', () {
      final goals = [_goal(id: 'g1', target: 100000, current: 20000)];
      final transactions = _groceryHistory();
      final first = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 30000, goals: goals, transactions: transactions,
        category: 'Groceries', now: _now,
      );
      final second = PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 30000, goals: goals, transactions: transactions,
        category: 'Groceries', now: _now,
      );
      expect(first.emiPercentage, second.emiPercentage);
      expect(first.savingsGoalPercentage, second.savingsGoalPercentage);
      expect(first.perspectiveMessage, second.perspectiveMessage);
    });

    test('the input goal/transaction lists are never mutated by calculate()', () {
      final goals = [_goal(id: 'g1', target: 100000, current: 20000)];
      final transactions = _groceryHistory();
      final goalsBefore = List.of(goals);
      final transactionsBefore = List.of(transactions);

      PurchaseImpactCalculator.calculate(
        amount: 5000, monthlyEmiBurden: 30000, goals: goals, transactions: transactions,
        category: 'Groceries', now: _now,
      );

      expect(goals, goalsBefore);
      expect(transactions, transactionsBefore);
      expect(goals.length, 1);
      expect(transactions.length, 13);
    });
  });
}
