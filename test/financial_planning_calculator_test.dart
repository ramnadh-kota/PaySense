// Focused tests for FinancialPlanningCalculator — the pure, read-only
// Financial Planning 2.0 layer. All data is synthetic. AnalyticsSummary
// objects are constructed directly (rather than derived from realistic
// transaction histories) so each test can control exactly the monthly
// income/expense figures it needs, matching the same technique used
// elsewhere in this app's calculator tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';

final _now = DateTime(2026, 8, 20);

MonthlyTotal _mt(DateTime month, {double income = 0, double expense = 0}) {
  return MonthlyTotal(month: month, income: income, expense: expense);
}

AnalyticsSummary _analytics({
  required List<MonthlyTotal> monthlyTotals,
  double currentMonthIncome = 0,
  double currentMonthExpense = 0,
}) {
  final savingsRate = currentMonthIncome > 0
      ? ((currentMonthIncome - currentMonthExpense) / currentMonthIncome * 100)
      : 0.0;
  return AnalyticsSummary(
    monthlyTotals: monthlyTotals,
    categoryBreakdown: const [],
    currentMonthIncome: currentMonthIncome,
    currentMonthExpense: currentMonthExpense,
    savingsRate: savingsRate,
  );
}

/// A 4-month trailing window (May/Jun/Jul complete, Aug current) with a
/// steady ₹20,000/month expense baseline and ₹50,000/month income —
/// reused by several tests as a realistic, fully-populated scenario.
AnalyticsSummary _steadyAnalytics() {
  return _analytics(
    monthlyTotals: [
      _mt(DateTime(2026, 5), income: 50000, expense: 20000),
      _mt(DateTime(2026, 6), income: 50000, expense: 20000),
      _mt(DateTime(2026, 7), income: 50000, expense: 20000),
      _mt(DateTime(2026, 8), income: 50000, expense: 15000), // current, partial
    ],
    currentMonthIncome: 50000,
    currentMonthExpense: 15000,
  );
}

Wallet _wallet(String id, double balance, {bool archived = false}) {
  return Wallet(
    id: id,
    name: id,
    bankName: '',
    type: 'Bank',
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
    isArchived: archived,
  );
}

Goal _goal({
  required String id,
  required double target,
  required double current,
  required DateTime createdAt,
  required DateTime targetDate,
}) {
  return Goal.create(
    id: id,
    title: id,
    targetAmount: target,
    currentAmount: current,
    targetDate: targetDate,
    category: 'Other',
    icon: 'savings',
    color: 0xFF000000,
    createdAt: createdAt,
  );
}

Loan _loan({
  required String id,
  required double principal,
  required double outstanding,
  required double emi,
  required double interestRate,
  DateTime? startDate,
  DateTime? endDate,
}) {
  final loan = Loan.create(
    id: id,
    loanName: id,
    lenderName: 'Bank',
    loanType: 'Personal',
    principalAmount: principal,
    interestRate: interestRate,
    tenureMonths: 24,
    emiAmount: emi,
    totalInterest: 0,
    accountId: 'w1',
    startDate: startDate ?? DateTime(2026, 1, 1),
    nextDueDate: DateTime(2026, 9, 1),
    createdAt: DateTime(2026, 1, 1),
  );
  return loan.copyWith(
    outstandingAmount: outstanding,
    endDate: endDate ?? DateTime(2028, 1, 1),
  );
}

Bill _recurringBill(String id, double amount, {String frequency = 'Monthly'}) {
  return Bill.create(
    id: id,
    title: id,
    amount: amount,
    categoryId: 'Utilities',
    accountId: 'w1',
    dueDate: DateTime(2026, 9, 1),
    isRecurring: true,
    frequency: frequency,
    createdAt: DateTime(2026, 1, 1),
  );
}

RecurringTransaction _recurring(
  String id,
  double amount, {
  String frequency = 'Monthly',
  String type = 'expense',
  DateTime? nextDueDate,
}) {
  return RecurringTransaction.create(
    id: id,
    title: id,
    amount: amount,
    categoryId: 'Other',
    accountId: 'w1',
    transactionType: type,
    frequency: frequency,
    startDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ).copyWith(nextDueDate: nextDueDate ?? DateTime(2026, 9, 1));
}

void main() {
  group('1. Financial overview', () {
    test('net worth, income, expenses computed from wallets/analytics', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: [
          Transaction(
            id: 't1', title: 'Salary', amount: 50000, categoryId: 'Income',
            accountId: 'w1', transactionType: 'income', paymentMethod: 'bank',
            note: '', createdAt: _now,
          ),
        ],
        wallets: [_wallet('w1', 100000)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        now: _now,
      );

      expect(result.overview.netWorth, 100000);
      expect(result.overview.monthlyIncome, 50000);
      expect(result.overview.monthlyExpenses, 15000);
    });
  });

  group('2. Savings calculation', () {
    test('monthlySavings = income - expenses', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 10000)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        now: _now,
      );
      expect(result.overview.monthlySavings, 35000);
    });
  });

  group('3. Savings rate', () {
    test('savings rate percent computed correctly', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: const [],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        now: _now,
      );
      expect(result.overview.savingsRatePercent, closeTo(70.0, 0.01));
    });
  });

  group('4. Zero-income handling', () {
    test('no income produces null rate/percentages, never NaN, never a crash', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: const [],
        goals: const [],
        loans: [_loan(id: 'l1', principal: 100000, outstanding: 80000, emi: 5000, interestRate: 10)],
        bills: const [],
        recurringTransactions: const [],
        analytics: _analytics(monthlyTotals: [_mt(DateTime(2026, 8))]),
        now: _now,
      );
      expect(result.overview.savingsRatePercent, isNull);
      expect(result.overview.hasIncomeData, isFalse);
      expect(result.commitments.percentageOfIncome, isNull);
      expect(result.debt.emiToIncomePercent, isNull);
      expect(result.overview.monthlyIncome.isNaN, isFalse);
    });
  });

  group('5. Emergency fund target', () {
    test('target = average of 3 complete months x target months', () {
      final ef = FinancialPlanningCalculator.calculateEmergencyFund(
        analytics: _steadyAnalytics(),
        wallets: [_wallet('w1', 0)],
        eligibleWalletIds: ['w1'],
        now: _now,
        targetMonths: 6,
        monthlySavings: 35000,
        hasIncomeData: true,
      );
      // 3 complete months (May/Jun/Jul) all at 20000 expense -> baseline 20000.
      expect(ef.monthlyExpenseBaseline, 20000);
      expect(ef.target, 120000);
    });
  });

  group('6. Emergency fund remaining', () {
    test('remaining = target - current, never negative', () {
      final ef = FinancialPlanningCalculator.calculateEmergencyFund(
        analytics: _steadyAnalytics(),
        wallets: [_wallet('w1', 50000)],
        eligibleWalletIds: ['w1'],
        now: _now,
        targetMonths: 6,
        monthlySavings: 35000,
        hasIncomeData: true,
      );
      expect(ef.current, 50000);
      expect(ef.remaining, 70000);
    });

    test('fully funded emergency fund never shows a negative remaining', () {
      final ef = FinancialPlanningCalculator.calculateEmergencyFund(
        analytics: _steadyAnalytics(),
        wallets: [_wallet('w1', 500000)],
        eligibleWalletIds: ['w1'],
        now: _now,
        targetMonths: 6,
        monthlySavings: 35000,
        hasIncomeData: true,
      );
      expect(ef.remaining, 0);
      expect(ef.isFullyFunded, isTrue);
    });
  });

  group('7. Emergency fund completion estimate', () {
    test('estimated months/date computed from monthly contribution', () {
      final ef = FinancialPlanningCalculator.calculateEmergencyFund(
        analytics: _steadyAnalytics(),
        wallets: [_wallet('w1', 60000)],
        eligibleWalletIds: ['w1'],
        now: _now,
        targetMonths: 6,
        monthlySavings: 20000,
        hasIncomeData: true,
      );
      // target 120000, current 60000 -> remaining 60000 / 20000 = 3 months.
      expect(ef.remaining, 60000);
      expect(ef.estimatedMonths, 3);
      expect(ef.estimatedCompletionDate, DateTime(2026, 11, 20));
    });

    test('never shows a fabricated estimate with zero/no monthly contribution', () {
      final ef = FinancialPlanningCalculator.calculateEmergencyFund(
        analytics: _steadyAnalytics(),
        wallets: [_wallet('w1', 0)],
        eligibleWalletIds: ['w1'],
        now: _now,
        targetMonths: 6,
        monthlySavings: 0,
        hasIncomeData: true,
      );
      expect(ef.monthlyContribution, isNull);
      expect(ef.estimatedMonths, isNull);
      expect(ef.estimatedCompletionDate, isNull);
    });
  });

  group('8. Goal completion projection', () {
    test('estimated completion derived from average pace since creation', () {
      final projections = FinancialPlanningCalculator.calculateGoalProjections(
        goals: [
          _goal(
            id: 'Vacation',
            target: 100000,
            current: 40000,
            createdAt: DateTime(2026, 4, 20), // 4 months before _now
            targetDate: DateTime(2027, 2, 20),
          ),
        ],
        now: _now,
      );
      final goal = projections.single;
      // implied pace = 40000 / 4 months = 10000/month.
      expect(goal.impliedMonthlyContribution, 10000);
      // remaining 60000 / 10000 = 6 months.
      expect(goal.estimatedMonths, 6);
      expect(goal.estimatedCompletionDate, DateTime(2027, 2, 20));
    });
  });

  group('9. Goal required contribution', () {
    test('required monthly contribution to meet the target date', () {
      final projections = FinancialPlanningCalculator.calculateGoalProjections(
        goals: [
          _goal(
            id: 'Vacation',
            target: 100000,
            current: 40000,
            createdAt: DateTime(2026, 4, 20),
            targetDate: DateTime(2026, 12, 20), // 4 months from _now
          ),
        ],
        now: _now,
      );
      final goal = projections.single;
      expect(goal.requiredMonthlyContribution, 15000); // 60000 / 4
      expect(goal.contributionGap, 5000); // 15000 required - 10000 implied
    });
  });

  group('10. Goal on-track status', () {
    test('implied pace meeting or exceeding required contribution is on-track', () {
      final projections = FinancialPlanningCalculator.calculateGoalProjections(
        goals: [
          _goal(
            id: 'Emergency-ish',
            target: 100000,
            current: 40000, // implied pace 10000/month over 4 months
            createdAt: DateTime(2026, 4, 20),
            targetDate: DateTime(2027, 2, 20), // 6 months left, needs 10000/month
          ),
        ],
        now: _now,
      );
      expect(projections.single.status, GoalProjectionStatus.onTrack);
    });
  });

  group('11. Goal at-risk status', () {
    test('implied pace below required contribution is at-risk', () {
      final projections = FinancialPlanningCalculator.calculateGoalProjections(
        goals: [
          _goal(
            id: 'Vacation',
            target: 100000,
            current: 40000, // implied 10000/month
            createdAt: DateTime(2026, 4, 20),
            targetDate: DateTime(2026, 12, 20), // needs 15000/month
          ),
        ],
        now: _now,
      );
      expect(projections.single.status, GoalProjectionStatus.atRisk);
    });
  });

  group('12. Monthly commitment calculation', () {
    test('total = loans + recurring bills + subscriptions + other recurring', () {
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: [_recurringBill('Electricity', 1200)],
        loans: [_loan(id: 'l1', principal: 100000, outstanding: 80000, emi: 5000, interestRate: 10)],
        recurringTransactions: [_recurring('Netflix', 500)],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.loanEmi, 5000);
      expect(commitments.recurringBills, 1200);
      expect(commitments.subscriptions, 500);
      expect(commitments.total, 6700);
    });
  });

  group('13. Subscription contribution', () {
    test('subscriptions bucket matches SubscriptionCalculator exactly', () {
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: const [],
        loans: const [],
        recurringTransactions: [_recurring('Spotify', 199, frequency: 'Monthly')],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.subscriptions, 199);
    });
  });

  group('14. Bill contribution', () {
    test('one-time (non-recurring) unpaid bills are excluded from monthly commitments', () {
      final oneTime = Bill.create(
        id: 'b1', title: 'One-off repair', amount: 5000, categoryId: 'Home',
        accountId: 'w1', dueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1),
      );
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: [oneTime],
        loans: const [],
        recurringTransactions: const [],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.recurringBills, 0);
    });

    test('a paid recurring bill is not double counted as a commitment', () {
      final bill = _recurringBill('Rent', 15000).markPaid(DateTime(2026, 8, 1));
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: [bill],
        loans: const [],
        recurringTransactions: const [],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      // Bill.markPaid on a recurring bill reopens it as unpaid at the next
      // due date, so it's still a live monthly commitment.
      expect(commitments.recurringBills, 15000);
    });
  });

  group('15. Loan EMI contribution', () {
    test('sums EMI across multiple active loans', () {
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: const [],
        loans: [
          _loan(id: 'l1', principal: 100000, outstanding: 80000, emi: 5000, interestRate: 10),
          _loan(id: 'l2', principal: 200000, outstanding: 150000, emi: 8000, interestRate: 8),
        ],
        recurringTransactions: const [],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.loanEmi, 13000);
    });
  });

  group('16. Recurring contribution', () {
    test('a recurring item with an unrecognized frequency is excluded, not guessed', () {
      final oddFrequency = _recurring('Odd', 300, frequency: 'Fortnightly');
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: const [],
        loans: const [],
        recurringTransactions: [oddFrequency],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.otherRecurring, 0);
      expect(commitments.excludedRecurringCount, 1);
    });

    test('income-type recurring items are never counted as a commitment', () {
      final income = _recurring('Freelance', 10000, type: 'income');
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: const [],
        loans: const [],
        recurringTransactions: [income],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.otherRecurring, 0);
      expect(commitments.subscriptions, 0);
    });
  });

  group('17. No double counting commitments', () {
    test('a recurring item eligible as a subscription is never also counted in otherRecurring', () {
      final commitments = FinancialPlanningCalculator.calculateCommitments(
        bills: const [],
        loans: const [],
        recurringTransactions: [_recurring('Netflix', 500)],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(commitments.subscriptions, 500);
      expect(commitments.otherRecurring, 0);
      expect(commitments.total, 500);
    });
  });

  group('18. Debt total', () {
    test('total outstanding across active loans', () {
      final debt = FinancialPlanningCalculator.calculateDebtOverview(
        loans: [
          _loan(id: 'l1', principal: 100000, outstanding: 80000, emi: 5000, interestRate: 10),
          _loan(id: 'l2', principal: 200000, outstanding: 150000, emi: 8000, interestRate: 8),
        ],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(debt.totalOutstanding, 230000);
      expect(debt.activeLoanCount, 2);
    });
  });

  group('19. Debt EMI burden', () {
    test('EMI-to-income percentage computed correctly', () {
      final debt = FinancialPlanningCalculator.calculateDebtOverview(
        loans: [_loan(id: 'l1', principal: 100000, outstanding: 80000, emi: 10000, interestRate: 10)],
        monthlyIncome: 50000,
        hasIncomeData: true,
        now: _now,
      );
      expect(debt.emiToIncomePercent, 20.0);
    });
  });

  group('20. Debt priority by interest rate', () {
    test('ranks loans by highest interest rate when all rates are known', () {
      final priority = FinancialPlanningCalculator.calculateDebtPriority([
        _loan(id: 'CarLoan', principal: 500000, outstanding: 400000, emi: 12000, interestRate: 9.2),
        _loan(id: 'PersonalLoan', principal: 200000, outstanding: 150000, emi: 8000, interestRate: 14.5),
      ]);
      expect(priority.method, DebtPriorityMethod.byInterestRate);
      expect(priority.ranked.first.name, 'PersonalLoan');
      expect(priority.ranked.last.name, 'CarLoan');
    });
  });

  group('21. Debt fallback priority', () {
    test('falls back to highest outstanding balance when a rate is missing', () {
      final priority = FinancialPlanningCalculator.calculateDebtPriority([
        _loan(id: 'l1', principal: 500000, outstanding: 400000, emi: 12000, interestRate: 0),
        _loan(id: 'l2', principal: 200000, outstanding: 150000, emi: 8000, interestRate: 14.5),
      ]);
      expect(priority.method, DebtPriorityMethod.byOutstandingBalance);
      expect(priority.ranked.first.name, 'l1');
    });

    test('a single loan is never auto-ranked, with an explicit reason', () {
      final priority = FinancialPlanningCalculator.calculateDebtPriority([
        _loan(id: 'l1', principal: 500000, outstanding: 400000, emi: 12000, interestRate: 10),
      ]);
      expect(priority.method, DebtPriorityMethod.none);
      expect(priority.reason, isNotEmpty);
    });
  });

  group('22. Zero-data handling', () {
    test('a completely empty account never crashes and reports insufficient data', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: const [],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _analytics(monthlyTotals: [_mt(DateTime(2026, 8))]),
        now: _now,
      );
      expect(result.hasSufficientData, isFalse);
      expect(result.overview.netWorth, 0);
      expect(result.readinessScore, inInclusiveRange(0, 100));
    });
  });

  group('23. Planning score', () {
    test('a well-prepared synthetic profile scores in the upper range', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: [Transaction(id: 't1', title: 'x', amount: 1, categoryId: 'x', accountId: 'w1', transactionType: 'income', paymentMethod: 'bank', note: '', createdAt: DateTime(2026, 8, 1))],
        wallets: [_wallet('w1', 500000)],
        goals: [
          _goal(id: 'g1', target: 100000, current: 100000, createdAt: DateTime(2026, 1, 1), targetDate: DateTime(2026, 6, 1)),
        ],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        emergencyFundEligibleWalletIds: const ['w1'],
        now: _now,
      );
      expect(result.readinessScore, greaterThanOrEqualTo(60));
    });
  });

  group('24. Planning score boundaries', () {
    test('readiness score is always clamped between 0 and 100', () {
      final worstCase = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: const [],
        goals: const [],
        loans: List.generate(
          5,
          (i) => _loan(id: 'l$i', principal: 1000000, outstanding: 1000000, emi: 50000, interestRate: 20),
        ),
        bills: const [],
        recurringTransactions: const [],
        analytics: _analytics(
          monthlyTotals: [_mt(DateTime(2026, 8), income: 10000, expense: 90000)],
          currentMonthIncome: 10000,
          currentMonthExpense: 90000,
        ),
        now: _now,
      );
      expect(worstCase.readinessScore, inInclusiveRange(0, 100));
    });
  });

  group('25. Action-plan generation', () {
    test('an emergency-fund gap produces a specific, data-backed action', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 10000)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        emergencyFundEligibleWalletIds: const ['w1'],
        now: _now,
      );
      expect(result.recommendations, isNotEmpty);
      expect(result.recommendations.first, contains('emergency savings'));
    });

    test('a fully-prepared profile shows the neutral on-track message', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 500000)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        emergencyFundEligibleWalletIds: const ['w1'],
        now: _now,
      );
      expect(
        result.recommendations,
        contains("You're on track. Keep maintaining your current savings rate."),
      );
    });
  });

  group('26. What-if savings calculation', () {
    test('a higher hypothetical monthly saving shortens the emergency fund timeline', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 60000)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        emergencyFundEligibleWalletIds: const ['w1'],
        now: _now,
      );
      final whatIf = FinancialPlanningCalculator.whatIf(
        result: result,
        hypotheticalMonthlySavings: 60000, // real monthly savings is 35000
        now: _now,
      );
      expect(whatIf.emergencyFundMonthsAfter!, lessThan(whatIf.emergencyFundMonthsBefore!));
    });
  });

  group('27. What-if goal completion', () {
    test('a higher hypothetical saving moves the earliest incomplete goal sooner', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 0)],
        goals: [
          _goal(id: 'Vacation', target: 100000, current: 40000, createdAt: DateTime(2026, 4, 20), targetDate: DateTime(2027, 2, 20)),
        ],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        now: _now,
      );
      final whatIf = FinancialPlanningCalculator.whatIf(
        result: result,
        hypotheticalMonthlySavings: 30000,
        now: _now,
      );
      expect(whatIf.goalId, 'Vacation');
      expect(whatIf.goalMonthsAfter, 2); // 60000 remaining / 30000
      expect(whatIf.goalDateAfter, DateTime(2026, 10, 20));
    });
  });

  group('28. No NaN/Infinity', () {
    test('every numeric field stays finite across a battery of zero-division edge cases', () {
      final scenarios = [
        _analytics(monthlyTotals: [_mt(DateTime(2026, 8))]),
        _analytics(
          monthlyTotals: [_mt(DateTime(2026, 8), income: 0, expense: 5000)],
          currentMonthExpense: 5000,
        ),
      ];
      for (final analytics in scenarios) {
        final result = FinancialPlanningCalculator.calculate(
          transactions: const [],
          wallets: const [],
          goals: [
            _goal(id: 'g1', target: 0, current: 0, createdAt: _now, targetDate: _now),
          ],
          loans: [_loan(id: 'l1', principal: 0, outstanding: 0, emi: 0, interestRate: 0)],
          bills: const [],
          recurringTransactions: const [],
          analytics: analytics,
          now: _now,
        );
        expect(result.overview.netWorth.isNaN, isFalse);
        expect(result.overview.netWorth.isInfinite, isFalse);
        expect(result.readinessScore.isNaN, isFalse);
        expect(result.commitments.total.isNaN, isFalse);
        expect(result.debt.totalOutstanding.isFinite, isTrue);
      }
    });
  });

  group('29. Multiple wallets', () {
    test('net worth and emergency fund current sum across multiple wallets', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 30000), _wallet('w2', 20000)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        emergencyFundEligibleWalletIds: const ['w1', 'w2'],
        now: _now,
      );
      expect(result.overview.netWorth, 50000);
      expect(result.emergencyFund.current, 50000);
    });
  });

  group('30. Archived wallets excluded', () {
    test('an archived wallet never counts toward net worth or emergency fund', () {
      final result = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [_wallet('w1', 30000), _wallet('w2', 20000, archived: true)],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: _steadyAnalytics(),
        emergencyFundEligibleWalletIds: const ['w1', 'w2'],
        now: _now,
      );
      expect(result.overview.netWorth, 30000);
      // The archived wallet is filtered out of the eligible pool entirely,
      // so even though its id is in the configured list, its balance never
      // contributes.
      expect(result.emergencyFund.current, 30000);
    });
  });
}
