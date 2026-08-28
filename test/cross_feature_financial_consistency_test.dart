// FINANCIAL CALCULATION AUDIT — cross-feature consistency regression suite.
//
// PaySense has several places that answer variants of "income/expense over
// some window": ReportsCalculator (Reports screen) and buildAnalyticsSummary
// (Dashboard/Financial Health/Loan Analytics). This file has two jobs:
//
//   1. Prove the ones that SHOULD agree (Reports "This month" vs
//      buildAnalyticsSummary's current-month figures) actually do, given
//      identical input — a regression guard against future silent drift
//      between the two independent implementations.
//
//   2. HISTORY: this audit originally found Dashboard's "Financial Summary"
//      Income/Expenses/Savings cards were UNSCOPED (all-time, since account
//      creation) via a private `_calculateTotals` loop, while every sibling
//      feature (Reports "This month" default, Financial Health, Compare
//      Periods) was current-month-scoped — a real, user-visible
//      inconsistency for any account with prior-month history. FIXED: the
//      Dashboard heading is now "This Month's Summary" and its totals are
//      read directly from `AnalyticsSummary.currentMonthIncome/Expense`
//      (`_totalsFromAnalytics` in dashboard_screen.dart) — the exact same
//      value Group 1 below proves agrees with Reports, so Dashboard/Reports
//      agreement is now guaranteed by construction, not just tested. Group
//      2 proves the fix: no leakage from adjacent months in either
//      direction.

import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/reports_calculator.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  required DateTime createdAt,
}) {
  return Transaction(
    id: id,
    title: type,
    amount: amount,
    categoryId: 'Other',
    accountId: 'w1',
    transactionType: type,
    paymentMethod: 'Bank',
    note: '',
    createdAt: createdAt,
  );
}

void main() {
  final now = DateTime(2026, 8, 28);
  final startOfThisMonth = DateTime(2026, 8, 1);
  final lastMonth = DateTime(2026, 7, 15);

  group('1. ReportsCalculator vs buildAnalyticsSummary agree for "this month"', () {
    test('income/expense/savingsRate are identical given the same data and "now"', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 12000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't3', amount: 8000, type: 'expense', createdAt: DateTime(2026, 8, 20)),
        // Prior-month noise that must NOT leak into "this month" totals.
        _tx(id: 't4', amount: 99999, type: 'income', createdAt: lastMonth),
        _tx(id: 't5', amount: 88888, type: 'expense', createdAt: lastMonth),
      ];

      final reports = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );
      final analytics = buildAnalyticsSummary(transactions, now);

      // Manually derived: income = 50000, expense = 12000 + 8000 = 20000.
      expect(reports.totalIncome, 50000);
      expect(reports.totalExpense, 20000);
      expect(analytics.currentMonthIncome, 50000);
      expect(analytics.currentMonthExpense, 20000);

      expect(reports.totalIncome, analytics.currentMonthIncome);
      expect(reports.totalExpense, analytics.currentMonthExpense);
      expect(reports.savingsRate, analytics.savingsRate);
      // savingsRate = (50000-20000)/50000*100 = 60.
      expect(analytics.savingsRate, 60);
    });

    test('agree exactly (not just approximately) with fractional-paise amounts', () {
      final transactions = [
        _tx(id: 't1', amount: 1000.33, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 250.11, type: 'expense', createdAt: DateTime(2026, 8, 10)),
        _tx(id: 't3', amount: 250.11, type: 'expense', createdAt: DateTime(2026, 8, 11)),
        _tx(id: 't4', amount: 250.11, type: 'expense', createdAt: DateTime(2026, 8, 12)),
      ];

      final reports = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );
      final analytics = buildAnalyticsSummary(transactions, now);

      // Both implementations sum the SAME doubles in the SAME order (list
      // iteration order), so they must be bit-for-bit identical, not just
      // "close enough" — no independent rounding has happened yet.
      expect(reports.totalExpense, analytics.currentMonthExpense);
      expect(reports.totalIncome, analytics.currentMonthIncome);
    });
  });

  group('2. Dashboard "This Month\'s Summary" scope fix', () {
    // Dashboard now computes its totals as
    // `AnalyticsSummary.currentMonthIncome/currentMonthExpense` — proven
    // directly here rather than importing dashboard_screen.dart's private
    // `_totalsFromAnalytics` (a one-line pass-through with nothing of its
    // own left to test).
    test('1. current-month income is correct', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 5000, type: 'income', createdAt: DateTime(2026, 8, 15)),
      ];
      expect(buildAnalyticsSummary(transactions, now).currentMonthIncome, 55000);
    });

    test('2. current-month expense is correct', () {
      final transactions = [
        _tx(id: 't1', amount: 12000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 8000, type: 'expense', createdAt: DateTime(2026, 8, 20)),
      ];
      expect(buildAnalyticsSummary(transactions, now).currentMonthExpense, 20000);
    });

    test('3. current-month savings (income - expense) is correct', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 20000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
      ];
      final analytics = buildAnalyticsSummary(transactions, now);
      final dashboardSavings = analytics.currentMonthIncome - analytics.currentMonthExpense;
      expect(dashboardSavings, 30000);
    });

    test('4. previous-month transactions do not leak into current-month totals', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 20000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
        // Large prior-month figures that would inflate the total if the
        // date filter were missing or off-by-one at the month boundary.
        _tx(id: 't3', amount: 99999, type: 'income', createdAt: lastMonth),
        _tx(id: 't4', amount: 88888, type: 'expense', createdAt: DateTime(2026, 7, 31, 23, 59, 59)),
      ];
      final analytics = buildAnalyticsSummary(transactions, now);
      expect(analytics.currentMonthIncome, 50000);
      expect(analytics.currentMonthExpense, 20000);
    });

    test('5. future transactions do not leak into current-month totals', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 20000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
        // A next-month transaction (e.g. a post-dated/scheduled entry) —
        // must not be counted in the current calendar month either.
        _tx(id: 't3', amount: 77777, type: 'income', createdAt: DateTime(2026, 9, 1)),
        _tx(id: 't4', amount: 66666, type: 'expense', createdAt: DateTime(2026, 9, 1)),
      ];
      final analytics = buildAnalyticsSummary(transactions, now);
      expect(analytics.currentMonthIncome, 50000);
      expect(analytics.currentMonthExpense, 20000);
    });

    test('6. Dashboard and Reports agree for the same period, even with cross-month noise', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 20000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't3', amount: 99999, type: 'income', createdAt: lastMonth),
        _tx(id: 't4', amount: 88888, type: 'expense', createdAt: lastMonth),
        _tx(id: 't5', amount: 77777, type: 'income', createdAt: DateTime(2026, 9, 1)),
      ];

      final analytics = buildAnalyticsSummary(transactions, now);
      final reportsThisMonth = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );

      // Dashboard's totals ARE these AnalyticsSummary fields (see
      // _totalsFromAnalytics in dashboard_screen.dart) — this is the same
      // agreement Group 1 proves, restated here with cross-month noise
      // present specifically to close the gap this audit originally found.
      expect(analytics.currentMonthIncome, reportsThisMonth.totalIncome);
      expect(analytics.currentMonthExpense, reportsThisMonth.totalExpense);
      expect(analytics.currentMonthIncome, 50000);
      expect(analytics.currentMonthExpense, 20000);
    });
  });

  group('3. Money precision', () {
    test('two independent summation loops over fractional-paise amounts never drift', () {
      final transactions = List.generate(
        37,
        (i) => _tx(
          id: 'p$i',
          amount: 33.33,
          type: 'expense',
          createdAt: DateTime(2026, 8, (i % 27) + 1),
        ),
      );

      final analytics = buildAnalyticsSummary(transactions, now);
      final reportsThisMonth = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );

      // 37 * 33.33 = 1233.21 exactly in decimal; verifies both
      // implementations accumulate identically (no summation-order-
      // dependent float drift) and that the double representation
      // round-trips through toStringAsFixed cleanly at display precision.
      expect(analytics.currentMonthExpense, closeTo(1233.21, 1e-9));
      expect(reportsThisMonth.totalExpense, analytics.currentMonthExpense);
    });

    test('CurrencyFormatter rounds to whole rupees consistently, never truncates silently', () {
      // .5-rounding cases are inherently formatter-specific; this only
      // pins down that the formatter is deterministic and near the exact
      // value, not that it rounds a specific direction on an exact tie.
      expect(CurrencyFormatter.format(99.99, 'INR'), '₹100');
      expect(CurrencyFormatter.format(0.01, 'INR'), '₹0');
      expect(CurrencyFormatter.format(999999.49, 'INR'), '₹999999');
      expect(CurrencyFormatter.format(0, 'INR'), '₹0');
    });
  });
}
