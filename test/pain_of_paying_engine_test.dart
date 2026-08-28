import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/pain_of_paying_result.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/pain_of_paying_engine.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

final _now = DateTime(2026, 8, 27); // a Thursday

Transaction _tx(String id, double amount, {String category = 'Food', DateTime? date}) {
  return Transaction(
    id: id, title: category, amount: amount, categoryId: category, accountId: 'w1',
    transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: date ?? _now,
  );
}

void main() {
  group('PainOfPayingEngine — no fabrication', () {
    test('with zero history and zero budgets/goals, only the perspective "not enough history" signal appears', () {
      final result = PainOfPayingEngine.evaluate(
        amount: 450,
        categoryId: 'Food',
        transactions: const [],
        budgets: const [],
        goals: const [],
        now: _now,
      );

      expect(result.level, PainOfPayingLevel.low);
      expect(result.signals.any((s) => s.label == 'Budget impact'), isFalse);
      expect(result.signals.any((s) => s.label == 'Size'), isFalse);
      expect(result.signals.any((s) => s.label == 'Savings goals'), isFalse);
      expect(result.signals.any((s) => s.label == 'Upcoming obligations'), isFalse);
      expect(result.suggestedAction, isNull);
    });

    test('EMI signal is omitted when monthlyEmiBurden is null/zero', () {
      final result = PainOfPayingEngine.evaluate(
        amount: 450, categoryId: 'Food', transactions: const [], budgets: const [], goals: const [], now: _now,
      );
      expect(result.signals.any((s) => s.label == 'EMI impact'), isFalse);
    });

    test('goal-awareness signal is omitted unless the amount is genuinely close to what remains', () {
      final farGoal = Goal.create(id: 'g1', title: 'Goa Trip', targetAmount: 100000, category: 'Travel', icon: '', color: 0, targetDate: DateTime(2027, 1, 1), createdAt: _now);
      final result = PainOfPayingEngine.evaluate(
        amount: 450, categoryId: 'Food', transactions: const [], budgets: const [], goals: [farGoal], now: _now,
      );
      expect(result.signals.any((s) => s.label == 'Goal awareness'), isFalse);
    });

    test('goal-awareness signal appears with neutral phrasing when the amount is close to what remains', () {
      final closeGoal = Goal.create(id: 'g1', title: 'Goa Trip', targetAmount: 3000, category: 'Travel', icon: '', color: 0, targetDate: DateTime(2027, 1, 1), createdAt: _now)
          .copyWith(currentAmount: 1000); // remaining = 2000
      final result = PainOfPayingEngine.evaluate(
        amount: 2000, categoryId: 'Food', transactions: const [], budgets: const [], goals: [closeGoal], now: _now,
      );
      final signal = result.signals.firstWhere((s) => s.label == 'Goal awareness');
      expect(signal.detail, contains('₹2000'));
      expect(signal.detail, contains('Goa Trip'));
      // Must be neutral — never imply the money was required to be saved.
      expect(signal.detail.toLowerCase(), isNot(contains('should have')));
      expect(signal.detail.toLowerCase(), isNot(contains('instead of')));
    });
  });

  group('PainOfPayingEngine — budget impact (real monthly budgets only)', () {
    test('omits the budget signal when no Budget exists for that category/month', () {
      final result = PainOfPayingEngine.evaluate(
        amount: 500, categoryId: 'Food', transactions: const [], budgets: const [], goals: const [], now: _now,
      );
      expect(result.signals.any((s) => s.label == 'Budget impact'), isFalse);
    });

    test('reports real remaining budget and raises the level as the projected spend nears/exceeds the limit', () {
      final budget = Budget.create(id: 'b1', categoryId: 'Food', categoryName: 'Food', allocatedAmount: 1000, month: 'August', year: 2026, createdAt: _now)
          .copyWith(spentAmount: 950, remainingAmount: 50, percentageUsed: 95);
      final result = PainOfPayingEngine.evaluate(
        amount: 200, // pushes spend to 1150/1000 = 115%
        categoryId: 'Food', transactions: const [], budgets: [budget], goals: const [], now: _now,
      );
      final signal = result.signals.firstWhere((s) => s.label == 'Budget impact');
      expect(signal.detail, contains('₹50'));
      expect(result.level, anyOf(PainOfPayingLevel.high, PainOfPayingLevel.veryHigh));
    });
  });

  group('PainOfPayingEngine — this-week frequency and totals (real counts only)', () {
    test('counts only same-category expenses within the last 7 days', () {
      final history = [
        _tx('t1', 300, date: _now.subtract(const Duration(days: 2))),
        _tx('t2', 300, date: _now.subtract(const Duration(days: 3))),
        _tx('t3', 300, category: 'Shopping', date: _now.subtract(const Duration(days: 1))), // different category
        _tx('t4', 300, date: _now.subtract(const Duration(days: 20))), // outside the window
      ];
      final result = PainOfPayingEngine.evaluate(
        amount: 450, categoryId: 'Food', transactions: history, budgets: const [], goals: const [], now: _now,
      );
      final signal = result.signals.firstWhere((s) => s.label == 'This week');
      expect(signal.detail, contains('3rd Food purchase')); // 2 prior + this one
      expect(signal.detail, contains('₹1050')); // 300+300+450
    });

    test('excludeTransactionId keeps an already-saved transaction from being counted against itself', () {
      final history = [_tx('self', 450, date: _now)];
      final result = PainOfPayingEngine.evaluate(
        amount: 450, categoryId: 'Food', transactions: history, budgets: const [], goals: const [], now: _now,
        excludeTransactionId: 'self',
      );
      final signal = result.signals.firstWhere((s) => s.label == 'This week');
      expect(signal.detail, contains('1st Food purchase'));
    });
  });

  group('PainOfPayingEngine — typical-size comparison (needs a real sample)', () {
    test('omits the Size signal with fewer than 3 recent same-category transactions', () {
      final history = [_tx('t1', 200, date: _now.subtract(const Duration(days: 10)))];
      final result = PainOfPayingEngine.evaluate(
        amount: 2000, categoryId: 'Food', transactions: history, budgets: const [], goals: const [], now: _now,
      );
      expect(result.signals.any((s) => s.label == 'Size'), isFalse);
    });

    test('flags an amount well above the real recent median as atypically large', () {
      final history = [
        _tx('t1', 200, date: _now.subtract(const Duration(days: 5))),
        _tx('t2', 220, date: _now.subtract(const Duration(days: 10))),
        _tx('t3', 210, date: _now.subtract(const Duration(days: 15))),
      ];
      final result = PainOfPayingEngine.evaluate(
        amount: 900, // ~4x the ~210 median
        categoryId: 'Food', transactions: history, budgets: const [], goals: const [], now: _now,
      );
      expect(result.signals.any((s) => s.label == 'Size'), isTrue);
      expect(result.level, anyOf(PainOfPayingLevel.high, PainOfPayingLevel.veryHigh));
    });
  });

  group('PainOfPayingEngine — upcoming obligations (reuses SafeToSpendResult)', () {
    test('omitted entirely when no SafeToSpendResult is supplied', () {
      final result = PainOfPayingEngine.evaluate(
        amount: 450, categoryId: 'Food', transactions: const [], budgets: const [], goals: const [], now: _now,
      );
      expect(result.signals.any((s) => s.label == 'Upcoming obligations'), isFalse);
    });

    test('a real shortfall raises the level to at least high with neutral suggested action', () {
      const safeToSpend = SafeToSpendResult(
        availableMoney: 1000, upcomingCommitments: 1500, plannedSavings: 0, savingsIncluded: false,
        safeToSpend: 0, dailySafeToSpend: 0, remainingDays: 30, hasSufficientData: true,
        shortfall: 500, commitmentBreakdown: [], windowDays: 30,
      );
      final result = PainOfPayingEngine.evaluate(
        amount: 450, categoryId: 'Food', transactions: const [], budgets: const [], goals: const [], now: _now,
        safeToSpend: safeToSpend,
      );
      expect(result.level, anyOf(PainOfPayingLevel.high, PainOfPayingLevel.veryHigh));
      expect(result.suggestedAction, isNotNull);
      expect(result.suggestedAction!.toLowerCase(), isNot(contains('should have')));
    });
  });

  group('PainOfPayingEngine — headline never fabricates', () {
    test('headline always reflects the real amount and category passed in', () {
      final result = PainOfPayingEngine.evaluate(
        amount: 8500, categoryId: 'Shopping', transactions: const [], budgets: const [], goals: const [], now: _now,
      );
      expect(result.headline, '₹8500 spent on Shopping.');
      expect(result.amount, 8500);
    });
  });
}
