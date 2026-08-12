import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  required DateTime createdAt,
  String categoryId = 'General',
}) {
  return Transaction(
    id: id,
    title: 'Test $id',
    amount: amount,
    categoryId: categoryId,
    accountId: 'Cash',
    transactionType: type,
    paymentMethod: '',
    note: '',
    createdAt: createdAt,
  );
}

void main() {
  final now = DateTime(2026, 8, 12, 12, 0);

  test('financialHealthStatusForScore respects the documented boundaries', () {
    expect(financialHealthStatusForScore(0), FinancialHealthStatus.needsAttention);
    expect(financialHealthStatusForScore(39), FinancialHealthStatus.needsAttention);
    expect(financialHealthStatusForScore(40), FinancialHealthStatus.gettingStarted);
    expect(financialHealthStatusForScore(59), FinancialHealthStatus.gettingStarted);
    expect(financialHealthStatusForScore(60), FinancialHealthStatus.fair);
    expect(financialHealthStatusForScore(74), FinancialHealthStatus.fair);
    expect(financialHealthStatusForScore(75), FinancialHealthStatus.good);
    expect(financialHealthStatusForScore(89), FinancialHealthStatus.good);
    expect(financialHealthStatusForScore(90), FinancialHealthStatus.excellent);
    expect(financialHealthStatusForScore(100), FinancialHealthStatus.excellent);
  });

  test('empty/new-user state is handled safely with no fabricated data', () {
    final result = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );

    expect(result.hasSufficientData, isFalse);
    // No loans/budgets/goals/bills should not be unfairly penalized.
    expect(result.components.debt, 100);
    expect(result.components.payments, 100);
    expect(result.components.budget, 60);
    expect(result.components.goals, 60);
    expect(result.comparisons.weeklySpending.hasData, isFalse);
    expect(result.comparisons.monthlyIncome.hasData, isFalse);
  });

  test('savings component scales with the current month savings rate', () {
    final highSavings = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 100000, type: 'income', createdAt: now),
        _tx(id: 't2', amount: 30000, type: 'expense', createdAt: now),
      ],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    // Savings rate = 70% -> clamped to 100.
    expect(highSavings.components.savings, 100);

    final noSavings = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 30000, type: 'income', createdAt: now),
        _tx(id: 't2', amount: 30000, type: 'expense', createdAt: now),
      ],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    expect(noSavings.components.savings, 0);
  });

  test('budget component penalizes overspending and rewards staying under limit', () {
    final now2 = now;
    final underBudget = Budget.create(
      id: 'b1',
      categoryId: 'Food',
      categoryName: 'Food',
      allocatedAmount: 10000,
      month: 'August',
      year: 2026,
      createdAt: now2,
    ).updateMetrics(spentAmount: 3000); // 30% used

    final overBudget = Budget.create(
      id: 'b2',
      categoryId: 'Shopping',
      categoryName: 'Shopping',
      allocatedAmount: 10000,
      month: 'August',
      year: 2026,
      createdAt: now2,
    ).updateMetrics(spentAmount: 15000); // 150% used

    final goodResult = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: [underBudget],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    expect(goodResult.components.budget, 100);

    final badResult = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: [overBudget],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    expect(badResult.components.budget, lessThan(50));
  });

  test('goal component reflects aggregate progress toward targets', () {
    final goal = Goal.create(
      id: 'g1',
      title: 'Vacation',
      targetAmount: 10000,
      targetDate: now.add(const Duration(days: 90)),
      category: 'Travel',
      icon: 'flight',
      color: 0xFF000000,
      createdAt: now,
      currentAmount: 6200,
    );

    final result = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: const [],
      goals: [goal],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    expect(result.components.goals, 62);
  });

  test('debt component: no active loans scores perfectly, high EMI burden scores poorly', () {
    final noLoans = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 50000,
      now: now,
    );
    expect(noLoans.components.debt, 100);

    final heavyLoan = Loan.create(
      id: 'l1',
      loanName: 'Car Loan',
      lenderName: 'Bank',
      loanType: 'Auto',
      principalAmount: 500000,
      interestRate: 9,
      tenureMonths: 60,
      emiAmount: 35000, // 70% of a 50000 income
      totalInterest: 50000,
      accountId: 'Cash',
      startDate: now,
      nextDueDate: now.add(const Duration(days: 10)),
      createdAt: now,
    );
    final heavyBurden = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: now),
      ],
      budgets: const [],
      goals: const [],
      loans: [heavyLoan],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 50000,
      now: now,
    );
    expect(heavyBurden.components.debt, lessThan(30));
  });

  test('payments component: overdue bills reduce the score, none overdue is perfect', () {
    final overdueBill = Bill.create(
      id: 'bill1',
      title: 'Electricity',
      amount: 1000,
      categoryId: 'Utilities',
      accountId: 'Cash',
      dueDate: now.subtract(const Duration(days: 5)),
      createdAt: now,
    );

    final withOverdue = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: [overdueBill],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    expect(withOverdue.components.payments, lessThan(100));

    final noBills = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );
    expect(noBills.components.payments, 100);
  });

  test('a strong financial profile yields a high overall score and no warnings', () {
    final result = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 100000, type: 'income', createdAt: now),
        _tx(id: 't2', amount: 40000, type: 'expense', createdAt: now),
      ],
      budgets: [
        Budget.create(
          id: 'b1',
          categoryId: 'Food',
          categoryName: 'Food',
          allocatedAmount: 10000,
          month: 'August',
          year: 2026,
          createdAt: now,
        ).updateMetrics(spentAmount: 2000),
      ],
      goals: [
        Goal.create(
          id: 'g1',
          title: 'Emergency Fund',
          targetAmount: 10000,
          targetDate: now.add(const Duration(days: 90)),
          category: 'Savings',
          icon: 'shield',
          color: 0xFF000000,
          createdAt: now,
          currentAmount: 9000,
        ),
      ],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );

    expect(result.overallScore, greaterThanOrEqualTo(85));
    expect(
      result.insights.any((i) => i.type == FinancialInsightType.warning),
      isFalse,
    );
  });

  test('a poor financial profile yields a low overall score with warnings', () {
    final overdueBill = Bill.create(
      id: 'bill1',
      title: 'Rent',
      amount: 20000,
      categoryId: 'Housing',
      accountId: 'Cash',
      dueDate: now.subtract(const Duration(days: 10)),
      createdAt: now,
    );
    final heavyLoan = Loan.create(
      id: 'l1',
      loanName: 'Personal Loan',
      lenderName: 'Bank',
      loanType: 'Personal',
      principalAmount: 300000,
      interestRate: 14,
      tenureMonths: 24,
      emiAmount: 25000,
      totalInterest: 60000,
      accountId: 'Cash',
      startDate: now,
      nextDueDate: now.add(const Duration(days: 5)),
      createdAt: now,
    );

    final result = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 30000, type: 'income', createdAt: now),
        _tx(id: 't2', amount: 32000, type: 'expense', createdAt: now),
      ],
      budgets: [
        Budget.create(
          id: 'b1',
          categoryId: 'Shopping',
          categoryName: 'Shopping',
          allocatedAmount: 5000,
          month: 'August',
          year: 2026,
          createdAt: now,
        ).updateMetrics(spentAmount: 9000),
      ],
      goals: const [],
      loans: [heavyLoan],
      bills: [overdueBill],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );

    expect(result.overallScore, lessThan(45));
    expect(
      result.insights.any((i) => i.type == FinancialInsightType.warning),
      isTrue,
    );
  });

  test('insight generation surfaces overdue bills and budget-near-limit', () {
    final nearLimitBudget = Budget.create(
      id: 'b1',
      categoryId: 'Dining',
      categoryName: 'Dining',
      allocatedAmount: 10000,
      month: 'August',
      year: 2026,
      createdAt: now,
    ).updateMetrics(spentAmount: 8700); // 87% used

    final overdueBill = Bill.create(
      id: 'bill1',
      title: 'Internet',
      amount: 999,
      categoryId: 'Utilities',
      accountId: 'Cash',
      dueDate: now.subtract(const Duration(days: 2)),
      createdAt: now,
    );

    final result = FinancialHealthCalculator.calculate(
      transactions: const [],
      budgets: [nearLimitBudget],
      goals: const [],
      loans: const [],
      bills: [overdueBill],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );

    expect(
      result.insights.any((i) => i.message.contains('overdue bill')),
      isTrue,
    );
    expect(
      result.insights.any((i) => i.message.contains('Dining budget is 87%')),
      isTrue,
    );
  });

  test('insufficient historical data gracefully reports no comparison', () {
    final result = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 5000, type: 'expense', createdAt: now),
      ],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );

    expect(result.comparisons.weeklySpending.hasData, isFalse);
    expect(result.comparisons.weeklySpending.changePercent, isNull);
  });

  test('no-loan/no-budget/no-goal user is not penalized for missing data', () {
    final result = FinancialHealthCalculator.calculate(
      transactions: [
        _tx(id: 't1', amount: 40000, type: 'income', createdAt: now),
        _tx(id: 't2', amount: 30000, type: 'expense', createdAt: now),
      ],
      budgets: const [],
      goals: const [],
      loans: const [],
      bills: const [],
      wallets: const [],
      profileMonthlyIncome: 0,
      now: now,
    );

    expect(result.components.debt, 100);
    expect(result.components.payments, 100);
    expect(result.components.budget, 60);
    expect(result.components.goals, 60);
  });
}
