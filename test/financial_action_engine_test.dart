// Focused tests for FinancialActionEngine (PHASE 1/2) — pure rule
// classification over already-computed FinancialPlanningCalculator/
// BudgetCalculator output. Synthetic data only. Follows the same
// AnalyticsSummary/Wallet/Goal/Loan construction pattern as
// financial_planning_calculator_test.dart so each scenario stays easy to
// reason about.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/subscription_summary.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/financial_action_engine.dart';
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

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: balance, currentBalance: balance, createdAt: DateTime(2026, 1, 1),
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
    id: id, title: id, targetAmount: target, currentAmount: current, targetDate: targetDate,
    category: 'Other', icon: 'savings', color: 0xFF000000, createdAt: createdAt,
  );
}

Loan _loan({
  required String id,
  required double principal,
  required double outstanding,
  required double emi,
}) {
  final loan = Loan.create(
    id: id, loanName: id, lenderName: 'Bank', loanType: 'Personal',
    principalAmount: principal, interestRate: 10, tenureMonths: 24, emiAmount: emi,
    totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1),
    nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1),
  );
  return loan.copyWith(outstandingAmount: outstanding, endDate: DateTime(2028, 1, 1));
}

Budget _budget({
  required String id,
  required String category,
  required double allocated,
  required double spent,
}) {
  return Budget(
    id: id, categoryId: category, categoryName: category, allocatedAmount: allocated,
    spentAmount: spent, remainingAmount: allocated - spent,
    percentageUsed: allocated > 0 ? spent / allocated * 100 : 0,
    month: 'August', year: 2026, createdAt: DateTime(2026, 8, 1),
  );
}

FinancialPlanningResult _planning({
  List<Transaction> transactions = const [],
  List<Wallet> wallets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  List<RecurringTransaction> recurringTransactions = const [],
  AnalyticsSummary? analytics,
  List<String>? emergencyFundEligibleWalletIds,
}) {
  return FinancialPlanningCalculator.calculate(
    transactions: transactions,
    wallets: wallets,
    goals: goals,
    loans: loans,
    bills: const [],
    recurringTransactions: recurringTransactions,
    analytics: analytics ?? _analytics(monthlyTotals: [_mt(DateTime(2026, 8))]),
    emergencyFundEligibleWalletIds: emergencyFundEligibleWalletIds,
    now: _now,
  );
}

void main() {
  group('1. Emergency fund gap', () {
    test('a configured, incomplete emergency fund surfaces a gap action with a safe recommendation', () {
      final planning = _planning(
        wallets: [_wallet('w1', 20000)],
        emergencyFundEligibleWalletIds: ['w1'],
        analytics: _analytics(
          monthlyTotals: [
            _mt(DateTime(2026, 6), income: 50000, expense: 30000),
            _mt(DateTime(2026, 7), income: 50000, expense: 30000),
            _mt(DateTime(2026, 8), income: 50000, expense: 30000),
          ],
          currentMonthIncome: 50000,
          currentMonthExpense: 30000,
        ),
      );
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );

      expect(plan.actions.any((a) => a.actionType == ActionType.emergencyFundGap), isTrue);
      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.emergencyFundGap);
      expect(action.supportingAmount, greaterThan(0));
      // The recommended monthly amount can never exceed real monthly savings.
      expect(action.recommendedAction, contains('₹20000')); // 50000 - 30000 = monthly savings
    });
  });

  group('2. Over-budget category', () {
    test('an over-budget category surfaces the largest overspend by name', () {
      final planning = _planning(wallets: [_wallet('w1', 50000)]);
      final budgets = [
        _budget(id: 'b1', category: 'Food', allocated: 10000, spent: 15000),
        _budget(id: 'b2', category: 'Shopping', allocated: 5000, spent: 5500),
      ];
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: budgets),
      );

      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.overBudget);
      expect(action.priority, ActionPriority.high);
      expect(action.relatedEntityName, 'Food'); // larger overspend: 5000 > 500
      expect(action.supportingAmount, 5500); // total overspend across both categories
    });
  });

  group('3. Near-limit category', () {
    test('a category between 80% and 100% used surfaces a near-limit action, not over-budget', () {
      final planning = _planning(wallets: [_wallet('w1', 50000)]);
      final budgets = [_budget(id: 'b1', category: 'Travel', allocated: 10000, spent: 8500)];
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: budgets),
      );

      expect(plan.actions.any((a) => a.actionType == ActionType.overBudget), isFalse);
      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.nearBudgetLimit);
      expect(action.relatedEntityName, 'Travel');
      expect(action.supportingPercentage, 85);
    });
  });

  group('4. Savings decline', () {
    test('a current month materially below the historical average surfaces a decline action', () {
      final planning = _planning(
        wallets: [_wallet('w1', 100000)],
        analytics: _analytics(
          monthlyTotals: [
            _mt(DateTime(2026, 5), income: 50000, expense: 20000), // 60% rate
            _mt(DateTime(2026, 6), income: 50000, expense: 20000),
            _mt(DateTime(2026, 7), income: 50000, expense: 20000),
            _mt(DateTime(2026, 8), income: 50000, expense: 45000), // 10% rate this month
          ],
          currentMonthIncome: 50000,
          currentMonthExpense: 45000,
        ),
      );
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );

      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.savingsRateDecline);
      expect(action.supportingPercentage, greaterThanOrEqualTo(FinancialActionEngine.savingsRateDeclineThresholdPoints));
    });

    test('a stable savings rate never fires the decline rule', () {
      final planning = _planning(
        wallets: [_wallet('w1', 100000)],
        analytics: _analytics(
          monthlyTotals: [
            _mt(DateTime(2026, 6), income: 50000, expense: 20000),
            _mt(DateTime(2026, 7), income: 50000, expense: 20000),
            _mt(DateTime(2026, 8), income: 50000, expense: 21000),
          ],
          currentMonthIncome: 50000,
          currentMonthExpense: 21000,
        ),
      );
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      expect(plan.actions.any((a) => a.actionType == ActionType.savingsRateDecline), isFalse);
    });
  });

  group('5. Debt burden', () {
    test('a high EMI-to-income ratio (needsAttention) surfaces a debt action', () {
      final planning = _planning(
        wallets: [_wallet('w1', 50000)],
        loans: [_loan(id: 'l1', principal: 500000, outstanding: 400000, emi: 35000)],
        analytics: _analytics(
          monthlyTotals: [_mt(DateTime(2026, 8), income: 50000, expense: 30000)],
          currentMonthIncome: 50000,
          currentMonthExpense: 30000,
        ),
      );
      expect(planning.debtStatus, PlanningComponentStatus.needsAttention);

      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.highDebtBurden);
      expect(action.priority, ActionPriority.high);
      expect(action.explanation, contains('not professional financial advice'));
    });

    test('no debt never fires the debt rule', () {
      final planning = _planning(wallets: [_wallet('w1', 50000)]);
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      expect(plan.actions.any((a) => a.actionType == ActionType.highDebtBurden), isFalse);
    });
  });

  group('6. Subscription burden', () {
    test('material recurring subscription cost surfaces the largest subscription by name', () {
      final planning = _planning(
        wallets: [_wallet('w1', 50000)],
        recurringTransactions: [
          RecurringTransaction.create(
            id: 'r1', title: 'Netflix', amount: 500, categoryId: 'Entertainment', accountId: 'w1',
            transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ).copyWith(nextDueDate: DateTime(2026, 9, 1)),
          RecurringTransaction.create(
            id: 'r2', title: 'Spotify', amount: 200, categoryId: 'Entertainment', accountId: 'w1',
            transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ).copyWith(nextDueDate: DateTime(2026, 9, 1)),
        ],
      );
      final subscriptions = [
        SubscriptionSummary(
          id: 'r1', name: 'Netflix', amount: 500, frequency: 'Monthly', nextDueDate: DateTime(2026, 9, 1),
          category: 'Entertainment', account: 'w1', monthlyEquivalent: 500, annualCost: 6000,
          status: SubscriptionStatus.active, sourceId: 'r1',
        ),
        SubscriptionSummary(
          id: 'r2', name: 'Spotify', amount: 200, frequency: 'Monthly', nextDueDate: DateTime(2026, 9, 1),
          category: 'Entertainment', account: 'w1', monthlyEquivalent: 200, annualCost: 2400,
          status: SubscriptionStatus.active, sourceId: 'r2',
        ),
      ];

      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const [], subscriptions: subscriptions),
      );
      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.subscriptionCost);
      expect(action.relatedEntityName, 'Netflix');
      expect(action.supportingAmount, 700);
    });

    test('a tiny subscription cost below the materiality threshold never fires', () {
      final planning = _planning(
        wallets: [_wallet('w1', 50000)],
        recurringTransactions: [
          RecurringTransaction.create(
            id: 'r1', title: 'Small', amount: 50, categoryId: 'Entertainment', accountId: 'w1',
            transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ).copyWith(nextDueDate: DateTime(2026, 9, 1)),
        ],
      );
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      expect(plan.actions.any((a) => a.actionType == ActionType.subscriptionCost), isFalse);
    });
  });

  group('7. Goal at risk', () {
    test('a goal far behind its own required pace surfaces an at-risk action', () {
      final planning = _planning(
        wallets: [_wallet('w1', 50000)],
        goals: [
          _goal(
            id: 'g1', target: 500000, current: 5000,
            createdAt: DateTime(2025, 1, 1), // 19 months old, barely funded -> low implied pace
            targetDate: DateTime(2026, 12, 1), // only 4 months left -> high required pace
          ),
        ],
      );
      final goalProjection = planning.goalProjections.first;
      expect(goalProjection.status, GoalProjectionStatus.atRisk);

      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      final action = plan.actions.firstWhere((a) => a.actionType == ActionType.goalAtRisk);
      expect(action.relatedEntityName, 'g1');
      expect(action.supportingAmount, greaterThan(0));
    });
  });

  group('8. Positive state', () {
    test('a healthy profile with no problems surfaces exactly one positive action, never fabricated', () {
      final planning = _planning(
        wallets: [_wallet('w1', 500000)],
        emergencyFundEligibleWalletIds: ['w1'],
        analytics: _analytics(
          monthlyTotals: [
            _mt(DateTime(2026, 6), income: 50000, expense: 20000),
            _mt(DateTime(2026, 7), income: 50000, expense: 20000),
            _mt(DateTime(2026, 8), income: 50000, expense: 20000),
          ],
          currentMonthIncome: 50000,
          currentMonthExpense: 20000,
        ),
      );

      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      expect(plan.actions, hasLength(1));
      expect(plan.actions.single.actionType, ActionType.allGood);
      expect(plan.actions.single.priority, ActionPriority.positive);
    });
  });

  group('9. Maximum 3 actions', () {
    test('many simultaneous problems are still capped at 3 actions', () {
      final planning = _planning(
        wallets: [_wallet('w1', 20000)],
        emergencyFundEligibleWalletIds: ['w1'],
        loans: [_loan(id: 'l1', principal: 500000, outstanding: 400000, emi: 35000)],
        goals: [
          _goal(
            id: 'g1', target: 500000, current: 5000,
            createdAt: DateTime(2025, 1, 1), targetDate: DateTime(2026, 12, 1),
          ),
        ],
        recurringTransactions: [
          RecurringTransaction.create(
            id: 'r1', title: 'Netflix', amount: 2000, categoryId: 'Entertainment', accountId: 'w1',
            transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ).copyWith(nextDueDate: DateTime(2026, 9, 1)),
        ],
        analytics: _analytics(
          monthlyTotals: [_mt(DateTime(2026, 8), income: 50000, expense: 30000)],
          currentMonthIncome: 50000,
          currentMonthExpense: 30000,
        ),
      );
      final budgets = [
        _budget(id: 'b1', category: 'Food', allocated: 10000, spent: 15000),
        _budget(id: 'b2', category: 'Travel', allocated: 10000, spent: 8500),
      ];

      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: budgets),
      );
      expect(plan.actions.length, lessThanOrEqualTo(FinancialActionEngine.maxActions));
    });
  });

  group('10. Priority ordering', () {
    test('critical/high-priority actions are ordered before medium ones', () {
      final planning = _planning(
        wallets: [_wallet('w1', 20000)],
        loans: [_loan(id: 'l1', principal: 500000, outstanding: 400000, emi: 35000)],
        analytics: _analytics(
          monthlyTotals: [_mt(DateTime(2026, 8), income: 50000, expense: 30000)],
          currentMonthIncome: 50000,
          currentMonthExpense: 30000,
        ),
      );
      final budgets = [_budget(id: 'b1', category: 'Travel', allocated: 10000, spent: 8500)];

      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: budgets),
      );
      for (var i = 0; i < plan.actions.length - 1; i++) {
        expect(
          plan.actions[i].priority.index,
          lessThanOrEqualTo(plan.actions[i + 1].priority.index),
        );
      }
    });
  });

  group('11. Empty data', () {
    test('a brand-new account with nothing at all never crashes and produces no fabricated actions', () {
      final planning = _planning();
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      // Nothing measurably good AND nothing measurably wrong -> no actions,
      // never a manufactured "you are on track".
      expect(plan.actions, isEmpty);
    });
  });

  group('12. No fabricated action', () {
    test('a merely fair (not good, not bad) profile produces neither a warning nor false praise', () {
      // A 12% savings rate scores 60/100 in this app's own established
      // savings scoring (rate / 20% recommended * 100) — squarely "fair"
      // (40-69), not "good" (>=70) and not "needsAttention" (<40).
      final planning = _planning(
        wallets: [_wallet('w1', 100000)],
        analytics: _analytics(
          monthlyTotals: [
            _mt(DateTime(2026, 6), income: 50000, expense: 44000),
            _mt(DateTime(2026, 7), income: 50000, expense: 44000),
            _mt(DateTime(2026, 8), income: 50000, expense: 44000),
          ],
          currentMonthIncome: 50000,
          currentMonthExpense: 44000,
        ),
      );
      final plan = FinancialActionEngine.generate(
        FinancialActionEngineInput(planning: planning, budgets: const []),
      );
      expect(plan.actions.any((a) => a.actionType == ActionType.allGood), isFalse);
    });
  });
}
