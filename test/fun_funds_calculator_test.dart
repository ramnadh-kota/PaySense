import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/providers/budget_provider.dart' show BudgetTotals;
import 'package:paysense/shared/utils/financial_planning_calculator.dart'
    show GoalProjection, GoalProjectionStatus;
import 'package:paysense/shared/utils/fun_funds_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

SafeToSpendResult _safeToSpend({
  required bool hasSufficientData,
  double safeToSpend = 0,
}) {
  return SafeToSpendResult(
    availableMoney: safeToSpend,
    upcomingCommitments: 0,
    plannedSavings: 0,
    savingsIncluded: false,
    safeToSpend: safeToSpend,
    dailySafeToSpend: 0,
    remainingDays: 30,
    hasSufficientData: hasSufficientData,
    shortfall: 0,
    commitmentBreakdown: const [],
    windowDays: 30,
  );
}

BudgetTotals _budgetTotals({required double remainingBudget}) {
  return BudgetTotals(
    totalBudget: 0,
    totalSpent: 0,
    remainingBudget: remainingBudget,
    percentageUsed: 0,
    highestSpendingCategory: '',
  );
}

GoalProjection _goalProjection({
  required double? requiredMonthlyContribution,
  GoalProjectionStatus status = GoalProjectionStatus.onTrack,
}) {
  return GoalProjection(
    goalId: 'g1',
    title: 'Goal',
    targetAmount: 10000,
    currentAmount: 1000,
    remainingAmount: 9000,
    targetDate: DateTime(2027, 1, 1),
    impliedMonthlyContribution: null,
    estimatedMonths: null,
    estimatedCompletionDate: null,
    requiredMonthlyContribution: requiredMonthlyContribution,
    contributionGap: null,
    status: status,
  );
}

FunGroupExpense _groupExpense({
  required double myShare,
  required DateTime date,
}) {
  return FunGroupExpense(
    id: 'e-${date.millisecondsSinceEpoch}',
    title: 'Dinner',
    categoryKey: FunGroupExpenseCategory.dinner.name,
    totalAmount: myShare * 2,
    date: date,
    paidByParticipantId: funGroupExpenseMeParticipantId,
    participants: [
      FunGroupParticipant(
        id: funGroupExpenseMeParticipantId,
        name: 'Me',
        shareAmount: myShare,
        isSettled: true,
      ),
      FunGroupParticipant(id: 'p2', name: 'Friend', shareAmount: myShare),
    ],
    createdAt: date,
  );
}

void main() {
  final now = DateTime(2026, 8, 15);

  group('FunFundsCalculator', () {
    test(
      'never suggests money is available when known obligations exceed '
      'available funds — a Safe-to-Spend shortfall (0) must yield 0 Fun '
      'Funds, never a positive figure',
      () {
        // A real shortfall: SafeToSpendCalculator itself floors this at 0
        // rather than a negative number, so 0 is exactly what a genuine
        // "obligations exceed available money" scenario looks like here.
        final result = FunFundsCalculator.calculate(
          safeToSpend: _safeToSpend(hasSufficientData: true, safeToSpend: 0),
          budgetTotals: _budgetTotals(remainingBudget: 0),
          goalProjections: const [],
          groupExpenses: const [],
          now: now,
        );

        expect(result.monthlyAvailable, 0);
        expect(result.remaining, 0);
        expect(result.dailyBudget, 0);
        expect(result.weeklyBudget, 0);
      },
    );

    test('returns insufficient-data result when Safe-to-Spend has no data', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(hasSufficientData: false),
        budgetTotals: _budgetTotals(remainingBudget: 0),
        goalProjections: const [],
        groupExpenses: const [],
        now: now,
      );

      expect(result.hasSufficientData, isFalse);
      expect(result.monthlyAvailable, 0);
      expect(result.remaining, 0);
    });

    test('nets out budget commitments, goal contributions, and the safety '
        'buffer deterministically', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(hasSufficientData: true, safeToSpend: 10000),
        budgetTotals: _budgetTotals(remainingBudget: 2000),
        goalProjections: [_goalProjection(requiredMonthlyContribution: 1000)],
        groupExpenses: const [],
        now: now,
      );

      // 10000 - 2000 (budget) - 1000 (goal) = 7000; buffer = 700 (10%);
      // available = 6300.
      expect(result.budgetCommitted, 2000);
      expect(result.goalCommitted, 1000);
      expect(result.safetyBuffer, closeTo(700, 0.001));
      expect(result.monthlyAvailable, closeTo(6300, 0.001));
      expect(result.hasSufficientData, isTrue);
    });

    test('ignores a completed goal\'s contribution and a negative/zero '
        'contribution gap', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(hasSufficientData: true, safeToSpend: 5000),
        budgetTotals: _budgetTotals(remainingBudget: 0),
        goalProjections: [
          _goalProjection(
            requiredMonthlyContribution: 500,
            status: GoalProjectionStatus.completed,
          ),
          _goalProjection(requiredMonthlyContribution: -100),
          _goalProjection(requiredMonthlyContribution: null),
        ],
        groupExpenses: const [],
        now: now,
      );

      expect(result.goalCommitted, 0);
      expect(result.monthlyAvailable, closeTo(5000 * 0.9, 0.001));
    });

    test('counts only this calendar month\'s Fun Funds group-expense spend '
        'toward spentThisMonth', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(hasSufficientData: true, safeToSpend: 10000),
        budgetTotals: _budgetTotals(remainingBudget: 0),
        goalProjections: const [],
        groupExpenses: [
          _groupExpense(myShare: 900, date: DateTime(2026, 8, 10)),
          _groupExpense(myShare: 500, date: DateTime(2026, 8, 1)),
          _groupExpense(myShare: 10000, date: DateTime(2026, 7, 31)), // last month
        ],
        now: now,
      );

      expect(result.spentThisMonth, closeTo(1400, 0.001));
      // available = 10000 * 0.9 = 9000; remaining = 9000 - 1400 = 7600.
      expect(result.monthlyAvailable, closeTo(9000, 0.001));
      expect(result.remaining, closeTo(7600, 0.001));
      expect(result.utilizationPercent, closeTo(1400 / 9000 * 100, 0.001));
    });

    test('remaining floors at 0 when spend this month exceeds the available '
        'fund, and weekly budget never exceeds remaining', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(hasSufficientData: true, safeToSpend: 1000),
        budgetTotals: _budgetTotals(remainingBudget: 0),
        goalProjections: const [],
        groupExpenses: [
          _groupExpense(myShare: 5000, date: now),
        ],
        now: now,
      );

      expect(result.remaining, 0);
      expect(result.dailyBudget, 0);
      expect(result.weeklyBudget, 0);
      expect(result.utilizationPercent, greaterThanOrEqualTo(100));
    });

    test('daily/weekly budgets are consistent with days left in the month', () {
      final result = FunFundsCalculator.calculate(
        safeToSpend: _safeToSpend(hasSufficientData: true, safeToSpend: 3100),
        budgetTotals: _budgetTotals(remainingBudget: 0),
        goalProjections: const [],
        groupExpenses: const [],
        now: DateTime(2026, 8, 1),
      );

      // available = 3100 * 0.9 = 2790; August has 31 days, all remaining.
      expect(result.daysRemainingInMonth, 31);
      expect(result.dailyBudget, closeTo(2790 / 31, 0.01));
      expect(result.weeklyBudget, closeTo(result.dailyBudget * 7, 0.01));
      expect(result.weeklyBudget, lessThanOrEqualTo(result.remaining));
    });
  });

  group('FunGroupExpense splitting', () {
    test('equalSplit divides the total evenly and shares always sum to the '
        'exact total, including a non-round amount', () {
      final participants = FunGroupExpense.equalSplit(
        totalAmount: 1000,
        participantNames: ['Me', 'A', 'B'],
      );

      expect(participants.length, 3);
      final sum = participants.fold<double>(0, (s, p) => s + p.shareAmount);
      expect(sum, closeTo(1000, 0.001));
      expect(participants.first.id, funGroupExpenseMeParticipantId);
    });

    test('a 3000/4-people split matches the spec example exactly '
        '(750 each)', () {
      final participants = FunGroupExpense.equalSplit(
        totalAmount: 3000,
        participantNames: ['Me', 'A', 'B', 'C'],
      );
      for (final p in participants) {
        expect(p.shareAmount, 750);
      }

      final expense = FunGroupExpense(
        id: 'e1',
        title: 'Dinner with friends',
        categoryKey: FunGroupExpenseCategory.dinner.name,
        totalAmount: 3000,
        date: DateTime(2026, 8, 20),
        paidByParticipantId: funGroupExpenseMeParticipantId,
        participants: participants
            .map(
              (p) => p.id == funGroupExpenseMeParticipantId
                  ? p.copyWith(isSettled: true)
                  : p,
            )
            .toList(),
        createdAt: DateTime(2026, 8, 20),
      );

      expect(expense.iPaid, isTrue);
      expect(expense.myShare, 750);
      expect(expense.othersOweMe, 2250);
      expect(expense.iOwe, 0);
      expect(expense.isFullySettled, isFalse);
    });

    test('when a friend paid, the user owes their own share until settled', () {
      final participants = FunGroupExpense.equalSplit(
        totalAmount: 800,
        participantNames: ['Me', 'Friend'],
      );
      final expense = FunGroupExpense(
        id: 'e2',
        title: 'Movie',
        categoryKey: FunGroupExpenseCategory.movie.name,
        totalAmount: 800,
        date: DateTime(2026, 8, 20),
        paidByParticipantId: 'participant-1',
        participants: participants
            .map(
              (p) => p.id == 'participant-1' ? p.copyWith(isSettled: true) : p,
            )
            .toList(),
        createdAt: DateTime(2026, 8, 20),
      );

      expect(expense.iPaid, isFalse);
      expect(expense.iOwe, 400);
      expect(expense.othersOweMe, 0);
      expect(expense.isFullySettled, isFalse);

      final settled = expense.copyWith(
        participants: expense.participants
            .map(
              (p) => p.id == funGroupExpenseMeParticipantId
                  ? p.copyWith(isSettled: true)
                  : p,
            )
            .toList(),
      );
      expect(settled.iOwe, 0);
      expect(settled.isFullySettled, isTrue);
    });
  });
}
