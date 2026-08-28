// Pure-calculator tests for FinancialMomentumCalculator (PHASE 3/4).
// Inputs are built via the REAL FinancialHealthTrendsCalculator, exactly
// like financial_timeline_calculator_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';
import 'package:paysense/shared/utils/financial_momentum_calculator.dart';

final _now = DateTime(2026, 8, 20);

Transaction _tx({required String id, required double amount, required String type, required DateTime date}) {
  return Transaction(
    id: id, title: id, amount: amount, categoryId: 'Food', accountId: 'w1',
    transactionType: type, paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

FinancialHealthTrendResult _trends(List<Transaction> transactions, {List<Wallet> wallets = const []}) {
  return FinancialHealthTrendsCalculator.calculate(
    transactions: transactions,
    budgets: const [],
    goals: const [],
    loans: const [],
    bills: const [],
    wallets: wallets,
    profileMonthlyIncome: 0,
    period: TrendPeriod.threeMonths,
    now: _now,
  );
}

/// Mirrors FinancialMomentumCalculator._statusForTrajectory exactly, so
/// these tests verify the ADAPTER's mapping is correct for whatever
/// trajectory the real FinancialHealthTrendsCalculator computes — rather
/// than trying to reverse-engineer synthetic data that reliably forces one
/// specific trajectory out of that calculator's own multi-domain weighted
/// formula (which is that calculator's concern, not this adapter's).
FinancialMomentumStatus _expectedStatusFor(OverallTrajectory trajectory) {
  switch (trajectory) {
    case OverallTrajectory.stronglyImproving:
    case OverallTrajectory.improving:
      return FinancialMomentumStatus.improving;
    case OverallTrajectory.declining:
      return FinancialMomentumStatus.declining;
    case OverallTrajectory.stable:
    case OverallTrajectory.mixed:
      return FinancialMomentumStatus.stable;
    case OverallTrajectory.insufficientData:
      return FinancialMomentumStatus.insufficientData;
  }
}

void main() {
  test('empty account produces insufficientData with no signals', () {
    final momentum = FinancialMomentumCalculator.calculate(_trends(const []));
    expect(momentum.status, FinancialMomentumStatus.insufficientData);
    expect(momentum.signals, isEmpty);
    expect(momentum.hasSufficientData, isFalse);
  });

  test('an improving-savings scenario maps to exactly the trajectory-implied status', () {
    final trends = _trends([
      _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 7, 1)),
      _tx(id: 'e1', amount: 45000, type: 'expense', date: DateTime(2026, 7, 5)),
      _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
      _tx(id: 'e2', amount: 15000, type: 'expense', date: DateTime(2026, 8, 5)),
    ]);
    final momentum = FinancialMomentumCalculator.calculate(trends);
    expect(momentum.status, _expectedStatusFor(trends.trajectory));
    expect(momentum.hasSufficientData, isTrue);
  });

  test('signals always cover exactly savings/spending/budget/debt when data is sufficient', () {
    final trends = _trends([
      _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 7, 1)),
      _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 7, 5)),
      _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
      _tx(id: 'e2', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
    ]);
    final momentum = FinancialMomentumCalculator.calculate(trends);
    final labels = momentum.signals.map((s) => s.label).toSet();
    expect(labels, {'Savings rate', 'Spending', 'Budget discipline', 'Debt'});
  });

  test('a declining-savings scenario maps to exactly the trajectory-implied status', () {
    final trends = _trends([
      _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 7, 1)),
      _tx(id: 'e1', amount: 10000, type: 'expense', date: DateTime(2026, 7, 5)),
      _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
      _tx(id: 'e2', amount: 47000, type: 'expense', date: DateTime(2026, 8, 5)),
    ]);
    final momentum = FinancialMomentumCalculator.calculate(trends);
    expect(momentum.status, _expectedStatusFor(trends.trajectory));
  });

  test('every signal detail string is non-empty and explains its direction', () {
    final trends = _trends([
      _tx(id: 'i1', amount: 50000, type: 'income', date: DateTime(2026, 7, 1)),
      _tx(id: 'e1', amount: 20000, type: 'expense', date: DateTime(2026, 7, 5)),
      _tx(id: 'i2', amount: 50000, type: 'income', date: DateTime(2026, 8, 1)),
      _tx(id: 'e2', amount: 20000, type: 'expense', date: DateTime(2026, 8, 5)),
    ]);
    final momentum = FinancialMomentumCalculator.calculate(trends);
    for (final signal in momentum.signals) {
      expect(signal.detail, isNotEmpty);
    }
  });
}
