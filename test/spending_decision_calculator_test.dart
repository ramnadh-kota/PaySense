import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/decision_memory_record.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/utils/allowance_calculator.dart';
import 'package:paysense/shared/utils/decision_memory_engine.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';
import 'package:paysense/shared/utils/spending_decision_calculator.dart';
import 'package:paysense/shared/utils/spending_limit_calculator.dart';

final _now = DateTime(2026, 8, 20);

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id,
    name: id,
    bankName: 'Test Bank',
    type: 'Bank',
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
}

Budget _budget({
  required String categoryId,
  required String categoryName,
  required double allocated,
  required double spent,
}) {
  final remaining = allocated - spent;
  final pct = allocated > 0 ? (spent / allocated * 100) : (spent > 0 ? 100.0 : 0.0);
  return Budget(
    id: 'b-$categoryId',
    categoryId: categoryId,
    categoryName: categoryName,
    allocatedAmount: allocated,
    spentAmount: spent,
    remainingAmount: remaining,
    percentageUsed: pct,
    month: 'august',
    year: 2026,
    createdAt: DateTime(2026, 8, 1),
  );
}

Goal _goal({
  required String id,
  required double target,
  required double current,
}) {
  return Goal.create(
    id: id,
    title: id,
    targetAmount: target,
    currentAmount: current,
    targetDate: DateTime(2027, 1, 1),
    category: 'Savings',
    icon: 'savings',
    color: 0xFF000000,
    createdAt: DateTime(2026, 1, 1),
  );
}

Loan _loan({required String id, required double emi}) {
  return Loan.create(
    id: id,
    loanName: id,
    lenderName: 'Bank',
    loanType: 'Personal',
    principalAmount: 200000,
    interestRate: 10,
    tenureMonths: 24,
    emiAmount: emi,
    totalInterest: 0,
    accountId: 'w1',
    startDate: DateTime(2026, 1, 1),
    nextDueDate: DateTime(2026, 9, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

FinancialPlanningResult _planning({
  required double balance,
  required double emi,
  required double income,
}) {
  final wallets = [_wallet('w1', balance)];
  final loans = emi > 0 ? [_loan(id: 'l1', emi: emi)] : <Loan>[];
  final analytics = AnalyticsSummary(
    monthlyTotals: [MonthlyTotal(month: _now, income: income, expense: 20000)],
    categoryBreakdown: const [],
    currentMonthIncome: income,
    currentMonthExpense: 20000,
    savingsRate: 20.0,
  );

  return FinancialPlanningCalculator.calculate(
    transactions: const [],
    wallets: wallets,
    goals: const [],
    loans: loans,
    bills: const [],
    recurringTransactions: const [],
    analytics: analytics,
    emergencyFundEligibleWalletIds: const ['w1'],
    emergencyFundTargetMonths: 3,
    now: _now,
  );
}

SafeToSpendResult _safeToSpend({required double balance, double commitments = 0}) {
  return SafeToSpendCalculator.calculate(
    wallets: [_wallet('w1', balance)],
    bills: const [],
    loans: commitments > 0 ? [_loan(id: 'l1', emi: commitments)] : const [],
    recurringTransactions: const [],
    now: _now,
  );
}

void main() {
  group('SpendingDecisionCalculator — Phase 6C Integration', () {
    test('1. Comfortable purchase within spending limits, allowance, and affordability', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 5000, income: 80000);
      final budgets = [
        _budget(categoryId: 'food', categoryName: 'Food', allocated: 10000, spent: 3000),
      ];

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'food',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          goals: [_goal(id: 'Emergency', target: 50000, current: 20000)],
          now: _now,
        ),
      );

      expect(result.amount, 500.0);
      expect(result.categoryId, 'food');
      expect(result.categorySpendingLimit, isNotNull);
      expect(result.categorySpendingLimit!.state, SpendingLimitState.comfortable);
      expect(result.allowance.state, AllowanceState.comfortable);
      expect(result.affordability.status, AffordabilityStatus.comfortable);
      expect(result.recommendationTier, SpendingRecommendationTier.spend);
      expect(result.recommendationLabel, 'Comfortable to spend');
      expect(result.isComfortable, isTrue);
      expect(result.isCautionary, isFalse);
      expect(result.verdictLine, contains('comfortable'));
    });

    test('2. Category spending limit approaching threshold', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 5000, income: 80000);
      final budgets = [
        _budget(categoryId: 'dining', categoryName: 'Dining', allocated: 10000, spent: 8500),
      ];

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'dining',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          now: _now,
        ),
      );

      expect(result.categorySpendingLimit?.state, SpendingLimitState.approaching);
      expect(result.recommendationTier, SpendingRecommendationTier.thinkAgain);
      expect(result.recommendationLabel, 'Think again');
      expect(result.verdictLine, contains('Approaching'));
    });

    test('3. Category spending limit exceeded threshold', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 5000, income: 80000);
      final budgets = [
        _budget(categoryId: 'shopping', categoryName: 'Shopping', allocated: 5000, spent: 5500),
      ];

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 1000,
          categoryId: 'shopping',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          now: _now,
        ),
      );

      expect(result.categorySpendingLimit?.state, SpendingLimitState.exceeded);
      expect(result.recommendationTier, SpendingRecommendationTier.avoid);
      expect(result.recommendationLabel, 'Consider avoiding');
      expect(result.isCautionary, isTrue);
      expect(result.verdictLine, contains('Category limit reached'));
    });

    test('4. Purchase exceeds wallet balance (not recommended)', () {
      final safe = _safeToSpend(balance: 2000);
      final plan = _planning(balance: 2000, emi: 0, income: 50000);

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 10000,
          categoryId: 'tech',
          safeToSpend: safe,
          planning: plan,
          now: _now,
        ),
      );

      expect(result.affordability.status, AffordabilityStatus.notRecommended);
      expect(result.recommendationTier, SpendingRecommendationTier.avoid);
      expect(result.isCautionary, isTrue);
      expect(result.verdictLine, contains('exceeds your available'));
    });

    test('5. Insufficient data when wallet or income data is missing', () {
      final emptySafe = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      final emptyPlan = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: const [],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: AnalyticsSummary(
          monthlyTotals: const [],
          categoryBreakdown: const [],
          currentMonthIncome: 0,
          currentMonthExpense: 0,
          savingsRate: 0,
        ),
        emergencyFundEligibleWalletIds: const [],
        emergencyFundTargetMonths: 3,
        now: _now,
      );

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'general',
          safeToSpend: emptySafe,
          planning: emptyPlan,
          now: _now,
        ),
      );

      expect(result.affordability.status, AffordabilityStatus.insufficientData);
      expect(result.verdictLine, contains('Insufficient'));
    });

    test('6. Integrates EMI and Savings Goal impact correctly', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 20000, income: 80000);
      final goal = _goal(id: 'Laptop', target: 50000, current: 30000); // 20000 remaining

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 5000,
          categoryId: 'gadgets',
          safeToSpend: safe,
          planning: plan,
          goals: [goal],
          now: _now,
        ),
      );

      expect(result.impact.emiPercentage, closeTo(25.0, 0.1));
      expect(result.impact.savingsGoalPercentage, closeTo(25.0, 0.1));
      expect(result.painOfPaying.signals, isNotEmpty);
    });

    test('7. No decision history produces null memoryInsight', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 0, income: 80000);

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'dining',
          safeToSpend: safe,
          planning: plan,
          decisionHistory: const [],
          now: _now,
        ),
      );

      expect(result.memoryInsight, isNull);
      expect(result.recommendationTier, SpendingRecommendationTier.spend);
      expect(result.isComfortable, isTrue);
    });

    test('8. Insufficient decision history (< 2) produces null memoryInsight', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 0, income: 80000);

      final singleRecord = DecisionMemoryRecord(
        id: 'dm-1',
        timestamp: _now.subtract(const Duration(days: 2)),
        categoryId: 'dining',
        amount: 500,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.proceeded,
        verdictLine: 'OK',
      );

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'dining',
          safeToSpend: safe,
          planning: plan,
          decisionHistory: [singleRecord],
          now: _now,
        ),
      );

      expect(result.memoryInsight, isNull);
      expect(result.recommendationTier, SpendingRecommendationTier.spend);
    });

    test('9. Relevant proceeded history produces frequentlyProceeded insight without altering recommendation', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 0, income: 80000);

      final history = [
        DecisionMemoryRecord(
          id: 'dm-1',
          timestamp: _now.subtract(const Duration(days: 3)),
          categoryId: 'dining',
          amount: 500,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
        DecisionMemoryRecord(
          id: 'dm-2',
          timestamp: _now.subtract(const Duration(days: 1)),
          categoryId: 'dining',
          amount: 550,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      ];

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'dining',
          safeToSpend: safe,
          planning: plan,
          decisionHistory: history,
          now: _now,
        ),
      );

      expect(result.memoryInsight, isNotNull);
      expect(result.memoryInsight!.type, DecisionMemoryPatternType.frequentlyProceeded);
      expect(result.memoryInsight!.similarDecisionCount, 2);
      expect(result.memoryInsight!.proceededCount, 2);
      expect(result.memoryInsight!.cancelledCount, 0);
      // Core financial recommendation is still authoritative and unchanged!
      expect(result.recommendationTier, SpendingRecommendationTier.spend);
      expect(result.isComfortable, isTrue);
    });

    test('10. Relevant cancelled/waited history produces frequentlyWaited insight without altering recommendation', () {
      final safe = _safeToSpend(balance: 50000);
      final plan = _planning(balance: 50000, emi: 0, income: 80000);
      final budgets = [
        _budget(categoryId: 'dining', categoryName: 'Dining', allocated: 10000, spent: 8500),
      ];

      final history = [
        DecisionMemoryRecord(
          id: 'dm-1',
          timestamp: _now.subtract(const Duration(days: 5)),
          categoryId: 'dining',
          amount: 500,
          recommendationTier: SpendingRecommendationTier.thinkAgain,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Approaching limit',
        ),
        DecisionMemoryRecord(
          id: 'dm-2',
          timestamp: _now.subtract(const Duration(days: 2)),
          categoryId: 'dining',
          amount: 600,
          recommendationTier: SpendingRecommendationTier.thinkAgain,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Approaching limit',
        ),
      ];

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'dining',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          decisionHistory: history,
          now: _now,
        ),
      );

      expect(result.memoryInsight, isNotNull);
      expect(result.memoryInsight!.type, DecisionMemoryPatternType.frequentlyWaited);
      expect(result.memoryInsight!.similarDecisionCount, 2);
      expect(result.memoryInsight!.cancelledCount, 2);
      expect(result.memoryInsight!.proceededCount, 0);
      // Core financial recommendation is still thinkAgain based on budget limit approaching!
      expect(result.recommendationTier, SpendingRecommendationTier.thinkAgain);
      expect(result.verdictLine, contains('Approaching'));
    });

    test('11. Mixed history produces mixedHistory insight without changing avoid recommendation', () {
      final safe = _safeToSpend(balance: 2000);
      final plan = _planning(balance: 2000, emi: 0, income: 50000);

      final history = [
        DecisionMemoryRecord(
          id: 'dm-1',
          timestamp: _now.subtract(const Duration(days: 4)),
          categoryId: 'tech',
          amount: 10000,
          recommendationTier: SpendingRecommendationTier.avoid,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'Avoid',
        ),
        DecisionMemoryRecord(
          id: 'dm-2',
          timestamp: _now.subtract(const Duration(days: 2)),
          categoryId: 'tech',
          amount: 9500,
          recommendationTier: SpendingRecommendationTier.avoid,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Avoid',
        ),
      ];

      final result = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 10000,
          categoryId: 'tech',
          safeToSpend: safe,
          planning: plan,
          decisionHistory: history,
          now: _now,
        ),
      );

      expect(result.memoryInsight, isNotNull);
      expect(result.memoryInsight!.type, DecisionMemoryPatternType.mixedHistory);
      expect(result.memoryInsight!.similarDecisionCount, 2);
      expect(result.memoryInsight!.proceededCount, 1);
      expect(result.memoryInsight!.cancelledCount, 1);
      // Core financial recommendation remains avoid due to wallet balance!
      expect(result.recommendationTier, SpendingRecommendationTier.avoid);
      expect(result.isCautionary, isTrue);
    });
  });
}
