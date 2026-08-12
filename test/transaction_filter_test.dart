import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/transaction_filters.dart';

Transaction _tx({
  required String id,
  required String title,
  required double amount,
  required String categoryId,
  required String accountId,
  required String transactionType,
  String note = '',
  required DateTime createdAt,
}) {
  return Transaction(
    id: id,
    title: title,
    amount: amount,
    categoryId: categoryId,
    accountId: accountId,
    transactionType: transactionType,
    paymentMethod: '',
    note: note,
    createdAt: createdAt,
  );
}

void main() {
  final now = DateTime(2026, 8, 12, 10, 0);

  final transactions = <Transaction>[
    _tx(
      id: 't1',
      title: 'Grocery run',
      amount: 1200,
      categoryId: 'Food',
      accountId: 'Cash',
      transactionType: 'expense',
      note: 'Weekly shopping',
      createdAt: now, // today
    ),
    _tx(
      id: 't2',
      title: 'Monthly salary',
      amount: 50000,
      categoryId: 'Salary',
      accountId: 'HDFC Salary',
      transactionType: 'income',
      createdAt: now.subtract(const Duration(days: 2)), // this week
    ),
    _tx(
      id: 't3',
      title: 'Movie night',
      amount: 600,
      categoryId: 'Entertainment',
      accountId: 'Cash',
      transactionType: 'expense',
      note: 'Fast food afterwards',
      createdAt: DateTime(2026, 8, 1), // this month, before this week
    ),
    _tx(
      id: 't4',
      title: 'Electricity bill',
      amount: 2500,
      categoryId: 'Utilities',
      accountId: 'HDFC Salary',
      transactionType: 'expense',
      createdAt: DateTime(2026, 7, 15), // last month
    ),
    _tx(
      id: 't5',
      title: 'Freelance payout',
      amount: 8000,
      categoryId: 'Freelance',
      accountId: 'Cash',
      transactionType: 'income',
      createdAt: DateTime(2026, 5, 1), // older than last month
    ),
  ];

  test('search matches description/title case-insensitively', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(searchQuery: 'GROCERY'),
      now: now,
    );
    expect(result.map((t) => t.id), ['t1']);
  });

  test('search matches category and note', () {
    final byCategory = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(searchQuery: 'food'),
      now: now,
    );
    // Matches t1 (categoryId 'Food') and t3 (note contains 'Fast food').
    expect(byCategory.map((t) => t.id).toSet(), {'t1', 't3'});
  });

  test('income filter returns only income transactions', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(type: TransactionTypeFilter.income),
      now: now,
    );
    expect(result.map((t) => t.id).toSet(), {'t2', 't5'});
  });

  test('expense filter returns only expense transactions', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(type: TransactionTypeFilter.expense),
      now: now,
    );
    expect(result.map((t) => t.id).toSet(), {'t1', 't3', 't4'});
  });

  test('category filter matches an exact category', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(category: 'Utilities'),
      now: now,
    );
    expect(result.map((t) => t.id), ['t4']);
  });

  test('date filter: today/this week/this month/last month', () {
    final today = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(dateRange: DateRangeFilter.today),
      now: now,
    );
    expect(today.map((t) => t.id), ['t1']);

    final thisWeek = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(dateRange: DateRangeFilter.thisWeek),
      now: now,
    );
    expect(thisWeek.map((t) => t.id).toSet(), {'t1', 't2'});

    final thisMonth = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(dateRange: DateRangeFilter.thisMonth),
      now: now,
    );
    expect(thisMonth.map((t) => t.id).toSet(), {'t1', 't2', 't3'});

    final lastMonth = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(dateRange: DateRangeFilter.lastMonth),
      now: now,
    );
    expect(lastMonth.map((t) => t.id), ['t4']);
  });

  test('custom date range filter is inclusive of both bounds', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      TransactionFilterState(
        dateRange: DateRangeFilter.custom,
        customStart: DateTime(2026, 7, 1),
        customEnd: DateTime(2026, 7, 31),
      ),
      now: now,
    );
    expect(result.map((t) => t.id), ['t4']);
  });

  test('account filter matches wallet name exactly', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(account: 'HDFC Salary'),
      now: now,
    );
    expect(result.map((t) => t.id).toSet(), {'t2', 't4'});
  });

  test('amount range filter respects min and max bounds', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(minAmount: 1000, maxAmount: 9000),
      now: now,
    );
    expect(result.map((t) => t.id).toSet(), {'t1', 't4', 't5'});
  });

  test('sorting: newest first, oldest first, highest and lowest amount', () {
    final newest = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(),
      now: now,
    );
    expect(newest.first.id, 't1');
    expect(newest.last.id, 't5');

    final oldest = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(sort: TransactionSortOption.oldestFirst),
      now: now,
    );
    expect(oldest.first.id, 't5');
    expect(oldest.last.id, 't1');

    final highest = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(sort: TransactionSortOption.highestAmount),
      now: now,
    );
    expect(highest.first.id, 't2');

    final lowest = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(sort: TransactionSortOption.lowestAmount),
      now: now,
    );
    expect(lowest.first.id, 't3');
  });

  test('combined filters: expense + category + amount + sort', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(
        type: TransactionTypeFilter.expense,
        account: 'Cash',
        maxAmount: 1500,
        sort: TransactionSortOption.lowestAmount,
      ),
      now: now,
    );
    expect(result.map((t) => t.id).toList(), ['t3', 't1']);
  });

  test('no matches returns an empty list', () {
    final result = TransactionFilterEngine.apply(
      transactions,
      const TransactionFilterState(searchQuery: 'nonexistent-term-xyz'),
      now: now,
    );
    expect(result, isEmpty);
  });
}
