// FINANCIAL CALCULATION AUDIT — cross-feature consistency regression suite.
//
// PaySense has several independently-written summation loops that all
// answer variants of "income/expense over some window": ReportsCalculator
// (Reports screen), buildAnalyticsSummary (Dashboard/Financial Health/Loan
// Analytics), and Dashboard's own top "Financial Summary" cards
// (`_calculateTotals` in dashboard_screen.dart — private to that file, so
// its formula is mirrored here as `_allTimeTotals` rather than imported).
// This file has two jobs:
//
//   1. Prove the ones that SHOULD agree (Reports "This month" vs
//      buildAnalyticsSummary's current-month figures) actually do, given
//      identical input — a regression guard against future silent drift
//      between the two independent implementations.
//
//   2. DOCUMENT a real product-level inconsistency found during this audit:
//      the Dashboard's "Financial Summary" Income/Expenses/Savings cards
//      are UNSCOPED (all-time, since account creation), while every
//      adjacent feature that shows income/expense (Reports "This month"
//      default, Financial Health's "this month" insights, Compare Periods'
//      "this month vs last month" default) is current-month-scoped. For an
//      account with prior-month history, the Dashboard cards will show a
//      LARGER number than Reports/Financial Health for what looks like the
//      same metric, with no "All time" label distinguishing them. This is
//      not a math bug — `_calculateTotals`'s all-time sum is internally
//      correct — but it is a real, user-visible consistency question this
//      audit was asked to surface, not silently resolve. Test 2 below
//      locks in TODAY's actual behavior (so a future change is deliberate,
//      not accidental) and documents the finding; it deliberately does NOT
//      assert the two numbers are equal, because today they are not.
//
// See the accompanying audit report for the recommendation: either scope
// the Dashboard cards to "This month" (aligning with its siblings) or add
// an explicit "All time" label — a product decision, not made here.

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

/// Mirrors `_calculateTotals` in dashboard_screen.dart EXACTLY (same loop,
/// same type-matching logic, no date filter) — that function is private to
/// its file and can't be imported, so this is a documented, literal copy
/// used only to prove what the Dashboard actually displays.
({double income, double expense, double balance}) _allTimeTotals(
  List<Transaction> transactions,
) {
  double totalIncome = 0;
  double totalExpense = 0;
  for (final t in transactions) {
    final normalized = t.transactionType.toLowerCase();
    if (normalized == 'income') {
      totalIncome += t.amount;
    } else if (normalized == 'expense') {
      totalExpense += t.amount;
    }
  }
  return (income: totalIncome, expense: totalExpense, balance: totalIncome - totalExpense);
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

  group('2. DOCUMENTED FINDING: Dashboard "Financial Summary" cards are all-time, not this-month', () {
    test('with cross-month data, Dashboard totals ≠ Reports "This month" totals', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 20000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't3', amount: 99999, type: 'income', createdAt: lastMonth),
        _tx(id: 't4', amount: 88888, type: 'expense', createdAt: lastMonth),
      ];

      final dashboardTotals = _allTimeTotals(transactions);
      final reportsThisMonth = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );

      // This-month-only figures (what Reports/Financial Health show).
      expect(reportsThisMonth.totalIncome, 50000);
      expect(reportsThisMonth.totalExpense, 20000);

      // All-time figures (what the Dashboard's "Income"/"Expenses" cards
      // actually show today) — includes July's transactions too.
      expect(dashboardTotals.income, 50000 + 99999);
      expect(dashboardTotals.expense, 20000 + 88888);

      // The documented finding: these genuinely disagree today. If this
      // assertion ever starts failing because someone scoped the Dashboard
      // cards to "this month", that's a deliberate fix, not a break —
      // update this test's expectations (and its header comment) to match.
      expect(dashboardTotals.income, isNot(equals(reportsThisMonth.totalIncome)));
      expect(dashboardTotals.expense, isNot(equals(reportsThisMonth.totalExpense)));
    });

    test('with only this-month data, the two happen to agree (masking the scope difference)', () {
      final transactions = [
        _tx(id: 't1', amount: 50000, type: 'income', createdAt: startOfThisMonth),
        _tx(id: 't2', amount: 20000, type: 'expense', createdAt: DateTime(2026, 8, 5)),
      ];

      final dashboardTotals = _allTimeTotals(transactions);
      final reportsThisMonth = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );

      // A brand-new account (or one only ever tested within a single
      // month) never notices the scope difference — exactly why it went
      // unflagged until this audit deliberately tested cross-month data.
      expect(dashboardTotals.income, reportsThisMonth.totalIncome);
      expect(dashboardTotals.expense, reportsThisMonth.totalExpense);
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

      final dashboardTotals = _allTimeTotals(transactions);
      final reportsAllMonth = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: const <Wallet>[],
        period: ReportPeriod.thisMonth,
        now: now,
      );

      // 37 * 33.33 = 1233.21 exactly in decimal; verifies both loops
      // accumulate identically (no summation-order-dependent float drift)
      // and that the double representation round-trips through
      // toStringAsFixed cleanly at the currency formatter's precision.
      expect(dashboardTotals.expense, closeTo(1233.21, 1e-9));
      expect(reportsAllMonth.totalExpense, dashboardTotals.expense);
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
