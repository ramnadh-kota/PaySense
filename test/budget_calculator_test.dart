// Focused tests for BudgetCalculator — the pure, centralized status/sorting/
// aggregation/history/comparison logic for Advanced Budgeting 2.0. All data
// is synthetic, constructed via Budget.create(...).updateMetrics(...) (the
// same path production code uses), so BudgetRepository's spentAmount
// matching itself is intentionally NOT re-tested here (see
// budget_repository_matching_test.dart for category/month-matching
// coverage, items 19-21).
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/utils/budget_calculator.dart';

Budget _budget({
  String id = 'b1',
  String category = 'Groceries',
  required double allocated,
  required double spent,
  String month = 'August',
  int year = 2026,
}) {
  final created = Budget.create(
    id: id,
    categoryId: category,
    categoryName: category,
    allocatedAmount: allocated,
    month: month,
    year: year,
    createdAt: DateTime(year, 1),
  );
  return created.updateMetrics(spentAmount: spent);
}

void main() {
  // 1. Budgeted amount
  test('1. budgeted amount is surfaced unchanged', () {
    final budget = _budget(allocated: 10000, spent: 3000);
    expect(budget.allocatedAmount, 10000.0);
  });

  // 2. Spent amount
  test('2. spent amount is surfaced unchanged', () {
    final budget = _budget(allocated: 10000, spent: 3000);
    expect(budget.spentAmount, 3000.0);
  });

  // 3. Remaining amount
  test('3. remaining amount = budgeted - spent', () {
    final budget = _budget(allocated: 10000, spent: 3000);
    expect(budget.remainingAmount, 7000.0);
  });

  // 4. Under-budget state
  test('4. under 80% is classified UNDER_BUDGET', () {
    final status = BudgetCalculator.statusFor(
      allocatedAmount: 10000,
      spentAmount: 5000,
    );
    expect(status, BudgetStatus.underBudget);
  });

  // 5. Near-limit state
  test('5. between 80% and 100% is classified NEAR_LIMIT', () {
    final status = BudgetCalculator.statusFor(
      allocatedAmount: 10000,
      spentAmount: 9000,
    );
    expect(status, BudgetStatus.nearLimit);
  });

  // 6. Exactly 100%
  test('6. exactly 100% is classified NEAR_LIMIT (top of that band)', () {
    final status = BudgetCalculator.statusFor(
      allocatedAmount: 10000,
      spentAmount: 10000,
    );
    expect(status, BudgetStatus.nearLimit);
  });

  // 7. Over-budget state
  test('7. above 100% is classified OVER_BUDGET', () {
    final status = BudgetCalculator.statusFor(
      allocatedAmount: 10000,
      spentAmount: 12000,
    );
    expect(status, BudgetStatus.overBudget);
  });

  // 8. Negative remaining amount
  test('8. remaining goes negative when overspent, never floored at 0', () {
    final budget = _budget(allocated: 10000, spent: 12000);
    expect(budget.remainingAmount, -2000.0);
  });

  // 9. Percentage above 100%
  test('9. percentageUsed is allowed to exceed 100', () {
    final budget = _budget(allocated: 10000, spent: 12000);
    expect(budget.percentageUsed, 120.0);
  });

  // 10. Zero budget handling
  test('10. allocatedAmount of 0 is handled safely, never divides by zero', () {
    final zeroNoSpend = _budget(allocated: 0, spent: 0);
    expect(zeroNoSpend.percentageUsed, 0.0);
    expect(
      BudgetCalculator.statusFor(allocatedAmount: 0, spentAmount: 0),
      BudgetStatus.underBudget,
    );

    final zeroWithSpend = _budget(allocated: 0, spent: 500);
    expect(zeroWithSpend.percentageUsed, 0.0);
    expect(
      BudgetCalculator.statusFor(allocatedAmount: 0, spentAmount: 500),
      BudgetStatus.overBudget,
    );
  });

  // 11. Multiple categories
  test('11. multiple distinct categories are all preserved through sorting', () {
    final budgets = [
      _budget(id: 'b1', category: 'Groceries', allocated: 5000, spent: 1000),
      _budget(id: 'b2', category: 'Travel', allocated: 8000, spent: 9000),
      _budget(id: 'b3', category: 'Dining', allocated: 3000, spent: 2700),
    ];
    final sorted = BudgetCalculator.sortByPerformance(budgets);
    expect(sorted.map((b) => b.categoryName).toSet(), {
      'Groceries',
      'Travel',
      'Dining',
    });
  });

  // 12. Over-budget sorting
  test('12. OVER_BUDGET categories are sorted first', () {
    final budgets = [
      _budget(id: 'b1', category: 'Under', allocated: 5000, spent: 1000),
      _budget(id: 'b2', category: 'Near', allocated: 5000, spent: 4500),
      _budget(id: 'b3', category: 'Over', allocated: 5000, spent: 6000),
    ];
    final sorted = BudgetCalculator.sortByPerformance(budgets);
    expect(sorted.first.categoryName, 'Over');
  });

  // 13. Near-limit sorting
  test('13. NEAR_LIMIT categories sort after OVER_BUDGET, before UNDER_BUDGET', () {
    final budgets = [
      _budget(id: 'b1', category: 'Under', allocated: 5000, spent: 1000),
      _budget(id: 'b2', category: 'Near', allocated: 5000, spent: 4500),
      _budget(id: 'b3', category: 'Over', allocated: 5000, spent: 6000),
    ];
    final sorted = BudgetCalculator.sortByPerformance(budgets);
    expect(
      sorted.map((b) => b.categoryName).toList(),
      ['Over', 'Near', 'Under'],
    );
  });

  // 14. Highest percentage sorting
  test('14. within the same status, highest percentage used sorts first', () {
    final budgets = [
      _budget(id: 'b1', category: 'OverA', allocated: 5000, spent: 6000), // 120%
      _budget(id: 'b2', category: 'OverB', allocated: 5000, spent: 9000), // 180%
      _budget(id: 'b3', category: 'OverC', allocated: 5000, spent: 5500), // 110%
    ];
    final sorted = BudgetCalculator.sortByPerformance(budgets);
    expect(
      sorted.map((b) => b.categoryName).toList(),
      ['OverB', 'OverA', 'OverC'],
    );
  });

  // 15. Overall monthly summary
  test('15. monthly summary matches the spec example '
      '(40000 budget / 31500 spent / 8500 remaining / 78.75% used)', () {
    final budgets = [
      _budget(id: 'b1', category: 'A', allocated: 25000, spent: 20000),
      _budget(id: 'b2', category: 'B', allocated: 15000, spent: 11500),
    ];
    final summary = BudgetCalculator.summarize(budgets);
    expect(summary.totalBudget, 40000.0);
    expect(summary.totalSpent, 31500.0);
    expect(summary.totalRemaining, 8500.0);
    expect(summary.overallPercentageUsed, closeTo(78.75, 0.001));
  });

  // 16. No budgets
  test('16. empty budget list produces safe, zeroed aggregates', () {
    final summary = BudgetCalculator.summarize(const []);
    expect(summary.totalBudget, 0.0);
    expect(summary.totalSpent, 0.0);
    expect(summary.totalRemaining, 0.0);
    expect(summary.overallPercentageUsed, 0.0);

    final overspend = BudgetCalculator.overspendSummary(const []);
    expect(overspend.hasOverspend, isFalse);
    expect(BudgetCalculator.nearLimitCount(const []), 0);
    expect(BudgetCalculator.sortByPerformance(const []), isEmpty);
    expect(BudgetCalculator.history(const []), isEmpty);
  });

  // 17. No expenses
  test('17. a budget with zero spend is fully UNDER_BUDGET with full remaining', () {
    final budget = _budget(allocated: 5000, spent: 0);
    expect(budget.remainingAmount, 5000.0);
    expect(budget.percentageUsed, 0.0);
    expect(BudgetCalculator.statusForBudget(budget), BudgetStatus.underBudget);
  });

  // 18. Multiple budgets
  test('18. overspend and near-limit counts aggregate correctly across many budgets', () {
    final budgets = [
      _budget(id: 'b1', category: 'A', allocated: 5000, spent: 6000), // over by 1000
      _budget(id: 'b2', category: 'B', allocated: 4000, spent: 4800), // over by 800
      _budget(id: 'b3', category: 'C', allocated: 3000, spent: 2850), // near limit
      _budget(id: 'b4', category: 'D', allocated: 2000, spent: 500), // under budget
    ];
    final overspend = BudgetCalculator.overspendSummary(budgets);
    expect(overspend.categoryCount, 2);
    expect(overspend.totalOverspend, 1800.0);
    expect(BudgetCalculator.nearLimitCount(budgets), 1);
  });

  // 19. Category matching (spentAmount matching itself is owned by
  // BudgetRepository — see budget_repository_matching_test.dart). Here we
  // verify the calculator only classifies/sorts by each budget's own
  // already-computed fields and never cross-contaminates between budgets
  // that share the same allocated/spent shape but different categories.
  test('19. status classification is per-budget and category-independent', () {
    final groceries = _budget(
      id: 'b1',
      category: 'Groceries',
      allocated: 5000,
      spent: 6000,
    );
    final travel = _budget(
      id: 'b2',
      category: 'Travel',
      allocated: 5000,
      spent: 1000,
    );
    expect(
      BudgetCalculator.statusForBudget(groceries),
      BudgetStatus.overBudget,
    );
    expect(
      BudgetCalculator.statusForBudget(travel),
      BudgetStatus.underBudget,
    );
  });

  // 20. Current month filtering (transaction-level filtering is owned by
  // BudgetRepository — see budget_repository_matching_test.dart). Here we
  // verify BudgetCalculator.history correctly separates budgets stamped
  // with different months/years into distinct groups rather than merging
  // them, which is the calculator-level half of "current month" awareness.
  test('20. history groups budgets by their own stamped month/year, not merged', () {
    final budgets = [
      _budget(id: 'b1', category: 'A', allocated: 5000, spent: 1000, month: 'August', year: 2026),
      _budget(id: 'b2', category: 'A', allocated: 5000, spent: 2000, month: 'July', year: 2026),
    ];
    final history = BudgetCalculator.history(budgets);
    expect(history, hasLength(2));
    expect(history.map((g) => g.month).toSet(), {'August', 'July'});
  });

  // 21. Month boundary (exact transaction-date boundary matching is owned
  // by BudgetRepository — see budget_repository_matching_test.dart). Here
  // we verify history() orders adjacent calendar months correctly across a
  // year boundary (December -> January), the calculator-level analogue.
  test('21. history orders across a year boundary correctly (most recent first)', () {
    final budgets = [
      _budget(id: 'b1', category: 'A', allocated: 5000, spent: 1000, month: 'January', year: 2027),
      _budget(id: 'b2', category: 'A', allocated: 5000, spent: 2000, month: 'December', year: 2026),
    ];
    final history = BudgetCalculator.history(budgets);
    expect(history.first.month, 'January');
    expect(history.first.year, 2027);
    expect(history.last.month, 'December');
    expect(history.last.year, 2026);
  });

  // 22. Previous-month comparison
  test('22. compareMonths computes budget and spend deltas', () {
    final current = [_budget(id: 'b1', allocated: 10000, spent: 8000)];
    final previous = [_budget(id: 'b2', allocated: 8000, spent: 4000)];
    final comparison = BudgetCalculator.compareMonths(
      currentMonthBudgets: current,
      previousMonthBudgets: previous,
    );
    expect(comparison.budgetChange.percentage, closeTo(25.0, 0.001));
    expect(comparison.spentChange.percentage, closeTo(100.0, 0.001));
  });

  // 23. Previous value zero
  test('23. a zero previous value is reported as "new", not a percentage', () {
    final current = [_budget(id: 'b1', allocated: 5000, spent: 1000)];
    final previous = <Budget>[];
    final comparison = BudgetCalculator.compareMonths(
      currentMonthBudgets: current,
      previousMonthBudgets: previous,
    );
    expect(comparison.budgetChange.isNew, isTrue);
    expect(comparison.budgetChange.percentage, isNull);
  });

  // 24. No NaN
  test('24. no computation ever produces NaN, even at every zero edge case', () {
    final zeroZero = BudgetCalculator.summarize([
      _budget(allocated: 0, spent: 0),
    ]);
    expect(zeroZero.overallPercentageUsed.isNaN, isFalse);

    final change = BudgetChangeValue.compute(0, 0);
    expect(change.percentage, isNull);
    expect(change.isNew, isFalse);
  });

  // 25. No Infinity
  test('25. no computation ever produces Infinity, even dividing against a zero budget', () {
    final budget = _budget(allocated: 0, spent: 500);
    expect(budget.percentageUsed.isInfinite, isFalse);

    final summary = BudgetCalculator.summarize([budget]);
    expect(summary.overallPercentageUsed.isInfinite, isFalse);
  });
}
