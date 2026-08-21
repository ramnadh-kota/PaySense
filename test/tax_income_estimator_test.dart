// Focused tests for TaxIncomeEstimator (PHASE 3). Synthetic data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/tax_income_estimator.dart';

Transaction _income(String id, double amount, DateTime date) {
  return Transaction(
    id: id, title: 'Salary', amount: amount, categoryId: 'Salary', accountId: 'w1',
    transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

Transaction _expense(String id, double amount, DateTime date) {
  return Transaction(
    id: id, title: 'Rent', amount: amount, categoryId: 'Rent', accountId: 'w1',
    transactionType: 'Expense', paymentMethod: 'Bank', note: '', createdAt: date,
  );
}

void main() {
  group('2. Annual income estimation', () {
    test('a regular monthly salary projects to a plausible annual estimate', () {
      final now = DateTime(2026, 8, 20); // FY2026-27, Apr-Aug = 5 elapsed months
      final transactions = [
        _income('t1', 100000, DateTime(2026, 4, 5)),
        _income('t2', 100000, DateTime(2026, 5, 5)),
        _income('t3', 100000, DateTime(2026, 6, 5)),
        _income('t4', 100000, DateTime(2026, 7, 5)),
        _income('t5', 100000, DateTime(2026, 8, 5)),
        _expense('t6', 20000, DateTime(2026, 8, 10)),
      ];

      final estimate = TaxIncomeEstimator.estimate(transactions, now);
      expect(estimate.observedMonths, 5);
      expect(estimate.observedIncome, 500000);
      expect(estimate.averageMonthlyIncome, 100000);
      expect(estimate.estimatedAnnualIncome, 1200000);
      expect(estimate.isEstimate, isTrue);
      expect(estimate.hasIncomeData, isTrue);
      expect(estimate.isIrregular, isFalse);
    });
  });

  group('3. Partial-year income', () {
    test('only 2 months into the FY still produces a labelled, honest estimate', () {
      final now = DateTime(2026, 5, 15);
      final transactions = [
        _income('t1', 80000, DateTime(2026, 4, 10)),
        _income('t2', 80000, DateTime(2026, 5, 10)),
      ];

      final estimate = TaxIncomeEstimator.estimate(transactions, now);
      expect(estimate.observedMonths, 2);
      expect(estimate.estimationPeriodLabel, contains('2 months'));
      expect(estimate.estimatedAnnualIncome, 960000);
    });
  });

  group('4. Irregular income', () {
    test('a month with no income transaction at all is flagged as irregular', () {
      final now = DateTime(2026, 6, 20);
      final transactions = [
        _income('t1', 100000, DateTime(2026, 4, 5)),
        // No income in May.
        _income('t3', 100000, DateTime(2026, 6, 5)),
      ];

      final estimate = TaxIncomeEstimator.estimate(transactions, now);
      expect(estimate.observedMonths, 3);
      expect(estimate.isIrregular, isTrue);
    });
  });

  group('9. Zero income (estimator)', () {
    test('no income transactions at all reports hasIncomeData=false, never a fabricated estimate', () {
      final now = DateTime(2026, 8, 20);
      final estimate = TaxIncomeEstimator.estimate(const [], now);
      expect(estimate.hasIncomeData, isFalse);
      expect(estimate.observedIncome, 0);
      expect(estimate.estimatedAnnualIncome, 0);
    });
  });

  group('Financial year bounds', () {
    test('a date in Jan-Mar belongs to the FY that started the previous April', () {
      final (start, end) = TaxIncomeEstimator.financialYearBounds(DateTime(2027, 2, 10));
      expect(start, DateTime(2026, 4, 1));
      expect(end, DateTime(2027, 3, 31));
    });

    test('a date in Apr-Dec belongs to the FY starting that same April', () {
      final (start, end) = TaxIncomeEstimator.financialYearBounds(DateTime(2026, 8, 20));
      expect(start, DateTime(2026, 4, 1));
      expect(end, DateTime(2027, 3, 31));
    });
  });
}
