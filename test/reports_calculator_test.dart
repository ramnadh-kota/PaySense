import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/reports_calculator.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String categoryId,
  required String accountId,
  required String type,
  required DateTime createdAt,
  String title = '',
}) {
  return Transaction(
    id: id,
    title: title.isEmpty ? id : title,
    amount: amount,
    categoryId: categoryId,
    accountId: accountId,
    transactionType: type,
    paymentMethod: 'card',
    note: '',
    createdAt: createdAt,
  );
}

Wallet _wallet(String id, String name, {String bankName = ''}) {
  return Wallet(
    id: id,
    name: name,
    bankName: bankName,
    type: 'Bank',
    openingBalance: 0,
    currentBalance: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // A fixed "now" inside "this month" so every test is deterministic
  // regardless of when it actually runs.
  final now = DateTime(2026, 8, 15);
  final wallets = [_wallet('w1', 'Wallet 1'), _wallet('w2', 'Wallet 2')];

  ReportsResult calc(
    List<Transaction> transactions, {
    ReportPeriod period = ReportPeriod.thisMonth,
    List<Wallet>? withWallets,
  }) {
    return ReportsCalculator.calculate(
      transactions: transactions,
      wallets: withWallets ?? wallets,
      period: period,
      now: now,
    );
  }

  group('Financial summary', () {
    test('1. income calculation sums only income transactions in the period', () {
      final result = calc([
        _tx(id: 't1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 500, categoryId: 'Bonus', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 10)),
        _tx(id: 't3', amount: 200, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 10)),
      ]);
      expect(result.totalIncome, 1500);
    });

    test('2. expense calculation sums only expense transactions in the period', () {
      final result = calc([
        _tx(id: 't1', amount: 300, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 200, categoryId: 'Transport', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 10)),
        _tx(id: 't3', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 10)),
      ]);
      expect(result.totalExpense, 500);
    });

    test('3. net cash flow is income minus expense', () {
      final result = calc([
        _tx(id: 't1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 400, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 10)),
      ]);
      expect(result.netCashFlow, 600);
    });

    test('4. savings rate is (income - expense) / income * 100', () {
      final result = calc([
        _tx(id: 't1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 750, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 10)),
      ]);
      expect(result.savingsRate, 25.0);
    });

    test('5. zero income never divides by zero — savingsRate is null, not NaN/Infinity', () {
      final result = calc([
        _tx(id: 't1', amount: 300, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
      ]);
      expect(result.totalIncome, 0);
      expect(result.savingsRate, isNull);
    });
  });

  group('Category spending', () {
    test('6. transactions are grouped by categoryId', () {
      final result = calc([
        _tx(id: 't1', amount: 300, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 200, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 6)),
        _tx(id: 't3', amount: 150, categoryId: 'Transport', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 7)),
      ]);
      final food = result.categoryBreakdown.firstWhere((c) => c.categoryId == 'Food');
      final transport = result.categoryBreakdown.firstWhere((c) => c.categoryId == 'Transport');
      expect(food.amount, 500);
      expect(transport.amount, 150);
      // highest spending first
      expect(result.categoryBreakdown.first.categoryId, 'Food');
    });

    test('7. category percentages are of total expenses and sum to ~100%', () {
      final result = calc([
        _tx(id: 't1', amount: 8500, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 4200, categoryId: 'Transport', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 6)),
        _tx(id: 't3', amount: 3700, categoryId: 'Shopping', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 7)),
      ]);
      final total = result.categoryBreakdown.fold<double>(0, (s, c) => s + c.percentage);
      expect(total, closeTo(100, 0.01));
      expect(result.categoryBreakdown[0].categoryId, 'Food');
      expect(result.categoryBreakdown[0].percentage, closeTo(51.5, 0.5));
    });
  });

  group('Top expenses', () {
    test('8. top expenses are sorted highest amount first, with correct fields', () {
      final result = calc([
        _tx(id: 't1', amount: 200, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5), title: 'Groceries'),
        _tx(id: 't2', amount: 5000, categoryId: 'Electronics', accountId: 'w2', type: 'expense', createdAt: DateTime(2026, 8, 6), title: 'Laptop'),
        _tx(id: 't3', amount: 1000, categoryId: 'Transport', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 7), title: 'Cab'),
      ]);
      expect(result.topExpenses.first.title, 'Laptop');
      expect(result.topExpenses.first.amount, 5000);
      expect(result.topExpenses.first.walletId, 'w2');
      expect(result.topExpenses.first.walletName, 'Wallet 2');
      expect(result.topExpenses.map((e) => e.amount), [5000, 1000, 200]);
    });

    test('top expenses list is limited to 5', () {
      final transactions = List.generate(
        8,
        (i) => _tx(
          id: 't$i',
          amount: (i + 1) * 100,
          categoryId: 'Misc',
          accountId: 'w1',
          type: 'expense',
          createdAt: DateTime(2026, 8, 5 + i),
        ),
      );
      final result = calc(transactions);
      expect(result.topExpenses, hasLength(5));
      expect(result.topExpenses.first.amount, 800);
    });
  });

  group('Wallet analysis', () {
    test('9. per-wallet income is summed using accountId == wallet.id', () {
      final result = calc([
        _tx(id: 't1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 500, categoryId: 'Salary', accountId: 'w2', type: 'income', createdAt: DateTime(2026, 8, 6)),
      ]);
      final w1 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w1');
      final w2 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w2');
      expect(w1.income, 1000);
      expect(w2.income, 500);
    });

    test('10. per-wallet expense is summed using accountId == wallet.id', () {
      final result = calc([
        _tx(id: 't1', amount: 300, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 700, categoryId: 'Food', accountId: 'w2', type: 'expense', createdAt: DateTime(2026, 8, 6)),
      ]);
      final w1 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w1');
      final w2 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w2');
      expect(w1.expense, 300);
      expect(w2.expense, 700);
    });

    test('11. wallet net movement is income minus expense for that wallet', () {
      final result = calc([
        _tx(id: 't1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 300, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 6)),
      ]);
      final w1 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w1');
      expect(w1.net, 700);
    });

    test(
      '12. a transfer never counts as income/expense, even though it '
      'appears in both wallets\' history',
      () {
        final result = calc([
          Transaction(
            id: 'transfer-out',
            title: 'Transfer to Wallet 2',
            amount: 500,
            categoryId: 'Transfer',
            accountId: 'w1',
            transactionType: 'transfer',
            paymentMethod: 'transfer',
            note: '',
            createdAt: DateTime(2026, 8, 5),
            transferId: 'tr1',
            transferCounterpartyWalletId: 'w2',
          ),
          Transaction(
            id: 'transfer-in',
            title: 'Transfer from Wallet 1',
            amount: 500,
            categoryId: 'Transfer',
            accountId: 'w2',
            transactionType: 'transfer',
            paymentMethod: 'transfer',
            note: '',
            createdAt: DateTime(2026, 8, 5),
            transferId: 'tr1',
            transferCounterpartyWalletId: 'w1',
          ),
        ]);
        expect(result.totalIncome, 0);
        expect(result.totalExpense, 0);
        final w1 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w1');
        final w2 = result.walletBreakdown.firstWhere((w) => w.walletId == 'w2');
        expect(w1.income, 0);
        expect(w1.expense, 0);
        expect(w2.income, 0);
        expect(w2.expense, 0);
        // The transfer transactions still exist but aren't income/expense.
        expect(result.hasAnyTransactions, isFalse);
      },
    );
  });

  group('Month-over-month comparison', () {
    test('13. current vs previous month totals are computed correctly', () {
      final result = calc([
        _tx(id: 'cur1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 'cur2', amount: 400, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 6)),
        _tx(id: 'prev1', amount: 800, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 7, 5)),
        _tx(id: 'prev2', amount: 300, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 7, 6)),
      ]);
      expect(result.comparison.currentIncome, 1000);
      expect(result.comparison.previousIncome, 800);
      expect(result.comparison.currentExpense, 400);
      expect(result.comparison.previousExpense, 300);
    });

    test('14. a positive income change is a positive percentage', () {
      final result = calc([
        _tx(id: 'cur1', amount: 1200, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 'prev1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 7, 5)),
      ]);
      expect(result.comparison.incomeChange.percentage, closeTo(20, 0.01));
    });

    test('15. an increased expense is a positive percentage change', () {
      final result = calc([
        _tx(id: 'cur1', amount: 590, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 'prev1', amount: 500, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 7, 5)),
      ]);
      expect(result.comparison.expenseChange.percentage, closeTo(18, 0.01));
    });

    test('16. a decreased expense is a negative percentage change', () {
      final result = calc([
        _tx(id: 'cur1', amount: 400, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 'prev1', amount: 500, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 7, 5)),
      ]);
      expect(result.comparison.expenseChange.percentage, closeTo(-20, 0.01));
    });

    test(
      '17. a zero previous-period value is handled safely — never an '
      'infinite/NaN percentage, flagged as "new" instead',
      () {
        final result = calc([
          _tx(id: 'cur1', amount: 500, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        ]);
        final change = result.comparison.expenseChange;
        expect(change.percentage, isNull);
        expect(change.isNew, isTrue);
        expect(change.percentage?.isNaN ?? false, isFalse);
        expect(change.percentage?.isInfinite ?? false, isFalse);
      },
    );
  });

  group('Empty and partial data', () {
    test('18. no transactions at all produces a safe, non-fabricated empty result', () {
      final result = calc([]);
      expect(result.hasAnyTransactions, isFalse);
      expect(result.totalIncome, 0);
      expect(result.totalExpense, 0);
      expect(result.netCashFlow, 0);
      expect(result.savingsRate, isNull);
      expect(result.categoryBreakdown, isEmpty);
      expect(result.topExpenses, isEmpty);
      expect(result.insights, isEmpty);
    });

    test('19. income-only data: savings rate is 100%, no expense categories', () {
      final result = calc([
        _tx(id: 't1', amount: 1000, categoryId: 'Salary', accountId: 'w1', type: 'income', createdAt: DateTime(2026, 8, 5)),
      ]);
      expect(result.hasIncome, isTrue);
      expect(result.hasExpense, isFalse);
      expect(result.savingsRate, 100.0);
      expect(result.categoryBreakdown, isEmpty);
      expect(result.topExpenses, isEmpty);
    });

    test('20. expense-only data: savings rate is null (no income to divide by)', () {
      final result = calc([
        _tx(id: 't1', amount: 500, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
      ]);
      expect(result.hasIncome, isFalse);
      expect(result.hasExpense, isTrue);
      expect(result.savingsRate, isNull);
      expect(result.categoryBreakdown, isNotEmpty);
    });
  });

  group('Multiple wallets/categories and date handling', () {
    test('21. multiple wallets remain distinguishable in the breakdown', () {
      final threeWallets = [
        _wallet('w1', 'Wallet A'),
        _wallet('w2', 'Wallet B'),
        _wallet('w3', 'Wallet C'),
      ];
      final result = calc([
        _tx(id: 't1', amount: 100, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 200, categoryId: 'Food', accountId: 'w2', type: 'expense', createdAt: DateTime(2026, 8, 6)),
        _tx(id: 't3', amount: 300, categoryId: 'Food', accountId: 'w3', type: 'expense', createdAt: DateTime(2026, 8, 7)),
      ], withWallets: threeWallets);
      expect(result.walletBreakdown, hasLength(3));
      expect(result.walletBreakdown.map((w) => w.expense).toSet(), {100.0, 200.0, 300.0});
    });

    test('22. multiple categories all appear, sorted by highest spend first', () {
      final result = calc([
        _tx(id: 't1', amount: 100, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 5)),
        _tx(id: 't2', amount: 400, categoryId: 'Rent', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 6)),
        _tx(id: 't3', amount: 250, categoryId: 'Transport', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 8, 7)),
      ]);
      expect(result.categoryBreakdown.map((c) => c.categoryId).toList(), ['Rent', 'Transport', 'Food']);
    });

    test('23. date range boundaries: the range start is included, the range end is excluded', () {
      final range = ReportsCalculator.dateRangeFor(ReportPeriod.thisMonth, now);
      final result = calc([
        _tx(id: 'start', amount: 100, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: range.start),
        _tx(id: 'end', amount: 200, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: range.end),
      ]);
      // Only the transaction exactly at `start` is in-period; the one
      // exactly at `end` belongs to the following month.
      expect(result.totalExpense, 100);
    });

    test('24. selected-period filtering excludes transactions outside a wider window', () {
      final result = calc([
        _tx(id: 'in', amount: 500, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 7, 1)),
        _tx(id: 'out', amount: 999, categoryId: 'Food', accountId: 'w1', type: 'expense', createdAt: DateTime(2026, 3, 1)),
      ], period: ReportPeriod.last3Months);
      // "3 months" from Aug 2026 covers Jun/Jul/Aug — March is excluded.
      expect(result.totalExpense, 500);
    });
  });
}
