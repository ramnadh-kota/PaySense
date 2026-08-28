// Pure-calculator tests for ComparePeriodsCalculator (Compare Periods 1.0,
// Phase 1/10). Mirrors the established "reuse real calculators" pattern —
// inputs are synthetic Transaction/Wallet/Budget records fed through the
// REAL ReportsCalculator (via ComparePeriodsCalculator), never a second
// hand-rolled formula.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/compare_periods_calculator.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  String category = 'Food',
  required DateTime date,
}) {
  return Transaction(
    id: id, title: id, amount: amount, categoryId: category, accountId: 'w1',
    transactionType: type, paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

Wallet _wallet(String id) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: 0, currentBalance: 0, createdAt: DateTime(2025, 1, 1),
  );
}

Budget _budget(String id, {required String month, required int year, required double allocated, required double spent}) {
  return Budget(
    id: id, categoryId: 'Food', categoryName: 'Food', allocatedAmount: allocated,
    spentAmount: spent, remainingAmount: allocated - spent,
    percentageUsed: allocated > 0 ? spent / allocated * 100 : 0,
    month: month, year: year, createdAt: DateTime(year, 1, 1),
  );
}

ComparePeriod _month(String label, int year, int month) {
  return ComparePeriod(
    label: label,
    start: DateTime(year, month, 1),
    end: DateTime(year, month + 1, 1),
  );
}

ComparePeriod _months(String label, int year, int startMonth, int count) {
  return ComparePeriod(
    label: label,
    start: DateTime(year, startMonth, 1),
    end: DateTime(year, startMonth + count, 1),
  );
}

ComparePeriodsResult _calc({
  List<Transaction> transactions = const [],
  List<Budget> budgets = const [],
  required ComparePeriod current,
  required ComparePeriod comparison,
}) {
  return ComparePeriodsCalculator.calculate(
    transactions: transactions,
    wallets: [_wallet('w1')],
    budgets: budgets,
    currentPeriod: current,
    comparisonPeriod: comparison,
  );
}

void main() {
  group('1-4. Income/Expense/Savings/Savings-rate comparison', () {
    test('1. income comparison reflects real totals for each period', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.income.currentValue, 50000);
      expect(result.income.comparisonValue, 40000);
      expect(result.income.absoluteDifference, 10000);
    });

    test('2. expense comparison reflects real totals for each period', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
          _tx(id: 'e2', amount: 15000, type: 'expense', date: DateTime(2026, 7, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.expense.currentValue, 20000);
      expect(result.expense.comparisonValue, 15000);
    });

    test('3. savings comparison is income minus expense per period', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 6)),
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 25000, type: 'expense', date: DateTime(2026, 7, 6)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.savings.currentValue, 30000); // 50000-20000
      expect(result.savings.comparisonValue, 15000); // 40000-25000
    });

    test('4. savings rate comparison is expressed in points, not a nested percentage', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 6)), // rate 60%
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 30000, type: 'expense', date: DateTime(2026, 7, 6)), // rate 25%
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.savingsRate.currentRate, closeTo(60, 0.01));
      expect(result.savingsRate.comparisonRate, closeTo(25, 0.01));
      expect(result.savingsRate.pointsDifference, closeTo(35, 0.01));
    });
  });

  group('5-7. Direction classification', () {
    test('5. a clear positive improvement is classified improved', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 60000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'e1', amount: 10000, type: 'expense', date: DateTime(2026, 8, 6)),
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 30000, type: 'expense', date: DateTime(2026, 7, 6)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.income.direction, ComparisonDirection.improved);
      expect(result.expense.direction, ComparisonDirection.improved); // lower is better
      expect(result.savings.direction, ComparisonDirection.improved);
      expect(result.verdict, "You're financially stronger than the previous period.");
    });

    test('6. a clear negative deterioration is classified worsened', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 30000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'e1', amount: 25000, type: 'expense', date: DateTime(2026, 8, 6)),
          _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 10000, type: 'expense', date: DateTime(2026, 7, 6)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.income.direction, ComparisonDirection.worsened);
      expect(result.expense.direction, ComparisonDirection.worsened);
      expect(result.verdict, 'Your financial position weakened compared with the previous period.');
    });

    test('7. identical values across periods produce "No meaningful change."', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 40000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 6)),
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 20000, type: 'expense', date: DateTime(2026, 7, 6)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.income.direction, ComparisonDirection.unchanged);
      expect(result.expense.direction, ComparisonDirection.unchanged);
      expect(result.verdict, 'No meaningful change.');
    });
  });

  group('8-9. Zero income/expense edge cases', () {
    test('8. zero income in a period never produces a fabricated savings rate', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 5000, type: 'expense', date: DateTime(2026, 8, 5)),
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 20000, type: 'expense', date: DateTime(2026, 7, 6)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.savingsRate.currentRate, isNull);
      expect(result.savingsRate.direction, ComparisonDirection.insufficientData);
    });

    test('9. zero expenses never produces NaN/Infinity anywhere', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 40000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'i2', amount: 40000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 10000, type: 'expense', date: DateTime(2026, 7, 6)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.expense.currentValue, 0);
      expect(result.expense.percentageDifference?.isNaN ?? false, isFalse);
      expect(result.expense.percentageDifference?.isInfinite ?? false, isFalse);
      expect(result.savingsRate.currentRate, 100);
      expect(result.savingsRate.currentRate!.isNaN, isFalse);
    });
  });

  group('10-11. Empty / one-sided history', () {
    test('10. empty history on both sides never fabricates a comparison', () {
      final result = _calc(
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.hasSufficientData, isFalse);
      expect(result.currentPeriodHasData, isFalse);
      expect(result.comparisonPeriodHasData, isFalse);
      expect(result.verdict, 'Add some transactions to compare your financial periods.');
    });

    test('11. one-sided history (only one period has data) is marked insufficient', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 40000, type: 'income', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.currentPeriodHasData, isTrue);
      expect(result.comparisonPeriodHasData, isFalse);
      expect(result.hasSufficientData, isFalse);
      expect(result.income.direction, ComparisonDirection.insufficientData);
      expect(result.verdict, "There's not enough historical data to make a meaningful comparison.");
    });
  });

  group('12-14. Category comparison', () {
    test('12. category comparison reflects real per-category totals for each period', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 8200, type: 'expense', category: 'Food', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 5900, type: 'expense', category: 'Food', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      final food = result.categoryChanges.firstWhere((c) => c.categoryId == 'Food');
      expect(food.change.current, 5900);
      expect(food.change.previous, 8200);
    });

    test('13. a category spending increase is classified increased, never "worsened"', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 3200, type: 'expense', category: 'Shopping', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 7100, type: 'expense', category: 'Shopping', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      final shopping = result.categoryChanges.firstWhere((c) => c.categoryId == 'Shopping');
      expect(shopping.direction, CategoryChangeDirection.increased);
    });

    test('14. a category spending decrease is classified decreased', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 2400, type: 'expense', category: 'Transport', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 2100, type: 'expense', category: 'Transport', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      final transport = result.categoryChanges.firstWhere((c) => c.categoryId == 'Transport');
      expect(transport.direction, CategoryChangeDirection.decreased);
    });

    test('category changes are sorted by largest absolute movement first', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 100, type: 'expense', category: 'Small', date: DateTime(2026, 7, 5)),
          _tx(id: 'e2', amount: 500, type: 'expense', category: 'Small', date: DateTime(2026, 8, 5)),
          _tx(id: 'e3', amount: 1000, type: 'expense', category: 'Big', date: DateTime(2026, 7, 5)),
          _tx(id: 'e4', amount: 6000, type: 'expense', category: 'Big', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.categoryChanges.first.categoryId, 'Big');
    });
  });

  group('15-18. Period presets', () {
    test('15. custom month vs custom month (August 2026 vs May 2026)', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'i2', amount: 45000, type: 'income', date: DateTime(2026, 5, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('May 2026', 2026, 5),
      );
      expect(result.currentPeriod.label, 'August 2026');
      expect(result.comparisonPeriod.label, 'May 2026');
      expect(result.income.currentValue, 50000);
      expect(result.income.comparisonValue, 45000);
    });

    test('16. this month vs previous month', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'i2', amount: 45000, type: 'income', date: DateTime(2026, 7, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.income.currentValue, 50000);
      expect(result.income.comparisonValue, 45000);
    });

    test('17. last 3 months vs previous 3 months sums across each month correctly', () {
      final result = _calc(
        transactions: [
          _tx(id: 'i1', amount: 10000, type: 'income', date: DateTime(2026, 6, 5)),
          _tx(id: 'i2', amount: 10000, type: 'income', date: DateTime(2026, 7, 5)),
          _tx(id: 'i3', amount: 10000, type: 'income', date: DateTime(2026, 8, 5)),
          _tx(id: 'p1', amount: 5000, type: 'income', date: DateTime(2026, 3, 5)),
          _tx(id: 'p2', amount: 5000, type: 'income', date: DateTime(2026, 4, 5)),
          _tx(id: 'p3', amount: 5000, type: 'income', date: DateTime(2026, 5, 5)),
        ],
        current: _months('Jun-Aug 2026', 2026, 6, 3),
        comparison: _months('Mar-May 2026', 2026, 3, 3),
      );
      expect(result.income.currentValue, 30000);
      expect(result.income.comparisonValue, 15000);
    });

    test('18. last 6 months vs previous 6 months sums across each month correctly', () {
      final currentTx = List.generate(
        6,
        (i) => _tx(id: 'c$i', amount: 1000, type: 'income', date: DateTime(2026, 3 + i, 5)),
      );
      final previousTx = List.generate(
        6,
        (i) => _tx(id: 'p$i', amount: 500, type: 'income', date: DateTime(2025, 9 + i, 5)),
      );
      final result = _calc(
        transactions: [...currentTx, ...previousTx],
        current: _months('Mar-Aug 2026', 2026, 3, 6),
        comparison: _months('Sep 2025-Feb 2026', 2025, 9, 6),
      );
      expect(result.income.currentValue, 6000);
      expect(result.income.comparisonValue, 3000);
    });
  });

  group('19. Simulation safety — no transaction mutation', () {
    test('calculate() never mutates its input transaction/budget lists', () {
      final transactions = [
        _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 5)),
        _tx(id: 'i2', amount: 45000, type: 'income', date: DateTime(2026, 7, 5)),
      ];
      final budgets = [_budget('b1', month: 'August', year: 2026, allocated: 10000, spent: 5000)];
      final transactionsBefore = List.of(transactions);
      final budgetsBefore = List.of(budgets);

      ComparePeriodsCalculator.calculate(
        transactions: transactions,
        wallets: [_wallet('w1')],
        budgets: budgets,
        currentPeriod: _month('August 2026', 2026, 8),
        comparisonPeriod: _month('July 2026', 2026, 7),
      );

      expect(transactions, transactionsBefore);
      expect(budgets, budgetsBefore);
    });
  });

  group('Budget comparison', () {
    test('is null when neither period has any real stored budget', () {
      final result = _calc(
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.budgetComparison, isNull);
    });

    test('reuses BudgetCalculator.summarize for each period, never a duplicate formula', () {
      final result = _calc(
        budgets: [
          _budget('b1', month: 'August', year: 2026, allocated: 10000, spent: 8000),
          _budget('b2', month: 'July', year: 2026, allocated: 10000, spent: 5000),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.budgetComparison, isNotNull);
      expect(result.budgetComparison!.currentSummary.totalSpent, 8000);
      expect(result.budgetComparison!.comparisonSummary.totalSpent, 5000);
    });
  });

  group('24. No fabricated historical data', () {
    test('a category with real data only in one period never fabricates a value for the other', () {
      final result = _calc(
        transactions: [
          _tx(id: 'e1', amount: 3000, type: 'expense', category: 'Travel', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      final travel = result.categoryChanges.firstWhere((c) => c.categoryId == 'Travel');
      expect(travel.change.previous, 0); // real zero, not fabricated
      expect(travel.change.current, 3000);
    });

    test('transfers are never counted as income or expense in the comparison', () {
      final result = _calc(
        transactions: [
          _tx(id: 't1', amount: 20000, type: 'transfer', date: DateTime(2026, 8, 5)),
        ],
        current: _month('August 2026', 2026, 8),
        comparison: _month('July 2026', 2026, 7),
      );
      expect(result.income.currentValue, 0);
      expect(result.expense.currentValue, 0);
    });
  });
}
