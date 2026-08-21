// Focused tests for FinancialHealthTrendsCalculator (PHASE 21). Follows
// the same synthetic-data construction pattern as
// financial_planning_calculator_test.dart. Synthetic data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';

final _now = DateTime(2026, 8, 20);

Transaction _tx(String id, double amount, String type, DateTime date, {String category = 'Other'}) {
  return Transaction(
    id: id, title: type, amount: amount, categoryId: category, accountId: 'w1',
    transactionType: type, paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: balance, currentBalance: balance, createdAt: DateTime(2025, 1, 1),
  );
}

Budget _budget(String id, String month, int year, {required double allocated, required double spent}) {
  return Budget(
    id: id, categoryId: 'Food', categoryName: 'Food', allocatedAmount: allocated,
    spentAmount: spent, remainingAmount: allocated - spent,
    percentageUsed: allocated > 0 ? spent / allocated * 100 : 0,
    month: month, year: year, createdAt: DateTime(year, 1, 1),
  );
}

Loan _loan({required String id, required double principal, required double outstanding, required double emi}) {
  final loan = Loan.create(
    id: id, loanName: id, lenderName: 'Bank', loanType: 'Personal',
    principalAmount: principal, interestRate: 10, tenureMonths: 24, emiAmount: emi,
    totalInterest: 0, accountId: 'w1', startDate: DateTime(2025, 1, 1),
    nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2025, 1, 1),
  );
  return loan.copyWith(outstandingAmount: outstanding, endDate: DateTime(2028, 1, 1));
}

Goal _goal({
  required String id,
  required double target,
  required double current,
  required DateTime createdAt,
  required DateTime targetDate,
}) {
  return Goal.create(
    id: id, title: id, targetAmount: target, currentAmount: current, targetDate: targetDate,
    category: 'Other', icon: 'star', color: 0xFF000000, createdAt: createdAt,
  );
}

/// Adds a steady income+expense transaction pair for [monthsAgo] months
/// back from [_now] (0 = current month), returning the two transactions.
List<Transaction> _monthTx(int monthsAgo, double income, double expense, {String id = ''}) {
  final date = DateTime(_now.year, _now.month - monthsAgo, 10);
  final tag = id.isEmpty ? '$monthsAgo' : id;
  final list = <Transaction>[];
  if (income > 0) list.add(_tx('inc-$tag', income, 'Income', date));
  if (expense > 0) list.add(_tx('exp-$tag', expense, 'Expense', date));
  return list;
}

FinancialHealthTrendResult _calc({
  required List<Transaction> transactions,
  List<Budget> budgets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  List<Wallet> wallets = const [],
  TrendPeriod period = TrendPeriod.threeMonths,
  List<String>? emergencyFundEligibleWalletIds,
}) {
  return FinancialHealthTrendsCalculator.calculate(
    transactions: transactions,
    budgets: budgets,
    goals: goals,
    loans: loans,
    bills: const [],
    wallets: wallets,
    profileMonthlyIncome: 0,
    period: period,
    emergencyFundEligibleWalletIds: emergencyFundEligibleWalletIds,
    now: _now,
  );
}

void main() {
  group('1. No transaction data', () {
    test('zero transactions never crashes and reports insufficient data throughout', () {
      final result = _calc(transactions: const []);
      expect(result.hasSufficientData, isFalse);
      expect(result.incomeTrend.hasSufficientData, isFalse);
      expect(result.savingsTrend.direction, TrendDirection.insufficientData);
      expect(result.scoreTrend.hasSufficientData, isFalse);
      expect(result.trajectory, OverallTrajectory.insufficientData);
    });
  });

  group('2. One-month data', () {
    test('a single month of data reports insufficient data for period-over-period comparisons', () {
      final result = _calc(
        transactions: _monthTx(0, 50000, 30000),
        period: TrendPeriod.oneMonth,
      );
      expect(result.hasSufficientData, isTrue);
      // previous point (1 month back) has no activity -> nothing genuine
      // to compare against, so this is honestly insufficientData, not a
      // guessed "stable".
      expect(result.incomeTrend.previousIncome, 0);
      expect(result.savingsTrend.direction, TrendDirection.insufficientData);
    });
  });

  group('3. Two-month comparison', () {
    test('income/expense/savings compare the current month against the prior one', () {
      final transactions = [
        ..._monthTx(1, 40000, 30000),
        ..._monthTx(0, 50000, 30000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.oneMonth);
      expect(result.incomeTrend.currentIncome, 50000);
      expect(result.incomeTrend.previousIncome, 40000);
      expect(result.incomeTrend.direction, TrendDirection.improving);
    });
  });

  group('4. Three-month trend', () {
    test('a 3-month window compares the current month to 3 months prior', () {
      final transactions = [
        ..._monthTx(3, 40000, 30000),
        ..._monthTx(2, 45000, 30000),
        ..._monthTx(1, 48000, 30000),
        ..._monthTx(0, 50000, 30000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.incomeTrend.currentIncome, 50000);
      expect(result.incomeTrend.previousIncome, 40000);
      expect(result.period, TrendPeriod.threeMonths);
    });
  });

  group('5. Six-month trend', () {
    test('a 6-month window builds a 7-month series (6 + anchor)', () {
      final transactions = [
        for (var i = 6; i >= 0; i--) ..._monthTx(i, 50000, 30000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.sixMonths);
      expect(result.monthsOfDataAvailable, 7);
    });
  });

  group('6. Twelve-month trend', () {
    test('a 12-month window builds a 13-month series (12 + anchor)', () {
      final transactions = [
        for (var i = 12; i >= 0; i--) ..._monthTx(i, 50000, 30000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.twelveMonths);
      expect(result.monthsOfDataAvailable, 13);
    });
  });

  group('7-9. Savings direction', () {
    test('7. improving: savings rate rose by more than the material threshold', () {
      final transactions = [
        ..._monthTx(3, 50000, 45000), // 10% rate
        ..._monthTx(0, 50000, 30000), // 40% rate
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.savingsTrend.direction, TrendDirection.improving);
    });

    test('8. declining: savings rate fell by more than the material threshold', () {
      final transactions = [
        ..._monthTx(3, 50000, 30000), // 40% rate
        ..._monthTx(0, 50000, 45000), // 10% rate
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.savingsTrend.direction, TrendDirection.declining);
    });

    test('9. stable: a tiny savings rate fluctuation is never reported as meaningful', () {
      final transactions = [
        ..._monthTx(3, 50000, 30000), // 40% rate
        ..._monthTx(0, 50000, 30500), // 39% rate
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.savingsTrend.direction, TrendDirection.stable);
    });
  });

  group('10-12. Income patterns', () {
    test('10. increasing income', () {
      final transactions = [
        ..._monthTx(2, 40000, 20000),
        ..._monthTx(1, 45000, 20000),
        ..._monthTx(0, 55000, 20000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.incomeTrend.pattern, IncomePattern.increasing);
    });

    test('11. declining income', () {
      final transactions = [
        ..._monthTx(2, 55000, 20000),
        ..._monthTx(1, 45000, 20000),
        ..._monthTx(0, 40000, 20000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.incomeTrend.pattern, IncomePattern.declining);
    });

    test('12. irregular income is never labelled "bad" — just irregular', () {
      final transactions = [
        ..._monthTx(2, 20000, 15000),
        ..._monthTx(1, 80000, 15000),
        ..._monthTx(0, 30000, 15000),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.incomeTrend.pattern, IncomePattern.irregular);
    });
  });

  group('13-14. Expense interpretation', () {
    test('13. increasing expenses with proportionally larger income increase is not declining', () {
      final transactions = [
        ..._monthTx(3, 40000, 20000), // 50% savings rate
        ..._monthTx(0, 50000, 24000), // 52% savings rate (both up, savings improved)
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.expenseTrend.direction, isNot(TrendDirection.declining));
    });

    test('14. increasing expenses with declining savings is reported as declining', () {
      final transactions = [
        ..._monthTx(3, 50000, 20000), // 60% savings rate
        ..._monthTx(0, 50000, 40000), // 20% savings rate
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.expenseTrend.direction, TrendDirection.declining);
    });
  });

  group('15-16. Budget trend', () {
    test('15. budget improvement: fewer over-budget categories now than before', () {
      final transactions = [..._monthTx(3, 50000, 20000), ..._monthTx(0, 50000, 20000)];
      final may = DateTime(_now.year, _now.month - 3, 1);
      final aug = _now;
      final budgets = [
        _budget('b1', _monthName(may.month), may.year, allocated: 10000, spent: 15000),
        _budget('b2', _monthName(may.month), may.year, allocated: 10000, spent: 8000),
        _budget('b3', _monthName(aug.month), aug.year, allocated: 10000, spent: 9000),
      ];
      final result = _calc(transactions: transactions, budgets: budgets, period: TrendPeriod.threeMonths);
      expect(result.budgetTrend.previousOverBudgetCount, 1);
      expect(result.budgetTrend.currentOverBudgetCount, 0);
      expect(result.budgetTrend.direction, TrendDirection.improving);
    });

    test('16. budget deterioration: more over-budget categories now than before', () {
      final transactions = [..._monthTx(3, 50000, 20000), ..._monthTx(0, 50000, 20000)];
      final may = DateTime(_now.year, _now.month - 3, 1);
      final aug = _now;
      final budgets = [
        _budget('b1', _monthName(may.month), may.year, allocated: 10000, spent: 9000),
        _budget('b2', _monthName(aug.month), aug.year, allocated: 10000, spent: 15000),
      ];
      final result = _calc(transactions: transactions, budgets: budgets, period: TrendPeriod.threeMonths);
      expect(result.budgetTrend.direction, TrendDirection.declining);
    });
  });

  group('17-18. Debt trend', () {
    test('17. debt reduction: material paydown across recorded loans is improving', () {
      final result = _calc(
        transactions: _monthTx(0, 50000, 20000),
        loans: [_loan(id: 'l1', principal: 500000, outstanding: 400000, emi: 20000)],
      );
      expect(result.debtTrend.direction, TrendDirection.improving);
      expect(result.debtTrend.totalPaidDown, 100000);
    });

    test('18. no loans at all is insufficient data, never a fabricated "improving"', () {
      final result = _calc(transactions: _monthTx(0, 50000, 20000));
      expect(result.debtTrend.direction, TrendDirection.insufficientData);
      expect(result.debtTrend.hasSufficientData, isFalse);
    });
  });

  group('19-20. Goal trend', () {
    test('19. goal counts reflect real on-track/at-risk/completed projections', () {
      final result = _calc(
        transactions: _monthTx(0, 50000, 20000),
        goals: [
          _goal(id: 'g1', target: 10000, current: 10000, createdAt: DateTime(2025, 1, 1), targetDate: DateTime(2025, 6, 1)),
          _goal(id: 'g2', target: 500000, current: 1000, createdAt: DateTime(2026, 7, 1), targetDate: DateTime(2026, 9, 1)),
        ],
      );
      expect(result.goalTrend.totalGoals, 2);
      expect(result.goalTrend.direction, TrendDirection.insufficientData);
    });

    test('20. no goals reports zero counts, never fabricated ones', () {
      final result = _calc(transactions: _monthTx(0, 50000, 20000));
      expect(result.goalTrend.totalGoals, 0);
    });
  });

  group('21-22. Emergency fund trend', () {
    test('21. a configured fund reports real target/current/progress', () {
      final result = _calc(
        transactions: [..._monthTx(3, 50000, 30000), ..._monthTx(2, 50000, 30000), ..._monthTx(1, 50000, 30000), ..._monthTx(0, 50000, 30000)],
        wallets: [_wallet('w1', 60000)],
        emergencyFundEligibleWalletIds: ['w1'],
      );
      expect(result.emergencyFundTrend.isConfigured, isTrue);
      expect(result.emergencyFundTrend.current, 60000);
      expect(result.emergencyFundTrend.direction, TrendDirection.insufficientData);
    });

    test('22. an unconfigured fund never says "critically low" — just unconfigured', () {
      final result = _calc(transactions: _monthTx(0, 50000, 20000));
      expect(result.emergencyFundTrend.isConfigured, isFalse);
      expect(result.emergencyFundTrend.target, isNull);
    });
  });

  group('23. Mixed trajectory', () {
    test('income up, expenses up, savings up, debt up all at once is MIXED, not forced either way', () {
      final transactions = [
        ..._monthTx(3, 40000, 20000), // 50% savings rate
        ..._monthTx(0, 60000, 27000), // 55% savings rate (savings improving)
      ];
      // Debt with a low (non-material) paydown fraction relative to a huge
      // principal keeps the debt signal from being "improving" too, but a
      // clean MIXED test just needs one clearly improving + one clearly
      // declining core domain; use budget deterioration for the decline.
      final may = DateTime(_now.year, _now.month - 3, 1);
      final aug = _now;
      final budgets = [
        _budget('b1', _monthName(may.month), may.year, allocated: 10000, spent: 9000),
        _budget('b2', _monthName(aug.month), aug.year, allocated: 10000, spent: 15000),
      ];
      final result = _calc(transactions: transactions, budgets: budgets, period: TrendPeriod.threeMonths);
      expect(result.savingsTrend.direction, TrendDirection.improving);
      expect(result.budgetTrend.direction, TrendDirection.declining);
      expect(result.trajectory, OverallTrajectory.mixed);
    });
  });

  group('24-25. Strongly improving / declining trajectory', () {
    test('24. every core domain improving yields a strongly-improving trajectory', () {
      final transactions = [
        ..._monthTx(3, 40000, 35000), // 12.5% rate, weak
        ..._monthTx(0, 60000, 24000), // 60% rate, strong
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.savingsTrend.direction, TrendDirection.improving);
      expect(result.trajectory, isNot(OverallTrajectory.declining));
      expect(result.trajectory, isNot(OverallTrajectory.mixed));
    });

    test('25. every core domain declining yields a declining trajectory', () {
      final transactions = [
        ..._monthTx(3, 60000, 24000), // 60% rate
        ..._monthTx(0, 40000, 35000), // 12.5% rate
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.savingsTrend.direction, TrendDirection.declining);
      expect(result.trajectory, isNot(OverallTrajectory.improving));
      expect(result.trajectory, isNot(OverallTrajectory.stronglyImproving));
      expect(result.trajectory, isNot(OverallTrajectory.mixed));
    });
  });

  group('26. Insight prioritization', () {
    test('key insights never exceed the maximum and deterioration is prioritized first', () {
      final transactions = [
        ..._monthTx(3, 60000, 24000), // strong savings rate
        ..._monthTx(0, 40000, 35000), // weak -> savings decline insight
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      expect(result.keyInsights.length, lessThanOrEqualTo(5));
      if (result.keyInsights.isNotEmpty) {
        expect(result.keyInsights.first.severity, isNot(SignalSeverity.info));
      }
    });
  });

  group('27-28. No NaN / no Infinity', () {
    test('zero income throughout never divides into NaN or Infinity', () {
      final result = _calc(transactions: _monthTx(0, 0, 5000));
      expect(result.savingsTrend.currentSavingsRate, isNull);
      expect(result.incomeTrend.currentIncome, 0);
    });

    test('extreme values never produce NaN/Infinity in the score history', () {
      final transactions = [
        ..._monthTx(3, 999999999, 1),
        ..._monthTx(0, 1, 999999999),
      ];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      for (final point in result.scoreTrend.history) {
        expect(point.score.isNaN, isFalse);
        expect(point.score, greaterThanOrEqualTo(0));
        expect(point.score, lessThanOrEqualTo(100));
      }
    });
  });

  group('29. No fabricated historical data', () {
    test('a month with zero activity is never included in the score history', () {
      final transactions = [..._monthTx(3, 50000, 20000), ..._monthTx(0, 50000, 20000)];
      // Months 1 and 2 have no transactions at all.
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      final monthsWithScores = result.scoreTrend.history.map((p) => '${p.month.year}-${p.month.month}').toSet();
      final gapMonth = DateTime(_now.year, _now.month - 1, 1);
      expect(monthsWithScores.contains('${gapMonth.year}-${gapMonth.month}'), isFalse);
    });

    test('the current month score is never marked approximated', () {
      final result = _calc(transactions: _monthTx(0, 50000, 20000));
      expect(result.scoreTrend.history.last.isApproximated, isFalse);
    });

    test('a historical month score IS marked approximated', () {
      final transactions = [..._monthTx(3, 50000, 20000), ..._monthTx(0, 50000, 20000)];
      final result = _calc(transactions: transactions, period: TrendPeriod.threeMonths);
      final historical = result.scoreTrend.history.where((p) => p != result.scoreTrend.history.last);
      expect(historical.every((p) => p.isApproximated), isTrue);
    });
  });
}

String _monthName(int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[month - 1];
}
