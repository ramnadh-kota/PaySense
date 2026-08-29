import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';
import 'package:paysense/shared/utils/spending_decision_calculator.dart';
import 'package:paysense/shared/widgets/decision_coach_dialog.dart';

final _now = DateTime(2026, 8, 20);

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

void main() {
  group('DecisionCoachDialog — Phase 6D UX Finalization', () {
    testWidgets('1. Renders legacy Decision Coach dialog and responds to actions', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const DecisionCoachDialog(
                      amount: 1500,
                      emiPercentage: 15.0,
                      savingsGoalPercentage: 5.0,
                      comparisonMessage: 'This is less than a week of dining spend.',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Think Before You Pay'), findsOneWidget);
      expect(find.text('PaySense Decision Coach'), findsOneWidget);
      expect(find.text('₹1,500'), findsOneWidget);
      expect(find.text('EMI Impact'), findsOneWidget);
      expect(find.text('Savings Goal Pace'), findsOneWidget);
      expect(find.text('Perspective'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Spend Anyway'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('2. Renders comfortable spending decision with "Comfortable to spend" badge', (tester) async {
      final safe = SafeToSpendCalculator.calculate(
        wallets: [
          Wallet(id: 'w1', name: 'Main', bankName: '', type: 'Bank', openingBalance: 50000, currentBalance: 50000, createdAt: _now),
        ],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      final plan = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [
          Wallet(id: 'w1', name: 'Main', bankName: '', type: 'Bank', openingBalance: 50000, currentBalance: 50000, createdAt: _now),
        ],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: AnalyticsSummary(
          monthlyTotals: [MonthlyTotal(month: _now, income: 80000, expense: 20000)],
          categoryBreakdown: const [],
          currentMonthIncome: 80000,
          currentMonthExpense: 20000,
          savingsRate: 25.0,
        ),
        emergencyFundEligibleWalletIds: const ['w1'],
        emergencyFundTargetMonths: 3,
        now: _now,
      );

      final budgets = [
        _budget(categoryId: 'dining', categoryName: 'Dining', allocated: 10000, spent: 2000),
      ];

      final decision = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'dining',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          now: _now,
        ),
      );

      expect(decision.recommendationTier, SpendingRecommendationTier.spend);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => DecisionCoachDialog(
                      amount: decision.amount,
                      decision: decision,
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Comfortable to spend'), findsOneWidget);
      expect(find.text('Dining Spending Limit'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('Discretionary Allowance'), findsOneWidget);

      await tester.tap(find.text('Spend Anyway'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('3. Renders approaching limit with "Think again" badge', (tester) async {
      final safe = SafeToSpendCalculator.calculate(
        wallets: [
          Wallet(id: 'w1', name: 'Main', bankName: '', type: 'Bank', openingBalance: 50000, currentBalance: 50000, createdAt: _now),
        ],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      final plan = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [
          Wallet(id: 'w1', name: 'Main', bankName: '', type: 'Bank', openingBalance: 50000, currentBalance: 50000, createdAt: _now),
        ],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: AnalyticsSummary(
          monthlyTotals: [MonthlyTotal(month: _now, income: 80000, expense: 20000)],
          categoryBreakdown: const [],
          currentMonthIncome: 80000,
          currentMonthExpense: 20000,
          savingsRate: 25.0,
        ),
        emergencyFundEligibleWalletIds: const ['w1'],
        emergencyFundTargetMonths: 3,
        now: _now,
      );

      final budgets = [
        _budget(categoryId: 'groceries', categoryName: 'Groceries', allocated: 10000, spent: 8500),
      ];

      final decision = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 500,
          categoryId: 'groceries',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          now: _now,
        ),
      );

      expect(decision.recommendationTier, SpendingRecommendationTier.thinkAgain);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => DecisionCoachDialog(
                    amount: decision.amount,
                    decision: decision,
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Think again'), findsOneWidget);
      expect(find.text('Approaching'), findsOneWidget);
      expect(find.text('Groceries Spending Limit'), findsOneWidget);
    });

    testWidgets('4. Renders exceeded limit with "Consider avoiding" badge', (tester) async {
      final safe = SafeToSpendCalculator.calculate(
        wallets: [
          Wallet(id: 'w1', name: 'Main', bankName: '', type: 'Bank', openingBalance: 50000, currentBalance: 50000, createdAt: _now),
        ],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      final plan = FinancialPlanningCalculator.calculate(
        transactions: const [],
        wallets: [
          Wallet(id: 'w1', name: 'Main', bankName: '', type: 'Bank', openingBalance: 50000, currentBalance: 50000, createdAt: _now),
        ],
        goals: const [],
        loans: const [],
        bills: const [],
        recurringTransactions: const [],
        analytics: AnalyticsSummary(
          monthlyTotals: [MonthlyTotal(month: _now, income: 80000, expense: 20000)],
          categoryBreakdown: const [],
          currentMonthIncome: 80000,
          currentMonthExpense: 20000,
          savingsRate: 25.0,
        ),
        emergencyFundEligibleWalletIds: const ['w1'],
        emergencyFundTargetMonths: 3,
        now: _now,
      );

      final budgets = [
        _budget(categoryId: 'shopping', categoryName: 'Shopping', allocated: 5000, spent: 5500),
      ];

      final decision = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: 1000,
          categoryId: 'shopping',
          safeToSpend: safe,
          planning: plan,
          budgets: budgets,
          now: _now,
        ),
      );

      expect(decision.recommendationTier, SpendingRecommendationTier.avoid);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => DecisionCoachDialog(
                    amount: decision.amount,
                    decision: decision,
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Consider avoiding'), findsOneWidget);
      expect(find.text('Limit Reached'), findsOneWidget);
      expect(find.text('Shopping Spending Limit'), findsOneWidget);
    });
  });
}
