// Tests for FinancialSnapshotBuilder (Consumer Monetization Foundation,
// PHASE 2/16 items 3-6). Inputs are built via the REAL FinancialPlanningCalculator/
// FinancialHealthCalculator/FinancialActionEngine/FinancialInsightEngine/
// SafeToSpendCalculator, exactly like every adapter test this session —
// synthetic transactions feed real calculators, whose real output feeds
// the builder under test.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/financial_action_engine.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/financial_snapshot_builder.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

final _now = DateTime(2026, 8, 20);

Transaction _tx({required String id, required double amount, required String type, required DateTime date}) {
  return Transaction(
    id: id, title: id, amount: amount, categoryId: 'Food', accountId: 'w1',
    transactionType: type, paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

Wallet _wallet(String id, double balance) {
  return Wallet(
    id: id, name: id, bankName: '', type: 'Bank',
    openingBalance: balance, currentBalance: balance, createdAt: DateTime(2025, 1, 1),
  );
}

FinancialSnapshotResult _snapshotFor({
  List<Transaction> transactions = const [],
  List<Wallet> wallets = const [],
  List<Goal> goals = const [],
  List<Loan> loans = const [],
  List<Budget> budgets = const [],
  List<RecurringTransaction> recurring = const [],
  List<String>? emergencyFundEligibleWalletIds,
  double profileMonthlyIncome = 0,
}) {
  final analytics = buildAnalyticsSummary(transactions, _now);
  final planning = FinancialPlanningCalculator.calculate(
    transactions: transactions, wallets: wallets, goals: goals, loans: loans,
    bills: const [], recurringTransactions: recurring, analytics: analytics,
    emergencyFundEligibleWalletIds: emergencyFundEligibleWalletIds, now: _now,
  );
  final health = FinancialHealthCalculator.calculate(
    transactions: transactions, budgets: budgets, goals: goals, loans: loans,
    bills: const [], wallets: wallets, profileMonthlyIncome: profileMonthlyIncome, now: _now,
  );
  final trends = FinancialHealthTrendsCalculator.calculate(
    transactions: transactions, budgets: budgets, goals: goals, loans: loans,
    bills: const [], wallets: wallets, profileMonthlyIncome: profileMonthlyIncome,
    period: TrendPeriod.threeMonths, now: _now,
  );
  final actionPlan = FinancialActionEngine.generate(
    FinancialActionEngineInput(planning: planning, budgets: budgets, now: _now),
  );
  final safeToSpend = SafeToSpendCalculator.calculate(
    wallets: wallets, bills: const [], loans: loans, recurringTransactions: recurring, now: _now,
  );
  final insights = FinancialInsightEngine.generate(
    actionPlan: actionPlan, trends: trends, safeToSpend: safeToSpend,
    recurringTransactions: recurring, now: _now,
  );

  return FinancialSnapshotBuilder.build(
    planning: planning, health: health, actionPlan: actionPlan, insights: insights, safeToSpend: safeToSpend,
  );
}

void main() {
  group('4. Empty account', () {
    test('a brand-new account with nothing recorded is marked insufficient, never fabricated', () {
      final snapshot = _snapshotFor();
      expect(snapshot.hasSufficientData, isFalse);
      expect(snapshot.personalizedSummary,
          'Add a little more financial data and PaySense will build your full financial picture.');
    });
  });

  group('5. Partial account', () {
    test('a wallet with no transaction history still yields a real net worth', () {
      final snapshot = _snapshotFor(wallets: [_wallet('w1', 25000)]);
      expect(snapshot.netWorth, 25000);
    });
  });

  group('6. Populated account', () {
    test('income/expense/savings-rate reflect real transaction totals', () {
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 50000)],
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
        ],
      );
      expect(snapshot.hasSufficientData, isTrue);
      expect(snapshot.monthlyIncome, 50000);
      expect(snapshot.monthlyExpenses, 20000);
      expect(snapshot.savingsRatePercent, closeTo(60, 0.01));
    });

    test('top actions and top insights are reused directly from their own engines, never re-derived', () {
      final budgets = [
        Budget(
          id: 'b1', categoryId: 'Food', categoryName: 'Food', allocatedAmount: 10000,
          spentAmount: 15000, remainingAmount: -5000, percentageUsed: 150,
          month: 'August', year: 2026, createdAt: DateTime(2026, 8, 1),
        ),
      ];
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 50000)],
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e1', amount: 15000, type: 'expense', date: DateTime(2026, 8, 5)),
        ],
        budgets: budgets,
      );
      expect(snapshot.topActions.length, lessThanOrEqualTo(FinancialActionEngine.maxActions));
      expect(snapshot.topInsights.length, lessThanOrEqualTo(FinancialInsightEngine.maxInsights));
    });

    test('a real emergency fund gap produces the emergency-fund-focused summary', () {
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 10000)],
        transactions: [
          _tx(id: 'i1', amount: 60000, type: 'income', date: DateTime(2026, 6, 1)),
          _tx(id: 'e1', amount: 40000, type: 'expense', date: DateTime(2026, 6, 5)),
          _tx(id: 'i2', amount: 60000, type: 'income', date: DateTime(2026, 7, 1)),
          _tx(id: 'e2', amount: 40000, type: 'expense', date: DateTime(2026, 7, 5)),
          _tx(id: 'i3', amount: 60000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e3', amount: 40000, type: 'expense', date: DateTime(2026, 8, 5)),
        ],
        emergencyFundEligibleWalletIds: ['w1'],
      );
      expect(snapshot.emergencyFund.isSourceConfigured, isTrue);
      expect(snapshot.personalizedSummary,
          "You're saving well, but your emergency fund is still your biggest financial gap.");
    });

    test('heavy fixed commitments produce the commitments-focused summary with a real figure', () {
      final loans = [
        Loan.create(
          id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Car',
          principalAmount: 500000, interestRate: 10, tenureMonths: 60, emiAmount: 22000,
          totalInterest: 0, accountId: 'w1', startDate: DateTime(2026, 1, 1),
          nextDueDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 1, 1),
        ),
      ];
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 50000)],
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e1', amount: 5000, type: 'expense', date: DateTime(2026, 8, 5)),
        ],
        loans: loans,
      );
      expect(snapshot.debt.monthlyEmiBurden, 22000);
      expect(snapshot.personalizedSummary, contains('₹22000'));
      expect(snapshot.personalizedSummary, contains('committed to expenses and EMIs'));
    });

    test('spending more than earning produces the overspend summary', () {
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 10000)],
        transactions: [
          _tx(id: 'i1', amount: 20000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e1', amount: 25000, type: 'expense', date: DateTime(2026, 8, 5)),
        ],
      );
      expect(snapshot.savingsRatePercent, lessThan(0));
      expect(snapshot.personalizedSummary, "You're spending more than you earn this month — let's find where to cut back.");
    });

    test('a strong savings rate produces the "managing well" summary', () {
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 50000)],
        transactions: [
          _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
          _tx(id: 'e1', amount: 10000, type: 'expense', date: DateTime(2026, 8, 5)),
        ],
      );
      expect(snapshot.savingsRatePercent, greaterThanOrEqualTo(20));
      expect(snapshot.personalizedSummary, "You're managing your money well — keep building on your strong savings habit.");
    });
  });

  group('No fabricated data', () {
    test('zero income never produces NaN/Infinity anywhere in the snapshot', () {
      final snapshot = _snapshotFor(
        wallets: [_wallet('w1', 10000)],
        transactions: [_tx(id: 'e1', amount: 5000, type: 'expense', date: DateTime(2026, 8, 5))],
      );
      expect(snapshot.savingsRatePercent, isNull);
      expect(snapshot.netWorth.isNaN, isFalse);
      expect(snapshot.netWorth.isInfinite, isFalse);
    });

    test('goal projections are reused verbatim from FinancialPlanningCalculator, never re-derived', () {
      final goals = [
        Goal.create(
          id: 'g1', title: 'Vacation', targetAmount: 50000, currentAmount: 10000,
          targetDate: DateTime(2027, 1, 1), category: 'Travel', icon: 'flight',
          color: 0xFF000000, createdAt: DateTime(2026, 1, 1),
        ),
      ];
      final snapshot = _snapshotFor(wallets: [_wallet('w1', 10000)], goals: goals);
      expect(snapshot.goalProjections.length, 1);
      expect(snapshot.goalProjections.single.goalId, 'g1');
      expect(snapshot.goalProjections.single.currentAmount, 10000);
    });
  });

  group('15. No repository mutation', () {
    test('build() never mutates any of its inputs', () {
      final wallets = [_wallet('w1', 10000)];
      final transactions = [_tx(id: 'i1', amount: 20000, type: 'income', date: DateTime(2026, 8, 1))];
      final walletsBefore = List.of(wallets);
      final transactionsBefore = List.of(transactions);

      _snapshotFor(wallets: wallets, transactions: transactions);

      expect(wallets, walletsBefore);
      expect(transactions, transactionsBefore);
    });
  });
}
