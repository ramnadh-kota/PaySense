import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  required String categoryId,
  required DateTime createdAt,
}) {
  return Transaction(
    id: id,
    title: id,
    amount: amount,
    categoryId: categoryId,
    accountId: 'Cash',
    transactionType: type,
    paymentMethod: 'card',
    note: '',
    createdAt: createdAt,
  );
}

void main() {
  group('buildAnalyticsSummary', () {
    test('returns all-zero data for an empty transaction list', () {
      final summary = buildAnalyticsSummary(const [], DateTime(2026, 8, 15));

      expect(summary.monthlyTotals, hasLength(analyticsTrendMonths));
      expect(summary.monthlyTotals.every((m) => m.income == 0 && m.expense == 0), isTrue);
      expect(summary.categoryBreakdown, isEmpty);
      expect(summary.currentMonthIncome, 0.0);
      expect(summary.currentMonthExpense, 0.0);
      expect(summary.savingsRate, 0.0);
    });

    test('buckets income and expense into the correct trailing months', () {
      final now = DateTime(2026, 8, 15);
      final transactions = [
        _tx(
          id: 't1',
          amount: 50000,
          type: 'income',
          categoryId: 'Salary',
          createdAt: DateTime(2026, 8, 1),
        ),
        _tx(
          id: 't2',
          amount: 12000,
          type: 'expense',
          categoryId: 'Groceries',
          createdAt: DateTime(2026, 8, 5),
        ),
        _tx(
          id: 't3',
          amount: 20000,
          type: 'income',
          categoryId: 'Salary',
          createdAt: DateTime(2026, 7, 1),
        ),
        // Outside the 6-month trend window (Mar 2026 is excluded when the
        // window is Mar..Aug only by inclusion of the boundary month).
        _tx(
          id: 't4',
          amount: 99999,
          type: 'expense',
          categoryId: 'Old',
          createdAt: DateTime(2025, 1, 1),
        ),
      ];

      final summary = buildAnalyticsSummary(transactions, now);

      expect(summary.monthlyTotals, hasLength(6));
      expect(summary.monthlyTotals.first.month, DateTime(2026, 3, 1));
      expect(summary.monthlyTotals.last.month, DateTime(2026, 8, 1));

      final august = summary.monthlyTotals.last;
      expect(august.income, 50000.0);
      expect(august.expense, 12000.0);

      final july = summary.monthlyTotals[summary.monthlyTotals.length - 2];
      expect(july.income, 20000.0);
      expect(july.expense, 0.0);

      // The Jan 2025 transaction must not leak into any bucket.
      expect(
        summary.monthlyTotals.fold<double>(0, (s, m) => s + m.expense),
        12000.0,
      );

      expect(summary.currentMonthIncome, 50000.0);
      expect(summary.currentMonthExpense, 12000.0);
      expect(summary.savingsRate, closeTo(76.0, 0.01));
    });

    test(
      'category breakdown only includes current-month expenses, sorted '
      'descending with percentages',
      () {
        final now = DateTime(2026, 8, 15);
        final transactions = [
          _tx(
            id: 't1',
            amount: 3000,
            type: 'expense',
            categoryId: 'Groceries',
            createdAt: DateTime(2026, 8, 2),
          ),
          _tx(
            id: 't2',
            amount: 1000,
            type: 'expense',
            categoryId: 'Dining',
            createdAt: DateTime(2026, 8, 3),
          ),
          _tx(
            id: 't3',
            amount: 500,
            type: 'expense',
            categoryId: 'Dining',
            createdAt: DateTime(2026, 8, 10),
          ),
          // Income should never appear in the breakdown.
          _tx(
            id: 't4',
            amount: 99999,
            type: 'income',
            categoryId: 'Salary',
            createdAt: DateTime(2026, 8, 1),
          ),
          // Last month's expense should be excluded.
          _tx(
            id: 't5',
            amount: 99999,
            type: 'expense',
            categoryId: 'Groceries',
            createdAt: DateTime(2026, 7, 1),
          ),
        ];

        final summary = buildAnalyticsSummary(transactions, now);

        expect(summary.categoryBreakdown, hasLength(2));
        expect(summary.categoryBreakdown.first.categoryId, 'Groceries');
        expect(summary.categoryBreakdown.first.amount, 3000.0);
        expect(summary.categoryBreakdown.first.percentage, closeTo(200 / 3, 0.01));
        expect(summary.categoryBreakdown.last.categoryId, 'Dining');
        expect(summary.categoryBreakdown.last.amount, 1500.0);
      },
    );

    test('savings rate is 0 when there is no income, never divides by zero', () {
      final now = DateTime(2026, 8, 15);
      final transactions = [
        _tx(
          id: 't1',
          amount: 500,
          type: 'expense',
          categoryId: 'Dining',
          createdAt: DateTime(2026, 8, 5),
        ),
      ];

      final summary = buildAnalyticsSummary(transactions, now);

      expect(summary.currentMonthIncome, 0.0);
      expect(summary.savingsRate, 0.0);
    });
  });
}
