import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/loan_provider.dart' show LoanSummary;
import 'package:paysense/shared/utils/financial_health_calculator.dart';
import 'package:paysense/shared/utils/monthly_review_calculator.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  required DateTime createdAt,
  String categoryId = 'General',
  String title = 'Test',
}) {
  return Transaction(
    id: id,
    title: title,
    amount: amount,
    categoryId: categoryId,
    accountId: 'Cash',
    transactionType: type,
    paymentMethod: '',
    note: '',
    createdAt: createdAt,
  );
}

LoanSummary _emptyLoanSummary() {
  return LoanSummary(
    totalLoans: 0,
    activeLoans: 0,
    closedLoans: 0,
    outstandingBalance: 0,
    totalEmiPerMonth: 0,
    totalInterest: 0,
    nextEmiLoanName: '',
    nextEmiAmount: 0,
    nextEmiDate: null,
  );
}

FinancialHealthResult _emptyFinancialHealth() {
  return FinancialHealthCalculator.calculate(
    transactions: const [],
    budgets: const [],
    goals: const [],
    loans: const [],
    bills: const [],
    wallets: const [],
    profileMonthlyIncome: 0,
  );
}

void main() {
  final august = DateTime(2026, 8, 15);

  MonthlyReviewResult calculate({
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
    List<Goal> goals = const [],
    List<Bill> bills = const [],
    LoanSummary? loanSummary,
    DateTime? targetMonth,
    DateTime? now,
  }) {
    return MonthlyReviewCalculator.calculate(
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      bills: bills,
      loanSummary: loanSummary ?? _emptyLoanSummary(),
      financialHealth: _emptyFinancialHealth(),
      targetMonth: targetMonth ?? august,
      now: now ?? august,
    );
  }

  test('computes monthly income, expenses, savings, and savings rate', () {
    final result = calculate(
      transactions: [
        _tx(id: 't1', amount: 60000, type: 'income', createdAt: august),
        _tx(id: 't2', amount: 40000, type: 'expense', createdAt: august),
      ],
    );

    expect(result.income, 60000);
    expect(result.expenses, 40000);
    expect(result.savings, 20000);
    expect(result.savingsRate, closeTo(33.33, 0.1));
    expect(result.hasSufficientData, isTrue);
  });

  test('handles zero income safely without dividing by zero', () {
    final result = calculate(
      transactions: [
        _tx(id: 't1', amount: 500, type: 'expense', createdAt: august),
      ],
    );

    expect(result.income, 0);
    expect(result.savingsRate, 0);
    expect(result.savings, -500);
  });

  test('empty month reports insufficient data with zeroed totals', () {
    final result = calculate(transactions: const []);
    expect(result.hasSufficientData, isFalse);
    expect(result.income, 0);
    expect(result.expenses, 0);
  });

  test('previous-month comparison computes percent change when data exists', () {
    final july = DateTime(2026, 7, 15);
    final result = calculate(
      transactions: [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: july),
        _tx(id: 't2', amount: 30000, type: 'expense', createdAt: july),
        _tx(id: 't3', amount: 55000, type: 'income', createdAt: august),
        _tx(id: 't4', amount: 24000, type: 'expense', createdAt: august),
      ],
    );

    expect(result.comparisons.income.hasData, isTrue);
    expect(result.comparisons.income.changePercent, closeTo(10, 0.1));
    expect(result.comparisons.expenses.hasData, isTrue);
    expect(result.comparisons.expenses.changePercent, closeTo(-20, 0.1));
  });

  test('reports insufficient historical data when the previous month is empty', () {
    final result = calculate(
      transactions: [
        _tx(id: 't1', amount: 1000, type: 'expense', createdAt: august),
      ],
    );
    expect(result.comparisons.income.hasData, isFalse);
    expect(result.comparisons.expenses.hasData, isFalse);
  });

  test('identifies the top spending category and largest transaction', () {
    final result = calculate(
      transactions: [
        _tx(id: 't1', amount: 3000, type: 'expense', categoryId: 'Dining', title: 'Dinner', createdAt: august),
        _tx(id: 't2', amount: 1850, type: 'expense', categoryId: 'Dining', title: 'Lunch', createdAt: august),
        _tx(id: 't3', amount: 1200, type: 'expense', categoryId: 'Utilities', title: 'Electricity', createdAt: august),
      ],
    );

    expect(result.topCategories, isNotEmpty);
    expect(result.topCategories.first.categoryId, 'Dining');
    expect(result.topCategories.first.amount, 4850);
    expect(result.largestTransaction, isNotNull);
    expect(result.largestTransaction!.title, 'Dinner');
    expect(result.largestTransaction!.amount, 3000);
  });

  test('budget status counts on-track/near-limit/exceeded for the reviewed month', () {
    final onTrack = Budget.create(
      id: 'b1',
      categoryId: 'food',
      categoryName: 'Food',
      allocatedAmount: 10000,
      month: 'August',
      year: 2026,
      createdAt: august,
    ).updateMetrics(spentAmount: 3000);
    final nearLimit = Budget.create(
      id: 'b2',
      categoryId: 'dining',
      categoryName: 'Dining',
      allocatedAmount: 5000,
      month: 'August',
      year: 2026,
      createdAt: august,
    ).updateMetrics(spentAmount: 4500);
    final exceeded = Budget.create(
      id: 'b3',
      categoryId: 'shopping',
      categoryName: 'Shopping',
      allocatedAmount: 2000,
      month: 'August',
      year: 2026,
      createdAt: august,
    ).updateMetrics(spentAmount: 2500);
    final otherMonth = Budget.create(
      id: 'b4',
      categoryId: 'travel',
      categoryName: 'Travel',
      allocatedAmount: 1000,
      month: 'July',
      year: 2026,
      createdAt: august,
    ).updateMetrics(spentAmount: 5000);

    final result = calculate(
      transactions: [_tx(id: 't1', amount: 100, type: 'income', createdAt: august)],
      budgets: [onTrack, nearLimit, exceeded, otherMonth],
    );

    expect(result.budgetStatus.hasBudgets, isTrue);
    expect(result.budgetStatus.onTrack, 1);
    expect(result.budgetStatus.nearLimit, 1);
    expect(result.budgetStatus.exceeded, 1);
  });

  test('no budgets is reported without penalizing or inventing one', () {
    final result = calculate(
      transactions: [_tx(id: 't1', amount: 100, type: 'income', createdAt: august)],
      budgets: const [],
    );
    expect(result.budgetStatus.hasBudgets, isFalse);
  });

  test('selects the most relevant goal and reports its progress', () {
    final goal = Goal.create(
      id: 'g1',
      title: 'Goa Trip',
      targetAmount: 40000,
      targetDate: august.add(const Duration(days: 30)),
      category: 'Travel',
      icon: 'flight',
      color: 0xFF000000,
      createdAt: august,
      currentAmount: 25000,
    );

    final result = calculate(
      transactions: [_tx(id: 't1', amount: 100, type: 'income', createdAt: august)],
      goals: [goal],
    );

    expect(result.relevantGoal, isNotNull);
    expect(result.relevantGoal!.title, 'Goa Trip');
    expect(result.relevantGoal!.progressPercentage, closeTo(62.5, 0.1));
  });

  test('bill status reports paid-this-month, overdue, and upcoming counts', () {
    final paidThisMonth = Bill.create(
      id: 'bill1',
      title: 'Internet',
      amount: 999,
      categoryId: 'Utilities',
      accountId: 'Cash',
      dueDate: august,
      createdAt: august,
    ).markPaid(august);
    final overdue = Bill.create(
      id: 'bill2',
      title: 'Water',
      amount: 400,
      categoryId: 'Utilities',
      accountId: 'Cash',
      dueDate: august.subtract(const Duration(days: 3)),
      createdAt: august,
    );
    final upcoming = Bill.create(
      id: 'bill3',
      title: 'Phone',
      amount: 599,
      categoryId: 'Utilities',
      accountId: 'Cash',
      dueDate: august.add(const Duration(days: 2)),
      createdAt: august,
    );

    final result = calculate(
      transactions: [_tx(id: 't1', amount: 100, type: 'income', createdAt: august)],
      bills: [paidThisMonth, overdue, upcoming],
      now: august,
    );

    expect(result.billStatus.hasBills, isTrue);
    expect(result.billStatus.paidThisMonth, 1);
    expect(result.billStatus.overdueNow, 1);
    expect(result.billStatus.upcomingCount, 1);
  });
}
